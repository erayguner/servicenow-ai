/**
 * Scripted REST API: Incident Router
 * Namespace: x_ai_incident_bridge
 *
 * Exposes CRUD-style endpoints for the AI agent.
 * Attach this script to the POST (collection), POST (action), and GET (item) resources.
 *
 * Required role: x_ai_incident_bridge.integration
 */

(function process(/*RESTAPIRequest*/ request, /*RESTAPIResponse*/ response) {
  var method = (request && request.method) ? request.method.toUpperCase() : 'GET';
  var payload = (request && request.body && typeof request.body.data === 'string') ? JSON.parse(request.body.data) : {};
  var sysId = request && request.pathParams && request.pathParams.sys_id;

  switch (method) {
    case 'POST':
      if (sysId) {
        return handleAction(sysId, payload, response);
      }
      return handleCreateOrUpdate(payload, response);
    case 'GET':
      return handleGet(sysId, response);
    default:
      response.setStatus(405);
      response.setBody({ error: 'Method not allowed' });
  }
})();

function handleCreateOrUpdate(payload, response) {
  if (!payload || !payload.short_description) {
    response.setStatus(400);
    return response.setBody({ error: 'short_description is required' });
  }

  var incident = findIncident(payload.sys_id, payload.number);
  var isNew = !incident;

  var gr = incident || new GlideRecord('incident');
  if (isNew) {
    gr.initialize();
  }

  setIfDefined(gr, 'short_description', payload.short_description);
  setIfDefined(gr, 'description', payload.description);
  setIfDefined(gr, 'category', payload.category);
  setIfDefined(gr, 'subcategory', payload.subcategory);
  setIfDefined(gr, 'assignment_group', payload.assignment_group);
  setIfDefined(gr, 'caller_id', payload.caller_id);
  setIfDefined(gr, 'state', payload.state);
  setIfDefined(gr, 'u_ai_status', payload.ai_status || 'pending');
  setIfDefined(gr, 'u_ai_last_action', 'create_or_update');

  var resultSysId = gr.update() || gr.insert();

  logAction(resultSysId, 'ingest', payload, { sys_id: resultSysId }, 200);

  response.setStatus(isNew ? 201 : 200);
  return response.setBody({ sys_id: resultSysId, number: gr.number });
}

function handleAction(sysId, payload, response) {
  if (!sysId) {
    response.setStatus(400);
    return response.setBody({ error: 'sys_id path parameter required' });
  }

  var gr = new GlideRecord('incident');
  if (!gr.get(sysId)) {
    response.setStatus(404);
    return response.setBody({ error: 'incident not found' });
  }

  if (payload.work_note) {
    gr.work_notes = payload.work_note;
  }
  if (payload.state) {
    gr.state = payload.state;
  }
  gr.u_ai_status = payload.ai_status || 'engaged';
  gr.u_ai_last_action = payload.action || 'update';
  gr.update();

  logAction(sysId, 'action', payload, { sys_id: sysId }, 200);

  response.setStatus(200);
  return response.setBody({ sys_id: sysId, state: gr.state });
}

function handleGet(sysId, response) {
  if (!sysId) {
    response.setStatus(400);
    return response.setBody({ error: 'sys_id path parameter required' });
  }

  var gr = new GlideRecord('incident');
  if (!gr.get(sysId)) {
    response.setStatus(404);
    return response.setBody({ error: 'incident not found' });
  }

  var result = {
    sys_id: gr.getUniqueValue(),
    number: gr.getValue('number'),
    short_description: gr.getValue('short_description'),
    description: gr.getValue('description'),
    category: gr.getValue('category'),
    subcategory: gr.getValue('subcategory'),
    assignment_group: gr.getValue('assignment_group'),
    state: gr.getValue('state'),
    u_ai_status: gr.getValue('u_ai_status'),
    u_ai_last_action: gr.getValue('u_ai_last_action'),
  };

  response.setStatus(200);
  return response.setBody(result);
}

function findIncident(sysId, number) {
  var gr = new GlideRecord('incident');
  if (sysId && gr.get(sysId)) {
    return gr;
  }
  if (number && gr.get('number', number)) {
    return gr;
  }
  return null;
}

function setIfDefined(record, field, value) {
  if (typeof value !== 'undefined' && value !== null && value !== '') {
    record[field] = value;
  }
}

function logAction(incidentSysId, actionType, requestPayload, responsePayload, responseCode) {
  var utils = new AiIntegrationUtils();
  utils.logAction(incidentSysId, actionType, requestPayload, responsePayload, responseCode);
}
