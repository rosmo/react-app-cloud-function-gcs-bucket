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

variable "project_id" {
  type        = string
  description = "Google Cloud project ID"
}

variable "region" {
  type        = string
  description = "Region where to deploy the function and resources"
}

variable "bucket_name" {
  type        = string
  description = "Bucket name for the React app frontend"
  default     = "my-react-app"
}

variable "bucket_random_suffix" {
  type        = bool
  description = "Add random string to bucket suffix"
  default     = true
}

variable "build_bucket_name" {
  type        = string
  description = "Bucket name for building Cloud Functions v2"
  default     = "my-react-app-build"
}

variable "xlb_name" {
  type        = string
  description = "External Application Load Balancer name"
  default     = "my-react-app"
}

variable "backend_function_name" {
  type        = string
  description = "Name of the Cloud Function for the backend"
  default     = "my-react-app-backend"
}

variable "backend_service_account" {
  type        = string
  description = "Service account to use for backend"
  default     = "my-react-app-backend"
}

variable "global_lb" {
  type        = bool
  description = "Deploy a global load balancer"
  default     = true
}

variable "regional_lb" {
  type        = bool
  description = "Deploy a regional load balancer"
  default     = false
}

variable "vpc_config" {
  type = object({
    network                = string
    network_project        = optional(string)
    subnetwork             = string
    subnet_cidr            = optional(string, "172.20.20.0/24")
    proxy_only_subnetwork  = string
    proxy_only_subnet_cidr = optional(string, "172.20.30.0/24")
    create                 = optional(bool, true)
  })
  description = "Settings for VPC (required when deploying a Regional XLB)"
  default = {
    network               = "my-react-app-vpc"
    subnetwork            = "my-react-app-vpc-subnet"
    proxy_only_subnetwork = "my-react-app-vpc-proxy-subnet"
  }
}
