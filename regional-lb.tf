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

module "vpc" {
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-vpc?ref=daily-2024.12.20"
  project_id = var.vpc_config.network_project != null ? var.vpc_config.network_project : module.project.project_id
  name       = var.vpc_config.network

  subnets = [
    {
      ip_cidr_range = var.vpc_config.subnet_cidr
      name          = var.vpc_config.subnetwork
      region        = var.region
      iam           = {}
    }
  ]

  subnets_proxy_only = [
    {
      ip_cidr_range = var.vpc_config.proxy_only_subnet_cidr
      name          = var.vpc_config.proxy_only_subnetwork
      region        = var.region
      active        = true
    }
  ]

  vpc_create = var.vpc_config.create
}

# Unprivileged service account
module "gcs-reverse-proxy-service-account" {
  for_each = toset(var.regional_lb ? [""] : [])

  source            = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account?ref=daily-2024.12.20"
  project_id        = module.project.project_id
  name              = format("%s-gcsproxy", var.backend_service_account)
  iam_project_roles = {}
}

# GCS reverse proxy function
module "gcs-reverse-proxy" {
  for_each = toset(var.regional_lb ? [""] : [])

  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/cloud-run-v2?ref=daily-2024.12.20"
  project_id = module.project.project_id
  region     = var.region
  name       = format("%s-gcsproxy", var.backend_function_name)

  service_account     = module.gcs-reverse-proxy-service-account[""].email
  deletion_protection = false

  containers = {
    nginx = {
      image = "gcr.io/cloud-marketplace/google/nginx1:1.26" # or :latest
      ports = {
        http = {
          container_port = "8080"
          name           = "h2c"
        }
      }
      volume_mounts = {
        "nginx-conf" = "/etc/nginx/conf.d/"
      }
    }
  }

  volumes = {
    nginx-conf = {
      secret = {
        name    = module.nginx-conf[""].secrets["nginx-conf-auto"].id
        path    = "default.conf"
        version = "latest"
      }
    }
  }

  iam = {
    "roles/run.invoker" = ["allUsers"]
  }
}

module "nginx-conf" {
  for_each = toset(var.regional_lb ? [""] : [])

  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/secret-manager?ref=daily-2024.12.20"
  project_id = module.project.project_id
  secrets = {
    nginx-conf-auto = {}
  }
  versions = {
    nginx-conf-auto = {
      v1 = {
        enabled = true
        data    = <<-EOT
          server {
            listen 8080 http2; 
            server_name _;
            gzip on;

            location / {
                proxy_pass   https://storage.googleapis.com/${module.bucket.name}/;
            }
          }
        EOT
      }
    }
  }

  iam = {
    nginx-conf-auto = {
      #"roles/secretmanager.secretAccessor" = [module.project.service_agents["run"].iam_email]
      "roles/secretmanager.secretAccessor" = [module.gcs-reverse-proxy-service-account[""].iam_email]
    }
  }
}

module "xlb-regional" {
  for_each   = toset(var.regional_lb ? [""] : [])
  source     = "github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-lb-app-ext-regional?ref=daily-2024.12.20"
  project_id = module.project.project_id
  name       = format("%s-%s", var.xlb_name, var.region)

  vpc    = module.vpc.self_link
  region = var.region

  backend_service_configs = {
    regional-python-backend = {
      backends = [
        { backend = "regional-python-backend-neg" },
      ]
      health_checks = []
      port_name     = "http"
    }
    regional-gcs-proxy-backend = {
      backends = [
        { backend = "regional-gcs-proxy-backend-neg" },
      ]
      health_checks = []
      port_name     = "http"
    }
  }

  health_check_configs = {}

  urlmap_config = {
    default_service = "regional-gcs-proxy-backend"
    host_rules = [{
      hosts        = ["*"]
      path_matcher = "api"
    }]
    path_matchers = {
      api = {
        default_service = "regional-gcs-proxy-backend"
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
            service  = "regional-python-backend"
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
                  value = "/*.js"
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
            service  = "regional-gcs-proxy-backend"
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
            service  = "regional-gcs-proxy-backend"
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
    regional-python-backend-neg = {
      cloudrun = {
        region = var.region
        target_service = {
          name = module.backend.function_name
        }
      }
    }
    regional-gcs-proxy-backend-neg = {
      cloudrun = {
        region = var.region
        target_service = {
          name = module.gcs-reverse-proxy[""].service_name
        }
      }
    }
  }
}

