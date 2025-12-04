resource "aws_secretsmanager_secret" "lambda_secrets" {
  name = "${var.project_prefix}-lambda-secrets"
}

resource "aws_secretsmanager_secret_version" "lambda_secrets_value" {
  secret_id     = aws_secretsmanager_secret.lambda_secrets.id
  secret_string = jsonencode(var.lambda_secret_values)
}

