provider "aws" {
  region  = "us-east-1"
  version = "~> 2.11"
}

resource "aws_lambda_function" "lambda" {
  filename         = "lambda.zip"
  function_name    = "rumrunner-example"
  handler          = "lambda.handler"
  role             = "rumrunner"
  runtime          = "ruby2.5"
  source_code_hash = filebase64sha256("lambda.zip")
}
