# ==============================================================================
# Shared AWS Data Sources Module
# ==============================================================================
# This module provides commonly used AWS data sources that are referenced across
# multiple Bedrock modules. By centralizing these data sources, we reduce
# duplication and improve plan/apply performance.
#
# Usage:
#   module "shared_data" {
#     source = "../../_shared/data-sources"
#   }
#
#   # Then reference as:
#   # - module.shared_data.account_id
#   # - module.shared_data.region_name
#   # - module.shared_data.caller_arn
# ==============================================================================

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
