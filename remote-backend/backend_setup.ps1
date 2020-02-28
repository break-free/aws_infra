$PROJECT_NAME = $args[0]
$LOCATION=$args[1]


$BUCKET_TERRAFORM = get-content .\bucket_template.txt

$BUCKET_TERRAFORM -replace 'default_project_name', "$PROJECT_NAME" -replace 'default_app_state', "$STORAGE_ACCOUNT_NAME" -replace 'default_region', "$region"| out-file -encoding utf8 .\main.tf

