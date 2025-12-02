variable "vpc_id" {
  description = "VPC id where endpoints will be created"
  type        = string
  default     = ""
}

variable "route_table_ids" {
  description = "Route tables for S3 endpoint"
  type        = list(string)
  default     = []
}

variable "vpc_subnet_ids" {
  description = "Subnets for interface endpoints"
  type        = list(string)
  default     = []
}

variable "vpc_endpoint_sg_ids" {
  description = "SGs for interface endpoints"
  type        = list(string)
  default     = []
}

resource "aws_vpc_endpoint" "s3" {
  count             = (length(var.vpc_id) > 0 && length(var.route_table_ids) > 0) ? 1 : 0
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  tags = {
    Name        = "${var.project_prefix}-${var.environment}-s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "kinesis" {
  count             = length(var.vpc_id) > 0 ? 1 : 0
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.kinesis-streams"
  vpc_endpoint_type = "Interface"

  subnet_ids         = var.vpc_subnet_ids
  security_group_ids = var.vpc_endpoint_sg_ids

  tags = {
    Name = "${var.project_prefix}-${var.environment}-kinesis-endpoint"
  }
}