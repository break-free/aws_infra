$PROJECT_NAME = $args[0]
$REGION=$args[1]

#   Create main.tf
$MAIN_TERRAFORM = get-content .\terraform_template.txt

$MAIN_TERRAFORM -replace 'default_project_name', "$PROJECT_NAME" -replace 'default_region', "$REGION"| out-file -encoding utf8 .\main.tf

#   Create terraform.tfvars
$VARIABLES_TERRAFORM = get-content .\variables_template.txt

$VARIABLES_TERRAFORM -replace 'default_project_name', "$PROJECT_NAME" -replace 'default_region', "$REGION" | out-file -encoding utf8 .\terraform.tfvars

