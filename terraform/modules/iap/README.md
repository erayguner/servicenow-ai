# IAP Module - Deprecation Migration Guide

## ⚠️ Important: IAP OAuth Admin API Deprecation

The `google_iap_brand` and `google_iap_client` Terraform resources are
**deprecated** and will stop functioning after **March 19, 2026**.

### Timeline

- **January 22, 2025**: Resources officially deprecated
- **January 19, 2026**: New projects cannot use these APIs
- **March 19, 2026**: APIs permanently shut down

## Migration Path

### Option 1: Manual Creation (Recommended)

This is the future-proof approach that will work after deprecation:

#### Step 1: Create OAuth Brand in GCP Console

1. Navigate to: **Security > Identity-Aware Proxy**
2. Click **Configure Consent Screen**
3. Fill in the required information:
   - Application name
   - Support email
   - Application homepage
4. Save the OAuth Brand
5. Note the brand name (format: `projects/{project_number}/brands/{brand_id}`)

#### Step 2: Create OAuth Client in GCP Console

1. Navigate to: **Security > Identity-Aware Proxy**
2. Click **Create OAuth Client** or go to **APIs & Services > Credentials**
3. Create a new OAuth 2.0 Client ID
4. Application type: **Web application**
5. Note the **Client ID** and **Client Secret**

#### Step 3: Store Credentials in Secret Manager

```bash
# Store OAuth client secret
echo -n "YOUR_CLIENT_SECRET" | gcloud secrets create iap-oauth-client-secret \
  --data-file=- \
  --project=YOUR_PROJECT_ID

# Store OAuth client ID (optional, for consistency)
echo -n "YOUR_CLIENT_ID" | gcloud secrets create iap-oauth-client-id \
  --data-file=- \
  --project=YOUR_PROJECT_ID
```

#### Step 4: Use Module with Manual Credentials

```hcl
module "iap" {
  source = "../../modules/iap"

  project_id               = var.project_id
  region                   = var.region
  service_name             = "my-service"
  cloud_run_service_name   = "my-cloud-run-service"
  network                  = module.vpc.network_self_link
  subnetwork               = module.vpc.subnet_self_links["subnet-name"]

  # IMPORTANT: Keep these as false (default)
  create_brand         = false
  create_oauth_client  = false

  # Provide manually-created credentials
  oauth_client_id      = "YOUR_CLIENT_ID.apps.googleusercontent.com"
  oauth_client_secret  = "YOUR_CLIENT_SECRET"  # Or reference from Secret Manager

  iap_access_members = [
    "user:alice@example.com",
    "group:ai-assist-users@example.com"
  ]
}
```

### Option 2: Automated Creation (Temporary, Deprecated)

⚠️ **Not recommended**: This will stop working after March 19, 2026

```hcl
module "iap" {
  source = "../../modules/iap"

  # ... other configuration ...

  # DEPRECATED: Will fail after March 19, 2026
  create_brand         = true
  create_oauth_client  = true
  support_email        = "support@example.com"
  application_title    = "My Application"
}
```

## Module Variables

### Required for Manual Approach

- `oauth_client_id` - OAuth 2.0 Client ID (from GCP Console)
- `oauth_client_secret` - OAuth 2.0 Client Secret (from GCP Console)

### Deprecated (Avoid Setting to `true`)

- `create_brand` - Default: `false` (leave as false)
- `create_oauth_client` - Default: `false` (leave as false)

## Alternative: Use Data Source (Future Enhancement)

After migrating to manual creation, you can optionally use Terraform data
sources to reference existing OAuth credentials:

```hcl
# Note: This is a conceptual example - actual implementation may vary
data "google_secret_manager_secret_version" "iap_client_id" {
  secret = "iap-oauth-client-id"
}

data "google_secret_manager_secret_version" "iap_client_secret" {
  secret = "iap-oauth-client-secret"
}

module "iap" {
  source = "../../modules/iap"
  # ...
  oauth_client_id     = data.google_secret_manager_secret_version.iap_client_id.secret_data
  oauth_client_secret = data.google_secret_manager_secret_version.iap_client_secret.secret_data
}
```

## Testing the Migration

1. **Create credentials manually** following Step 1-2 above
2. **Update your Terraform configuration** to use manual credentials
3. **Run terraform plan** to verify no changes to IAP backend service
4. **Apply changes** if needed
5. **Verify IAP authentication** still works

## References

- [GCP IAP Documentation](https://cloud.google.com/iap/docs)
- [OAuth 2.0 Client Configuration](https://cloud.google.com/iap/docs/authentication-howto)
- [Terraform google_iap_brand Deprecation Notice](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iap_brand)

## Support

For issues related to IAP configuration, consult:

1. GCP IAP documentation
2. Your organization's security team
3. This repository's issue tracker
