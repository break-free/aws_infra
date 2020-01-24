# Create a Bucket

aws s3api create-bucket --bucket ${AWS_TFSATE_BUCKET_NAME} --region ${AWS_DEFAULT_REGION} --create-bucket-configuration LocationConstraint=${AWS_DEFAULT_REGION}

# Create Encryption for this Bucket

aws s3api put-bucket-encryption --bucket ${AWS_TFSATE_BUCKET_NAME} --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'

# Apply Bucket Policy to your Terraform IAM user

1) Navigate to the "bucket_policy" directory

2) Replace all instances of "rdtfstate" with the name of your bucket

3) 



# Then configure Terraform to use it if you already have local state

terraform init -reconfigure -backend-config="bucket="${AWS_TFSATE_BUCKET_NAME}"" -backend-config="key="${SERVICE_NAME}""



get-bucket-policy --bucket ${AWS_TFSATE_BUCKET_NAME}