# Security Policy

## Supported Versions

We actively maintain security fixes for the following branches and release
streams:

| Version / Branch | Supported | Notes                                                                                                |
| ---------------- | --------- | ---------------------------------------------------------------------------------------------------- |
| `main`           | ✅        | Receives security updates and hardened defaults immediately.                                         |
| Tagged releases  | ✅        | Release tags generated from `main` via Release Please remain supported until the next minor release. |
| Other branches   | ⚠️        | Considered best-effort. Pull the latest `main` before deploying to production.                       |

If you are running a fork or a pinned commit, monitor this repository for new
releases and rebase regularly to pick up patches.

## Reporting a Vulnerability

Please **do not** open public GitHub issues for security reports. Instead:

1. Email the security response team at `x@company.com`. If you prefer GitHub,
   use Private Vulnerability Reporting or open a draft Security Advisory
   addressed to `@erayguner/servicenow-ai-maintainers`.
2. Include detailed reproduction steps, affected modules (Terraform, Kubernetes,
   scripts, etc.), and any relevant logs or plan outputs. Sanitise secrets
   before sharing.
3. Indicate the environment impact (`dev`, `staging`, `prod`) and whether the
   issue is exploitable without authenticated access.
4. Provide a recommended remediation if you have one and specify whether the
   report may be credited once fixed.

The security team aims to acknowledge new reports within **2 business days**. We
will coordinate remediation, request additional detail if needed, and keep you
informed of disclosure timelines. Critical issues may trigger out-of-band
hotfixes and a public security advisory once mitigations are deployed.

## Handling Secrets & Credentials

This project follows a strict zero-key posture:

- Use **Workload Identity Federation** for GitHub Actions
  (`google-github-actions/auth@v1`) and avoid long-lived service account keys.
  See `ZERO_SERVICE_ACCOUNT_KEYS.md` for policy details.
- Store sensitive values exclusively in Google Secret Manager definitions
  managed through Terraform. Never commit secrets, `.tfvars` with credentials,
  or encoded keys to the repository.
- Kubernetes ServiceAccounts must include the required Workload Identity
  annotations (`iam.gke.io/gcp-service-account`). Review manifests under
  `k8s/service-accounts/` when making changes.

If you discover leaked credentials or suspect compromise, rotate the secret
immediately and notify the security team.

## Dependency & Infrastructure Hygiene

- Run the provided GitHub Actions linting workflow (`Lint and Validate`) and
  `terraform fmt`, `tflint`, `tfsec`, `checkov`, plus kube-linter/kubeconform
  before raising pull requests.
- Keep Terraform provider and module versions up-to-date; review
  `terraform/docs/SECURITY_CONFIGURATION.md` for recommended baselines.
- Prefer Google-managed identities and least-privilege IAM roles when extending
  infrastructure. New IAM bindings should be peer-reviewed for scope and logged
  in change notes.

## Coordinated Disclosure

We support responsible disclosure. After a fix is available, we will publish a
SECURITY advisory summarising the impact, mitigation, and credited reporters. If
you need an embargo or have timelines mandated by a third party, mention that in
your initial report so we can accommodate the request.

Thank you for helping keep the ServiceNow AI platform secure.
