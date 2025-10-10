resource "google_billing_budget_budget" "monthly" {
  billing_account = var.billing_account
  display_name    = "${var.project_id}-monthly-budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = floor(var.amount_monthly)
      nanos         = (var.amount_monthly - floor(var.amount_monthly)) * 1e9
    }
  }

  threshold_rules {
    threshold_percent = 0.0
  }

  dynamic "threshold_rules" {
    for_each = var.thresholds
    content {
      threshold_percent = threshold_rules.value
    }
  }
}

