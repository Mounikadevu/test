variable "name_prefix" {
  description = "Prefix for the VPC and its resources"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_cidrs" {
  description = "List of CIDR blocks for the public subnets"
  type        = list(string)
}

variable "private_cidrs" {
  description = "List of CIDR blocks for the private subnets"
  type        = list(string)
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "elb_name" {
  description = "Name of the ELB"
  type        = string
}

variable "zone_name" {
  description = "Name of the Route 53 hosted zone"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the Route 53 CNAME record"
  type        = string
}
