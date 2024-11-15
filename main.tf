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
  source         = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/project?ref=daily-2024.11.15"
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
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/gcs?ref=daily-2024.11.15"
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
  source            = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account?ref=daily-2024.11.15"
  project_id        = module.project.project_id
  name              = var.backend_service_account
  iam_project_roles = {}
}

module "build-bucket" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/gcs?ref=daily-2024.11.15"
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
  for_each = { for f in fileset(format("%s/my-app/build/", path.module), "**") : f => {
    name   = replace(f, format("%s/my-app/build/", path.module), "")
    source = f
  } }

  bucket       = module.bucket.id
  name         = each.value.name
  source       = format("%s/my-app/build/%s", path.module, each.value.source)
  content_type = element(reverse([for ext, mime in local.mime_types : mime if length(regexall(ext, each.key)) > 0]), 0)

  # For development, in production you may want a longer caching period
  cache_control = "public, max-age=0, s-maxage=0"
}

module "xlb" {
  source              = "./modules/net-lb-app-ext"
  project_id          = module.project.project_id
  name                = var.xlb_name
  use_classic_version = false
  backend_service_configs = {
    python-backend = {
      backends = [
        { backend = "python-backend-neg" },
      ]
      health_checks = []
      port_name     = "http"
    }
  }
  backend_buckets_config = {
    gcs-static = {
      bucket_name = module.bucket.name
    }
  }
  health_check_configs = {}

  urlmap_config = {
    default_service = "gcs-static"
    host_rules = [{
      hosts        = ["*"]
      path_matcher = "api"
    }]
    path_matchers = {
      api = {
        default_service = "gcs-static"
        route_rules = [
          {
            description = "Send all backend traffic to our Cloud Function"
            match_rules = [
              {
                path = {
                  value = "/api/"
                  type  = "prefix"
                }
              }
            ]
            service  = "python-backend"
            priority = 50
          },
          {
            description = "Passthrough all static assets to the bucket"
            match_rules = [
              {
                path = {
                  value = "/*.ico"
                  type  = "template"
                }
              },
              {
                path = {
                  value = "/*.png"
                  type  = "template"
                }
              },
              {
                path = {
                  value = "/*.json"
                  type  = "template"
                }
              },
              {
                path = {
                  value = "/*.txt"
                  type  = "template"
                }
              },
              {
                path = {
                  value = "/static/"
                  type  = "prefix"
                }
              }
            ]
            service  = "gcs-static"
            priority = 60
          },
          {
            description = "Rewrite all non-static requests to index.html"
            match_rules = [
              {
                path = {
                  value = "/**"
                  type  = "template"
                }
              }
            ]
            service  = "gcs-static"
            priority = 100
            route_action = {
              url_rewrite = {
                path_template = "/index.html"
              }
            }
          }
        ]
      }
    }
  }

  neg_configs = {
    python-backend-neg = {
      cloudrun = {
        region = var.region
        target_service = {
          name = module.backend.function_name
        }
      }
    }
  }
}

module "backend" {
  source      = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/cloud-function-v2?ref=daily-2024.11.15"
  project_id  = module.project.project_id
  region      = var.region
  name        = var.backend_function_name
  bucket_name = module.build-bucket.name

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
