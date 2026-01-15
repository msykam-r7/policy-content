*** Settings ***
Documentation     Scan Operations Keywords for Nexpose/InsightVM
Library           RequestsLibrary
Library           Collections
Library           String
Library           XML
Resource          ../testdata/endpoints.robot
Resource          login.robot


*** Variables ***
${SESSION_ID}         ${EMPTY}
${BASE_URL}           ${EMPTY}


*** Keywords ***
Start Scan
    [Documentation]    Start an ad-hoc scan on a site using XML API
    ...    Automatically handles session expiry by re-authenticating and retrying
    ...    
    ...    Arguments:
    ...    - site_id: Site ID to scan
    ...    - engine_id: Optional (not used in XML API, kept for compatibility)
    ...    - scan_name: Optional (not used in XML API, kept for compatibility)
    ...    
    ...    Returns: Dictionary with scan_id and scan details
    [Arguments]    ${site_id}    ${engine_id}=${EMPTY}    ${scan_name}=${EMPTY}
    
    # Validate session
    ${session_valid}=    Run Keyword And Return Status    Should Not Be Equal    ${SESSION_ID}    ${EMPTY}
    
    IF    not ${session_valid}
        Fail    Session ID is empty. Please login first.
    END
    
    # Load start scan request payload template
    ${payload_file}=    Set Variable    ${CURDIR}/../payloads/start_scan_request.json
    ${payload_json}=    Evaluate    json.load(open('${payload_file}'))    json
    ${scan_xml_template}=    Get From Dictionary    ${payload_json}    xml_payload
    
    # Replace session and site ID placeholders (convert site_id to string)
    ${site_id_str}=    Convert To String    ${site_id}
    ${scan_xml}=    Replace String    ${scan_xml_template}    SESSION_ID_PLACEHOLDER    ${SESSION_ID}
    ${scan_xml}=    Replace String    ${scan_xml}    SITE_ID_PLACEHOLDER    ${site_id_str}
    
    # Prepare headers
    ${headers}=    Create Dictionary    
    ...    Content-Type=text/xml
    ...    Cookie=nexposeCCSessionID=${SESSION_ID}
    
    Log    ========================================    console=True
    Log    STARTING SCAN FOR SITE: ${site_id}    console=True
    Log    Request XML: ${scan_xml}    console=True
    Log    ========================================    console=True
    
    # Send POST request with auto-reauth
    ${response}=    login.API Call With Auto Reauth
    ...    POST
    ...    ${API_V1_XML}
    ...    data=${scan_xml}
    ...    headers=${headers}
    
    Log    Status Code: ${response.status_code}    console=True
    Log    Response Body: ${response.text}    console=True
    
    # Check if successful
    Should Be Equal As Strings    ${response.status_code}    200
    ...    msg=Failed to start scan for site ${site_id}. Status: ${response.status_code}, Response: ${response.text}
    
    ${root}=    Parse XML    ${response.text}
    
    # Extract scan-id from the Scan element
    ${scan_element}=    Get Element    ${root}    Scan
    ${scan_id}=    Get Element Attribute    ${scan_element}    scan-id
    
    Log    ✓ Scan started successfully - Scan ID: ${scan_id}    console=True
    
    ${result}=    Create Dictionary
    ...    scan_id=${scan_id}
    ...    response=${response.text}
    
    RETURN    ${result}


Get Scan Status
    [Documentation]    Get the current status of a scan using XML API
    ...    Automatically handles session expiry by re-authenticating and retrying
    ...    
    ...    Arguments:
    ...    - scan_id: Scan ID to check status for
    ...    
    ...    Returns: Dictionary with status, scan_id, and full response
    [Arguments]    ${scan_id}
    
    # Validate session
    ${session_valid}=    Run Keyword And Return Status    Should Not Be Equal    ${SESSION_ID}    ${EMPTY}
    
    IF    not ${session_valid}
        Fail    Session ID is empty. Please login first.
    END
    
    # Load scan status request payload template
    ${payload_file}=    Set Variable    ${CURDIR}/../payloads/scan_status_request.json
    ${payload_json}=    Evaluate    json.load(open('${payload_file}'))    json
    ${status_xml_template}=    Get From Dictionary    ${payload_json}    xml_payload
    
    # Replace session and scan ID placeholders (convert scan_id to string)
    ${scan_id_str}=    Convert To String    ${scan_id}
    ${status_xml}=    Replace String    ${status_xml_template}    SESSION_ID_PLACEHOLDER    ${SESSION_ID}
    ${status_xml}=    Replace String    ${status_xml}    SCAN_ID_PLACEHOLDER    ${scan_id_str}
    
    # Prepare headers
    ${headers}=    Create Dictionary    
    ...    Content-Type=text/xml
    ...    Cookie=nexposeCCSessionID=${SESSION_ID}
    
    # Send POST request with auto-reauth
    ${response}=    login.API Call With Auto Reauth
    ...    POST
    ...    ${API_V1_XML}
    ...    data=${status_xml}
    ...    headers=${headers}
    
    # Check if successful
    Should Be Equal As Strings    ${response.status_code}    200
    ...    msg=Failed to get scan status for scan ${scan_id}. Status: ${response.status_code}, Response: ${response.text}
    
    ${root}=    Parse XML    ${response.text}
    ${status}=    Get Element Attribute    ${root}    status
    ${success}=    Get Element Attribute    ${root}    success
    
    # Don't fail immediately if success=0, let Monitor keyword handle timeout
    # Just return the status with success flag for monitoring
    ${result}=    Create Dictionary
    ...    status=${status}
    ...    scan_id=${scan_id}
    ...    response=${response.text}
    ...    success=${success}
    
    RETURN    ${result}


Get Scan Details
    [Documentation]    Get detailed information about a scan using XML API
    ...    Automatically handles session expiry by re-authenticating and retrying
    ...    
    ...    Arguments:
    ...    - scan_id: Scan ID
    ...    - site_id: Site ID (optional, not used in XML API but kept for compatibility)
    ...    
    ...    Returns: Dictionary with complete scan details
    [Arguments]    ${scan_id}    ${site_id}=${EMPTY}
    
    # Validate session
    ${session_valid}=    Run Keyword And Return Status    Should Not Be Equal    ${SESSION_ID}    ${EMPTY}
    
    IF    not ${session_valid}
        Fail    Session ID is empty. Please login first.
    END
    
    # Load scan statistics request payload template
    ${payload_file}=    Set Variable    ${CURDIR}/../payloads/scan_statistics_request.json
    ${payload_json}=    Evaluate    json.load(open('${payload_file}'))    json
    ${stats_xml_template}=    Get From Dictionary    ${payload_json}    xml_payload
    
    # Replace session and scan ID placeholders (convert scan_id to string)
    ${scan_id_str}=    Convert To String    ${scan_id}
    ${stats_xml}=    Replace String    ${stats_xml_template}    SESSION_ID_PLACEHOLDER    ${SESSION_ID}
    ${stats_xml}=    Replace String    ${stats_xml}    SCAN_ID_PLACEHOLDER    ${scan_id_str}
    
    # Prepare headers
    ${headers}=    Create Dictionary    
    ...    Content-Type=text/xml
    ...    Cookie=nexposeCCSessionID=${SESSION_ID}
    
    # Send POST request with auto-reauth
    ${response}=    login.API Call With Auto Reauth
    ...    POST
    ...    ${API_V1_XML}
    ...    data=${stats_xml}
    ...    headers=${headers}
    
    # Check if successful
    Should Be Equal As Strings    ${response.status_code}    200
    ...    msg=Failed to get scan statistics for scan ${scan_id}. Status: ${response.status_code}, Response: ${response.text}
    
    Log    Scan Statistics XML Response: ${response.text}    console=True
    ${root}=    Parse XML    ${response.text}
    
    # Log all attributes for debugging
    ${attributes}=    Get Element Attributes    ${root}
    Log    All XML Attributes: ${attributes}    console=True
    
    # Create return dictionary with scan details from XML attributes
    ${result}=    Create Dictionary
    ...    scan_id=${scan_id}
    ...    response=${response.text}
    
    # Extract all available attributes dynamically
    FOR    ${attr_name}    IN    @{attributes}
        ${attr_value}=    Get Element Attribute    ${root}    ${attr_name}
        Set To Dictionary    ${result}    ${attr_name}=${attr_value}
    END
    
    RETURN    ${result}


Monitor Scan Until Complete
    [Documentation]    Monitor scan status with adaptive polling until completion
    ...    
    ...    Uses adaptive polling strategy:
    ...    - First 2 minutes: Poll every 10 seconds (asset discovery phase)
    ...    - After 2 minutes: Poll every 15 seconds (scan execution phase)
    ...    - Logs every 1 minute to console
    ...    Waits indefinitely until scan reaches finished/error state
    ...    Has 10-minute timeout for asset discovery only
    ...    
    ...    Arguments:
    ...    - scan_id: Scan ID to monitor
    ...    - site_id: Site ID (optional, for detailed scan info)
    ...    - poll_interval: Initial polling interval (default: 10, adaptive after 2 min)
    ...    - log_interval: Log interval in seconds (default: 60 = 1 minute)
    ...    
    ...    Returns: Dictionary with final status and scan details
    [Arguments]    ${scan_id}    ${site_id}=${EMPTY}    ${poll_interval}=10    ${log_interval}=60
    
    Log    ========================================    console=True
    Log    MONITORING SCAN: ${scan_id}    console=True
    Log    Adaptive Polling Strategy:    console=True
    Log    • First 2 minutes: Poll every 10 seconds (asset discovery)    console=True
    Log    • After 2 minutes: Poll every 15 seconds (scan execution)    console=True
    Log    Log Display Interval: ${log_interval} seconds    console=True
    Log    No overall timeout - waiting until scan finishes    console=True
    Log    Asset Discovery Timeout: 600 seconds (10 minutes)    console=True
    Log    ========================================    console=True
    
    ${start_time}=    Evaluate    int(__import__('time').time())
    ${last_log_time}=    Set Variable    ${start_time}
    ${elapsed}=    Set Variable    0
    ${status}=    Set Variable    unknown
    ${previous_status}=    Set Variable    unknown
    ${asset_discovery_timeout}=    Set Variable    ${600}    # 10 minutes in seconds
    ${asset_discovered}=    Set Variable    ${False}
    ${adaptive_threshold}=    Set Variable    ${120}    # Switch to slower polling after 2 minutes
    ${current_poll_interval}=    Set Variable    ${poll_interval}
    
    WHILE    True
        # Adaptive polling: Switch to slower polling after 2 minutes
        IF    ${elapsed} >= ${adaptive_threshold}
            ${current_poll_interval}=    Set Variable    ${15}
        END
        
        # Get current scan status (API called every current_poll_interval)
        # Wrap in TRY/EXCEPT to handle connection errors gracefully
        TRY
            ${status_result}=    Get Scan Status    ${scan_id}
            ${status}=    Set Variable    ${status_result}[status]
        EXCEPT    AS    ${error}
            Log    <span style="color: orange;">⚠️ Connection error during status check: ${error}</span>    html=True
            Log    Waiting ${current_poll_interval}s before retrying...    console=True
            Sleep    ${current_poll_interval}s
            ${elapsed}=    Evaluate    ${elapsed} + ${current_poll_interval}
            CONTINUE
        END
        
        # Check if assets have been discovered (success != 0)
        ${has_success}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${status_result}    success
        IF    ${has_success}
            ${success}=    Get From Dictionary    ${status_result}    success
            IF    '${success}' != '0'
                ${asset_discovered}=    Set Variable    ${True}
            END
        END
        
        # Check if 10 minutes elapsed without discovering any assets
        IF    ${elapsed} >= ${asset_discovery_timeout} and not ${asset_discovered}
            Log    <span style="color: orange; font-weight: bold;">========================================</span>    html=True
            Log    <span style="color: orange; font-weight: bold;">WARNING: ASSET NOT DISCOVERED YET</span>    html=True
            Log    <span style="color: orange; font-weight: bold;">========================================</span>    html=True
            Log    <span style="color: orange;">No assets discovered after 10 minutes</span>    html=True
            Log    <span style="color: orange;">Scan ID: ${scan_id}</span>    html=True
            Log    <span style="color: orange;">Elapsed: ${elapsed} seconds</span>    html=True
            Log    <span style="color: orange;">Returning to allow retry...</span>    html=True
            Log    <span style="color: orange; font-weight: bold;">========================================</span>    html=True
            ${result}=    Create Dictionary
            ...    status=asset_discovery_timeout
            ...    scan_id=${scan_id}
            ...    elapsed_time=${elapsed}
            ...    error=Asset not discovered after 10 minutes (600 seconds) - retry possible
            ...    previous_status=${previous_status}
            RETURN    ${result}
        END
        
        # Check if scan failed due to asset not being discovered (success=0)
        ${has_error}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${status_result}    error
        IF    ${has_error}
            ${error_msg}=    Get From Dictionary    ${status_result}    error
            Log    <span style="color: red; font-weight: bold;">✗ Scan failed: ${error_msg}</span>    html=True
            ${elapsed}=    Evaluate    ${elapsed} + ${poll_interval}
            ${result}=    Create Dictionary
            ...    status=failed
            ...    scan_id=${scan_id}
            ...    elapsed_time=${elapsed}
            ...    error=${error_msg}
            ...    previous_status=${previous_status}
            RETURN    ${result}
        END
        
        ${current_time}=    Evaluate    int(__import__('time').time())
        ${elapsed}=    Evaluate    ${current_time} - ${start_time}
        ${time_since_last_log}=    Evaluate    ${current_time} - ${last_log_time}
        
        # Log only every log_interval seconds or when status changes
        ${should_log}=    Evaluate    ${time_since_last_log} >= ${log_interval} or '${status}' != '${previous_status}'
        
        IF    ${should_log}
            # Color code based on status: yellow for running, green for finished, red for errors
            IF    '${status}' == 'running'
                Log    <span style="color: orange; font-weight: bold;">[${elapsed}s] Scan ${scan_id} status: ${status}</span>    html=True
            ELSE IF    '${status}' == 'finished'
                Log    <span style="color: green; font-weight: bold;">[${elapsed}s] Scan ${scan_id} status: ${status}</span>    html=True
            ELSE IF    '${status}' == 'error' or '${status}' == 'stopped' or '${status}' == 'aborted' or '${status}' == 'failed'
                Log    <span style="color: red; font-weight: bold;">[${elapsed}s] Scan ${scan_id} status: ${status}</span>    html=True
            ELSE
                Log    [${elapsed}s] Scan ${scan_id} status: ${status}    html=True
            END
            ${last_log_time}=    Set Variable    ${current_time}
        END
        
        # Check if scan has finished
        IF    '${status}' == 'finished'
            # Get detailed scan information to check if assets were discovered
            # Wrap in TRY/EXCEPT to handle connection errors
            TRY
                IF    '${site_id}' != '${EMPTY}'
                    ${scan_details}=    Get Scan Details    ${scan_id}    ${site_id}
                ELSE
                    ${scan_details}=    Get Scan Details    ${scan_id}
                END
            EXCEPT    AS    ${error}
                Log    <span style="color: orange;">⚠️ Connection error getting scan details: ${error}</span>    html=True
                Log    Waiting ${current_poll_interval}s before retrying...    console=True
                Sleep    ${current_poll_interval}s
                ${elapsed}=    Evaluate    ${elapsed} + ${current_poll_interval}
                CONTINUE
            END
            
            # Parse the scan details XML to check for live nodes
            ${details_response}=    Get From Dictionary    ${scan_details}    response
            ${has_nodes}=    Run Keyword And Return Status    Should Contain    ${details_response}    <nodes
            ${live_nodes}=    Set Variable    0
            
            IF    ${has_nodes}
                # Extract live nodes count from XML
                TRY
                    ${live_nodes}=    Evaluate    __import__('re').search(r'<nodes\\s+live="(\\d+)"', '''${details_response}''').group(1) if __import__('re').search(r'<nodes\\s+live="(\\d+)"', '''${details_response}''') else '0'
                    Log    Detected ${live_nodes} live node(s) in scan results    console=True
                EXCEPT
                    Log    Could not extract live nodes count, assuming 0    console=True
                END
            END
            
            # Check if scan finished but with no assets discovered
            # Check both success="0" flag AND live nodes count
            ${has_success}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${status_result}    success
            ${success_is_zero}=    Set Variable    False
            
            IF    ${has_success}
                ${success}=    Get From Dictionary    ${status_result}    success
                IF    '${success}' == '0'
                    ${success_is_zero}=    Set Variable    True
                END
            END
            
            # If no assets discovered (either success=0 OR live nodes=0), return failed status
            IF    ${success_is_zero} or '${live_nodes}' == '0'
                Log    <span style="color: red; font-weight: bold;">✗ Scan finished but no assets were discovered (success=${success_is_zero}, live_nodes=${live_nodes})</span>    html=True
                ${result}=    Create Dictionary
                ...    status=failed
                ...    scan_id=${scan_id}
                ...    elapsed_time=${elapsed}
                ...    error=Scan finished but no assets discovered (live_nodes=${live_nodes})
                ...    scan_details=${scan_details}
                ...    previous_status=${previous_status}
                RETURN    ${result}
            END
            
            Log    <span style="color: green; font-weight: bold;">✓ Scan completed successfully with ${live_nodes} live node(s)!</span>    html=True
            
            ${result}=    Create Dictionary
            ...    status=${status}
            ...    scan_id=${scan_id}
            ...    elapsed_time=${elapsed}
            ...    scan_details=${scan_details}
            ...    previous_status=${previous_status}
            RETURN    ${result}
        END
        
        # Check for error states - but check for assets first before failing
        IF    '${status}' == 'error' or '${status}' == 'stopped' or '${status}' == 'aborted' or '${status}' == 'failed'
            Log    <span style="color: red; font-weight: bold;">✗ Scan ended with status: ${status}</span>    html=True
            
            # Even if scan stopped/failed, check if any assets were discovered
            ${scan_details}=    Set Variable    ${None}
            ${live_nodes}=    Set Variable    0
            
            TRY
                IF    '${site_id}' != '${EMPTY}'
                    ${scan_details}=    Get Scan Details    ${scan_id}    ${site_id}
                ELSE
                    ${scan_details}=    Get Scan Details    ${scan_id}
                END
                
                ${details_response}=    Get From Dictionary    ${scan_details}    response
                ${has_nodes}=    Run Keyword And Return Status    Should Contain    ${details_response}    <nodes
                
                IF    ${has_nodes}
                    ${live_nodes}=    Evaluate    __import__('re').search(r'<nodes\\s+live="(\\d+)"', '''${details_response}''').group(1) if __import__('re').search(r'<nodes\\s+live="(\\d+)"', '''${details_response}''') else '0'
                    Log    Detected ${live_nodes} live node(s) before scan stopped    console=True
                END
            EXCEPT
                Log    Could not retrieve scan details for stopped scan    console=True
            END
            
            # If no assets discovered, return 'failed' status to trigger retry
            IF    '${live_nodes}' == '0'
                Log    <span style="color: red; font-weight: bold;">✗ Scan stopped but no assets were discovered - will retry</span>    html=True
                ${result}=    Create Dictionary
                ...    status=failed
                ...    scan_id=${scan_id}
                ...    elapsed_time=${elapsed}
                ...    error=Scan stopped with no assets discovered (live_nodes=0)
                ...    scan_details=${scan_details}
                ...    previous_status=${previous_status}
                RETURN    ${result}
            END
            
            # If assets were discovered before stopping, that's still an error
            ${result}=    Create Dictionary
            ...    status=${status}
            ...    scan_id=${scan_id}
            ...    elapsed_time=${elapsed}
            ...    error=Scan ended with non-success status: ${status}
            ...    scan_details=${scan_details}
            ...    previous_status=${previous_status}
            RETURN    ${result}
        END
        
        # Store current status as previous for next iteration
        ${previous_status}=    Set Variable    ${status}
        
        # Wait before next poll (adaptive interval)
        Sleep    ${current_poll_interval}s
        ${elapsed}=    Evaluate    ${elapsed} + ${current_poll_interval}
    END
    
    # This line should never be reached as the loop continues until scan finishes
    # If it does, return current status
    ${result}=    Create Dictionary
    ...    status=${status}
    ...    scan_id=${scan_id}
    ...    elapsed_time=${elapsed}
    ...    error=Unexpected loop exit
    
    RETURN    ${result}

