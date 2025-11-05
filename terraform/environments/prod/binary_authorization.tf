# Binary Authorization Configuration
# Enforces container image signing and verification

# Attestor for container images
resource "google_binary_authorization_attestor" "prod_container_attestor" {
  project = var.project_id
  name    = "prod-container-attestor"

  attestation_authority_note {
    note_reference = google_container_analysis_note.attestor_note.name
  }

  description = "Production container image attestor"
}

# Container Analysis Note for attestor
resource "google_container_analysis_note" "attestor_note" {
  project = var.project_id
  name    = "prod-attestor-note"

  attestation_authority {
    hint {
      human_readable_name = "Production Container Attestor"
    }
  }
}

# IAM binding for attestor
resource "google_binary_authorization_attestor_iam_member" "attestor_viewer" {
  project  = var.project_id
  attestor = google_binary_authorization_attestor.prod_container_attestor.id
  role     = "roles/binaryauthorization.attestorsViewer"
  member   = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

# Binary Authorization Policy
resource "google_binary_authorization_policy" "policy" {
  project = var.project_id

  # Default admission rule - require attestation
  default_admission_rule {
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"

    require_attestations_by = [
      google_binary_authorization_attestor.prod_container_attestor.name
    ]
  }

  # Cluster-specific admission rules
  cluster_admission_rules {
    cluster          = "europe-west2.prod-ai-agent-gke"
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [
      google_binary_authorization_attestor.prod_container_attestor.name
    ]
  }

  # Admission allowlist patterns (for Google-maintained images)
  admission_whitelist_patterns {
    name_pattern = "gcr.io/google_containers/*"
  }

  admission_whitelist_patterns {
    name_pattern = "gcr.io/gke-release/*"
  }

  admission_whitelist_patterns {
    name_pattern = "gke.gcr.io/*"
  }

  admission_whitelist_patterns {
    name_pattern = "k8s.gcr.io/*"
  }

  admission_whitelist_patterns {
    name_pattern = "gcr.io/config-management-release/*"
  }

  admission_whitelist_patterns {
    name_pattern = "gcr.io/gkeconnect/*"
  }

  # Allow Istio and other system images
  admission_whitelist_patterns {
    name_pattern = "docker.io/istio/*"
  }

  # Global evaluation mode
  global_policy_evaluation_mode = "ENABLE"

  description = "Binary Authorization policy for production GKE cluster"
}

# KMS key for attestation signing
resource "google_kms_crypto_key" "attestor_key" {
  name     = "attestor-key"
  key_ring = module.kms.keyring_id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm = "RSA_SIGN_PKCS1_4096_SHA512"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# IAM binding for attestor to use KMS key
resource "google_kms_crypto_key_iam_member" "attestor_signer" {
  crypto_key_id = google_kms_crypto_key.attestor_key.id
  role          = "roles/cloudkms.signerVerifier"
  member        = "serviceAccount:${module.workload_identity_federation.service_account_email}"
}

# Public key for attestor
resource "google_binary_authorization_attestor" "attestor_with_key" {
  project = var.project_id
  name    = "prod-container-attestor-with-key"

  attestation_authority_note {
    note_reference = google_container_analysis_note.attestor_note.name

    public_keys {
      id = google_kms_crypto_key.attestor_key.id

      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.attestor_key_version.public_key[0].pem
        signature_algorithm = "RSA_SIGN_PKCS1_4096_SHA512"
      }
    }
  }

  description = "Production attestor with KMS key"
}

# Get the latest key version
data "google_kms_crypto_key_version" "attestor_key_version" {
  crypto_key = google_kms_crypto_key.attestor_key.id
}

# Outputs
output "attestor_name" {
  description = "Binary Authorization attestor name"
  value       = google_binary_authorization_attestor.prod_container_attestor.name
}

output "attestor_key_id" {
  description = "KMS key for attestation signing"
  value       = google_kms_crypto_key.attestor_key.id
}

output "binary_auth_signing_command" {
  description = "Command to sign container images"
  value       = <<-EOT
    # Sign a container image
    gcloud beta container binauthz attestations sign-and-create \
      --artifact-url=ARTIFACT_URL \
      --attestor=${google_binary_authorization_attestor.prod_container_attestor.name} \
      --attestor-project=${var.project_id} \
      --keyversion-project=${var.project_id} \
      --keyversion-location=${var.region} \
      --keyversion-keyring=prod-keyring \
      --keyversion-key=attestor-key \
      --keyversion=1
  EOT
  sensitive   = false
}
