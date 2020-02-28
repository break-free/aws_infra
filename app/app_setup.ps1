$PROJECT_NAME = $args[0]
$REGION=$args[1]

#   Create main.tf
$MAIN_TERRAFORM = get-content .\app_template.txt

$MAIN_TERRAFORM -replace 'default_project_name', "$PROJECT_NAME" -replace 'default_region', "$REGION"| out-file -encoding utf8 .\main.tf

#   Create terraform.tfvars
$APP_VARIABLES_TERRAFORM = get-content .\app_variables_template.txt

$APP_VARIABLES_TERRAFORM -replace 'default_project_name', "$PROJECT_NAME" -replace 'default_region', "$REGION" | out-file -encoding utf8 .\terraform.tfvars

