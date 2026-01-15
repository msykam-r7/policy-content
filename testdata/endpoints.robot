*** Variables ***
# Nexpose API v1.1 XML Endpoints
${API_V1_XML}                                                   /api/1.1/xml

# Nexpose API v2.1 JSON Endpoints  
${GLOBAL_NEXPOSE_V2_ENDPOINTS_ASSETS}                           /assets
${GLOBAL_NEXPOSE_V2_ENDPOINTS_SITES}                            /api/2.1/site_configurations/
${GLOBAL_NEXPOSE_V2_ENDPOINTS_SCANS}                            /api/2.1/scans

# Data API Endpoints
${GLOBAL_NEXPOSE_DATA_SCAN_TEMPLATES}                           /data/scan-templates
${GLOBAL_NEXPOSE_DATA_SCAN_TEMPLATES_PATH}                      /data/scan/templates
${GLOBAL_NEXPOSE_DATA_POLICY_SURROGATE}                         /data/policy/surrogate_identifier

# Report Endpoints
${GLOBAL_NEXPOSE_REPORTS_PATH}                                  /reports
