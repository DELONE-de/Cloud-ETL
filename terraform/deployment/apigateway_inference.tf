# modules/api_gateway/main.tf
resource "aws_api_gateway_rest_api" "insurance_api" {
  name        = "${var.name_prefix}-insurance-api"
  description = "API Gateway for Insurance Cost Prediction"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

# Root resource
resource "aws_api_gateway_resource" "root" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  parent_id   = aws_api_gateway_rest_api.insurance_api.root_resource_id
  path_part   = "api"
}

# Health check endpoint
resource "aws_api_gateway_resource" "health" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  parent_id   = aws_api_gateway_resource.root.id
  path_part   = "health"
}

resource "aws_api_gateway_method" "health_get" {
  rest_api_id   = aws_api_gateway_rest_api.insurance_api.id
  resource_id   = aws_api_gateway_resource.health.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "health_integration" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_get.http_method

  type                    = "MOCK"
  integration_http_method = "POST"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "health_response_200" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_get.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "health_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_get.http_method
  status_code = aws_api_gateway_method_response.health_response_200.status_code

  response_templates = {
    "application/json" = jsonencode({
      status  = "healthy"
      service = "insurance-prediction-api"
      version = var.model_version
    })
  }
}

# Prediction endpoint
resource "aws_api_gateway_resource" "predict" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  parent_id   = aws_api_gateway_resource.root.id
  path_part   = "predict"
}

# POST method for prediction (JSON input)
resource "aws_api_gateway_method" "predict_post" {
  rest_api_id   = aws_api_gateway_rest_api.insurance_api.id
  resource_id   = aws_api_gateway_resource.predict.id
  http_method   = "POST"
  authorization = "NONE"

  request_parameters = {
    "method.request.header.Content-Type" = true
  }
}

resource "aws_api_gateway_method_response" "predict_response_200" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  resource_id = aws_api_gateway_resource.predict.id
  http_method = aws_api_gateway_method.predict_post.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "predict_response_400" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  resource_id = aws_api_gateway_resource.predict.id
  http_method = aws_api_gateway_method.predict_post.http_method
  status_code = "400"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_method_response" "predict_response_500" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  resource_id = aws_api_gateway_resource.predict.id
  http_method = aws_api_gateway_method.predict_post.http_method
  status_code = "500"

  response_models = {
    "application/json" = "Empty"
  }
}

# Integration with SageMaker endpoint
resource "aws_api_gateway_integration" "sagemaker_integration" {
  rest_api_id             = aws_api_gateway_rest_api.insurance_api.id
  resource_id             = aws_api_gateway_resource.predict.id
  http_method             = aws_api_gateway_method.predict_post.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:runtime.sagemaker:path//endpoints/${var.endpoint_name}/invocations"
  credentials             = aws_iam_role.api_gateway.arn

  # Request mapping templates for different content types
  request_templates = {
    "application/json" = <<EOF
#set($allParams = $input.params())
#set($body = $input.json('$'))

## Handle different input formats
#if($body.size() > 0)
  #if($body.startsWith("[") && $body.endsWith("]"))
    ## Array format: [{"age": 25, ...}]
    {
      "instances": $body
    }
  #elseif($body.contains("instances"))
    ## Already has "instances" key
    $body
  #elseif($body.contains("features"))
    ## Has "features" key
    {
      "instances": [$body.features]
    }
  #elseif($body.contains("age") && $body.contains("bmi"))
    ## Direct object with expected fields
    {
      "instances": [$body]
    }
  #else
    ## Unknown format, pass through
    $body
  #end
#else
  {
    "instances": []
  }
#end
EOF

    "application/x-www-form-urlencoded" = <<EOF
#set($allParams = $input.params())
#set($formData = $input.params().querystring)
{
  "instances": [{
    "age": "$formData.get('age')",
    "children": "$formData.get('children')",
    "bmi": "$formData.get('bmi')",
    "sex": "$formData.get('sex')",
    "smoker": "$formData.get('smoker')",
    "region": "$formData.get('region')"
  }]
}
EOF

    "text/csv" = <<EOF
#set($allParams = $input.params())
#set($csvData = $input.body)
$csvData
EOF
  }

  # Cache key parameters
  cache_key_parameters = ["method.request.header.Content-Type"]

  passthrough_behavior = "WHEN_NO_TEMPLATES"

  request_parameters = {
    "integration.request.header.Content-Type" = "method.request.header.Content-Type"
  }

  timeout_milliseconds = 29000 # 29 seconds (SageMaker timeout is 30 seconds)
}

resource "aws_api_gateway_integration_response" "sagemaker_integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  resource_id = aws_api_gateway_resource.predict.id
  http_method = aws_api_gateway_method.predict_post.http_method
  status_code = aws_api_gateway_method_response.predict_response_200.status_code

  response_templates = {
    "application/json" = <<EOF
#set($inputRoot = $input.path('$'))
#if($inputRoot.predictions && $inputRoot.predictions.size() > 0)
  #if($inputRoot.predictions.size() == 1)
{
  "prediction": $inputRoot.predictions[0],
  "cost": "$${inputRoot.predictions[0]}",
  "status": "success",
  "timestamp": "$context.requestTimeEpoch",
  "request_id": "$context.requestId"
}
  #else
{
  "predictions": $inputRoot.predictions,
  "count": $inputRoot.predictions.size(),
  "status": "success",
  "timestamp": "$context.requestTimeEpoch",
  "request_id": "$context.requestId"
}
  #end
#elseif($inputRoot.prediction)
{
  "prediction": $inputRoot.prediction,
  "cost": "$${inputRoot.prediction}",
  "status": "success",
  "timestamp": "$context.requestTimeEpoch",
  "request_id": "$context.requestId"
}
#else
{
  "error": "Invalid response format from SageMaker",
  "raw_response": $inputRoot,
  "status": "error",
  "timestamp": "$context.requestTimeEpoch",
  "request_id": "$context.requestId"
}
#end
EOF

    "text/csv" = <<EOF
#set($inputRoot = $input.path('$'))
#if($inputRoot.predictions && $inputRoot.predictions.size() > 0)
#foreach($prediction in $inputRoot.predictions)
$prediction
#end
#elseif($inputRoot.prediction)
$inputRoot.prediction
#else
error
#end
EOF
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
    "method.response.header.Content-Type" = "'application/json'"
  }
}

# Integration error responses
resource "aws_api_gateway_integration_response" "sagemaker_integration_response_400" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  resource_id = aws_api_gateway_resource.predict.id
  http_method = aws_api_gateway_method.predict_post.http_method
  status_code = "400"
  selection_pattern = "4\\d{2}"

  response_templates = {
    "application/json" = jsonencode({
      error       = "Bad Request"
      message     = "Invalid input parameters"
      status_code = 400
      request_id  = "$context.requestId"
    })
  }
}

resource "aws_api_gateway_integration_response" "sagemaker_integration_response_500" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  resource_id = aws_api_gateway_resource.predict.id
  http_method = aws_api_gateway_method.predict_post.http_method
  status_code = "500"
  selection_pattern = "5\\d{2}"

  response_templates = {
    "application/json" = jsonencode({
      error       = "Internal Server Error"
      message     = "SageMaker endpoint error"
      status_code = 500
      request_id  = "$context.requestId"
    })
  }
}

# CORS support for OPTIONS method
resource "aws_api_gateway_method" "predict_options" {
  rest_api_id   = aws_api_gateway_rest_api.insurance_api.id
  resource_id   = aws_api_gateway_resource.predict.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "cors_integration" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  resource_id = aws_api_gateway_resource.predict.id
  http_method = aws_api_gateway_method.predict_options.http_method

  type                    = "MOCK"
  integration_http_method = "OPTIONS"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "cors_response_200" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  resource_id = aws_api_gateway_resource.predict.id
  http_method = aws_api_gateway_method.predict_options.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "cors_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  resource_id = aws_api_gateway_resource.predict.id
  http_method = aws_api_gateway_method.predict_options.http_method
  status_code = aws_api_gateway_method_response.cors_response_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }
}

# GET method for HTML form (Flask-like interface)
resource "aws_api_gateway_resource" "predict_form" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  parent_id   = aws_api_gateway_resource.root.id
  path_part   = "predict-form"
}

resource "aws_api_gateway_method" "predict_form_get" {
  rest_api_id   = aws_api_gateway_rest_api.insurance_api.id
  resource_id   = aws_api_gateway_resource.predict_form.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "form_integration" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  resource_id = aws_api_gateway_resource.predict_form.id
  http_method = aws_api_gateway_method.predict_form_get.http_method

  type                    = "MOCK"
  integration_http_method = "POST"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "form_response_200" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  resource_id = aws_api_gateway_resource.predict_form.id
  http_method = aws_api_gateway_method.predict_form_get.http_method
  status_code = "200"

  response_models = {
    "text/html" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "form_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  resource_id = aws_api_gateway_resource.predict_form.id
  http_method = aws_api_gateway_method.predict_form_get.http_method
  status_code = aws_api_gateway_method_response.form_response_200.status_code

  response_templates = {
    "text/html" = <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Insurance Cost Prediction</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .container { max-width: 600px; margin: 0 auto; }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 5px; font-weight: bold; }
        input, select { width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px; }
        button { background-color: #4CAF50; color: white; padding: 12px 20px; border: none; border-radius: 4px; cursor: pointer; }
        button:hover { background-color: #45a049; }
        .result { margin-top: 30px; padding: 20px; background-color: #f9f9f9; border-radius: 4px; }
        .prediction { font-size: 24px; color: #2c3e50; font-weight: bold; }
        .error { color: #e74c3c; padding: 10px; background-color: #ffebee; border-radius: 4px; }
        .api-info { margin-top: 30px; padding: 15px; background-color: #e8f4f8; border-radius: 4px; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Insurance Cost Prediction</h1>
        <p>Enter your information to predict insurance costs:</p>

        <form id="predictionForm">
            <div class="form-group">
                <label for="age">Age:</label>
                <input type="number" id="age" name="age" min="18" max="100" value="25" required>
            </div>

            <div class="form-group">
                <label for="children">Number of Children:</label>
                <input type="number" id="children" name="children" min="0" max="10" value="0" required>
            </div>

            <div class="form-group">
                <label for="bmi">BMI:</label>
                <input type="number" id="bmi" name="bmi" min="10" max="50" step="0.1" value="22.5" required>
            </div>

            <div class="form-group">
                <label for="sex">Sex:</label>
                <select id="sex" name="sex" required>
                    <option value="male">Male</option>
                    <option value="female">Female</option>
                </select>
            </div>

            <div class="form-group">
                <label for="smoker">Smoker:</label>
                <select id="smoker" name="smoker" required>
                    <option value="no">No</option>
                    <option value="yes">Yes</option>
                </select>
            </div>

            <div class="form-group">
                <label for="region">Region:</label>
                <select id="region" name="region" required>
                    <option value="northeast">Northeast</option>
                    <option value="northwest">Northwest</option>
                    <option value="southeast">Southeast</option>
                    <option value="southwest">Southwest</option>
                </select>
            </div>

            <button type="submit">Predict Insurance Cost</button>
        </form>

        <div id="result" class="result" style="display: none;">
            <h2>Prediction Result</h2>
            <div class="prediction" id="predictionValue"></div>
            <p><small>Predicted using machine learning model</small></p>
        </div>

        <div id="error" class="error" style="display: none;"></div>

        <div class="api-info">
            <h3>API Information</h3>
            <p><strong>Endpoint:</strong> <code>POST ${var.api_url}/api/predict</code></p>
            <p><strong>Content-Type:</strong> <code>application/json</code></p>
            <p><strong>Example Request:</strong></p>
            <pre><code>{
  "age": 25,
  "children": 0,
  "bmi": 22.5,
  "sex": "male",
  "smoker": "no",
  "region": "northeast"
}</code></pre>
            <p><strong>Example Response:</strong></p>
            <pre><code>{
  "prediction": 24667.34,
  "cost": "$24667.34",
  "status": "success"
}</code></pre>
        </div>
    </div>

    <script>
        document.getElementById('predictionForm').addEventListener('submit', async function(e) {
            e.preventDefault();

            // Reset displays
            document.getElementById('result').style.display = 'none';
            document.getElementById('error').style.display = 'none';

            // Get form data
            const formData = {
                age: parseInt(document.getElementById('age').value),
                children: parseInt(document.getElementById('children').value),
                bmi: parseFloat(document.getElementById('bmi').value),
                sex: document.getElementById('sex').value,
                smoker: document.getElementById('smoker').value,
                region: document.getElementById('region').value
            };

            try {
                const response = await fetch('${var.api_url}/api/predict', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify(formData)
                });

                const data = await response.json();

                if (response.ok) {
                    document.getElementById('predictionValue').textContent = '$' + data.prediction.toLocaleString('en-US', {
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2
                    });
                    document.getElementById('result').style.display = 'block';
                } else {
                    document.getElementById('error').textContent = data.error || 'Prediction failed';
                    document.getElementById('error').style.display = 'block';
                }
            } catch (error) {
                document.getElementById('error').textContent = 'Error: ' + error.message;
                document.getElementById('error').style.display = 'block';
            }
        });
    </script>
</body>
</html>
EOF
  }
}

# IAM role for API Gateway
resource "aws_iam_role" "api_gateway" {
  name = "${var.name_prefix}-api-gateway-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "api_gateway_sagemaker" {
  name = "${var.name_prefix}-api-gateway-sagemaker-policy"
  role = aws_iam_role.api_gateway.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sagemaker:InvokeEndpoint"
        ]
        Resource = [
          "arn:aws:sagemaker:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:endpoint/${var.endpoint_name}"
        ]
      }
    ]
  })
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "insurance_api" {
  depends_on = [
    aws_api_gateway_integration.sagemaker_integration,
    aws_api_gateway_integration.health_integration,
    aws_api_gateway_integration.form_integration,
    aws_api_gateway_integration.cors_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.insurance_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.health.id,
      aws_api_gateway_resource.predict.id,
      aws_api_gateway_resource.predict_form.id,
      aws_api_gateway_method.health_get.id,
      aws_api_gateway_method.predict_post.id,
      aws_api_gateway_method.predict_form_get.id,
      aws_api_gateway_method.predict_options.id,
      aws_api_gateway_integration.health_integration.id,
      aws_api_gateway_integration.sagemaker_integration.id,
      aws_api_gateway_integration.form_integration.id,
      aws_api_gateway_integration.cors_integration.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway stage
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.insurance_api.id
  rest_api_id   = aws_api_gateway_rest_api.insurance_api.id
  stage_name    = "prod"

  tags = var.tags
}

# API Gateway usage plan and API key (optional)
resource "aws_api_gateway_usage_plan" "main" {
  name = "${var.name_prefix}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.insurance_api.id
    stage  = aws_api_gateway_stage.prod.stage_name
  }

  throttle_settings {
    burst_limit = 20
    rate_limit  = 10
  }

  quota_settings {
    limit  = 10000
    period = "MONTH"
  }

  tags = var.tags
}

resource "aws_api_gateway_api_key" "main" {
  name = "${var.name_prefix}-api-key"

  tags = var.tags
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.main.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.main.id
}



# API Gateway access logging
resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}



# Method settings for logging
resource "aws_api_gateway_method_settings" "predict_settings" {
  rest_api_id = aws_api_gateway_rest_api.insurance_api.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "${aws_api_gateway_resource.predict.path_part}/${aws_api_gateway_method.predict_post.http_method}"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
    data_trace_enabled = true
  }
}

# Outputs for API Gateway module
