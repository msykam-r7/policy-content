*** Settings ***
Documentation     VM Configuration Management Keywords
Library           OperatingSystem
Library           Collections
Library           String


*** Keywords ***
Get VM Config
    [Documentation]    Get VM configuration based on OS identifier or framework path
    ...    Supports both new format (os_identifier) and legacy format (framework path)
    ...    New format examples: 
    ...    - Get VM Config    CIS_RHEL_9    compliance    server
    ...    - Get VM Config    CIS_Ubuntu_20.04    compliance    server
    ...    - Get VM Config    CIS_Apache_Tomcat_9    compliance    server    database
    ...    Legacy format examples (backward compatibility):
    ...    - Get VM Config    CIS    Ubuntu    Ubuntu-20-04    server
    ...    - Get VM Config    CIS    Apache    Tomcat    9    server    database
    [Arguments]    ${framework}    @{vm_path_and_types}
    
    ${config_file}=    Set Variable    ${CURDIR}/../testdata/vm_config.json
    ${config_json}=    Evaluate    json.load(open('${config_file}'))    json
    
    # Check if framework contains '_' - indicates new format with os_identifier (e.g., CIS_RHEL_9)
    ${is_new_format}=    Run Keyword And Return Status    Should Contain    ${framework}    _
    
    ${path_list}=    Create List
    ${cred_types}=    Create List
    
    IF    ${is_new_format}
        # New format: framework is "CIS_ORACLE_19C" and vm_path_and_types are "compliance", "server", "database"
        @{path_parts}=    Evaluate    "${framework}".split('_')
        FOR    ${part}    IN    @{path_parts}
            Append To List    ${path_list}    ${part}
        END
        
        # Separate path elements from credential types
        FOR    ${element}    IN    @{vm_path_and_types}
            ${is_cred_type}=    Run Keyword And Return Status    Should Match Regexp    ${element}    ^(server|database)$
            IF    ${is_cred_type}
                Append To List    ${cred_types}    ${element}
            ELSE
                # Path element (e.g., compliance, not-compliance)
                Append To List    ${path_list}    ${element}
            END
        END
        
        # Extract the framework (first element)
        ${framework}=    Get From List    ${path_list}    0
        # Remove first element to get the path
        ${path_list}=    Evaluate    list(${path_list})[1:]    builtins
    ELSE
        # Legacy format: Separate VM path from credential types (server/database)
        FOR    ${element}    IN    @{vm_path_and_types}
            ${is_cred_type}=    Run Keyword And Return Status    Should Match Regexp    ${element}    ^(server|database)$
            IF    ${is_cred_type}
                Append To List    ${cred_types}    ${element}
            ELSE
                Append To List    ${path_list}    ${element}
            END
        END
        
        # If no credential types specified, default to 'server'
        ${cred_count}=    Get Length    ${cred_types}
        IF    ${cred_count} == 0
            Append To List    ${cred_types}    server
        END
    END
    
    # Navigate to compliance framework (e.g., "CIS", "DISA", "FDCC")
    ${framework_exists}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${config_json}    ${framework}
    IF    not ${framework_exists}
        Log    ========================================    console=True    level=ERROR
        Log    ERROR: VM CONFIGURATION NOT FOUND    console=True    level=ERROR
        Log    ========================================    console=True    level=ERROR
        Log    Framework '${framework}' not found in vm_config.json    console=True    level=WARN
        Log    Path: ${framework}    console=True    level=WARN
        Log    ========================================    console=True    level=ERROR
        Fail    VM Configuration not found: Framework '${framework}' does not exist in vm_config.json
    END
    ${current_level}=    Get From Dictionary    ${config_json}    ${framework}
    
    # Navigate through the path (e.g., Apache -> Tomcat -> 9) - case insensitive
    FOR    ${path_element}    IN    @{path_list}
        # Try to find matching key case-insensitively
        ${matched_key}=    Find Key Case Insensitive    ${current_level}    ${path_element}
        IF    '${matched_key}' == '${EMPTY}'
            Log    ========================================    console=True    level=ERROR
            Log    ERROR: VM CONFIGURATION NOT FOUND    console=True    level=ERROR
            Log    ========================================    console=True    level=ERROR
            Log    Path element '${path_element}' not found in vm_config.json    console=True    level=WARN
            Log    Full path attempted: ${framework}    console=True    level=WARN
            Log    Failed at: ${path_element}    console=True    level=WARN
            Log    ========================================    console=True    level=ERROR
            Fail    VM Configuration not found: '${framework}' - Path element '${path_element}' does not exist in vm_config.json
        END
        ${current_level}=    Get From Dictionary    ${current_level}    ${matched_key}
    END
    
    # Check what format the config is in
    ${has_ip}=    Run Keyword And Return Status    
    ...    Dictionary Should Contain Key    ${current_level}    ip
    ${has_server}=    Run Keyword And Return Status    
    ...    Dictionary Should Contain Key    ${current_level}    server
    ${has_database}=    Run Keyword And Return Status    
    ...    Dictionary Should Contain Key    ${current_level}    database
    
    # Build result based on requested credential types
    ${result}=    Create Dictionary
    
    IF    ${has_server} or ${has_database}
        # New format - return requested credentials
        FOR    ${cred_type}    IN    @{cred_types}
            IF    '${cred_type}' == 'server' and ${has_server}
                ${server_creds}=    Get From Dictionary    ${current_level}    server
                Set To Dictionary    ${result}    server=${server_creds}
            ELSE IF    '${cred_type}' == 'database' and ${has_database}
                ${db_creds}=    Get From Dictionary    ${current_level}    database
                Set To Dictionary    ${result}    database=${db_creds}
            ELSE IF    '${cred_type}' == 'server' and not ${has_server}
                Log    ========================================    console=True    level=ERROR
                Log    ERROR: SERVER CREDENTIALS NOT FOUND    console=True    level=ERROR
                Log    ========================================    console=True    level=ERROR
                Log    Server credentials not found in vm_config.json    console=True    level=WARN
                Log    Path: ${framework}    console=True    level=WARN
                Log    Looking for: server    console=True    level=WARN
                Log    Available: ${current_level.keys()}    console=True    level=WARN
                Log    ========================================    console=True    level=ERROR
                Fail    Server credentials not found for ${framework}
            ELSE IF    '${cred_type}' == 'database' and not ${has_database}
                Log    ========================================    console=True    level=ERROR
                Log    ERROR: DATABASE CREDENTIALS NOT FOUND    console=True    level=ERROR
                Log    ========================================    console=True    level=ERROR
                Log    Database credentials not found in vm_config.json    console=True    level=WARN
                Log    Path: ${framework}    console=True    level=WARN
                Log    Looking for: database    console=True    level=WARN
                Log    Available: ${current_level.keys()}    console=True    level=WARN
                Log    ========================================    console=True    level=ERROR
                Fail    Database credentials not found for ${framework}
            END
        END
    ELSE IF    ${has_ip}
        # Old format - treat as server credentials
        Set To Dictionary    ${result}    server=${current_level}
    ELSE
        Log    ========================================    console=True    level=ERROR
        Log    ERROR: INVALID VM CONFIGURATION    console=True    level=ERROR
        Log    ========================================    console=True    level=ERROR
        Log    Path does not point to valid VM configuration    console=True    level=WARN
        Log    Path: ${framework}    console=True    level=WARN
        Log    Expected: 'server' or 'database' or direct IP config    console=True    level=WARN
        Log    Found keys: ${current_level.keys()}    console=True    level=WARN
        Log    ========================================    console=True    level=ERROR
        Fail    Path ${framework} does not point to a valid VM configuration.
    END
    
    Log    Found VM Config for ${framework}/@{path_list} with types @{cred_types}: ${result}
    
    RETURN    ${result}

Get Server Config
    [Documentation]    Get server configuration (returns server credentials if available, otherwise main credentials)
    [Arguments]    ${framework}    @{vm_path}
    
    ${vm_config}=    Get VM Config    ${framework}    @{vm_path}
    
    # Check if server config exists
    ${has_server}=    Run Keyword And Return Status    
    ...    Dictionary Should Contain Key    ${vm_config}    server
    
    ${server_config}=    Run Keyword If    ${has_server}
    ...    Get From Dictionary    ${vm_config}    server
    ...    ELSE
    ...    Set Variable    ${vm_config}
    
    RETURN    ${server_config}

Get Database Config
    [Documentation]    Get database configuration (returns None if not available)
    [Arguments]    ${framework}    @{vm_path}
    
    ${vm_config}=    Get VM Config    ${framework}    @{vm_path}
    
    # Check if database config exists
    ${has_database}=    Run Keyword And Return Status    
    ...    Dictionary Should Contain Key    ${vm_config}    database
    
    ${database_config}=    Run Keyword If    ${has_database}
    ...    Get From Dictionary    ${vm_config}    database
    ...    ELSE
    ...    Set Variable    ${None}
    
    RETURN    ${database_config}

Get VM IP
    [Documentation]    Get VM IP address based on compliance framework and VM path
    [Arguments]    ${framework}    @{vm_path}
    
    ${vm_config}=    Get VM Config    ${framework}    @{vm_path}
    ${ip}=    Get From Dictionary    ${vm_config}    ip
    
    RETURN    ${ip}

Get VM Credentials
    [Documentation]    Get VM credentials based on compliance framework and VM path
    [Arguments]    ${framework}    @{vm_path}
    
    ${vm_config}=    Get VM Config    ${framework}    @{vm_path}
    
    # Determine if it's Windows or Linux based on presence of ssh_username
    ${has_ssh_username}=    Run Keyword And Return Status    
    ...    Dictionary Should Contain Key    ${vm_config}    ssh_username
    
    ${credentials}=    Run Keyword If    ${has_ssh_username}
    ...    Create Linux Credentials    ${vm_config}
    ...    ELSE
    ...    Create Windows Credentials    ${vm_config}
    
    RETURN    ${credentials}

Create Linux Credentials
    [Documentation]    Create SSH credentials for Linux VM
    [Arguments]    ${vm_config}
    
    ${creds}=    Create Dictionary
    ...    service=ssh
    ...    user_name=${vm_config}[ssh_username]
    ...    password=${vm_config}[ssh_password]
    ...    permission_elevation_type=${vm_config}[permission_elevation_type]
    ...    enabled=true
    ...    scope=S
    
    # Add elevation details if needed
    ${has_elevation_user}=    Run Keyword And Return Status    
    ...    Dictionary Should Contain Key    ${vm_config}    permission_elevation_user
    
    Run Keyword If    ${has_elevation_user}
    ...    Set To Dictionary    ${creds}    
    ...    permission_elevation_user=${vm_config}[permission_elevation_user]
    ...    permission_elevation_password=${vm_config}[permission_elevation_password]
    
    RETURN    ${creds}

Create Windows Credentials
    [Documentation]    Create credentials for Windows VM
    [Arguments]    ${vm_config}
    
    ${creds}=    Create Dictionary
    ...    service=cifs
    ...    user_name=${vm_config}[username]
    ...    password=${vm_config}[password]
    ...    enabled=true
    ...    scope=S
    
    # Add domain if present
    ${has_domain}=    Run Keyword And Return Status    
    ...    Dictionary Should Contain Key    ${vm_config}    domain
    
    Run Keyword If    ${has_domain} and '${vm_config}[domain]' != ''
    ...    Set To Dictionary    ${creds}    domain=${vm_config}[domain]
    
    RETURN    ${creds}

Create Virtualization Credentials
    [Documentation]    Create credentials for virtualization platforms
    [Arguments]    ${vm_config}    ${platform_type}
    
    # vSphere uses username/password, ESXi/Docker use SSH
    ${has_ssh_username}=    Run Keyword And Return Status    
    ...    Dictionary Should Contain Key    ${vm_config}    ssh_username
    
    ${creds}=    Run Keyword If    ${has_ssh_username}
    ...    Create Linux Credentials    ${vm_config}
    ...    ELSE
    ...    Create Windows Credentials    ${vm_config}
    
    RETURN    ${creds}

Get All VM Configs
    [Documentation]    Get all VM configurations from all frameworks
    
    ${config_file}=    Set Variable    ${CURDIR}/../testdata/vm_config.json
    ${config_json}=    Evaluate    json.load(open('${config_file}'))    json
    
    # Remove description key
    ${all_vms}=    Copy Dictionary    ${config_json}
    Remove From Dictionary    ${all_vms}    description
    
    RETURN    ${all_vms}

Get VMs By Framework
    [Documentation]    Get all VMs in a specific compliance framework
    [Arguments]    ${framework}
    
    ${config_file}=    Set Variable    ${CURDIR}/../testdata/vm_config.json
    ${config_json}=    Evaluate    json.load(open('${config_file}'))    json
    ${framework_vms}=    Get From Dictionary    ${config_json}    ${framework}
    
    RETURN    ${framework_vms}

Find Key Case Insensitive
    [Documentation]    Find a dictionary key case-insensitively
    ...    Returns the actual key from the dictionary if found, empty string if not found
    [Arguments]    ${dictionary}    ${search_key}
    
    ${search_key_lower}=    Convert To Lower Case    ${search_key}
    @{dict_keys}=    Get Dictionary Keys    ${dictionary}
    
    FOR    ${key}    IN    @{dict_keys}
        ${key_lower}=    Convert To Lower Case    ${key}
        IF    '${key_lower}' == '${search_key_lower}'
            RETURN    ${key}
        END
    END
    
    RETURN    ${EMPTY}
