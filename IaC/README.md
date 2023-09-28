1. define files 
- main.tf: setup IaC (see more in terraform_overview.md)
- variable.tf: define variables
- terraform.tfvars: assign variable value

2. Initialize state file (.tfstate)
terraform init

3. Have a dry run to see what will it do
terraform plan 

4. Apply it and create IaC 
terraform apply


# List all the resources
terraform state list

# Destroy the resource you want
terraform destroy -target <resourcetype.name>

# Advanced
resources are no longer tracked by terraform, not destroy itself
- terraform state rm <resourcetype.name>
