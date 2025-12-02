variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "zebraan-gcp-zebo"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-south1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "asia-south1-a"
}

variable "billing_account_id" {
  description = "GCP Billing Account ID"
  type        = string
}
