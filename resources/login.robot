*** Settings ***
Documentation     Login and Session Management Keywords
Library           RequestsLibrary
Library           XML
Library           String
Library           OperatingSystem
Library           Collections
Resource          ../testdata/endpoints.robot


*** Variables ***
${CONSOLE_IP}         ${EMPTY}
${DEFAULT_IP}         127.0.0.1
${PORT}               3780
${USERNAME}           nxadmin
${PASSWORD}           nxadmin
${VERIFY_SSL}         ${FALSE}
${SESSION_ID}         ${EMPTY}
${BASE_URL}           ${EMPTY}


*** Keywords ***
Login To Console
    [Documentation]    Login to Nexpose console and return session ID
    
    # Use default IP if CONSOLE_IP is not provided
    ${ip}=    Set Variable If    '${CONSOLE_IP}' == '${EMPTY}' or '${CONSOLE_IP}' == ''    ${DEFAULT_IP}    ${CONSOLE_IP}
    
    # Construct BASE_URL from IP and PORT
    ${console_url}=    Set Variable    https://${ip}:${PORT}
    Set Global Variable    ${BASE_URL}    ${console_url}
    
    Log    Using Console URL: ${BASE_URL}
    
    # Create session with extended timeout for long-running operations
    # For remote consoles and compliance scans, use longer timeout (30 minutes)
    # Also increase max_retries for better reliability over network
    Create Session    nexpose    ${BASE_URL}    verify=${VERIFY_SSL}    timeout=1800    max_retries=5
    
    # Load login request payload from JSON file
    ${payload_file}=    Set Variable    ${CURDIR}/../payloads/login_request.json
    ${payload_json}=    Evaluate    json.load(open('${payload_file}'))    json
    ${login_xml_template}=    Get From Dictionary    ${payload_json}    xml_payload
    
    # Replace username and password placeholders
    ${login_xml}=    Replace String    ${login_xml_template}    USERNAME_PLACEHOLDER    ${USERNAME}
    ${login_xml}=    Replace String    ${login_xml}    PASSWORD_PLACEHOLDER    ${PASSWORD}
    
    ${headers}=    Create Dictionary    Content-Type=application/xml
    
    # Make login request
    ${response}=    POST On Session    nexpose    ${API_V1_XML}    data=${login_xml}    headers=${headers}    expected_status=200
    
    # Extract session ID from response
    ${session_id}=    Extract Session ID From XML Response    ${response.text}
    
    # Validate session ID
    Should Not Be Empty    ${session_id}    Session ID should not be empty
    Should Not Be Equal    ${session_id}    ${EMPTY}    Session ID should not be empty
    
    Set Global Variable    ${SESSION_ID}    ${session_id}
    
    Log    Successfully logged in. Session ID: ${SESSION_ID}
    
    RETURN    ${session_id}

Extract Session ID From XML Response
    [Documentation]    Parse XML response and extract session-id attribute
    [Arguments]    ${xml_response}
    
    ${root}=    Parse XML    ${xml_response}
    ${session_id}=    Get Element Attribute    ${root}    session-id
    
    Should Not Be Empty    ${session_id}    Session ID should not be empty
    
    RETURN    ${session_id}

Get Session ID
    [Documentation]    Return the current session ID
    RETURN    ${SESSION_ID}


API Call With Auto Reauth
    [Documentation]    Make API call with automatic re-authentication on session expiry
    ...    Automatically detects session expiration and re-authenticates
    ...    Supports both GET and POST methods
    ...    Example: API Call With Auto Reauth    POST    /api/1.1/xml    headers=${headers}    data=${xml_body}
    [Arguments]    ${method}    ${endpoint}    &{kwargs}
    
    # First attempt - use current session
    ${response}=    Make API Call    ${method}    ${endpoint}    &{kwargs}
    
    # Check if session expired (401, 403, or specific error in response)
    ${session_expired}=    Check If Session Expired    ${response}
    
    IF    ${session_expired}
        Log    ⚠️ Session expired detected. Re-authenticating...    console=True
        
        # Re-login to get new session
        ${new_session_id}=    Login To Console
        Log    ✓ Re-authentication successful. New Session ID: ${new_session_id}    console=True
        
        # Update session ID in headers if present
        ${has_headers}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${kwargs}    headers
        IF    ${has_headers}
            ${headers}=    Get From Dictionary    ${kwargs}    headers
            ${updated_headers}=    Update Session In Headers    ${headers}    ${new_session_id}
            Set To Dictionary    ${kwargs}    headers=${updated_headers}
        END
        
        # Update session ID in data/body if it's XML with session-id attribute
        ${has_data}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${kwargs}    data
        IF    ${has_data}
            ${data}=    Get From Dictionary    ${kwargs}    data
            ${updated_data}=    Update Session In XML Data    ${data}    ${new_session_id}
            Set To Dictionary    ${kwargs}    data=${updated_data}
        END
        
        # Retry the API call with new session
        Log    🔄 Retrying API call with new session...    console=True
        ${response}=    Make API Call    ${method}    ${endpoint}    &{kwargs}
        
        # Check if retry was successful
        ${retry_expired}=    Check If Session Expired    ${response}
        IF    ${retry_expired}
            Fail    API call failed even after re-authentication. Status: ${response.status_code}, Response: ${response.text}
        END
    END
    
    RETURN    ${response}


Make API Call
    [Documentation]    Internal keyword to make the actual API call
    [Arguments]    ${method}    ${endpoint}    &{kwargs}
    
    # Set expected_status to any if not specified
    ${has_expected_status}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${kwargs}    expected_status
    IF    not ${has_expected_status}
        Set To Dictionary    ${kwargs}    expected_status=any
    END
    
    # Make the API call based on method
    IF    '${method.upper()}' == 'GET'
        ${response}=    GET On Session    nexpose    ${endpoint}    &{kwargs}
    ELSE IF    '${method.upper()}' == 'POST'
        ${response}=    POST On Session    nexpose    ${endpoint}    &{kwargs}
    ELSE IF    '${method.upper()}' == 'PUT'
        ${response}=    PUT On Session    nexpose    ${endpoint}    &{kwargs}
    ELSE IF    '${method.upper()}' == 'DELETE'
        ${response}=    DELETE On Session    nexpose    ${endpoint}    &{kwargs}
    ELSE
        Fail    Unsupported HTTP method: ${method}
    END
    
    RETURN    ${response}


Check If Session Expired
    [Documentation]    Check if the API response indicates session expiration
    [Arguments]    ${response}
    
    # Check HTTP status codes that indicate authentication issues
    IF    ${response.status_code} == 401 or ${response.status_code} == 403
        RETURN    ${TRUE}
    END
    
    # Check for 500 errors that might be session-related
    # Only treat 500 as session expiration if response contains session/auth keywords
    IF    ${response.status_code} == 500
        ${has_session_keywords}=    Run Keyword And Return Status    Should Contain Any    ${response.text}    session    expired    invalid    authentication    unauthorized
        IF    ${has_session_keywords}
            Log    500 error with session-related message detected, will retry with fresh session    WARN
            RETURN    ${TRUE}
        END
    END
    
    # Check for session expiration in XML responses
    ${is_xml}=    Run Keyword And Return Status    Should Contain    ${response.text}    <?xml
    IF    ${is_xml}
        # Check for failure messages in XML
        ${has_failure}=    Run Keyword And Return Status    Should Contain    ${response.text}    success="0"
        IF    ${has_failure}
            ${has_session_error}=    Run Keyword And Return Status    Should Contain Any    ${response.text}    session    expired    invalid    authentication
            IF    ${has_session_error}
                RETURN    ${TRUE}
            END
        END
    END
    
    # Check for session expiration in JSON responses
    ${is_json}=    Run Keyword And Return Status    Should Contain    ${response.headers.get('Content-Type', '')}    json
    IF    ${is_json}
        ${has_message}=    Run Keyword And Return Status    Should Contain Any    ${response.text}    expired    unauthorized    invalid session
        IF    ${has_message}
            RETURN    ${TRUE}
        END
    END
    
    RETURN    ${FALSE}


Update Session In Headers
    [Documentation]    Update session ID in request headers
    [Arguments]    ${headers}    ${new_session_id}
    
    ${updated_headers}=    Copy Dictionary    ${headers}
    
    # Update nexposeCCSessionID header if present
    ${has_session_header}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${headers}    nexposeCCSessionID
    IF    ${has_session_header}
        Set To Dictionary    ${updated_headers}    nexposeCCSessionID=${new_session_id}
    END
    
    # Update Cookie header if present
    ${has_cookie}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${headers}    Cookie
    IF    ${has_cookie}
        ${cookie}=    Get From Dictionary    ${headers}    Cookie
        ${new_cookie}=    Replace String    ${cookie}    nexposeCCSessionID=    nexposeCCSessionID=${new_session_id}
        # Remove old session ID from cookie string
        ${new_cookie}=    Evaluate    '; '.join([c for c in '${new_cookie}'.split('; ') if 'nexposeCCSessionID=' in c][:1])
        ${new_cookie}=    Set Variable    nexposeCCSessionID=${new_session_id}
        Set To Dictionary    ${updated_headers}    Cookie=${new_cookie}
    END
    
    RETURN    ${updated_headers}


Update Session In XML Data
    [Documentation]    Update session-id attribute in XML data
    [Arguments]    ${xml_data}    ${new_session_id}
    
    # Check if data contains session-id attribute
    ${has_session_id}=    Run Keyword And Return Status    Should Contain    ${xml_data}    session-id=
    IF    not ${has_session_id}
        RETURN    ${xml_data}
    END
    
    # Replace session-id with new value using regex
    ${updated_xml}=    Evaluate    __import__('re').sub(r'session-id="[^"]*"', 'session-id="${new_session_id}"', '''${xml_data}''')
    
    RETURN    ${updated_xml}

