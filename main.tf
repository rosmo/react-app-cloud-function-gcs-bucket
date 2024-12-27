# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module "project" {
  source         = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/project?ref=daily-2024.12.20"
  name           = var.project_id
  project_create = false
  services = [
    "compute.googleapis.com",
    "cloudfunctions.googleapis.com",
    "run.googleapis.com",
  ]
}

locals {
  mime_types = {
    "\\.js$"     = "text/javascript"
    "\\.js.map$" = "application/json"
    "\\.html$"   = "text/html"
    "\\.png$"    = "image/png"
    "\\.jpg$"    = "image/jpeg"
    "\\.jpeg$"   = "image/jpeg"
    "\\.txt$"    = "text/plain"
    "\\.json$"   = "application/json"
    "\\.ico$"    = "image/vnd.microsoft.icon."
    "\\.css$"    = "text/css"
    "\\.svg$"    = "image/svg+xml"
    ".*"         = "application/octet-stream"
  }
  app_path = format("%s/my-app/dist", path.module)

  # Collect all assets and hashes from webpack build
  asset_manifest = jsondecode(file(format("%s/assets-manifest.json", local.app_path)))

  # Determine which extensions go to what CSP tag
  integrity_assets = {
    ".css" = "style-src",
    ".js"  = "script-src"
  }

  # Build a list of assets
  assets = { for f in fileset(local.app_path, "**") : filesha256(format("%s/%s", local.app_path, f)) =>
    {
      name            = replace(f, local.app_path, "")
      source          = f
      integrity_class = try(element([for ext, cls in local.integrity_assets : cls if endswith(f, ext)], 0), "")
      integrity_hash  = try(element(split(" ", local.asset_manifest[replace(f, "${local.app_path}/", "")].integrity), 1), "")
    }
  }

  # Create CSP header
  csp_settings = {
    "script-src" = compact([for k, v in local.assets : format("'%s'", v.integrity_hash) if v.integrity_hash != "" && v.integrity_class == "script-src"])
    "style-src"  = compact([for k, v in local.assets : format("'%s'", v.integrity_hash) if v.integrity_hash != "" && v.integrity_class == "style-src"])
  }

  # The CSP header
  # (Please note that using hashes for styles does not seem to be supported for stylesheets, 
  # at least on Chrome - Safari seems to understand style-src. This is why 'self' is included in style-src.)
  csp_header = format("default-src 'none'; base-uri 'self'; connect-src 'self'; img-src 'self'; manifest-src 'self'; script-src-elem %s; style-src-elem 'self' %s; script-src %s; style-src 'self' %s;", join(" ", local.csp_settings["script-src"]), join(" ", local.csp_settings["style-src"]), join(" ", local.csp_settings["script-src"]), join(" ", local.csp_settings["style-src"]))
}

resource "random_string" "random" {
  count   = var.bucket_random_suffix == true ? 1 : 0
  length  = 8
  lower   = true
  upper   = false
  numeric = true
  special = false
}

module "bucket" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/gcs?ref=daily-2024.12.20"
  project_id = module.project.project_id
  name       = var.bucket_random_suffix == true ? format("%s-%s", var.bucket_name, random_string.random.0.result) : var.bucket_name
  location   = var.region
  versioning = false
  labels     = {}

  iam = {
    "roles/storage.objectViewer" = ["allUsers"]
  }

  website = {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
}

module "service-account" {
  source            = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account?ref=daily-2024.12.20"
  project_id        = module.project.project_id
  name              = var.backend_service_account
  iam_project_roles = {}
}

module "build-bucket" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/gcs?ref=daily-2024.12.20"
  project_id = module.project.project_id
  name       = var.bucket_random_suffix == true ? format("%s-%s", var.build_bucket_name, random_string.random.0.result) : var.build_bucket_name
  location   = var.region
  versioning = false
  labels     = {}

  iam = {
    "roles/storage.objectViewer" = [format("serviceAccount:%d-compute@developer.gserviceaccount.com", module.project.number)]
  }
}

resource "google_storage_bucket_object" "objects" {
  for_each = local.assets

  bucket       = module.bucket.id
  name         = each.value.name
  source       = format("%s/my-app/dist/%s", path.module, each.value.source)
  content_type = element(reverse([for ext, mime in local.mime_types : mime if length(regexall(ext, each.value.name)) > 0]), 0)

  # For development, in production you may want a longer caching period
  cache_control = "public, max-age=0, s-maxage=0"
}

module "backend" {
  source      = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/cloud-function-v2?ref=daily-2024.12.20"
  project_id  = module.project.project_id
  region      = var.region
  name        = var.backend_function_name
  bucket_name = module.build-bucket.name

  service_account = module.service-account.email

  function_config = {
    entry_point = "hello_function"
  }
  bundle_config = {
    path = format("%s/backend", path.module)
  }

  iam = {
    "roles/run.invoker" = ["allUsers"]
  }
}
