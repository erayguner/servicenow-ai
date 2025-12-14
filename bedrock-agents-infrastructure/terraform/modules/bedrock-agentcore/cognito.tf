# ==============================================================================
# Cognito User Pool for JWT Authentication
# ==============================================================================
# Provides JWT token-based authentication for AgentCore Gateway
# Used when gateway_authorizer_type is "CUSTOM_JWT"
# ==============================================================================

# ==============================================================================
# Cognito User Pool
# ==============================================================================

resource "aws_cognito_user_pool" "gateway" {
  count = local.create_cognito ? 1 : 0

  name = "${local.name_prefix}-agentcore-gateway-pool"

  # Username configuration
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Password policy
  password_policy {
    minimum_length                   = var.cognito_password_minimum_length
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = var.cognito_temporary_password_validity_days
  }

  # MFA configuration
  mfa_configuration = var.cognito_mfa_configuration

  dynamic "software_token_mfa_configuration" {
    for_each = var.cognito_mfa_configuration != "OFF" ? [1] : []
    content {
      enabled = true
    }
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # User attribute schema
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    required                 = true
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 5
      max_length = 256
    }
  }

  schema {
    name                     = "agentcore_access"
    attribute_data_type      = "String"
    required                 = false
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Admin create user config
  admin_create_user_config {
    allow_admin_create_user_only = var.cognito_allow_admin_create_user_only

    invite_message_template {
      email_message = "Your AgentCore Gateway username is {username} and temporary password is {####}"
      email_subject = "Your AgentCore Gateway temporary password"
      sms_message   = "Your AgentCore Gateway username is {username} and temporary password is {####}"
    }
  }

  # User pool add-ons
  user_pool_add_ons {
    advanced_security_mode = var.cognito_advanced_security_mode
  }

  # Deletion protection
  deletion_protection = var.cognito_deletion_protection ? "ACTIVE" : "INACTIVE"

  tags = merge(
    local.common_tags,
    {
      Name    = "${local.name_prefix}-agentcore-gateway-pool"
      Purpose = "agentcore-gateway-authentication"
    }
  )
}

# ==============================================================================
# Cognito User Pool Client
# ==============================================================================

resource "aws_cognito_user_pool_client" "gateway" {
  count = local.create_cognito ? 1 : 0

  name         = "${local.name_prefix}-agentcore-gateway-client"
  user_pool_id = aws_cognito_user_pool.gateway[0].id

  # Token configuration
  access_token_validity  = var.cognito_access_token_validity
  id_token_validity      = var.cognito_id_token_validity
  refresh_token_validity = var.cognito_refresh_token_validity

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # OAuth configuration
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  # Callback and logout URLs
  callback_urls = var.cognito_callback_urls
  logout_urls   = var.cognito_logout_urls

  # Supported identity providers
  supported_identity_providers = ["COGNITO"]

  # Explicit auth flows
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"

  # Read/write attributes
  read_attributes = [
    "email",
    "email_verified",
    "custom:agentcore_access"
  ]

  write_attributes = [
    "email",
    "custom:agentcore_access"
  ]

  # Generate client secret (for confidential clients)
  generate_secret = var.cognito_generate_client_secret
}

# ==============================================================================
# Cognito User Pool Domain
# ==============================================================================

resource "aws_cognito_user_pool_domain" "gateway" {
  count = local.create_cognito && var.cognito_domain_prefix != "" ? 1 : 0

  domain       = "${var.cognito_domain_prefix}-${local.resource_suffix}"
  user_pool_id = aws_cognito_user_pool.gateway[0].id
}

# ==============================================================================
# Cognito Resource Server (for custom scopes)
# ==============================================================================

resource "aws_cognito_resource_server" "gateway" {
  count = local.create_cognito ? 1 : 0

  identifier   = "agentcore-gateway"
  name         = "AgentCore Gateway API"
  user_pool_id = aws_cognito_user_pool.gateway[0].id

  scope {
    scope_name        = "invoke"
    scope_description = "Invoke AgentCore Gateway"
  }

  scope {
    scope_name        = "read"
    scope_description = "Read from AgentCore Gateway"
  }

  scope {
    scope_name        = "write"
    scope_description = "Write to AgentCore Gateway"
  }

  scope {
    scope_name        = "admin"
    scope_description = "Admin access to AgentCore Gateway"
  }
}

# ==============================================================================
# Cognito User Groups
# ==============================================================================

resource "aws_cognito_user_group" "gateway_admins" {
  count = local.create_cognito ? 1 : 0

  name         = "agentcore-admins"
  user_pool_id = aws_cognito_user_pool.gateway[0].id
  description  = "AgentCore Gateway Administrators"
  precedence   = 1
}

resource "aws_cognito_user_group" "gateway_users" {
  count = local.create_cognito ? 1 : 0

  name         = "agentcore-users"
  user_pool_id = aws_cognito_user_pool.gateway[0].id
  description  = "AgentCore Gateway Users"
  precedence   = 2
}

resource "aws_cognito_user_group" "gateway_readonly" {
  count = local.create_cognito ? 1 : 0

  name         = "agentcore-readonly"
  user_pool_id = aws_cognito_user_pool.gateway[0].id
  description  = "AgentCore Gateway Read-Only Users"
  precedence   = 3
}
