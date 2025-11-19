/**
 * API Canary Script for Bedrock Agent Monitoring
 * Tests endpoint availability and response time
 */

const synthetics = require('Synthetics');
const log = require('SyntheticsLogger');
const https = require('https');
const http = require('http');

const apiCanaryBlueprint = async function () {
    const endpoint = "${endpoint_url}";
    const method = "${method}";
    const expectedStatus = ${expected_status};
    const timeout = ${timeout};
    const headers = ${headers};
    const body = ${body};

    const url = new URL(endpoint);
    const protocol = url.protocol === 'https:' ? https : http;

    const options = {
        hostname: url.hostname,
        port: url.port || (url.protocol === 'https:' ? 443 : 80),
        path: url.pathname + url.search,
        method: method,
        headers: headers,
        timeout: timeout
    };

    log.info(`Testing endpoint: $${endpoint}`);
    log.info(`Method: $${method}`);
    log.info(`Expected status: $${expectedStatus}`);

    const startTime = Date.now();

    return new Promise((resolve, reject) => {
        const req = protocol.request(options, (res) => {
            const duration = Date.now() - startTime;
            let data = '';

            res.on('data', (chunk) => {
                data += chunk;
            });

            res.on('end', () => {
                log.info(`Response status: $${res.statusCode}`);
                log.info(`Response time: $${duration}ms`);

                // Record custom metrics
                synthetics.addUserAgent('CloudWatchSynthetics', '1.0');

                if (res.statusCode === expectedStatus) {
                    log.info('✓ Status code matches expected value');
                    resolve({
                        statusCode: res.statusCode,
                        duration: duration,
                        success: true
                    });
                } else {
                    const error = `Unexpected status code: $${res.statusCode} (expected $${expectedStatus})`;
                    log.error(error);
                    reject(new Error(error));
                }
            });
        });

        req.on('error', (error) => {
            const duration = Date.now() - startTime;
            log.error(`Request failed after $${duration}ms: $${error.message}`);
            reject(error);
        });

        req.on('timeout', () => {
            const duration = Date.now() - startTime;
            log.error(`Request timed out after $${duration}ms`);
            req.destroy();
            reject(new Error(`Request timeout after $${timeout}ms`));
        });

        // Send request body if provided
        if (body !== null && (method === 'POST' || method === 'PUT' || method === 'PATCH')) {
            req.write(JSON.stringify(body));
        }

        req.end();
    });
};

exports.handler = async () => {
    return await synthetics.executeHttpStep('BedrockAgentEndpointCheck', apiCanaryBlueprint);
};
