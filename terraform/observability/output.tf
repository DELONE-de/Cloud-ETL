output "aws_cloudwatch_metric_alarm_id" {
  value = aws_cloudwatch_metric_alarm.lambda_errors.id
}

output "aws_cloudwatch_log_group_sfn_logs_name" {
  value = aws_cloudwatch_log_group.sfn_logs.name
}

output "log_stream_name" {
  value = aws_cloudwatch_log_stream.etl_log_stream
}

output "aws_cloudwatch_metric_alarm_endpoint_errors_id" {
  value = aws_cloudwatch_metric_alarm.endpoint_errors.*.id
}

