*** Settings ***
Documentation     Report operations - Generate and monitor XCCDF reports
Library           RequestsLibrary
Library           Collections
Library           XML
Library           ../library/generate_xccdf_report.py
Resource          login.robot
Resource          ../testdata/endpoints.robot


*** Keywords ***
Validate Report From Excel
    [Documentation]    Load rules from Excel/CSV and validate against XCCDF report
    [Arguments]    ${excel_path}    ${xml_content}    ${file_type}=csv    ${profile_filter}=${None}
    
    # Write XML content to temporary file to avoid escaping issues
    ${temp_xml_file}=    Evaluate    __import__('tempfile').NamedTemporaryFile(mode='w', suffix='.xml', delete=False).name
    Create File    ${temp_xml_file}    ${xml_content}
    
    # Import Python library and create validator instance
    Evaluate    __import__('sys').path.insert(0, '${EXECDIR}/library')
    ${validator}=    Evaluate    __import__('excel_validator').ExcelValidator()
    
    # Load rules from file with optional profile filter
    Log    <span style="color: blue; font-weight: bold;">📊 Loading rules from: ${excel_path}</span>    html=True
    Run Keyword If    '${profile_filter}' != 'None'
    ...    Log    <span style="color: purple; font-weight: bold;">🔍 Filtering rules for profile: ${profile_filter}</span>    html=True
    
    Run Keyword If    '${file_type}' == 'csv'
    ...    Evaluate    $validator.load_rules_from_csv('${excel_path}', profile_filter='${profile_filter}' if '${profile_filter}' != 'None' else None)
    ...    ELSE
    ...    Evaluate    $validator.load_rules_from_excel('${excel_path}', profile_filter='${profile_filter}' if '${profile_filter}' != 'None' else None)
    
    ${rules}=    Evaluate    $validator.rules
    ${rule_count}=    Get Length    ${rules}
    Log    <span style="color: green; font-weight: bold;">✓ Loaded ${rule_count} rules from file</span>    html=True
    
    # Read XML from temp file and validate
    Log    <span style="color: blue; font-weight: bold;">🔍 Validating rules against XCCDF report...</span>    html=True
    ${xml_from_file}=    Get File    ${temp_xml_file}
    ${passed}    ${failed}    ${results}=    Evaluate    $validator.validate_xccdf_report($xml_from_file)
    
    # Clean up temp file
    Remove File    ${temp_xml_file}
    
    # Get and display summary
    ${summary}=    Evaluate    $validator.get_validation_summary()
    Log    ${summary}    console=True
    
    # Get failed rules for detailed logging
    ${failed_rules}=    Evaluate    $validator.get_failed_rules()
    ${failed_count}=    Get Length    ${failed_rules}
    
    IF    ${failed_count} > 0
        Log    <span style="color: red; font-weight: bold; font-size: 1.2em;">❌ FAILED RULES DETAIL:</span>    html=True
        FOR    ${failed_rule}    IN    @{failed_rules}
            Log    <span style="color: red; font-weight: bold;">Rule #${failed_rule['number']}: ${failed_rule['message']}</span>    html=True
            Log    <span style="color: #666;">- Rule ID: ${failed_rule['rule_id']}</span>    html=True
            Log    <span style="color: #666;">- Expected: ${failed_rule['expected']}</span>    html=True
            Log    <span style="color: #666;">- Actual: ${failed_rule['actual']}</span>    html=True
            Log    <span style="color: #ccc;">---</span>    html=True
        END
    END
    
    # Return validation results
    RETURN    ${passed}    ${failed}    ${results}

Generate XCCDF Report For Policy
    [Documentation]    Generate XCCDF report for a specific policy and site
    ...    Creates a policy compliance report and triggers immediate generation
    ...    Example: Generate XCCDF Report For Policy    site_id=9    policy_natural_id=190    report_name=My Policy Report
    [Arguments]    ${site_id}    ${policy_natural_id}    ${report_name}
    
    # Import payload builder and load JSON template to build XML
    Evaluate    __import__('sys').path.insert(0, '${EXECDIR}/library')
    ${xccdf_generator}=    Evaluate    __import__('generate_xccdf_report').XCCDFReportGenerator()
    ${payload_file}=    Set Variable    ${EXECDIR}/payloads/create_xccdf_report.json
    
    # Build XML from JSON template with parameters
    ${report_xml}=    Evaluate    $xccdf_generator.load_and_build_xccdf_report('${payload_file}', '${SESSION_ID}', '${site_id}', '${policy_natural_id}', '${report_name}')
    
    # Create headers with session ID
    ${headers}=    Create Dictionary    
    ...    Content-Type=text/xml; charset=UTF-8    
    ...    Cookie=nexposeCCSessionID=${SESSION_ID}
    
    Log    ========================================    console=True
    Log    GENERATING XCCDF REPORT    console=True
    Log    Report Name: ${report_name}    console=True
    Log    Site ID: ${site_id}    console=True
    Log    Policy Natural ID: ${policy_natural_id}    console=True
    Log    ========================================    console=True
    Log    📤 REQUEST DETAILS:    console=True
    Log    Endpoint: POST ${API_V1_XML}    console=True
    Log    Headers:    console=True
    Log    - Content-Type: text/xml; charset=UTF-8    console=True
    Log    - Cookie: nexposeCCSessionID=${SESSION_ID}    console=True
    Log    ========================================    console=True
    Log    📝 REQUEST BODY (XML):    console=True
    Log    ${report_xml}    console=True
    Log    ========================================    console=True
    
    # Use auto-reauth wrapper for API call
    ${response}=    login.API Call With Auto Reauth    
    ...    POST    
    ...    ${API_V1_XML}    
    ...    headers=${headers}
    ...    data=${report_xml}
    
    # Log response details immediately
    Log    ========================================    console=True
    Log    📥 RESPONSE RECEIVED    console=True
    Log    ========================================    console=True
    Log    Status Code: ${response.status_code}    console=True
    Log    Response Headers:    console=True
    ${header_keys}=    Evaluate    list($response.headers.keys())
    FOR    ${header}    IN    @{header_keys}
        ${header_value}=    Evaluate    $response.headers.get($header)
        Log    - ${header}: ${header_value}    console=True
    END
    Log    ========================================    console=True
    Log    📄 RESPONSE BODY (XML):    console=True
    Log    ${response.text}    console=True
    Log    ========================================    console=True
    
    # Check if response is successful
    IF    ${response.status_code} != 200
        Log    ❌ Failed to generate report. Status: ${response.status_code}    console=True
        Log    Error Response: ${response.text}    console=True
        Fail    Failed to generate XCCDF report with status ${response.status_code}: ${response.text}
    END
    
    # Parse XML response to extract report ID
    # Response format: <ReportSaveResponse success="1" reportcfg-id="123"/>
    ${root}=    Parse XML    ${response.text}
    ${success}=    Get Element Attribute    ${root}    success
    ${report_id}=    Get Element Attribute    ${root}    reportcfg-id
    
    Log    ========================================    console=True
    Log    📊 PARSED RESPONSE DETAILS    console=True
    Log    ========================================    console=True
    Log    API Success Flag: ${success}    console=True
    Log    Report Config ID: ${report_id}    console=True
    
    IF    '${success}' != '1'
        Log    ❌ Report generation failed. API returned success=${success}    console=True
        Fail    Report generation failed. API returned success=${success}
    END
    
    Log    ========================================    console=True
    Log    ✅ REPORT CREATION SUCCESS    console=True
    Log    ========================================    console=True
    Log    Report Config ID: ${report_id}    console=True
    Log    Report Name: ${report_name}    console=True
    Log    Site ID: ${site_id}    console=True
    Log    Policy Natural ID: ${policy_natural_id}    console=True
    Log    ========================================    console=True
    
    # Return dictionary with report details
    ${result}=    Create Dictionary
    ...    report_id=${report_id}
    ...    report_format=xccdf-xml
    ...    site_id=${site_id}
    ...    policy_natural_id=${policy_natural_id}
    ...    report_name=${report_name}
    ...    raw_response=${response.text}
    
    RETURN    ${result}


Get Report Status
    [Documentation]    Get the status and history of a report by its configuration ID
    ...    Returns report generation status and history
    ...    Example: Get Report Status    report_config_id=123
    [Arguments]    ${report_config_id}
    
    # Create XML request body for report history
    ${history_xml}=    Catenate    SEPARATOR=
    ...    <?xml version="1.0" encoding="UTF-8"?>
    ...    <ReportHistoryRequest session-id="${SESSION_ID}" reportcfg-id="${report_config_id}"/>
    
    # Create headers with session ID
    ${headers}=    Create Dictionary    
    ...    Content-Type=text/xml; charset=UTF-8    
    ...    Cookie=nexposeCCSessionID=${SESSION_ID}
    
    Log    ========================================    console=True
    Log    GETTING REPORT STATUS    console=True
    Log    Report Config ID: ${report_config_id}    console=True
    Log    ========================================    console=True
    Log    📤 REQUEST DETAILS:    console=True
    Log    Endpoint: POST ${API_V1_XML}    console=True
    Log    Headers:    console=True
    Log    - Content-Type: text/xml; charset=UTF-8    console=True
    Log    - Cookie: nexposeCCSessionID=${SESSION_ID}    console=True
    Log    ========================================    console=True
    Log    📝 REQUEST BODY (XML):    console=True
    Log    ${history_xml}    console=True
    Log    ========================================    console=True
    
    # Use auto-reauth wrapper for API call
    ${response}=    login.API Call With Auto Reauth    
    ...    POST    
    ...    ${API_V1_XML}    
    ...    headers=${headers}
    ...    data=${history_xml}
    
    # Log response details
    Log    ========================================    console=True
    Log    📥 RESPONSE RECEIVED    console=True
    Log    ========================================    console=True
    Log    Status Code: ${response.status_code}    console=True
    Log    ========================================    console=True
    Log    📄 RESPONSE BODY (XML):    console=True
    Log    ${response.text}    console=True
    Log    ========================================    console=True
    
    # Check if response is successful
    IF    ${response.status_code} != 200
        Log    ❌ Failed to get report status. Status: ${response.status_code}    console=True
        Log    Error Response: ${response.text}    console=True
        Fail    Failed to get report status with code ${response.status_code}: ${response.text}
    END
    
    # Parse XML response
    ${root}=    Parse XML    ${response.text}
    ${success}=    Get Element Attribute    ${root}    success
    
    Log    ========================================    console=True
    Log    📊 PARSED RESPONSE DETAILS    console=True
    Log    ========================================    console=True
    Log    API Success Flag: ${success}    console=True
    
    IF    '${success}' != '1'
        Log    ❌ Report status check failed. API returned success=${success}    console=True
        Fail    Report status check failed. API returned success=${success}
    END
    
    # Extract report history information
    ${result}=    Create Dictionary
    ...    report_config_id=${report_config_id}
    ...    success=${success}
    ...    raw_response=${response.text}
    
    # Try to extract ReportSummary elements if they exist
    ${has_reports}=    Run Keyword And Return Status    Element Should Exist    ${root}    ReportSummary
    IF    ${has_reports}
        ${reports}=    Get Elements    ${root}    ReportSummary
        ${report_count}=    Get Length    ${reports}
        Set To Dictionary    ${result}    report_count=${report_count}
        
        # Get details of the most recent report (first in list)
        IF    ${report_count} > 0
            ${latest_report}=    Set Variable    ${reports}[0]
            ${report_id}=    Get Element Attribute    ${latest_report}    id
            ${status}=    Get Element Attribute    ${latest_report}    status
            ${generated_on}=    Get Element Attribute    ${latest_report}    generated-on
            
            Set To Dictionary    ${result}    
            ...    latest_report_id=${report_id}
            ...    latest_status=${status}
            ...    generated_on=${generated_on}
            
            Log    Latest Report ID: ${report_id}    console=True
            Log    Status: ${status}    console=True
            Log    Generated On: ${generated_on}    console=True
        END
    ELSE
        Set To Dictionary    ${result}    report_count=0
        Log    No report history found yet    console=True
    END
    
    Log    ========================================    console=True
    Log    ✅ REPORT STATUS RETRIEVED    console=True
    Log    ========================================    console=True
    
    RETURN    ${result}


Download Report
    [Documentation]    Download a generated report by its report config ID and report instance ID
    ...    Downloads the XCCDF XML report file with retry logic for transient errors
    ...    Will retry up to 3 times with exponential backoff for 500 errors
    ...    NOTE: Report IDs in URLs use HEXADECIMAL format with 8-digit zero-padding
    ...    Example: Download Report    report_config_id=11    report_instance_id=11
    [Arguments]    ${report_config_id}    ${report_instance_id}
    
    # Convert IDs to HEXADECIMAL 8-digit zero-padded format (not decimal!)
    # Example: 11 decimal -> 0x0B hex -> 0000000B with padding
    ${config_id_hex}=    Evaluate    hex(${report_config_id})[2:].upper().zfill(8)
    ${instance_id_hex}=    Evaluate    hex(${report_instance_id})[2:].upper().zfill(8)
    
    # Construct download URL with hex-padded IDs
    ${download_url}=    Set Variable    ${GLOBAL_NEXPOSE_REPORTS_PATH}/${config_id_hex}/${instance_id_hex}/xccdf.xml
    
    # Retry logic for download
    ${max_retries}=    Set Variable    3
    ${retry_count}=    Set Variable    0
    ${download_success}=    Set Variable    ${FALSE}
    ${response}=    Set Variable    ${NONE}
    
    WHILE    ${retry_count} < ${max_retries} and not ${download_success}
        ${retry_count}=    Evaluate    ${retry_count} + 1
        
        # Create headers with current session ID
        ${headers}=    Create Dictionary    
        ...    Cookie=nexposeCCSessionID=${SESSION_ID}
        
        Log    ========================================    console=True
        Log    DOWNLOADING REPORT (Attempt ${retry_count}/${max_retries})    console=True
        Log    Report Config ID: ${report_config_id} (0x${config_id_hex})    console=True
        Log    Report Instance ID: ${report_instance_id} (0x${instance_id_hex})    console=True
        Log    Download URL: ${download_url}    console=True
        Log    ========================================    console=True
        Log    📤 REQUEST DETAILS:    console=True
        Log    Endpoint: GET ${download_url}    console=True
        Log    Headers:    console=True
        Log    - Cookie: nexposeCCSessionID=${SESSION_ID}    console=True
        Log    ========================================    console=True
        
        # Use auto-reauth wrapper for API call
        ${response}=    login.API Call With Auto Reauth    
        ...    GET    
        ...    ${download_url}    
        ...    headers=${headers}
        
        # Log response details
        Log    ========================================    console=True
        Log    📥 RESPONSE RECEIVED    console=True
        Log    ========================================    console=True
        Log    Status Code: ${response.status_code}    console=True
        Log    Content Type: ${response.headers.get('Content-Type')}    console=True
        ${content_length}=    Evaluate    len($response.content)
        Log    Content Length: ${content_length} bytes    console=True
        Log    ========================================    console=True
        
        # Check if download was successful
        IF    ${response.status_code} == 200
            ${download_success}=    Set Variable    ${TRUE}
            Log    ✅ Download successful on attempt ${retry_count}    console=True
        ELSE IF    ${response.status_code} == 500 and ${retry_count} < ${max_retries}
            Log    ⚠️ Received 500 error on attempt ${retry_count}, will retry...    WARN    console=True
            Log    Error Response: ${response.text}    console=True
            # Exponential backoff: 5s, 10s, 15s
            ${sleep_time}=    Evaluate    ${retry_count} * 5
            Log    Waiting ${sleep_time} seconds before retry...    console=True
            Sleep    ${sleep_time}s
        ELSE
            Log    ❌ Failed to download report. Status: ${response.status_code}    console=True
            Log    Error Response: ${response.text}    console=True
            Fail    Failed to download report after ${retry_count} attempts. Status ${response.status_code}: ${response.text}
        END
    END
    
    # Final check after retry loop
    IF    not ${download_success}
        Fail    Failed to download report after ${max_retries} attempts. Last status: ${response.status_code}
    END
    
    # Log full report content
    Log    ========================================    console=True
    Log    📄 FULL REPORT CONTENT (XML):    console=True
    Log    ========================================    console=True
    Log    ${response.text}    console=True
    Log    ========================================    console=True
    
    Log    ========================================    console=True
    Log    ✅ REPORT DOWNLOAD SUCCESSFUL    console=True
    Log    ========================================    console=True
    Log    Report Config ID: ${report_config_id}    console=True
    Log    Report Instance ID: ${report_instance_id}    console=True
    Log    Content Size: ${content_length} bytes    console=True
    Log    ========================================    console=True
    
    # Return dictionary with download details
    ${result}=    Create Dictionary
    ...    report_config_id=${report_config_id}
    ...    report_instance_id=${report_instance_id}
    ...    content_length=${content_length}
    ...    content_type=${response.headers.get('Content-Type')}
    ...    download_url=${download_url}
    ...    report_content=${response.text}
    
    RETURN    ${result}


Validate Report Rules
    [Documentation]    Validate that specific rules exist in the report with expected results
    ...    Takes report XML content and list of rules with expected results
    ...    Example: Validate Report Rules    ${report_xml}    ${rules_list}
    [Arguments]    ${report_content}    ${rules_to_validate}
    
    # Parse the report XML
    ${report_xml}=    Parse XML    ${report_content}
    
    # Result mapping from XCCDF to expected format
    ${result_mapping}=    Create Dictionary
    ...    pass=COMPLIANT
    ...    fail=NOT COMPLIANT
    ...    notapplicable=NOT APPLICABLE
    ...    notchecked=NOT CHECKED
    ...    unknown=UNKNOWN
    ...    informational=INFORMATIONAL
    
    Log    ========================================    console=True
    Log    🔍 VALIDATING REPORT RULES    console=True
    Log    ========================================    console=True
    Log    Total rules to validate: ${rules_to_validate.__len__()}    console=True
    Log    ========================================    console=True
    
    # Create validation results dictionary
    ${validation_results}=    Create Dictionary
    ${passed_count}=    Set Variable    ${0}
    ${failed_count}=    Set Variable    ${0}
    
    # Iterate through each rule to validate
    FOR    ${rule}    IN    @{rules_to_validate}
        ${rule_id}=    Set Variable    ${rule}[rule_id]
        ${expected_result}=    Set Variable    ${rule}[expected_result]
        
        Log    ----------------------------------------    console=True
        Log    Rule: ${rule_id}    console=True
        Log    Expected: ${expected_result}    console=True
        
        # Search for the rule in XML using xpath
        # XCCDF format: <rule-result idref="rule_id"><result>pass</result></rule-result>
        ${rule_found}=    Run Keyword And Return Status    
        ...    Element Should Exist    ${report_xml}    .//rule-result[@idref='${rule_id}']
        
        IF    ${rule_found}
            # Get the rule-result element
            ${rule_element}=    Get Element    ${report_xml}    .//rule-result[@idref='${rule_id}']
            ${result_element}=    Get Element    ${rule_element}    result
            ${actual_result_raw}=    Get Element Text    ${result_element}
            
            # Map the result from XCCDF format to expected format
            ${actual_result}=    Get From Dictionary    ${result_mapping}    ${actual_result_raw}
            
            Log    Actual: ${actual_result} (${actual_result_raw})    console=True
            
            # Compare expected vs actual
            ${matches}=    Evaluate    '${actual_result}' == '${expected_result}'
            
            IF    ${matches}
                Log    ✅ PASS - Result matches expected    console=True
                ${passed_count}=    Evaluate    ${passed_count} + 1
                Set To Dictionary    ${validation_results}    ${rule_id}=PASS
            ELSE
                Log    ❌ FAIL - Expected: ${expected_result}, Got: ${actual_result}    console=True
                ${failed_count}=    Evaluate    ${failed_count} + 1
                Set To Dictionary    ${validation_results}    ${rule_id}=FAIL: Expected ${expected_result}, Got ${actual_result}
            END
        ELSE
            Log    ❌ FAIL - Rule not found in report    console=True
            ${failed_count}=    Evaluate    ${failed_count} + 1
            Set To Dictionary    ${validation_results}    ${rule_id}=FAIL: Rule not found in report
        END
    END
    
    Log    ========================================    console=True
    Log    📊 VALIDATION SUMMARY    console=True
    Log    ========================================    console=True
    Log    Total Rules Validated: ${rules_to_validate.__len__()}    console=True
    Log    Passed: ${passed_count}    console=True
    Log    Failed: ${failed_count}    console=True
    Log    ========================================    console=True
    
    # Create result dictionary
    ${summary}=    Create Dictionary
    ...    total=${rules_to_validate.__len__()}
    ...    passed=${passed_count}
    ...    failed=${failed_count}
    ...    details=${validation_results}
    
    # Fail the test if any validation failed
    IF    ${failed_count} > 0
        Fail    ${failed_count} rule validation(s) failed. See details above.
    END
    
    RETURN    ${summary}
