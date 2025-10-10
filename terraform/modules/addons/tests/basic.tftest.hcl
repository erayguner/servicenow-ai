mock_provider "kubernetes" {}
mock_provider "helm" {}

run "plan_addons" {
  command = plan
  variables {
    security_policy_name   = "prod-gke-waf"
    create_example_ingress = true
    ingress_host           = "ui.internal.example.com"
    cluster_issuer         = "letsencrypt"
  }

  assert {
    condition     = resource.helm_release.istiod.chart == "istiod"
    error_message = "Istio control plane (istiod) must be installed"
  }

  assert {
    condition     = resource.helm_release.cert_manager.chart == "cert-manager"
    error_message = "cert-manager Helm release must be installed"
  }

  assert {
    condition     = resource.kubernetes_ingress_v1.internal_ui_ingress.metadata[0].annotations["networking.gke.io/security-policy"] == "prod-gke-waf"
    error_message = "Ingress must carry Cloud Armor policy annotation"
  }
}
