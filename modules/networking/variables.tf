variable "project_name" {
  description = "The name of the project."
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type = string
}

variable "location" {
  description = "Location for resources"
  type = string
}

variable "vnet_address_space" {
  description = "Virtual network address space"
  type = list(string)
  default = [ "10.0.0.0/16" ]
}

variable "subnet_api_prefix" {
  description = "Subnet prefix for API"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "subnet_database_prefix" {
    description = "Subnet prefix for Database"
    type        = list(string)
    default     = ["10.0.2.0/24"]
}

variable "subnet_agw_prefix" {
    description = "Subnet prefix for Application Gateway"
    type        = list(string)
    default     = ["10.0.3.0/24"]
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}