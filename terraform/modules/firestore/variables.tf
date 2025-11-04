variable "project_id" { type = string }
variable "location_id" { type = string } # e.g., nam5 (multi-region) or regional id
variable "deletion_protection" {
  type    = bool
  default = false
}
