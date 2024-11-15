# Sample React app on Cloud Run + Cloud Storage

## How the app was created

1) `npx create-react-app my-app`
2) Add `homepage` to `my-app/package.json`.

## How to deploy

First, lets create the Terraform variables in `terraform.tfvars`:

```
# vi terraform.tfvars
project_id="my-project-id"
region="europe-west4"
```

Then build the application (this creates the required `my-app/build` directory):
```sh
# cd my-app && npm run build && cd ..
```

Now, we should be able to deploy the solution with:

```sh
# terraform init
# terraform apply
```

The load balancer will take a while to get programmed and after a couple minutes, you should
be able to use the application via the provisioned load balancer!

## Resulting URL map

```
creationTimestamp: '2024-11-15T05:18:04.603-08:00'
defaultService: https://www.googleapis.com/compute/v1/projects/my-project/global/backendBuckets/my-react-app-gcs-static
description: Terraform managed.
fingerprint: Y2nfiuvf-BM=
hostRules:
- hosts:
  - '*'
  pathMatcher: api
id: '1234567890'
kind: compute#urlMap
name: my-react-app
pathMatchers:
- defaultService: https://www.googleapis.com/compute/v1/projects/my-project/global/backendBuckets/my-react-app-gcs-static
  name: api
  routeRules:
  - matchRules:
    - prefixMatch: /api/
    priority: 50
    service: https://www.googleapis.com/compute/v1/projects/my-project/global/backendServices/my-react-app-python-backend
  - matchRules:
    - prefixMatch: /static/
    - pathTemplateMatch: /*.ico
    - pathTemplateMatch: /*.json
    - pathTemplateMatch: /*.png
    - pathTemplateMatch: /*.txt
    priority: 60
    service: https://www.googleapis.com/compute/v1/projects/my-project/global/backendBuckets/my-react-app-gcs-static
  - matchRules:
    - pathTemplateMatch: /**
    priority: 100
    routeAction:
      urlRewrite:
        pathTemplateRewrite: /index.html
    service: https://www.googleapis.com/compute/v1/projects/my-project/global/backendBuckets/my-react-app-gcs-static
selfLink: https://www.googleapis.com/compute/v1/projects/my-project/global/urlMaps/my-react-app
```
