# Sample React app on Cloud Run + Cloud Storage

## How the app was created

1) `npx create-react-app my-app`
2) Move static stuff (images, CSS, JS) into `my-app/public/static` to simplify path rules
3) Add `homepage` to `my-app/package.json`.
4) Create a simple [`Dockerfile`](Dockerfile)

## How to deploy

First, lets create the Terraform variables in `terraform.tfvars`:

```
# vi terraform.tfvars
project_id="my-project-id"
region="europe-west4"
```

Then build the application (this creates the required `my-app/build` directory):
```sh
# cd my-app && npm run build
```

Now, we should be able to deploy the solution with:

```sh
# terraform init
# terraform apply
```

The load balancer will take a while to get programmed and after a couple minutes, you should
be able to use the application via the provisioned load balancer!

