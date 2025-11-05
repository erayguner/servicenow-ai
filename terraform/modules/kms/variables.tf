variable "project_id" { type = string }
variable "location" { type = string }
variable "keyring_name" { type = string }
variable "keys" {
  description = "Map of key names to rotation periods (e.g., 90d)."
  type        = map(string)
}
