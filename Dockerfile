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

FROM node:23-alpine AS build
WORKDIR /src

# Copy things one by one to avoid local dev files
COPY my-app/*.json .
COPY my-app/*.js .
COPY my-app/src src
COPY my-app/public public

# Install build dependencies
RUN npm install

# Build the application
RUN npm run build

# Build the actual image
FROM nginx:mainline-alpine

# Nginx will listen on port 80 by default
ENV NGINX_PORT="${PORT:-8080}"
RUN mkdir /etc/nginx/templates
# Use Nginx image envsubst functionality to set the listening port to satisfy Cloud Run
COPY default.conf.template /etc/nginx/templates/default.conf.template
RUN rm /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist/* /usr/share/nginx/html

