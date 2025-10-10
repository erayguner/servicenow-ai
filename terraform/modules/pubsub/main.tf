resource "google_pubsub_topic" "topics" {
  for_each                   = { for t in var.topics : t.name => t }
  name                       = each.value.name
  project                    = var.project_id
  message_retention_duration = each.value.message_retention_duration
  kms_key_name               = try(each.value.kms_key, null)
}

output "topic_names" { value = [for t in google_pubsub_topic.topics : t.name] }

