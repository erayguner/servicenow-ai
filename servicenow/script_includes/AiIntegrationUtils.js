var AiIntegrationUtils = Class.create();
AiIntegrationUtils.prototype = {
  initialize: function() {
  },

  logAction: function(incidentSysId, actionType, requestPayload, responsePayload, responseCode) {
    var log = new GlideRecord('u_ai_action_log');
    if (!log.isValid()) {
      return;
    }
    log.initialize();
    log.u_incident = incidentSysId;
    log.u_action_type = actionType;
    log.u_request_payload = JSON.stringify(requestPayload || {});
    log.u_response_payload = JSON.stringify(responsePayload || {});
    log.u_response_code = responseCode;
    log.u_executed_by = gs.getUserName();
    log.u_timestamp = new GlideDateTime();
    log.insert();
  },

  publishCommentToBridge: function(context) {
    if (!context || !context.incidentSysId || !context.comment) {
      gs.error('[AI Bridge] Invalid publish context: ' + JSON.stringify(context));
      return;
    }

    var endpoint = gs.getProperty('x_ai_incident_bridge.pubsub_endpoint', '');
    if (!endpoint) {
      gs.error('[AI Bridge] Missing property x_ai_incident_bridge.pubsub_endpoint');
      return;
    }

    var apiKey = gs.getProperty('x_ai_incident_bridge.pubsub_api_key', '');
    var body = {
      incident_sys_id: context.incidentSysId,
      incident_number: context.incidentNumber || '',
      comment: context.comment,
      author_sys_id: context.authorSysId || '',
      author_display_value: context.authorDisplay || '',
      created_on: context.createdOn || new GlideDateTime().getDisplayValue(),
      source: 'servicenow',
    };

    var responseCode = 0;
    var responseBody = '';

    try {
      var request = new sn_ws.RESTMessageV2();
      request.setEndpoint(endpoint);
      request.setHttpMethod('POST');
      request.setRequestHeader('Content-Type', 'application/json');
      if (apiKey) {
        request.setRequestHeader('X-Api-Key', apiKey);
      }
      request.setRequestBody(JSON.stringify(body));

      var response = request.execute();
      responseCode = response.getStatusCode();
      responseBody = response.getBody();
    } catch (ex) {
      responseCode = 500;
      responseBody = { error: ex.message || ex.toString() };
      gs.error('[AI Bridge] Publish failed: ' + ex);
    }

    this.logAction(
      context.incidentSysId,
      'comment_publish',
      body,
      responseBody,
      responseCode,
    );
  },

  type: 'AiIntegrationUtils',
};
