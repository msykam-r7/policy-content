*** Settings ***
Documentation     Engine Management Keywords
Library           RequestsLibrary
Library           XML
Library           String
Resource          ../testdata/endpoints.robot
Resource          login.robot


*** Keywords ***
Get Available Engines
    [Documentation]    Get list of available scan engines from Nexpose console
    
    # Load engine listing request payload from JSON file
    ${payload_file}=    Set Variable    ${CURDIR}/../payloads/engine_listing_request.json
    ${payload_json}=    Evaluate    json.load(open('${payload_file}'))    json
    ${engine_xml_template}=    Get From Dictionary    ${payload_json}    xml_payload
    
    # Replace session ID placeholder
    ${engine_xml}=    Replace String    ${engine_xml_template}    SESSION_ID_PLACEHOLDER    ${SESSION_ID}
    
    ${headers}=    Create Dictionary    
    ...    Content-Type=application/xml
    ...    Cookie=nexposeCCSessionID=${SESSION_ID}
    
    # Make engine listing request with auto-reauth
    ${response}=    login.API Call With Auto Reauth
    ...    POST
    ...    ${API_V1_XML}
    ...    data=${engine_xml}
    ...    headers=${headers}
    
    Should Be Equal As Strings    ${response.status_code}    200
    ...    msg=Failed to get engines. Status: ${response.status_code}, Response: ${response.text}
    
    Log    Engine Listing Response: ${response.text}
    
    # Parse response and extract engines
    ${engines}=    Extract Engines From Response    ${response.text}
    
    RETURN    ${engines}

Extract Engines From Response
    [Documentation]    Parse XML response and extract engine information
    [Arguments]    ${xml_response}
    
    ${root}=    Parse XML    ${xml_response}
    ${engines}=    Get Elements    ${root}    .//Engine
    ${engine_count}=    Get Length    ${engines}
    
    Log    Found ${engine_count} available engines
    
    # Extract engine details and collect IDs
    ${engine_ids}=    Create List
    FOR    ${engine}    IN    @{engines}
        ${engine_id}=    Get Element Attribute    ${engine}    id
        ${engine_name}=    Get Element Attribute    ${engine}    name
        ${engine_address}=    Get Element Attribute    ${engine}    address
        ${engine_status}=    Get Element Attribute    ${engine}    status    default=unknown
        Log    Engine ID: ${engine_id}, Name: ${engine_name}, Address: ${engine_address}, Status: ${engine_status}
        Append To List    ${engine_ids}    ${engine_id}
    END
    
    RETURN    ${engine_ids}

Get Engine By ID
    [Documentation]    Get specific engine by ID
    [Arguments]    ${engine_id}
    
    ${engines}=    Get Available Engines
    ${root}=    Parse XML    ${engines}
    ${engine}=    Get Element    ${root}    .//Engine[@id='${engine_id}']
    
    RETURN    ${engine}
