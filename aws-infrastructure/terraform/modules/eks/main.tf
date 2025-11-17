# AWS EKS Module - 2025 Best Practices
# Equivalent to GCP GKE module

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

locals {
  cluster_name = var.cluster_name

  common_tags = merge(
    var.tags,
    {
      "kubernetes.io/cluster/${local.cluster_name}" = "owned"
      ManagedBy                                     = "Terraform"
      Module                                        = "eks"
      Environment                                   = var.environment
    }
  )
}

data "aws_partition" "current" {}

# EKS Cluster IAM Role
resource "aws_iam_role" "cluster" {
  name = "${local.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_vpc_resource_controller" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# EKS Cluster Security Group
resource "aws_security_group" "cluster" {
  name_prefix = "${local.cluster_name}-cluster-"
  description = "Security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-cluster-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "cluster_egress" {
  description       = "Allow cluster egress to internet"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
}

# KMS Key for EKS encryption (2025 best practice)
resource "aws_kms_key" "eks" {
  description             = "EKS cluster encryption key for ${local.cluster_name}"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-eks-key"
    }
  )
}

resource "aws_kms_alias" "eks" {
  name          = "alias/eks/${local.cluster_name}"
  target_key_id = aws_kms_key.eks.key_id
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
  }

  encryption_config {
    resources = ["secrets"]
    provider {
      key_arn = aws_kms_key.eks.arn
    }
  }

  enabled_cluster_log_types = var.enabled_cluster_log_types

  # 2025: Use Pod Identity instead of IRSA for better performance
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_vpc_resource_controller,
    aws_cloudwatch_log_group.cluster
  ]
}

# CloudWatch Log Group for EKS Control Plane Logs
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

# EKS Node Group IAM Role
resource "aws_iam_role" "node_group" {
  name = "${local.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "node_group_policies" {
  for_each = toset([
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])

  policy_arn = each.value
  role       = aws_iam_role.node_group.name
}

# Node Security Group
resource "aws_security_group" "node" {
  name_prefix = "${local.cluster_name}-node-"
  description = "Security group for EKS worker nodes"
  vpc_id      = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name                                          = "${local.cluster_name}-node-sg"
      "kubernetes.io/cluster/${local.cluster_name}" = "owned"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "node_ingress_self" {
  description              = "Allow nodes to communicate with each other"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.node.id
}

resource "aws_security_group_rule" "node_ingress_cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "node_egress" {
  description       = "Allow nodes all egress"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.node.id
}

resource "aws_security_group_rule" "cluster_ingress_node_https" {
  description              = "Allow pods to communicate with the cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
}

# General Purpose Node Group
resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.cluster_name}-general"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  version         = var.kubernetes_version

  scaling_config {
    desired_size = var.general_node_group.desired_size
    max_size     = var.general_node_group.max_size
    min_size     = var.general_node_group.min_size
  }

  update_config {
    max_unavailable_percentage = 33
  }

  # 2025: Use Graviton3 (ARM) for better price/performance
  instance_types = var.general_node_group.instance_types
  capacity_type  = var.general_node_group.capacity_type # ON_DEMAND or SPOT
  disk_size      = 50

  labels = merge(
    var.general_node_group.labels,
    {
      "node.kubernetes.io/workload" = "general"
    }
  )

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-general-node-group"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_group_policies
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# AI Workload Node Group (GPU/High Memory)
resource "aws_eks_node_group" "ai" {
  count = var.enable_ai_node_group ? 1 : 0

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${local.cluster_name}-ai"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids
  version         = var.kubernetes_version

  scaling_config {
    desired_size = var.ai_node_group.desired_size
    max_size     = var.ai_node_group.max_size
    min_size     = var.ai_node_group.min_size
  }

  update_config {
    max_unavailable_percentage = 33
  }

  instance_types = var.ai_node_group.instance_types
  capacity_type  = var.ai_node_group.capacity_type
  disk_size      = 100

  labels = merge(
    var.ai_node_group.labels,
    {
      "node.kubernetes.io/workload" = "ai"
    }
  )

  taints {
    key    = "workload"
    value  = "ai"
    effect = "NO_SCHEDULE"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.cluster_name}-ai-node-group"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_group_policies
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# EKS Add-ons (2025 best practice)
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  addon_version               = var.vpc_cni_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  addon_version               = var.coredns_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags

  depends_on = [
    aws_eks_node_group.general
  ]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  addon_version               = var.kube_proxy_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags
}

# EKS Pod Identity Add-on (2025: Replaces IRSA for better performance)
resource "aws_eks_addon" "pod_identity" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = var.pod_identity_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags
}

# EBS CSI Driver Add-on (for persistent volumes)
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.ebs_csi_driver_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.ebs_csi_driver.arn

  tags = local.common_tags
}

# IAM Role for EBS CSI Driver
data "aws_iam_policy_document" "ebs_csi_driver_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${local.cluster_name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver_assume_role.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

resource "aws_eks_pod_identity_association" "ebs_csi_driver" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi_driver.arn
}

# OIDC Provider for IRSA (still useful for some workloads)
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = local.common_tags
}
