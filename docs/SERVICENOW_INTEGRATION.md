# ServiceNow → Pub/Sub Integration Runbook

## Context
When an agent or end user adds a new comment to an incident in `https://dev301424.service-now.com`, the comment must be forwarded to Google Cloud Pub/Sub so the LLM pipeline running in project `hypnotic-runway-324821` can react in near real-time. The recommended pattern is:

```
ServiceNow (sys_journal_field insert) ──► Scoped Script Include
                                       └──► Cloud Run webhook (authenticated)
                                              └──► Pub/Sub topic (incident-comment-events)
                                                     └──► LLM worker
```

ServiceNow invokes a lightweight HTTPS endpoint (Cloud Run or Cloud Functions) that handles Google authentication and publishes to Pub/Sub, avoiding long-lived keys inside ServiceNow.

## Prerequisites
- Scoped app or update-set access on the ServiceNow dev instance.
- Ability to create/edit business rules, script includes, and system properties.
- GCP IAM permissions in `hypnotic-runway-324821` to create Pub/Sub topics, Cloud Run services, service accounts, and Secret Manager entries.

## GCP Setup
1. **Pub/Sub Topic**
   ```bash
   gcloud pubsub topics create incident-comment-events \
     --project hypnotic-runway-324821
   ```
2. **Service Account**
   ```bash
   gcloud iam service-accounts create servicenow-pubsub \
     --display-name "ServiceNow Pub/Sub Bridge" \
     --project hypnotic-runway-324821

   gcloud projects add-iam-policy-binding hypnotic-runway-324821 \
     --member="serviceAccount:servicenow-pubsub@hypnotic-runway-324821.iam.gserviceaccount.com" \
     --role="roles/pubsub.publisher"
   ```
3. **Cloud Run Webhook**
   - Build a container (any supported runtime) that accepts POST requests with JSON payload and publishes to `incident-comment-events` using the service account above.
   - Example deployment:
     ```bash
     gcloud run deploy servicenow-comment-bridge \
       --image gcr.io/hypnotic-runway-324821/servicenow-comment-bridge:latest \
       --region us-central1 \
       --service-account servicenow-pubsub@hypnotic-runway-324821.iam.gserviceaccount.com \
       --allow-unauthenticated
     ```
   - Generate a shared secret and store it in Secret Manager:
     ```bash
     gcloud secrets create servicenow-bridge-api-key \
       --replication-policy=automatic \
       --project hypnotic-runway-324821
     echo -n "<random-32-byte-string>" | \
       gcloud secrets versions add servicenow-bridge-api-key --data-file=- \
       --project hypnotic-runway-324821
     ```
   - Configure Cloud Run to validate the `X-Api-Key` header against this secret.

## ServiceNow Configuration
1. **Scoped Application**
   - Create app **AI Incident Bridge** (`x_ai_incident_bridge`) to hold script includes, business rules, and logging artifacts.
2. **System Properties**
   - `x_ai_incident_bridge.pubsub_endpoint` → Cloud Run URL (e.g., `https://servicenow-comment-bridge-<hash>-uc.a.run.app/dispatch`).
   - `x_ai_incident_bridge.pubsub_api_key` → API key stored using the `Encrypted Text` type.
3. **Integration User**
   - Create `svc_ai_agent` with roles `itil` and custom role `x_ai_incident_bridge.integration`.
   - Disable interactive logins; restrict to API usage.
4. **Logging Table**
   - Add `u_ai_action_log` table (or reuse existing) with fields: `u_incident` (reference), `u_action_type`, `u_request_payload`, `u_response_payload`, `u_response_code`, `u_executed_by`, `u_timestamp`.
5. **Script Include**
   - Import `servicenow/script_includes/AiIntegrationUtils.js`. It exposes helper methods to log actions and invoke the Cloud Run endpoint.
6. **Business Rule**
   - On table `sys_journal_field`, `after insert`, condition `current.name == "incident"` and `current.element == "comments"`.
   - Use the script sample in `servicenow/business_rules/incident_comment_to_pubsub.js` to publish the comment payload via `AiIntegrationUtils`.

## Security Guards
- Configure IP Access Control or rate limiting on the Cloud Run service to accept only ServiceNow IP ranges plus the API key check.
- Encrypt the API key property in ServiceNow and limit read access to system administrators.
- Monitor Cloud Run and Pub/Sub metrics (request count, publish errors) with Cloud Monitoring alerts.

## Testing Checklist
1. Insert an incident comment in the ServiceNow dev instance.
2. Confirm the business rule log (System Logs → Application Logs) shows a successful publish entry.
3. Verify Cloud Run receives the request (Cloud Logging) and publishes to Pub/Sub (check subscription ack counts or use `gcloud pubsub subscriptions pull`).
4. Trigger at least one error path (e.g., shutdown Cloud Run) to ensure failures are captured in `u_ai_action_log`.

## Promotion
- Export all artifacts (script include, business rule, table, properties) in an Update Set named **AI Comment Bridge v1** and promote through test to production following CAB approvals.
- Update the Cloud Run service with production URL/API key and replicate the system properties in higher environments.

## Operational Notes
- Rotate the API key quarterly; update both Secret Manager and ServiceNow properties.
- Clearly document runbook steps in a ServiceNow Knowledge article for on-call responders.
- Future enhancements (optional): remove the Cloud Run hop if ServiceNow gains native support for Google service account JWT signing, or extend the business rule to include attachments/work notes.
