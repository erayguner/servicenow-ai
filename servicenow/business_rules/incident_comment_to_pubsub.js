/**
 * Business Rule: Publish Incident Comments to Pub/Sub
 * Table: sys_journal_field
 * When: after insert
 * Condition: name == "incident" && element == "comments"
 * Notes: Mark the rule as async to keep UI responsive.
 */

(function executeRule(current /*, previous*/) {
  try {
    if (current.name !== 'incident') {
      return;
    }

    if (current.element !== 'comments') {
      return;
    }

    if (gs.nil(current.value)) {
      return;
    }

    if (current.sys_created_by === 'svc_ai_agent') {
      // Avoid feedback loops for comments inserted by the integration itself.
      return;
    }

    var incidentSysId = current.element_id;
    if (gs.nil(incidentSysId)) {
      return;
    }

    var incidentNumber = '';
    var incident = new GlideRecord('incident');
    if (incident.get(incidentSysId)) {
      incidentNumber = incident.getValue('number');
    }

    var authorName = current.sys_created_by;
    var authorSysId = '';
    var authorDisplay = authorName || '';

    if (!gs.nil(authorName)) {
      var user = new GlideRecord('sys_user');
      if (user.get('user_name', authorName)) {
        authorSysId = user.getUniqueValue();
        authorDisplay = user.getDisplayValue();
      }
    }

    var utils = new AiIntegrationUtils();
    utils.publishCommentToBridge({
      incidentSysId: incidentSysId,
      incidentNumber: incidentNumber,
      comment: current.value,
      authorSysId: authorSysId,
      authorDisplay: authorDisplay,
      createdOn: current.sys_created_on.getDisplayValue(),
    });
  } catch (e) {
    gs.error('[AI Bridge] Error publishing comment: ' + e);
  }
})(current);
