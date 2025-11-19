plugin "google" {
  enabled = true
  version = "0.34.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}

config {
  call_module_type = "all"
}

# Disable unused declarations rule
# Many variables are defined for future use or optional features
rule "terraform_unused_declarations" {
  enabled = false
}
