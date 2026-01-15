*** Settings ***
Documentation     Site Management Keywords for Nexpose/InsightVM
Library           RequestsLibrary
Library           Collections
Library           String
Library           Process
Library           OperatingSystem
Resource          vm_config.robot
Resource          ../testdata/endpoints.robot
Resource          login.robot


*** Keywords ***
Check Host Reachability
    [Documentation]    Check if a host is reachable using multiple methods
    ...    Tries the following in order:
    ...    1. TCP port check (SSH:22, RDP:3389, WinRM:5985, SMB:445)
    ...    2. Ping (ICMP) - may be blocked by Windows Firewall
    ...    
    ...    This ensures Windows VMs with firewall enabled are still detected
    ...    
    ...    Arguments:
    ...    - ip: IP address to check
    ...    - timeout: Maximum timeout in seconds (default: 600 = 10 minutes)
    ...    - interval: Interval between checks in seconds (default: 5)
    ...    - service: Service type hint (ssh, cifs, rdp, winrm) to prioritize port check
    ...    
    ...    Example: ${reachable}=    Check Host Reachability    ${ip_address}
    ...    Example: ${reachable}=    Check Host Reachability    ${ip_address}    service=ssh
    [Arguments]    ${ip}    ${timeout}=600    ${interval}=5    ${service}=${EMPTY}
    
    Log    ========================================    console=True
    Log    CHECKING HOST REACHABILITY    console=True
    Log    IP Address: ${ip}    console=True
    Log    Timeout: ${timeout} seconds (${${timeout}/60} minutes)    console=True
    Log    Method: TCP Port Check + Ping Fallback    console=True
    Log    ========================================    console=True
    
    ${start_time}=    Get Time    epoch
    ${end_time}=    Evaluate    ${start_time} + ${timeout}
    ${attempt}=    Set Variable    ${1}
    
    # Determine ports to check based on service hint
    ${ports}=    Get Ports For Service    ${service}
    
    WHILE    True
        ${current_time}=    Get Time    epoch
        
        # Check if timeout reached
        IF    ${current_time} >= ${end_time}
            Log    ❌ Host ${ip} not reachable after ${timeout} seconds (${${timeout}/60} minutes)    console=True
            RETURN    ${False}
        END
        
        # Method 1: Try TCP port check first (works even with firewall blocking ICMP)
        ${tcp_reachable}=    Check TCP Port Reachability    ${ip}    ${ports}
        
        IF    ${tcp_reachable}
            ${elapsed}=    Evaluate    ${current_time} - ${start_time}
            Log    ✓ Host ${ip} is REACHABLE via TCP port (responded in ${elapsed} seconds, attempt ${attempt})    console=True
            RETURN    ${True}
        END
        
        # Method 2: Fallback to ping (ICMP)
        ${ping_result}=    Run Process    ping    -c    1    -W    3    ${ip}
        
        IF    ${ping_result.rc} == ${0}
            ${elapsed}=    Evaluate    ${current_time} - ${start_time}
            Log    ✓ Host ${ip} is REACHABLE via Ping (responded in ${elapsed} seconds, attempt ${attempt})    console=True
            RETURN    ${True}
        ELSE
            ${elapsed}=    Evaluate    ${current_time} - ${start_time}
            Log    Attempt ${attempt}: Host ${ip} not reachable yet (elapsed: ${elapsed}s)    console=True
            
            # Wait before next attempt
            Sleep    ${interval}s
            ${attempt}=    Evaluate    ${attempt} + 1
        END
    END

Get Ports For Service
    [Documentation]    Returns list of ports to check based on service type
    [Arguments]    ${service}
    
    # Default ports: SSH, RDP, WinRM, SMB
    ${default_ports}=    Create List    22    3389    5985    445    5986
    
    # If service specified, prioritize that port
    IF    '${service}' == 'ssh'
        ${ports}=    Create List    22    3389    5985    445
    ELSE IF    '${service}' == 'cifs' or '${service}' == 'smb'
        ${ports}=    Create List    445    3389    5985    5986
    ELSE IF    '${service}' == 'rdp'
        ${ports}=    Create List    3389    5985    445
    ELSE IF    '${service}' == 'winrm'
        ${ports}=    Create List    5985    5986    3389    445
    ELSE IF    '${service}' == 'oracle'
        ${ports}=    Create List    1521    22    445
    ELSE IF    '${service}' == 'mysql'
        ${ports}=    Create List    3306    22    445
    ELSE IF    '${service}' == 'mssql'
        ${ports}=    Create List    1433    3389    445
    ELSE
        ${ports}=    Set Variable    ${default_ports}
    END
    
    RETURN    ${ports}

Check TCP Port Reachability
    [Documentation]    Checks if any of the specified TCP ports are open on the host
    ...    Uses nc (netcat) or Python socket to check port connectivity
    ...    This works even when ICMP (ping) is blocked by firewall
    [Arguments]    ${ip}    ${ports}
    
    FOR    ${port}    IN    @{ports}
        # Try using nc (netcat) - fast and reliable
        ${result}=    Run Process    nc    -z    -w    2    ${ip}    ${port}
        
        IF    ${result.rc} == ${0}
            Log    TCP port ${port} is open on ${ip}    DEBUG
            RETURN    ${True}
        END
    END
    
    # No ports were reachable
    RETURN    ${False}

Check Host Reachability Legacy
    [Documentation]    Legacy ping-only reachability check (kept for backward compatibility)
    ...    Use Check Host Reachability instead for better Windows firewall support
    [Arguments]    ${ip}    ${timeout}=600    ${interval}=5
    
    ${start_time}=    Get Time    epoch
    ${end_time}=    Evaluate    ${start_time} + ${timeout}
    ${attempt}=    Set Variable    ${1}
    
    WHILE    True
        ${current_time}=    Get Time    epoch
        
        IF    ${current_time} >= ${end_time}
            Log    ❌ Host ${ip} not reachable after ${timeout} seconds    console=True
            RETURN    ${False}
        END
        
        ${result}=    Run Process    ping    -c    1    -W    5    ${ip}
        
        IF    ${result.rc} == ${0}
            ${elapsed}=    Evaluate    ${current_time} - ${start_time}
            Log    ✓ Host ${ip} is REACHABLE (responded in ${elapsed} seconds, attempt ${attempt})    console=True
            RETURN    ${True}
        ELSE
            ${elapsed}=    Evaluate    ${current_time} - ${start_time}
            Log    Attempt ${attempt}: Host ${ip} not reachable (elapsed: ${elapsed}s)    console=True
            Sleep    ${interval}s
            ${attempt}=    Evaluate    ${attempt} + 1
        END
    END
Create Site With VM Config
    [Documentation]    Create a site using VM configuration based on OS identifier
    ...    Supports credential types: server, database, or both
    ...    Checks host reachability via ping before creating site (10 minute timeout)
    ...    Examples:
    ...    - Create Site With VM Config    My Site    CIS_RHEL_9    server    scan_template=cis    scope=S    engine_id=3
    ...    - Create Site With VM Config    Tomcat Site    CIS_Apache_Tomcat_9    server    database    scan_template=cis    scope=S    engine_id=3
    ...    - Create Site With VM Config    CentOS Site    CIS_CentOS_4    server    scan_template=cis    scope=S    engine_id=3
    ...    - Create Site With VM Config    My Site    CIS_RHEL_9    server    scan_template=cis    scope=S    engine_id=3    skip_ping_check=${True}
    [Arguments]    ${site_name}    ${os_identifier}    @{vm_cred_types}    &{options}
    
    # Extract options or use defaults
    ${scan_template}=    Get From Dictionary    ${options}    scan_template    ${EMPTY}
    ${scope}=    Get From Dictionary    ${options}    scope    ${EMPTY}
    ${engine_id}=    Get From Dictionary    ${options}    engine_id    ${EMPTY}
    ${service}=    Get From Dictionary    ${options}    service    ${EMPTY}
    ${db_service}=    Get From Dictionary    ${options}    db_service    ${EMPTY}
    ${db_sid}=    Get From Dictionary    ${options}    db_sid    ${EMPTY}
    ${db_port}=    Get From Dictionary    ${options}    db_port    ${EMPTY}
    ${db_domain}=    Get From Dictionary    ${options}    db_domain    ${EMPTY}
    ${skip_ping_check}=    Get From Dictionary    ${options}    skip_ping_check    ${False}
    ${ping_timeout}=    Get From Dictionary    ${options}    ping_timeout    600
    
    # Optional permission elevation parameters
    ${perm_elevation_type}=    Get From Dictionary    ${options}    perm_elevation_type    ${EMPTY}
    ${perm_elevation_user}=    Get From Dictionary    ${options}    perm_elevation_user    ${EMPTY}
    ${perm_elevation_password}=    Get From Dictionary    ${options}    perm_elevation_password    ${EMPTY}
    
    # Validate required parameters are provided
    Run Keyword If    '${engine_id}' == '${EMPTY}'    Fail    engine_id is required. Please pass engine_id from robot file.
    Run Keyword If    '${scan_template}' == '${EMPTY}'    Fail    scan_template is required. Please pass scan_template from robot file.
    Run Keyword If    '${scope}' == '${EMPTY}'    Fail    scope is required. Please pass scope from robot file.
    Run Keyword If    '${service}' == '${EMPTY}'    Fail    service is required. Please pass service from robot file (e.g., ssh, cifs, oracle, mysql).
    
    # Get VM config (supports server, database, or both)
    ${vm_config}=    Get VM Config    ${os_identifier}    @{vm_cred_types}
    
    # Extract server credentials
    ${has_server}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${vm_config}    server
    Run Keyword If    not ${has_server}    Fail    Server credentials not found in VM config
    
    ${server_config}=    Get From Dictionary    ${vm_config}    server
    ${ip}=    Get From Dictionary    ${server_config}    ip
    ${username}=    Get From Dictionary    ${server_config}    username
    ${password}=    Get From Dictionary    ${server_config}    password
    
    # Check if permission elevation is defined in vm_config
    ${has_perm_elevation}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${server_config}    permission_elevation_type
    ${vm_perm_type}=    Set Variable If    ${has_perm_elevation}    ${server_config['permission_elevation_type']}    NONE
    ${vm_perm_user}=    Set Variable If    ${has_perm_elevation}    ${server_config.get('permission_elevation_user', '')}    ${EMPTY}
    ${vm_perm_pass}=    Set Variable If    ${has_perm_elevation}    ${server_config.get('permission_elevation_password', '')}    ${EMPTY}
    
    # Check host reachability before creating site (unless skipped)
    IF    not ${skip_ping_check}
        ${is_reachable}=    Check Host Reachability    ${ip}    timeout=${ping_timeout}
        IF    not ${is_reachable}
            Fail    Host ${ip} is not reachable after ${ping_timeout} seconds. Cannot create site for unreachable host.
        END
        Log    Host ${ip} is reachable, proceeding with site creation    console=True
    ELSE
        Log    Skipping ping check as requested    console=True
    END
    
    # Check if database credentials are available
    ${has_database}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${vm_config}    database
    
    # Load site creation payload
    ${payload_file}=    Set Variable    ${CURDIR}/../payloads/site_creation.json
    ${payload}=    Evaluate    json.load(open('${payload_file}'))    json
    
    # Update payload with site details from robot file - match working format
    Set To Dictionary    ${payload}    name=${site_name}
    Set To Dictionary    ${payload}    description=${EMPTY}
    Set To Dictionary    ${payload}    auto_engine_selection_enabled=${True}
    Set To Dictionary    ${payload}    scan_template_id=${scan_template}
    ${engine_id_int}=    Convert To Integer    ${engine_id}
    Set To Dictionary    ${payload}    engine_id=${engine_id_int}
    
    # Remove fields that may cause issues
    Run Keyword And Ignore Error    Remove From Dictionary    ${payload}    version
    Run Keyword And Ignore Error    Remove From Dictionary    ${payload}    id
    Run Keyword And Ignore Error    Remove From Dictionary    ${payload}    discovery_config
    Run Keyword And Ignore Error    Remove From Dictionary    ${payload}    search_criteria
    
    # Set the included asset (IP address)
    ${ip_list}=    Create List    ${ip}
    Set To Dictionary    ${payload}[included_scan_targets]    addresses=${ip_list}
    
    # Use only one SSH credential for server access - match working format
    ${cred_id}=    Convert To Integer    -1
    ${service_upper}=    Evaluate    "${service}".upper()
    ${ssh_cred}=    Create Dictionary
    ...    id=${cred_id}
    ...    name=${service_upper} Credential
    ...    service=${service}
    ...    user_name=${username}
    ...    password=${password}
    ...    enabled=${True}
    ...    scope=${scope}
    
    # Add permission elevation fields - priority: test file params > vm_config > NONE
    IF    '${perm_elevation_type}' != '${EMPTY}'
        # Use values from test file (explicitly passed)
        Set To Dictionary    ${ssh_cred}    permission_elevation_type=${perm_elevation_type}
        Set To Dictionary    ${ssh_cred}    permission_elevation_user=${perm_elevation_user}
        Set To Dictionary    ${ssh_cred}    permission_elevation_password=${perm_elevation_password}
        Log    Added permission elevation from test file: ${perm_elevation_type}    console=True
    ELSE IF    '${vm_perm_type}' != 'NONE' and '${vm_perm_type}' != '${EMPTY}'
        # Use values from vm_config if available
        Set To Dictionary    ${ssh_cred}    permission_elevation_type=${vm_perm_type}
        IF    '${vm_perm_user}' != '${EMPTY}'
            Set To Dictionary    ${ssh_cred}    permission_elevation_user=${vm_perm_user}
        END
        IF    '${vm_perm_pass}' != '${EMPTY}'
            Set To Dictionary    ${ssh_cred}    permission_elevation_password=${vm_perm_pass}
        END
        Log    Added permission elevation from vm_config: ${vm_perm_type}    console=True
    ELSE
        # Default to NONE
        Set To Dictionary    ${ssh_cred}    permission_elevation_type=NONE
        Log    Permission elevation set to NONE (not defined in test file or vm_config)    console=True
    END
    
    ${site_creds}=    Create List    ${ssh_cred}
    Set To Dictionary    ${payload}    site_credentials=${site_creds}
    
    # Set organization to empty object to match working curl format
    ${empty_dict}=    Create Dictionary
    Set To Dictionary    ${payload}    organization=${empty_dict}
    
    # Ensure other required fields are set to empty arrays/objects
    Set To Dictionary    ${payload}[included_scan_targets]    asset_groups=@{EMPTY}
    Set To Dictionary    ${payload}[excluded_scan_targets]    addresses=@{EMPTY}
    Set To Dictionary    ${payload}[excluded_scan_targets]    asset_groups=@{EMPTY}
    
    # If database credentials are available, add database credential
    IF    ${has_database}
        ${database_config}=    Get From Dictionary    ${vm_config}    database
        ${db_ip}=    Get From Dictionary    ${database_config}    ip
        ${db_username}=    Get From Dictionary    ${database_config}    username
        ${db_password}=    Get From Dictionary    ${database_config}    password
        
        # Determine database service type from db_service option or default to oracle
        ${db_service_type}=    Set Variable If    '${db_service}' != '${EMPTY}'    ${db_service}    oracle
        
        # Create database credential - match working payload format
        ${db_cred_id}=    Convert To Integer    -1
        ${db_cred}=    Create Dictionary
        ...    id=${db_cred_id}
        ...    name=Database Credential
        ...    service=${db_service_type}
        ...    user_name=${db_username}
        ...    password=${db_password}
        ...    permission_elevation_type=NONE
        ...    enabled=${True}
        ...    scope=${scope}
        
        # Add database-specific fields if provided
        IF    '${db_sid}' != '${EMPTY}'
            Set To Dictionary    ${db_cred}    database=${db_sid}
        END
        IF    '${db_port}' != '${EMPTY}'
            Set To Dictionary    ${db_cred}    port=${db_port}
        END
        IF    '${db_domain}' != '${EMPTY}'
            Set To Dictionary    ${db_cred}    domain=${db_domain}
            Log    Added database domain: ${db_domain}
        END
        
        Append To List    ${payload}[site_credentials]    ${db_cred}
        Log    Added database credential for ${db_service_type}
    END
    
    # Log the complete payload for debugging (after all credentials are added)
    ${payload_json}=    Evaluate    json.dumps($payload, indent=2)    json
    Log    Site Creation Payload:\n${payload_json}    console=True
    
    # Create POST request with session authentication - match working curl format
    ${headers}=    Create Dictionary    
    ...    Content-Type=application/json    
    ...    nexposeCCSessionID=${SESSION_ID}
    
    # Log headers for debugging
    Log    Request Headers: ${headers}    console=True
    
    # Create site with auto-reauth
    ${response}=    login.API Call With Auto Reauth
    ...    POST
    ...    ${GLOBAL_NEXPOSE_V2_ENDPOINTS_SITES}
    ...    json=${payload}
    ...    headers=${headers}
    
    # Check if successful (201 Created)
    IF    ${response.status_code} != 201
        Log    Site creation failed. Status: ${response.status_code}    console=True
        Log    Error Response Body: ${response.text}    console=True
        Fail    Site creation failed with status ${response.status_code}: ${response.text}
    END
    
    # Get site ID from response
    ${response_json}=    Set Variable    ${response.json()}
    
    # Log full response for debugging
    ${response_str}=    Evaluate    json.dumps($response_json, indent=2)    json
    Log    Site Creation Response:\n${response_str}    console=True
    
    # Check if response is a dictionary or just an integer
    ${response_type}=    Evaluate    type($response_json).__name__
    ${site_id}=    Run Keyword If    '${response_type}' == 'dict'
    ...    Get From Dictionary    ${response_json}    id
    ...    ELSE
    ...    Set Variable    ${response_json}
    
    Log    Site created successfully with ID: ${site_id}, IP: ${ip}, Engine: ${engine_id}, Scope: ${scope}    console=True
    
    RETURN    ${site_id}


Update Site With VM Config
    [Documentation]    Update an existing site using the same payload structure as site creation
    ...    Examples:
    ...    - Update Site With VM Config    ${site_id}    My Site    CIS_RHEL_9    server    service=ssh    scan_template=cis    scope=S    engine_id=3
    ...    - Update Site With VM Config    ${site_id}    Oracle Site    CIS_Oracle_19c    server    database    service=cifs    db_service=oracle    db_sid=orcl    db_domain=ORACLE.LOCAL    scan_template=cis    scope=S    engine_id=3
    [Arguments]    ${site_id}    ${site_name}    ${os_identifier}    @{vm_cred_types}    &{options}
    
    # Extract options or use defaults
    ${scan_template}=    Get From Dictionary    ${options}    scan_template    ${EMPTY}
    ${scope}=    Get From Dictionary    ${options}    scope    ${EMPTY}
    ${engine_id}=    Get From Dictionary    ${options}    engine_id    ${EMPTY}
    ${service}=    Get From Dictionary    ${options}    service    ${EMPTY}
    ${db_service}=    Get From Dictionary    ${options}    db_service    ${EMPTY}
    ${db_sid}=    Get From Dictionary    ${options}    db_sid    ${EMPTY}
    ${db_port}=    Get From Dictionary    ${options}    db_port    ${EMPTY}
    ${db_domain}=    Get From Dictionary    ${options}    db_domain    ${EMPTY}
    
    # Optional permission elevation parameters
    ${perm_elevation_type}=    Get From Dictionary    ${options}    perm_elevation_type    ${EMPTY}
    ${perm_elevation_user}=    Get From Dictionary    ${options}    perm_elevation_user    ${EMPTY}
    ${perm_elevation_password}=    Get From Dictionary    ${options}    perm_elevation_password    ${EMPTY}
    
    # Validate required parameters are provided
    Run Keyword If    '${engine_id}' == '${EMPTY}'    Fail    engine_id is required. Please pass engine_id from robot file.
    Run Keyword If    '${scan_template}' == '${EMPTY}'    Fail    scan_template is required. Please pass scan_template from robot file.
    Run Keyword If    '${scope}' == '${EMPTY}'    Fail    scope is required. Please pass scope from robot file.
    Run Keyword If    '${service}' == '${EMPTY}'    Fail    service is required. Please pass service from robot file (e.g., ssh, cifs, oracle, mysql).
    
    # Get VM config (supports server, database, or both)
    ${vm_config}=    Get VM Config    ${os_identifier}    @{vm_cred_types}
    
    # Extract server credentials
    ${has_server}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${vm_config}    server
    Run Keyword If    not ${has_server}    Fail    Server credentials not found in VM config
    
    ${server_config}=    Get From Dictionary    ${vm_config}    server
    ${ip}=    Get From Dictionary    ${server_config}    ip
    ${username}=    Get From Dictionary    ${server_config}    username
    ${password}=    Get From Dictionary    ${server_config}    password
    
    # Check if permission elevation is defined in vm_config
    ${has_perm_elevation}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${server_config}    permission_elevation_type
    ${vm_perm_type}=    Set Variable If    ${has_perm_elevation}    ${server_config['permission_elevation_type']}    NONE
    ${vm_perm_user}=    Set Variable If    ${has_perm_elevation}    ${server_config.get('permission_elevation_user', '')}    ${EMPTY}
    ${vm_perm_pass}=    Set Variable If    ${has_perm_elevation}    ${server_config.get('permission_elevation_password', '')}    ${EMPTY}
    
    # Check if database credentials are available
    ${has_database}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${vm_config}    database
    
    # Load site creation payload template
    ${payload_file}=    Set Variable    ${CURDIR}/../payloads/site_creation.json
    ${payload}=    Evaluate    json.load(open('${payload_file}'))    json
    
    # Update payload with site details - same as create but include site_id
    ${site_id_int}=    Convert To Integer    ${site_id}
    Set To Dictionary    ${payload}    id=${site_id_int}
    Set To Dictionary    ${payload}    name=${site_name}
    Set To Dictionary    ${payload}    description=${EMPTY}
    Set To Dictionary    ${payload}    auto_engine_selection_enabled=${True}
    Set To Dictionary    ${payload}    scan_template_id=${scan_template}
    ${engine_id_int}=    Convert To Integer    ${engine_id}
    Set To Dictionary    ${payload}    engine_id=${engine_id_int}
    
    # Remove fields that may cause issues (but keep id for update)
    Run Keyword And Ignore Error    Remove From Dictionary    ${payload}    version
    Run Keyword And Ignore Error    Remove From Dictionary    ${payload}    discovery_config
    Run Keyword And Ignore Error    Remove From Dictionary    ${payload}    search_criteria
    
    # Set the included asset (IP address)
    ${ip_list}=    Create List    ${ip}
    Set To Dictionary    ${payload}[included_scan_targets]    addresses=${ip_list}
    
    # Create server credential
    ${cred_id}=    Convert To Integer    -1
    ${service_upper}=    Evaluate    "${service}".upper()
    ${ssh_cred}=    Create Dictionary
    ...    id=${cred_id}
    ...    name=${service_upper} Credential
    ...    service=${service}
    ...    user_name=${username}
    ...    password=${password}
    ...    enabled=${True}
    ...    scope=${scope}
    
    # Add permission elevation fields - priority: test file params > vm_config > NONE
    IF    '${perm_elevation_type}' != '${EMPTY}'
        # Use values from test file (explicitly passed)
        Set To Dictionary    ${ssh_cred}    permission_elevation_type=${perm_elevation_type}
        Set To Dictionary    ${ssh_cred}    permission_elevation_user=${perm_elevation_user}
        Set To Dictionary    ${ssh_cred}    permission_elevation_password=${perm_elevation_password}
        Log    Added permission elevation from test file: ${perm_elevation_type}    console=True
    ELSE IF    '${vm_perm_type}' != 'NONE' and '${vm_perm_type}' != '${EMPTY}'
        # Use values from vm_config if available
        Set To Dictionary    ${ssh_cred}    permission_elevation_type=${vm_perm_type}
        IF    '${vm_perm_user}' != '${EMPTY}'
            Set To Dictionary    ${ssh_cred}    permission_elevation_user=${vm_perm_user}
        END
        IF    '${vm_perm_pass}' != '${EMPTY}'
            Set To Dictionary    ${ssh_cred}    permission_elevation_password=${vm_perm_pass}
        END
        Log    Added permission elevation from vm_config: ${vm_perm_type}    console=True
    ELSE
        # Default to NONE
        Set To Dictionary    ${ssh_cred}    permission_elevation_type=NONE
        Log    Permission elevation set to NONE (not defined in test file or vm_config)    console=True
    END
    
    ${site_creds}=    Create List    ${ssh_cred}
    Set To Dictionary    ${payload}    site_credentials=${site_creds}
    
    # Set organization to empty object
    ${empty_dict}=    Create Dictionary
    Set To Dictionary    ${payload}    organization=${empty_dict}
    
    # Ensure other required fields are set to empty arrays/objects
    Set To Dictionary    ${payload}[included_scan_targets]    asset_groups=@{EMPTY}
    Set To Dictionary    ${payload}[excluded_scan_targets]    addresses=@{EMPTY}
    Set To Dictionary    ${payload}[excluded_scan_targets]    asset_groups=@{EMPTY}
    
    # If database credentials are available, add database credential
    IF    ${has_database}
        ${database_config}=    Get From Dictionary    ${vm_config}    database
        ${db_ip}=    Get From Dictionary    ${database_config}    ip
        ${db_username}=    Get From Dictionary    ${database_config}    username
        ${db_password}=    Get From Dictionary    ${database_config}    password
        
        ${db_service_type}=    Set Variable If    '${db_service}' != '${EMPTY}'    ${db_service}    oracle
        
        ${db_cred_id}=    Convert To Integer    -1
        ${db_cred}=    Create Dictionary
        ...    id=${db_cred_id}
        ...    name=Database Credential
        ...    service=${db_service_type}
        ...    user_name=${db_username}
        ...    password=${db_password}
        ...    permission_elevation_type=NONE
        ...    enabled=${True}
        ...    scope=${scope}
        
        IF    '${db_sid}' != '${EMPTY}'
            Set To Dictionary    ${db_cred}    database=${db_sid}
        END
        IF    '${db_port}' != '${EMPTY}'
            Set To Dictionary    ${db_cred}    port=${db_port}
        END
        IF    '${db_domain}' != '${EMPTY}'
            Set To Dictionary    ${db_cred}    domain=${db_domain}
        END
        
        Append To List    ${payload}[site_credentials]    ${db_cred}
    END
    
    # Log the complete payload for debugging
    ${payload_json}=    Evaluate    json.dumps($payload, indent=2)    json
    Log    Site Update Payload:\n${payload_json}    console=True
    
    # Create PUT request with session authentication
    ${headers}=    Create Dictionary    
    ...    Content-Type=application/json    
    ...    nexposeCCSessionID=${SESSION_ID}
    
    Log    Request Headers: ${headers}    console=True
    
    # Update site using PUT request
    ${endpoint}=    Set Variable    ${GLOBAL_NEXPOSE_V2_ENDPOINTS_SITES}${site_id}
    
    # Update site with auto-reauth
    ${response}=    login.API Call With Auto Reauth
    ...    PUT
    ...    ${endpoint}
    ...    json=${payload}
    ...    headers=${headers}
    
    # Check if successful (200 OK)
    IF    ${response.status_code} != 200
        Log    Site update failed. Status: ${response.status_code}    console=True
        Log    Error Response Body: ${response.text}    console=True
        Fail    Site update failed with status ${response.status_code}: ${response.text}
    END
    
    # Check if response has JSON content
    ${response_text}=    Set Variable    ${response.text}
    ${has_content}=    Run Keyword And Return Status    Should Not Be Empty    ${response_text}
    
    IF    ${has_content}
        ${response_json}=    Set Variable    ${response.json()}
        ${response_str}=    Evaluate    json.dumps($response_json, indent=2)    json
        Log    Site Update Response:\n${response_str}    console=True
    ELSE
        Log    Site Update Response: No content (empty response)    console=True
    END
    
    Log    Site updated successfully with ID: ${site_id}, IP: ${ip}, Engine: ${engine_id}, Scope: ${scope}    console=True
    
    RETURN    ${site_id}


Add Database Credential To List
    [Documentation]    Add database credential to credentials list
    ...    Supports Oracle, DB2, MySQL, PostgreSQL, SQL Server, Sybase
    [Arguments]    ${cred_list}    ${db_service}    ${db_username}    ${db_password}    ${db_sid}    ${db_port}    ${scope}
    
    # Create database credential dictionary
    ${db_cred}=    Create Dictionary
    ...    service=${db_service}
    ...    user_name=${db_username}
    ...    password=${db_password}
    ...    name=${db_service} Database Credential
    ...    enabled=${True}
    ...    scope=${scope}
    ...    description=${db_service} database credential for compliance scanning
    ...    sid=${db_sid}
    ...    port=${db_port}
    ...    host_restriction=${None}
    ...    port_restriction=${None}
    
    Append To List    ${cred_list}    ${db_cred}
    Log    Added ${db_service} database credential to site credentials

Add Database Credential From Config
    [Documentation]    Add database credential from database config in vm_config.json
    [Arguments]    ${cred_list}    ${database_config}    ${db_service}=${EMPTY}    ${db_sid}=${EMPTY}    ${db_port}=${EMPTY}    ${scope}=S
    
    ${db_username}=    Get From Dictionary    ${database_config}    username
    ${db_password}=    Get From Dictionary    ${database_config}    password
    
    # Use provided db_service or default based on context
    ${service}=    Set Variable If    '${db_service}' != '${EMPTY}'    ${db_service}    oracle
    
    # Create database credential dictionary
    ${db_cred}=    Create Dictionary
    ...    service=${service}
    ...    user_name=${db_username}
    ...    password=${db_password}
    ...    name=${service} Database Credential
    ...    enabled=${True}
    ...    scope=${scope}
    ...    description=${service} database credential from VM config
    
    # Add optional fields if provided
    Run Keyword If    '${db_sid}' != '${EMPTY}'
    ...    Set To Dictionary    ${db_cred}    sid=${db_sid}
    
    Run Keyword If    '${db_port}' != '${EMPTY}'
    ...    Set To Dictionary    ${db_cred}    port=${db_port}
    
    Set To Dictionary    ${db_cred}    host_restriction=${None}    port_restriction=${None}
    
    Append To List    ${cred_list}    ${db_cred}
    Log    Added ${service} database credential from config to site credentials

Update Site With VM Credentials
    [Documentation]    Update site with credentials based on compliance framework
    [Arguments]    ${site_id}    ${framework}    @{vm_path}
    
    # Get VM credentials
    ${vm_config}=    Get VM Config    ${framework}    @{vm_path}
    ${credentials}=    Get VM Credentials    ${framework}    @{vm_path}
    
    # Load site update payload
    ${payload_file}=    Set Variable    ${CURDIR}/../payloads/site_update.json
    ${payload}=    Evaluate    json.load(open('${payload_file}'))    json
    
    # Update credentials in payload
    ${cred_list}=    Create List    ${credentials}
    Set To Dictionary    ${payload}[site]    credentials=${cred_list}
    
    # Create PUT request with session authentication
    ${headers}=    Create Dictionary    
    ...    Content-Type=application/json
    ...    nexposeCCSessionID=${SESSION_ID}
    
    ${response}=    login.API Call With Auto Reauth
    ...    PUT
    ...    ${GLOBAL_NEXPOSE_V2_ENDPOINTS_SITES}/${site_id}
    ...    json=${payload}
    ...    headers=${headers}
    
    Should Be Equal As Strings    ${response.status_code}    200
    ...    msg=Failed to update site credentials. Status: ${response.status_code}, Response: ${response.text}
    
    ${vm_path_str}=    Catenate    SEPARATOR=/    @{vm_path}
    Log    Site ${site_id} updated with ${framework}/${vm_path_str} credentials
    
    RETURN    ${response}

Get Site Details
    [Documentation]    Get site details by site ID
    [Arguments]    ${site_id}
    
    ${headers}=    Create Dictionary
    ...    nexposeCCSessionID=${SESSION_ID}
    
    ${response}=    login.API Call With Auto Reauth
    ...    GET
    ...    ${GLOBAL_NEXPOSE_V2_ENDPOINTS_SITES}/${site_id}
    ...    headers=${headers}
    
    Should Be Equal As Strings    ${response.status_code}    200
    ...    msg=Failed to get site details. Status: ${response.status_code}, Response: ${response.text}
    
    RETURN    ${response.json()}


Delete Site
    [Documentation]    Delete a site by site ID using XML API
    ...    
    ...    Arguments:
    ...    - site_id: Site ID to delete (e.g., 76)
    ...    
    ...    Returns: Response text
    ...    
    ...    Example: Delete Site    76
    [Arguments]    ${site_id}
    
    # Validate session
    ${session_valid}=    Run Keyword And Return Status    Should Not Be Equal    ${SESSION_ID}    ${EMPTY}
    
    IF    not ${session_valid}
        Login To Console
    END
    
    # Prepare XML request
    ${xml_request}=    Set Variable    <?xml version="1.0" encoding="UTF-8"?>\n<SiteDeleteRequest session-id="${SESSION_ID}" site-id="${site_id}"/>
    
    # Prepare headers
    ${headers}=    Create Dictionary
    ...    Content-Type=text/xml
    ...    Cookie=nexposeCCSessionID=${SESSION_ID}
    
    Log    ========================================    console=True
    Log    DELETING SITE    console=True
    Log    Site ID: ${site_id}    console=True
    Log    Request XML: ${xml_request}    console=True
    Log    ========================================    console=True
    
    # Send POST request with XML
    ${response}=    POST
    ...    ${BASE_URL}/api/1.1/xml
    ...    data=${xml_request}
    ...    headers=${headers}
    ...    verify=${False}
    ...    expected_status=any
    
    Log    ========================================    console=True
    Log    DELETE SITE RESPONSE    console=True
    Log    Status Code: ${response.status_code}    console=True
    Log    Response Body: ${response.text}    console=True
    Log    ========================================    console=True
    
    # Validate status code
    Should Be Equal As Strings    ${response.status_code}    200
    ...    msg=Failed to delete site ${site_id}. Status Code: ${response.status_code}, Response: ${response.text}
    
    # Validate XML response contains success="1"
    Should Contain    ${response.text}    success="1"
    ...    msg=Site deletion API returned non-success response: ${response.text}
    
    Log    ========================================    console=True
    Log    ✓ SITE DELETED SUCCESSFULLY    console=True
    Log    Site ID: ${site_id}    console=True
    Log    Status Code: ${response.status_code}    console=True
    Log    ========================================    console=True
    
    RETURN    ${response.text}
