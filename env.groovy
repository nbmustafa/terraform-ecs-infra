env.SERVICE_NAME='xyz'
env.APP_NAME='abc'
env.APP_ID = "APID001"


//AWS SETTINGS
env.aws_account_id=sh(script:"aws sts get-caller-identity --output text --query 'Account'",returnStdout: true).trim()

//PROXY SETTINGS
env.AUTH_API = 'http://localhost:8000'
env.http_proxy = 'http://'
env.https_proxy = 'http://'
env.NO_PROXY = "${NO_PROXY},.s3.ap-southeast-2.amazonaws.com,localhost,169.254.169.254,169.254.170.2"
env.no_proxy = "${no_proxy},.s3.ap-southeast-2.amazonaws.com,localhost,169.254.169.254,169.254.170.2"

//Terraform Backend Variables

if (params.EnvironmentName == 'ppte') {
    env.BUCKET_NAME = 'ppte-terraform-state'
    env.DYNAMODB_TABLE = "ppte-terraform-locking-table"
}
else if (params.EnvironmentName == 'prod') {
    env.BUCKET_NAME = 'prod-terraform-state'
    env.DYNAMODB_TABLE = "prod-terraform-locking-table"
}
else {
    env.BUCKET_NAME = 'dev-terraform-state'
    env.DYNAMODB_TABLE = "dev-terraform-locking-table"
}

env.KEY = "${env.SERVICE_NAME}-${env.APP_NAME}-${env.ENVIRONMENT}-infra-state"