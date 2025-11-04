resource "google_billing_budget" "monthly" {
  provider        = google
  billing_account = var.billing_account
  display_name    = "${var.project_id}-monthly-budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(floor(var.amount_monthly))
      nanos         = floor((var.amount_monthly - floor(var.amount_monthly)) * 1e9)
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

