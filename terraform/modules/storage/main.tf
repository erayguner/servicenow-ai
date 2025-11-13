resource "google_storage_bucket" "buckets" {
  for_each                    = { for b in var.buckets : b.name => b }
  name                        = each.value.name
  project                     = var.project_id
  location                    = var.location
  force_destroy               = coalesce(each.value.force_destroy, false)
  uniform_bucket_level_access = true # Always enforce uniform bucket-level access for security
  public_access_prevention    = "enforced"

  encryption {
    default_kms_key_name = each.value.kms_key
  }

  versioning {
    enabled = true
  }

  logging {
    log_bucket        = coalesce(each.value.log_bucket, "${var.project_id}-logs")
    log_object_prefix = "storage/${each.value.name}/"
  }

  dynamic "lifecycle_rule" {
    for_each = each.value.lifecycle_rules
    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = try(lifecycle_rule.value.action.storage_class, null)
      }
      condition {
        age                   = try(lifecycle_rule.value.condition.age, null)
        matches_storage_class = try(lifecycle_rule.value.condition.matches_storage_class, null)
        num_newer_versions    = try(lifecycle_rule.value.condition.num_newer_versions, null)
        with_state            = try(lifecycle_rule.value.condition.with_state, null)
      }
    }
  }
}

output "bucket_names" { value = [for b in google_storage_bucket.buckets : b.name] }
