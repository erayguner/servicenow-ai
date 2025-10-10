variable "project_id" { type = string }
variable "region" { type = string }
variable "display_name" { type = string }
variable "dimensions" {
  type    = number
  default = 768
}
variable "distance_measure_type" {
  type    = string
  default = "COSINE_DISTANCE"
}
