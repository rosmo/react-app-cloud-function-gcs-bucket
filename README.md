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

