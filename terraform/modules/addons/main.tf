resource "kubernetes_namespace" "istio_system" {
  metadata { name = "istio-system" }
}

resource "kubernetes_namespace" "cert_manager" {
  metadata { name = "cert-manager" }
}

resource "helm_release" "istio_base" {
  name       = "istio-base"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "base"
  namespace  = kubernetes_namespace.istio_system.metadata[0].name
}

resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  namespace  = kubernetes_namespace.istio_system.metadata[0].name
  depends_on = [helm_release.istio_base]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = kubernetes_namespace.cert_manager.metadata[0].name
  create_namespace = false
  set {
    name  = "installCRDs"
    value = "true"
  }
}

# Example Ingress annotated with Cloud Armor policy and cert-manager issuer
resource "kubernetes_namespace" "internal_ui" {
  count = var.create_example_ingress ? 1 : 0
  metadata { name = "internal-ui" }
}

resource "kubernetes_service" "internal_ui_svc" {
  count = var.create_example_ingress ? 1 : 0
  metadata {
    name      = "internal-ui-svc"
    namespace = kubernetes_namespace.internal_ui[0].metadata[0].name
    labels    = { app = "internal-ui" }
  }
  spec {
    port {
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "internal_ui_ingress" {
  count = var.create_example_ingress ? 1 : 0
  metadata {
    name      = "internal-ui-ingress"
    namespace = kubernetes_namespace.internal_ui[0].metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"       = "gce"
      "networking.gke.io/security-policy" = var.security_policy_name
      "cert-manager.io/cluster-issuer"    = var.cluster_issuer
      "kubernetes.io/ingress.allow-http"  = "false"
    }
  }
  spec {
    dynamic "tls" {
      for_each = var.ingress_host == "" ? [] : [var.ingress_host]
      content {
        hosts       = [tls.value]
        secret_name = "internal-ui-tls"
      }
    }

    rule {
      host = var.ingress_host
      http {
        path {
          path = "/"
          backend {
            service {
              name = kubernetes_service.internal_ui_svc[0].metadata[0].name
              port { number = 80 }
            }
          }
        }
      }
    }
  }
}
