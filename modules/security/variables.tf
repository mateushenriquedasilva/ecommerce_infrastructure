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

variable "resource_group_name" {
  description = "The name of the resource group."
  type = string
}

variable "subnet_id" {
  description = "Subnet ID for Private Endpoint"
  type = string
}

variable "vnet_id" {
  description = "Virtual Network ID"
  type = string
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}