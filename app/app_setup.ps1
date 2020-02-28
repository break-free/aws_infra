$PROJECT_NAME = $args[0]
$REGION=$args[1]

#   Create main.tf
$BUCKET_TERRAFORM = get-content .\bucket_template.txt

$BUCKET_TERRAFORM -replace 'default_project_name', "$PROJECT_NAME" -replace 'default_region', "$REGION"| out-file -encoding utf8 .\main.tf

#   Create terraform.tfvars
$VARIABLES_TERRAFORM = get-content .\variables_template.txt

$VARIABLES_TERRAFORM -replace 'default_project_name', "$PROJECT_NAME" -replace 'default_region', "$REGION" | out-file -encoding utf8 .\terraform.tfvars

