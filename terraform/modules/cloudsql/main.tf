resource "google_sql_database_instance" "pg" {
  name                = var.instance_name
  project             = var.project_id
  region              = var.region
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  settings {
    tier              = var.tier
    disk_size         = var.disk_size
    disk_autoresize   = var.disk_autoresize
    availability_type = var.availability_type

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      backup_retention_settings { retained_backups = 7 }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.private_network
      # Explicitly require SSL for all incoming connections (CKV_GCP_6 compliance)
      # Note: For PostgreSQL with private IP + ENCRYPTED_ONLY this enforces TLS.
      ssl_mode = "TRUSTED_CLIENT_CERTIFICATE_REQUIRED"
    }

    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }

    database_flags {
      name  = "log_hostname"
      value = "on"
    }

    database_flags {
      name  = "log_statement"
      value = "all"
    }

    database_flags {
      name  = "log_min_messages"
      value = "error"
    }

    database_flags {
      name  = "log_min_error_statement"
      value = "error"
    }

    database_flags {
      name  = "log_duration"
      value = "on"
    }

    maintenance_window {
      day  = 7
      hour = 5
    }
  }

  encryption_key_name = var.kms_key
}

resource "google_sql_database" "dbs" {
  for_each = toset(var.databases)
  name     = each.value
  project  = var.project_id
  instance = google_sql_database_instance.pg.name
}

resource "google_sql_user" "users" {
  for_each = { for u in var.users : u.name => u }
  name     = each.value.name
  project  = var.project_id
  instance = google_sql_database_instance.pg.name
  password = try(each.value.password, null)
}

# Multi-region read replica for disaster recovery
resource "google_sql_database_instance" "replica" {
  count                = var.enable_read_replica ? 1 : 0
  name                 = "${var.instance_name}-replica"
  project              = var.project_id
  region               = var.replica_region
  database_version     = var.database_version
  deletion_protection  = var.deletion_protection
  master_instance_name = google_sql_database_instance.pg.name

  replica_configuration {
    failover_target = true
  }

  settings {
    tier              = coalesce(var.replica_tier, var.tier)
    disk_size         = var.disk_size
    disk_autoresize   = var.disk_autoresize
    availability_type = "REGIONAL"

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      backup_retention_settings { retained_backups = 7 }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.private_network
      ssl_mode        = "TRUSTED_CLIENT_CERTIFICATE_REQUIRED"
    }

    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_duration"
      value = "on"
    }

    maintenance_window {
      day  = 7
      hour = 6
    }
  }

  encryption_key_name = var.kms_key
}
