*** Settings ***
Documentation     Scan Template API Keywords for Nexpose/InsightVM
Library           RequestsLibrary
Library           Collections
Library           OperatingSystem
Library           XML
Library           String
Library           Process
Resource          ../testdata/endpoints.robot
Resource          login.robot


*** Keywords ***
Get Scan Template Details
    [Documentation]    Get scan template details by template ID/name from Nexpose API
    ...    Example: Get Scan Template Details    cis
    [Arguments]    ${template_id}
    
    # Create GET request with session authentication
    ${headers}=    Create Dictionary    
    ...    Content-Type=application/json    
    ...    nexposeCCSessionID=${SESSION_ID}
    
    Log    Getting scan template details for: ${template_id}    console=True
    
    # Get template details using GET request with copy=true parameter
    ${endpoint}=    Set Variable    ${GLOBAL_NEXPOSE_DATA_SCAN_TEMPLATES}/${template_id}
    ${params}=    Create Dictionary    copy=true
    
    ${response}=    GET On Session    
    ...    nexpose    
    ...    ${endpoint}    
    ...    headers=${headers}
    ...    params=${params}    
    ...    expected_status=any
    
    # Check if response is successful
    IF    ${response.status_code} != 200
        Log    Failed to get scan template. Status: ${response.status_code}    console=True
        Log    Error Response Body: ${response.text}    console=True
        Fail    Failed to get scan template with status ${response.status_code}: ${response.text}
    END
    
    # Check if response has content
    ${has_content}=    Run Keyword And Return Status    Should Not Be Empty    ${response.text}
    IF    not ${has_content}
        Log    Template API returned empty response    console=True
        Fail    Template API returned empty response for template: ${template_id}
    END
    
    # Try to parse as JSON, if fails treat as XML
    ${status}    ${response_json}=    Run Keyword And Ignore Error    Set Variable    ${response.json()}
    
    IF    '${status}' == 'FAIL'
        # Response is XML, save as-is
        Log    Template response is XML format    console=True
        ${template_content}=    Set Variable    ${response.text}
        ${response_data}=    Create Dictionary    content=${template_content}    format=xml
    ELSE
        # Response is JSON
        Log    Template response is JSON format    console=True
        ${response_str}=    Evaluate    json.dumps($response_json, indent=2)    json
        Log    Scan Template Details:\n${response_str}    console=True
        ${template_content}=    Set Variable    ${response.text}
        ${response_data}=    Set Variable    ${response_json}
    END
    
    # Save template to data/templates directory
    ${template_filename}=    Set Variable    ${template_id}_template.xml
    ${template_path}=    Set Variable    ${EXECDIR}/data/templates/${template_filename}
    
    Create File    ${template_path}    ${template_content}
    Log    Saved template XML to: ${template_path}    console=True
    
    # Parse PolicyBenchmark entries from the XML
    ${policy_benchmarks}=    Extract Policy Benchmarks From Template    ${template_path}
    Log    Extracted ${policy_benchmarks}[count] policy benchmarks    console=True
    
    # Check if policies JSON already exists and handle version changes
    ${json_filename}=    Set Variable    ${template_id}_policies.json
    ${json_path}=    Set Variable    ${EXECDIR}/data/policies/${json_filename}
    ${existing_data}=    Load Existing Policies If Exists    ${json_path}
    
    # Merge with existing data to track deprecated versions
    ${merged_benchmarks}=    Merge Benchmark Versions    ${policy_benchmarks}[policies]    ${existing_data}
    
    # Create structured JSON response with OS, benchmark, version, and policies
    ${structured_response}=    Create Dictionary
    ...    template_id=${template_id}
    ...    policy_benchmarks=${merged_benchmarks}
    ...    total_policies=${policy_benchmarks}[count]
    
    # Save JSON file to data/policies
    ${response_json}=    Evaluate    json.dumps($structured_response, indent=2)    json
    Create File    ${json_path}    ${response_json}
    Log    Saved policies JSON to: ${json_path}    console=True
    Log    Template Structure:\n${response_json}    console=True
    
    RETURN    ${structured_response}


List All Scan Templates
    [Documentation]    List all available scan templates from Nexpose
    
    # Create GET request with session authentication
    ${headers}=    Create Dictionary    
    ...    Content-Type=application/json    
    ...    nexposeCCSessionID=${SESSION_ID}
    
    Log    Retrieving all scan templates    console=True
    
    # Get all templates
    ${response}=    GET On Session    
    ...    nexpose    
    ...    ${GLOBAL_NEXPOSE_DATA_SCAN_TEMPLATES}    
    ...    headers=${headers}    
    ...    expected_status=200
    
    ${response_json}=    Set Variable    ${response.json()}
    ${template_count}=    Get Length    ${response_json}
    Log    Found ${template_count} scan templates    console=True
    
    RETURN    ${response_json}


Extract Policy Benchmarks From Template
    [Documentation]    Extract all PolicyBenchmark entries from the template XML
    ...    Returns a dictionary with count and list of policies with OS, benchmark, version, and policy IDs
    ...    Consolidates multiple PolicyBenchmark entries with the same benchmark_id
    [Arguments]    ${template_xml_path}
    
    # Parse the XML file
    ${xml_root}=    Parse XML    ${template_xml_path}
    
    # Get all PolicyBenchmark elements
    ${benchmarks}=    Get Elements    ${xml_root}    .//PolicyBenchmark
    
    # Dictionary to consolidate benchmarks by ID
    ${benchmark_dict}=    Create Dictionary
    
    FOR    ${benchmark}    IN    @{benchmarks}
        ${benchmark_id}=    Get Element Attribute    ${benchmark}    benchmarkID
        ${benchmark_version}=    Get Element Attribute    ${benchmark}    benchmarkVersion
        ${scope}=    Get Element Attribute    ${benchmark}    scope
        
        # Get all Policy elements within this benchmark
        ${policies}=    Get Elements    ${benchmark}    Policy
        
        FOR    ${policy}    IN    @{policies}
            ${policy_id}=    Get Element Attribute    ${policy}    policyID
            
            # Check if this benchmark_id already exists in our dictionary
            ${exists}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${benchmark_dict}    ${benchmark_id}
            
            IF    ${exists}
                # Append to existing policy list
                ${existing_entry}=    Get From Dictionary    ${benchmark_dict}    ${benchmark_id}
                Append To List    ${existing_entry}[policies]    ${policy_id}
            ELSE
                # Extract OS name from benchmark ID
                ${os_name}=    Extract OS Name From Benchmark ID    ${benchmark_id}
                
                # Create new entry
                @{policy_list}=    Create List    ${policy_id}
                ${new_entry}=    Create Dictionary
                ...    os=${os_name}
                ...    benchmark_id=${benchmark_id}
                ...    version=${benchmark_version}
                ...    scope=${scope}
                ...    policies=${policy_list}
                
                Set To Dictionary    ${benchmark_dict}    ${benchmark_id}    ${new_entry}
            END
        END
    END
    
    # Convert dictionary values to list and update policy counts
    @{policy_list}=    Create List
    ${benchmark_keys}=    Get Dictionary Keys    ${benchmark_dict}
    
    FOR    ${key}    IN    @{benchmark_keys}
        ${entry}=    Get From Dictionary    ${benchmark_dict}    ${key}
        ${policy_count}=    Get Length    ${entry}[policies]
        Set To Dictionary    ${entry}    policy_count=${policy_count}
        Append To List    ${policy_list}    ${entry}
    END
    
    ${benchmark_count}=    Get Length    ${policy_list}
    
    # Create result dictionary
    ${result}=    Create Dictionary
    ...    count=${benchmark_count}
    ...    policies=${policy_list}
    
    RETURN    ${result}


Extract OS Name From Benchmark ID
    [Documentation]    Extract human-readable OS name from benchmark ID
    [Arguments]    ${benchmark_id}
    
    # Common patterns to extract OS name
    ${os_name}=    Set Variable    ${benchmark_id}
    
    # Replace underscores with spaces and capitalize
    ${os_name}=    Replace String    ${os_name}    _    ${SPACE}
    ${os_name}=    Replace String    ${os_name}    cis    ${EMPTY}
    ${os_name}=    Replace String    ${os_name}    benchmark    ${EMPTY}
    ${os_name}=    Strip String    ${os_name}
    
    # Capitalize each word
    ${os_name}=    Evaluate    ' '.join(word.capitalize() for word in '''${os_name}'''.split())
    
    RETURN    ${os_name}


Load Existing Policies If Exists
    [Documentation]    Load existing policies JSON file if it exists, return empty dict if not
    [Arguments]    ${json_path}
    
    ${file_exists}=    Run Keyword And Return Status    File Should Exist    ${json_path}
    
    IF    ${file_exists}
        ${existing_content}=    Get File    ${json_path}
        ${existing_data}=    Evaluate    json.loads('''${existing_content}''')    json
        Log    Loaded existing policies from: ${json_path}    console=True
        RETURN    ${existing_data}
    ELSE
        ${empty_dict}=    Create Dictionary
        Log    No existing policies file found, starting fresh    console=True
        RETURN    ${empty_dict}
    END


Merge Benchmark Versions
    [Documentation]    Merge new benchmarks with existing data, tracking deprecated versions
    ...    If a benchmark version changes, add the old version to deprecated array
    [Arguments]    ${new_benchmarks}    ${existing_data}
    
    # If no existing data, return new benchmarks as-is
    ${has_existing}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${existing_data}    policy_benchmarks
    IF    not ${has_existing}
        Log    No existing data to merge, using new benchmarks    console=True
        RETURN    ${new_benchmarks}
    END
    
    # Create a dictionary of existing benchmarks keyed by benchmark_id
    ${existing_benchmarks}=    Get From Dictionary    ${existing_data}    policy_benchmarks
    ${existing_dict}=    Create Dictionary
    
    FOR    ${benchmark}    IN    @{existing_benchmarks}
        ${bench_id}=    Get From Dictionary    ${benchmark}    benchmark_id
        Set To Dictionary    ${existing_dict}    ${bench_id}    ${benchmark}
    END
    
    # Process new benchmarks and check for version changes
    @{merged_list}=    Create List
    
    FOR    ${new_benchmark}    IN    @{new_benchmarks}
        ${bench_id}=    Get From Dictionary    ${new_benchmark}    benchmark_id
        ${new_version}=    Get From Dictionary    ${new_benchmark}    version
        
        # Check if this benchmark_id exists in existing data
        ${exists}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${existing_dict}    ${bench_id}
        
        IF    ${exists}
            ${existing_benchmark}=    Get From Dictionary    ${existing_dict}    ${bench_id}
            ${existing_version}=    Get From Dictionary    ${existing_benchmark}    version
            
            # Check if version changed
            IF    '${new_version}' != '${existing_version}'
                Log    Version change detected for ${bench_id}: ${existing_version} -> ${new_version}    console=True
                
                # Get existing deprecated list or create new one
                ${has_deprecated}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${existing_benchmark}    deprecated
                IF    ${has_deprecated}
                    ${deprecated_list}=    Get From Dictionary    ${existing_benchmark}    deprecated
                ELSE
                    @{deprecated_list}=    Create List
                END
                
                # Add old version to deprecated list if not already there
                ${already_deprecated}=    Run Keyword And Return Status    List Should Contain Value    ${deprecated_list}    ${existing_version}
                IF    not ${already_deprecated}
                    Append To List    ${deprecated_list}    ${existing_version}
                    Log    Added version ${existing_version} to deprecated list for ${bench_id}    console=True
                END
                
                # Add deprecated list to new benchmark
                Set To Dictionary    ${new_benchmark}    deprecated=${deprecated_list}
            ELSE
                # Version same, preserve existing deprecated list if present
                ${has_deprecated}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${existing_benchmark}    deprecated
                IF    ${has_deprecated}
                    ${deprecated_list}=    Get From Dictionary    ${existing_benchmark}    deprecated
                    Set To Dictionary    ${new_benchmark}    deprecated=${deprecated_list}
                END
            END
        END
        
        Append To List    ${merged_list}    ${new_benchmark}
    END
    
    RETURN    ${merged_list}


Get Benchmark ID And Policies For OS
    [Documentation]    Get benchmark ID and policies for a specific OS
    ...    This is a simplified wrapper that returns the benchmark ID and policy list
    ...    for a given OS name and optional version.
    ...    
    ...    Arguments:
    ...    - template_id: Template ID (e.g., 'cis', 'disa_stig')
    ...    - os_name: OS name (e.g., 'Red Hat Enterprise Linux 9 STIG', 'Ubuntu 20.04')
    ...    - version: Optional version to filter (e.g., '1.0.0', '3.0.0')
    ...    
    ...    Returns: Dictionary with:
    ...        - benchmark_id: The benchmark identifier
    ...        - os: Operating system name
    ...        - version: OS version
    ...        - policies: List of policy IDs
    ...        - policy_count: Number of policies
    ...    
    ...    Example: ${result}=    Get Benchmark ID And Policies For OS    cis    Red Hat Enterprise Linux 9 STIG    1.0.0
    ...    Example: ${result}=    Get Benchmark ID And Policies For OS    cis    Ubuntu 20.04
    [Arguments]    ${template_id}    ${os_name}    ${version}=${EMPTY}
    
    # Get policies for the specified OS
    ${os_policies}=    Get Policies For OS    ${template_id}    ${os_name}
    
    # Verify we got results
    ${policy_count}=    Get Length    ${os_policies}
    Should Be True    ${policy_count} > 0    No policies found for ${os_name} in template ${template_id}
    
    # Filter by version if specified
    IF    '${version}' != '${EMPTY}'
        @{version_filtered}=    Create List
        FOR    ${benchmark}    IN    @{os_policies}
            IF    '${benchmark}[version]' == '${version}'
                Append To List    ${version_filtered}    ${benchmark}
            END
        END
        ${os_policies}=    Set Variable    ${version_filtered}
        ${filtered_count}=    Get Length    ${os_policies}
        Should Be True    ${filtered_count} > 0    No policies found for ${os_name} version ${version}
    END
    
    # Get the first matching benchmark (should be only one for specific OS+version)
    ${benchmark}=    Get From List    ${os_policies}    0
    
    # Log the details
    Log    ========================================    console=True
    Log    BENCHMARK DETAILS FOR ${os_name}    console=True
    Log    Benchmark ID: ${benchmark}[benchmark_id]    console=True
    Log    OS: ${benchmark}[os]    console=True
    Log    Version: ${benchmark}[version]    console=True
    Log    Policy Count: ${benchmark}[policy_count]    console=True
    Log    Policies: ${benchmark}[policies]    console=True
    Log    ========================================    console=True
    
    # Return the benchmark details
    RETURN    ${benchmark}


Get Policies For OS
    [Documentation]    Get policies for a specific OS from the template
    ...    Arguments:
    ...    - template_id: Template ID (e.g., 'cis', 'disa_stig')
    ...    - os_name: OS name from vm_config.json (e.g., 'Apache Tomcat 8', 'Windows Server 2019')
    ...              Use 'all' to get all policies for all OS versions
    ...    Returns: List of policy benchmarks matching the OS name, or all if os_name='all'
    ...    Example: ${policies}=    Get Policies For OS    cis    Apache Tomcat 8
    ...    Example: ${all_policies}=    Get Policies For OS    cis    all
    [Arguments]    ${template_id}    ${os_name}
    
    # Load the policies JSON file
    ${json_path}=    Set Variable    ${EXECDIR}/data/policies/${template_id}_policies.json
    ${file_exists}=    Run Keyword And Return Status    File Should Exist    ${json_path}
    
    IF    not ${file_exists}
        Log    Policies file not found, fetching from API: ${json_path}    console=True
        ${template_data}=    Get Scan Template Details    ${template_id}
    ELSE
        ${json_content}=    Get File    ${json_path}
        ${template_data}=    Evaluate    json.loads('''${json_content}''')    json
        Log    Loaded policies from: ${json_path}    console=True
    END
    
    ${all_benchmarks}=    Get From Dictionary    ${template_data}    policy_benchmarks
    
    # Convert os_name to lowercase for comparison
    ${os_name_lower}=    Convert To Lower Case    ${os_name}
    
    # If 'all', return all benchmarks
    IF    '${os_name_lower}' == 'all'
        Log    Returning all policies for all OS versions    console=True
        RETURN    ${all_benchmarks}
    END
    
    # Filter benchmarks by OS name
    @{filtered_benchmarks}=    Create List
    
    # Split OS name into individual words for matching
    ${os_words}=    Split String    ${os_name_lower}
    
    FOR    ${benchmark}    IN    @{all_benchmarks}
        ${bench_os}=    Get From Dictionary    ${benchmark}    os
        ${bench_os_lower}=    Convert To Lower Case    ${bench_os}
        
        # Check if all words from os_name appear in bench_os (in any order)
        ${all_words_match}=    Set Variable    ${True}
        FOR    ${word}    IN    @{os_words}
            ${word_found}=    Run Keyword And Return Status    Should Contain    ${bench_os_lower}    ${word}
            IF    not ${word_found}
                ${all_words_match}=    Set Variable    ${False}
                BREAK
            END
        END
        
        IF    ${all_words_match}
            Log    Found matching benchmark: ${bench_os} (${benchmark}[benchmark_id])    console=True
            Append To List    ${filtered_benchmarks}    ${benchmark}
        END
    END
    
    ${match_count}=    Get Length    ${filtered_benchmarks}
    Log    Found ${match_count} benchmarks matching OS: ${os_name}    console=True
    
    RETURN    ${filtered_benchmarks}


Process Template For OS
    [Documentation]    Complete workflow to get template, extract policies, and create filtered copy
    ...    This keyword handles template processing with flexible policy filtering options.
    ...    
    ...    Arguments:
    ...    - template_id: Template/Benchmark ID (e.g., 'cis', 'disa_stig')
    ...    - os_name: OS name to filter (e.g., 'Ubuntu 20.04', 'Apache Tomcat 8')
    ...    - version: Optional version to filter (e.g., '3.0.0', '1.0.1')
    ...    - policies: Either 'all' to copy all policies, or comma-separated policy IDs
    ...                (e.g., 'Level-I,Level-II' or 'xccdf_org.cisecurity.benchmarks_profile_Level_1')
    ...    - template_title: Optional custom title for templateDescription attribute
    ...    
    ...    Returns: Dictionary with template_path, os_policies, all_policies, deprecated_count
    ...    
    ...    Example: ${result}=    Process Template For OS    cis    Ubuntu 20.04    3.0.0    all
    ...    Example: ${result}=    Process Template For OS    cis    Apache Tomcat 8    1.0.0    Level-I,Level-II    My Custom Title
    [Arguments]    ${template_id}    ${os_name}    ${version}=${EMPTY}    ${policies}=all    ${template_title}=${EMPTY}
    
    # Step 1: Get template and extract policies
    ${template_data}=    Get Scan Template Details    ${template_id}
    Log    Retrieved ${template_id} template with ${template_data}[total_policies] total policies    console=True
    
    # Step 2: Get ALL policies from template
    ${all_policies}=    Get Policies For OS    ${template_id}    all
    ${all_count}=    Get Length    ${all_policies}
    Log    Total benchmarks across all OS: ${all_count}    console=True
    
    # Count total policies across all benchmarks
    ${total_policy_count}=    Set Variable    ${0}
    FOR    ${benchmark}    IN    @{all_policies}
        ${total_policy_count}=    Evaluate    ${total_policy_count} + ${benchmark}[policy_count]
    END
    Log    Total individual policies across all OS: ${total_policy_count}    console=True
    
    # Step 3: Get policies specifically for the target OS
    ${os_policies}=    Get Policies For OS    ${template_id}    ${os_name}
    
    # Verify we got OS policies
    ${policy_count}=    Get Length    ${os_policies}
    Should Be True    ${policy_count} > 0    No policies found for ${os_name}
    Log    Found ${policy_count} benchmark(s) for ${os_name}    console=True
    
    # Step 4: Filter by version if specified
    IF    '${version}' != '${EMPTY}'
        @{version_filtered}=    Create List
        FOR    ${benchmark}    IN    @{os_policies}
            IF    '${benchmark}[version]' == '${version}'
                Append To List    ${version_filtered}    ${benchmark}
                Log    Matched version ${version} for ${benchmark}[benchmark_id]    console=True
            END
        END
        ${os_policies}=    Set Variable    ${version_filtered}
        ${filtered_count}=    Get Length    ${os_policies}
        Log    Filtered to ${filtered_count} benchmark(s) with version ${version}    console=True
    END
    
    # Step 5: Log details of each benchmark and check for deprecated versions
    ${deprecated_count}=    Set Variable    ${0}
    FOR    ${benchmark}    IN    @{os_policies}
        Log    ========================================    console=True
        Log    OS: ${benchmark}[os]    console=True
        Log    Benchmark ID: ${benchmark}[benchmark_id]    console=True
        Log    Version: ${benchmark}[version]    console=True
        Log    Policy Count: ${benchmark}[policy_count]    console=True
        Log    Policies: ${benchmark}[policies]    console=True
        
        # Check if deprecated versions exist
        ${has_deprecated}=    Run Keyword And Return Status    
        ...    Dictionary Should Contain Key    ${benchmark}    deprecated
        IF    ${has_deprecated}
            ${deprecated_count}=    Evaluate    ${deprecated_count} + 1
            Log    Deprecated Versions: ${benchmark}[deprecated]    console=True
        ELSE
            Log    No deprecated versions (current: ${benchmark}[version])    console=True
        END
        Log    ========================================    console=True
    END
    
    Log    Found ${deprecated_count} benchmarks with deprecated versions    console=True
    
    # Step 6: If policies='all', generate formatted list of all policies
    ${policies_lower}=    Convert To Lower Case    ${policies}
    @{all_policy_list}=    Create List
    
    IF    '${policies_lower}' == 'all'
        Log    ========================================    console=True
        Log    GENERATING ALL POLICIES LIST    console=True
        FOR    ${benchmark}    IN    @{os_policies}
            ${benchmark_id}=    Set Variable    ${benchmark}[benchmark_id]
            ${benchmark_version}=    Set Variable    ${benchmark}[version]
            ${policy_ids}=    Set Variable    ${benchmark}[policies]
            
            # Check if policy_ids is already a list or a string
            ${is_list}=    Run Keyword And Return Status    Evaluate    isinstance($policy_ids, list)
            
            IF    ${is_list}
                # Already a list, iterate directly
                FOR    ${policy_id}    IN    @{policy_ids}
                    ${formatted_policy}=    Set Variable    ${benchmark_id}:${benchmark_version}:${policy_id}
                    Append To List    ${all_policy_list}    ${formatted_policy}
                    Log    ${formatted_policy}    console=True
                END
            ELSE
                # It's a string, split it first
                @{policies_in_benchmark}=    Split String    ${policy_ids}    ,
                FOR    ${policy_id}    IN    @{policies_in_benchmark}
                    ${policy_id_trimmed}=    Strip String    ${policy_id}
                    ${formatted_policy}=    Set Variable    ${benchmark_id}:${benchmark_version}:${policy_id_trimmed}
                    Append To List    ${all_policy_list}    ${formatted_policy}
                    Log    ${formatted_policy}    console=True
                END
            END
        END
        Log    ========================================    console=True
    END
    
    # Step 7: Create template XML with policy filtering
    ${template_xml}=    Create Template Copy For OS With Policies    
    ...    ${template_id}    
    ...    ${os_name}    
    ...    ${version}    
    ...    ${policies}
    ...    ${template_title}
    
    Log    ========================================    console=True
    Log    GENERATED TEMPLATE XML:    console=True
    Log    ${template_xml}    console=True
    Log    ========================================    console=True
    
    # Return all the results
    ${result}=    Create Dictionary
    ...    template_xml=${template_xml}
    ...    os_policies=${os_policies}
    ...    all_policies=${all_policies}
    ...    deprecated_count=${deprecated_count}
    ...    total_policies=${total_policy_count}
    ...    formatted_policies=${all_policy_list}
    ...    benchmark_id=${template_id}
    ...    os_name=${os_name}
    ...    version=${version}
    ...    policies=${policies}
    ...    template_title=${template_title}
    
    RETURN    ${result}


Create Template Copy For OS With Policies
    [Documentation]    Create template copy filtered by OS, version, and specific policies
    ...    
    ...    Arguments:
    ...    - template_id: Template ID (e.g., 'cis')
    ...    - os_name: OS name (e.g., 'Ubuntu 20.04')
    ...    - version: Optional version filter (e.g., '3.0.0')
    ...    - policies: Either 'all' or comma-separated policy IDs
    ...    - template_title: Optional custom title for templateDescription attribute
    ...    
    ...    Returns: Path to created template file
    [Arguments]    ${template_id}    ${os_name}    ${version}=${EMPTY}    ${policies}=all    ${template_title}=${EMPTY}
    
    # Get template path
    ${template_xml_path}=    Set Variable    ${EXECDIR}/data/templates/${template_id}_template.xml
    ${template_exists}=    Run Keyword And Return Status    File Should Exist    ${template_xml_path}
    
    IF    not ${template_exists}
        Log    Template not found, fetching from API: ${template_id}    console=True
        ${template_data}=    Get Scan Template Details    ${template_id}
    END
    
    # Read and parse XML
    ${xml_content}=    Get File    ${template_xml_path}
    ${xml_root}=    Parse XML    ${xml_content}
    
    # Get matching benchmark IDs
    ${os_policies_data}=    Get Policies For OS    ${template_id}    ${os_name}
    
    # Filter by version if specified
    @{benchmark_ids_to_keep}=    Create List
    FOR    ${policy}    IN    @{os_policies_data}
        ${bench_id}=    Get From Dictionary    ${policy}    benchmark_id
        
        IF    '${version}' != '${EMPTY}'
            IF    '${policy}[version]' == '${version}'
                Append To List    ${benchmark_ids_to_keep}    ${bench_id}
            END
        ELSE
            Append To List    ${benchmark_ids_to_keep}    ${bench_id}
        END
    END
    
    # Validate that we found matching benchmarks
    ${benchmark_count}=    Get Length    ${benchmark_ids_to_keep}
    IF    ${benchmark_count} == 0
        IF    '${version}' != '${EMPTY}'
            Fail    No benchmarks found for OS "${os_name}" with version "${version}". Please check the OS name and version are correct.
        ELSE
            Fail    No benchmarks found for OS "${os_name}". Please check the OS name is correct.
        END
    END
    
    IF    '${version}' != '${EMPTY}'
        Log    Found ${benchmark_count} matching benchmark(s) for OS "${os_name}" version "${version}"    console=True
    ELSE
        Log    Found ${benchmark_count} matching benchmark(s) for OS "${os_name}"    console=True
    END
    
    # Get all PolicyBenchmark elements
    ${all_benchmarks}=    Get Elements    ${xml_root}    .//PolicyBenchmark
    
    # Remove non-matching benchmarks
    ${removed_count}=    Set Variable    ${0}
    @{benchmarks_to_remove}=    Create List
    FOR    ${benchmark}    IN    @{all_benchmarks}
        ${benchmark_id}=    Get Element Attribute    ${benchmark}    benchmarkID
        ${should_keep}=    Run Keyword And Return Status    
        ...    List Should Contain Value    ${benchmark_ids_to_keep}    ${benchmark_id}
        
        IF    not ${should_keep}
            Append To List    ${benchmarks_to_remove}    ${benchmark_id}
            ${removed_count}=    Evaluate    ${removed_count} + 1
        END
    END
    
    # Remove benchmarks by XPath
    FOR    ${bench_id}    IN    @{benchmarks_to_remove}
        ${xpath}=    Set Variable    .//PolicyBenchmark[@benchmarkID='${bench_id}']
        Remove Elements    ${xml_root}    ${xpath}
        Log    Removed PolicyBenchmark: ${bench_id}    console=True
    END
    
    # Filter policies within kept benchmarks if not 'all'
    ${policies_lower}=    Convert To Lower Case    ${policies}
    IF    '${policies_lower}' != 'all'
        Log    Filtering specific policies: ${policies}    console=True
        
        # Split policy IDs
        @{policy_list}=    Split String    ${policies}    ,
        @{policy_list}=    Evaluate    [p.strip() for p in $policy_list]
        
        # Get remaining benchmarks after OS/version filtering
        ${enabled_element}=    Get Element    ${xml_root}    .//Enabled
        ${kept_benchmarks}=    Get Elements    ${xml_root}    .//PolicyBenchmark
        
        # Track benchmark elements to remove
        @{benchmarks_to_remove}=    Create List
        
        FOR    ${benchmark}    IN    @{kept_benchmarks}
            ${benchmark_policies}=    Get Elements    ${benchmark}    Policy
            ${benchmark_id}=    Get Element Attribute    ${benchmark}    benchmarkID
            
            # Check if this specific PolicyBenchmark has any of the specified policies
            ${has_matching_policy}=    Set Variable    ${False}
            FOR    ${policy}    IN    @{benchmark_policies}
                ${policy_id}=    Get Element Attribute    ${policy}    policyID
                ${is_match}=    Run Keyword And Return Status    
                ...    List Should Contain Value    ${policy_list}    ${policy_id}
                
                IF    ${is_match}
                    ${has_matching_policy}=    Set Variable    ${True}
                    BREAK
                END
            END
            
            # If no matching policies in this PolicyBenchmark, mark for removal
            IF    not ${has_matching_policy}
                Append To List    ${benchmarks_to_remove}    ${benchmark}
                Log    Marking PolicyBenchmark for removal (no matching policies): ${benchmark_id}    console=True
            END
        END
        
        # Remove PolicyBenchmark elements that have no matching policies
        FOR    ${benchmark}    IN    @{benchmarks_to_remove}
            ${benchmark_id}=    Get Element Attribute    ${benchmark}    benchmarkID
            Evaluate    $enabled_element.remove($benchmark)
            Log    Removed PolicyBenchmark: ${benchmark_id}    console=True
        END
    END
    
    # Update template title if custom title provided
    IF    '${template_title}' != '${EMPTY}'
        ${title_elem}=    Get Element    ${xml_root}    .//templateDescription
        Set Element Attribute    ${title_elem}    title    ${template_title}
        Log    Updated template title to: ${template_title}    console=True
    END
    
    # Disable UDP port scan by setting mode to "none"
    ${udp_scan_elements}=    Get Elements    ${xml_root}    .//UDPPortScan
    ${udp_count}=    Get Length    ${udp_scan_elements}
    IF    ${udp_count} > 0
        FOR    ${udp_elem}    IN    @{udp_scan_elements}
            Set Element Attribute    ${udp_elem}    mode    none
            Log    Disabled UDP port scan (set mode=none)    console=True
        END
    END
    
    # Enable SCAN data (persistARFResults)
    ${persist_arf_elements}=    Get Elements    ${xml_root}    .//persistARFResults
    ${persist_arf_count}=    Get Length    ${persist_arf_elements}
    IF    ${persist_arf_count} > 0
        FOR    ${persist_elem}    IN    @{persist_arf_elements}
            Set Element Attribute    ${persist_elem}    enabled    1
            Log    Enabled SCAN data (persistARFResults enabled=1)    console=True
        END
    END
    
    # Enable enhanced logging (debugLogging)
    ${debug_log_elements}=    Get Elements    ${xml_root}    .//debugLogging
    ${debug_log_count}=    Get Length    ${debug_log_elements}
    IF    ${debug_log_count} > 0
        FOR    ${debug_elem}    IN    @{debug_log_elements}
            Set Element Attribute    ${debug_elem}    enabled    1
            Log    Enabled enhanced logging (debugLogging enabled=1)    console=True
        END
    END
    
    # Generate formatted XML string
    ${xml_string}=    Element To String    ${xml_root}
    ${temp_path}=    Set Variable    ${EXECDIR}/data/templates/temp_template.xml
    ${output_path}=    Set Variable    ${EXECDIR}/data/templates/formatted_template.xml
    Create File    ${temp_path}    ${xml_string}    encoding=UTF-8
    
    # Format XML with proper indentation using Python helper
    ${result}=    Run Process    python3    ${EXECDIR}/library/format_xml.py    ${temp_path}    ${output_path}
    ...    shell=False    stdout=${TEMPDIR}/format_out.txt    stderr=${TEMPDIR}/format_err.txt
    
    # Read formatted XML
    ${formatted_xml}=    Get File    ${output_path}    encoding=UTF-8
    
    # Clean up temp files
    Remove File    ${temp_path}
    Remove File    ${output_path}
    
    Log    Generated formatted template XML for OS: ${os_name}, Version: ${version}, Policies: ${policies}    console=True
    
    RETURN    ${formatted_xml}


Create Custom Template With Policy Filter
    [Documentation]    Create a customized template by filtering PolicyBenchmark entries
    ...    Arguments:
    ...    - template_id: Base template ID (e.g., 'cis')
    ...    - policy_ids: Either 'all' or comma-separated policy IDs (e.g., 'windows-profile-1,windows-profile-2')
    ...    - custom_template_name: Name for the custom template file (optional)
    ...    Example: Create Custom Template With Policy Filter    cis    windows-profile-1,windows-profile-2
    [Arguments]    ${template_id}    ${policy_ids}=all    ${custom_template_name}=${EMPTY}
    
    # Step 1: Get the original template
    ${template_details}=    Get Scan Template Details    ${template_id}
    
    # Step 2: Read the saved template XML
    ${template_path}=    Set Variable    ${EXECDIR}/testdata/${template_id}_template.xml
    ${xml_content}=    Get File    ${template_path}
    
    # Step 3: Parse XML
    ${xml_root}=    Parse XML    ${xml_content}
    
    # Step 4: Filter PolicyBenchmark entries if not 'all'
    ${policy_ids_lower}=    Convert To Lower Case    ${policy_ids}
    
    IF    '${policy_ids_lower}' != 'all'
        Log    Filtering PolicyBenchmark entries for specific policies: ${policy_ids}    console=True
        
        # Convert comma-separated policy IDs to list
        ${policy_list}=    Split String    ${policy_ids}    ,
        ${policy_list}=    Evaluate    [p.strip() for p in $policy_list]
        
        # Get all PolicyBenchmark elements
        ${all_benchmarks}=    Get Elements    ${xml_root}    .//PolicyBenchmark
        
        # Remove PolicyBenchmark elements that don't match our policy IDs
        FOR    ${benchmark}    IN    @{all_benchmarks}
            ${policies_in_benchmark}=    Get Elements    ${benchmark}    Policy
            ${keep_benchmark}=    Set Variable    ${FALSE}
            
            # Check if any Policy in this benchmark matches our policy list
            FOR    ${policy}    IN    @{policies_in_benchmark}
                ${policy_id}=    Get Element Attribute    ${policy}    policyID
                ${is_in_list}=    Evaluate    '${policy_id}' in $policy_list
                IF    ${is_in_list}
                    ${keep_benchmark}=    Set Variable    ${TRUE}
                    BREAK
                END
            END
            
            # Remove benchmark if it doesn't contain any matching policies
            IF    not ${keep_benchmark}
                Remove Element    ${xml_root}    ${benchmark}
                ${benchmark_id}=    Get Element Attribute    ${benchmark}    benchmarkID
                Log    Removed PolicyBenchmark: ${benchmark_id}    console=True
            END
        END
        
        Log    Filtered template to include only specified policies    console=True
    ELSE
        Log    Keeping all PolicyBenchmark entries (policy_ids=all)    console=True
    END
    
    # Step 5: Save the customized template
    ${timestamp}=    Evaluate    int(__import__('time').time())
    
    IF    '${custom_template_name}' == '${EMPTY}'
        ${custom_filename}=    Set Variable    ${template_id}_template_custom_${timestamp}.xml
    ELSE
        ${custom_filename}=    Set Variable    ${custom_template_name}.xml
    END
    
    ${custom_template_path}=    Set Variable    ${EXECDIR}/testdata/${custom_filename}
    ${custom_xml_content}=    Element To String    ${xml_root}    encoding=unicode
    Create File    ${custom_template_path}    ${custom_xml_content}
    
    Log    Created custom template: ${custom_template_path}    console=True
    Log    Custom template saved with ${policy_ids} policies    console=True
    
    RETURN    ${custom_template_path}


Create Scan Template
    [Documentation]    Create a new scan template via POST API
    ...    Arguments:
    ...    - template_xml: XML content of the template to create
    ...    - template_title: Optional template title to include in return value
    ...    
    ...    Returns: Dictionary with template_id and template_title
    ...    
    ...    Example: ${result}=    Create Scan Template    ${template_xml}    My Template Title
    [Arguments]    ${template_xml}    ${template_title}=${EMPTY}
    
    # Validate session - re-login if SESSION_ID is empty or expired
    ${session_valid}=    Run Keyword And Return Status    Should Not Be Equal    ${SESSION_ID}    ${EMPTY}
    IF    not ${session_valid}
        Log    Session expired or not initialized. Logging in again...    console=True
        Login To Console
    END
    
    # Create headers with session ID, Cookie, and XML content type (as per Postman collection)
    ${headers}=    Create Dictionary
    ...    Content-Type=text/xml; charset=UTF-8
    ...    nexposeCCSessionID=${SESSION_ID}
    ...    Cookie=nexposeCCSessionID=${SESSION_ID}
    
    Log    ========================================    console=True
    Log    CREATING NEW SCAN TEMPLATE (POST)    console=True
    Log    Request Headers: ${headers}    console=True
    Log    XML Payload Length: ${template_xml.__len__()}    console=True
    Log    ========================================    console=True
    
    # Send POST request to create the template
    ${response}=    POST
    ...    ${BASE_URL}/data/scan/templates
    ...    data=${template_xml}
    ...    headers=${headers}
    ...    verify=${False}
    ...    expected_status=any
    
    Log    ========================================    console=True
    Log    CREATE TEMPLATE RESPONSE    console=True
    Log    Status Code: ${response.status_code}    console=True
    Log    Response Headers: ${response.headers}    console=True
    Log    Response Body:    console=True
    Log    ${response.text}    console=True
    Log    ========================================    console=True
    
    # Check if creation was successful (201 Created or 200 OK)
    ${status_ok}=    Evaluate    ${response.status_code} in [200, 201]
    
    # If failed with 401/403 (session expired), retry once after re-login
    IF    not ${status_ok} and ${response.status_code} in [401, 403]
        Log    Session may have expired (${response.status_code}). Re-logging and retrying...    console=True
        Login To Console
        
        # Update headers with new session ID
        ${headers}=    Create Dictionary
        ...    Content-Type=text/xml; charset=UTF-8
        ...    nexposeCCSessionID=${SESSION_ID}
        ...    Cookie=nexposeCCSessionID=${SESSION_ID}
        
        # Retry POST request
        ${response}=    POST
        ...    ${BASE_URL}/data/scan/templates
        ...    data=${template_xml}
        ...    headers=${headers}
        ...    verify=${False}
        ...    expected_status=any
        
        Log    ========================================    console=True
        Log    RETRY RESPONSE    console=True
        Log    Status Code: ${response.status_code}    console=True
        Log    Response Body: ${response.text}    console=True
        Log    ========================================    console=True
        
        ${status_ok}=    Evaluate    ${response.status_code} in [200, 201]
    END
    
    Should Be True    ${status_ok}
    ...    msg=Failed to create template. Status: ${response.status_code}, Response: ${response.text}
    
    Log    ✓ Successfully created scan template    console=True
    
    # Parse response to extract template ID
    ${response_json}=    Evaluate    json.loads($response.text)    json
    ${template_id}=    Set Variable    ${response_json}[value]
    
    # Transform template title: replace spaces with underscores
    ${transformed_title}=    Replace String    ${template_title}    ${SPACE}    _
    
    # Create return dictionary with template ID and transformed title
    ${result}=    Create Dictionary
    ...    template_id=${template_id}
    ...    template_title=${transformed_title}
    ...    response=${response.text}
    
    RETURN    ${result}

Update Scan Template
    [Documentation]    Update an existing scan template with new XML content via PUT API
    ...    Arguments:
    ...    - template_name: Name of the template to update (e.g., 'cis-linux-red-hat-latest-new')
    ...    - template_xml: XML content of the template
    ...    
    ...    Example: Update Scan Template    cis-ubuntu-custom    ${template_xml}
    [Arguments]    ${template_name}    ${template_xml}
    
    # Create PUT request with XML content
    ${headers}=    Create Dictionary    
    ...    Content-Type=application/xml    
    ...    nexposeCCSessionID=${SESSION_ID}
    
    Log    ========================================    console=True
    Log    UPDATING SCAN TEMPLATE    console=True
    Log    Template Name: ${template_name}    console=True
    Log    Request Headers: ${headers}    console=True
    Log    XML Payload Length: ${template_xml.__len__()}    console=True
    Log    ========================================    console=True
    
    ${response}=    PUT    
    ...    ${BASE_URL}/data/scan/templates/${template_name}    
    ...    data=${template_xml}
    ...    headers=${headers}    
    ...    verify=${False}
    
    Log    ========================================    console=True
    Log    TEMPLATE UPDATE RESPONSE    console=True
    Log    Status Code: ${response.status_code}    console=True
    Log    Response Body: ${response.text}    console=True
    Log    ========================================    console=True
    
    Should Be Equal As Strings    ${response.status_code}    200    
    ...    msg=Failed to update template ${template_name}. Status: ${response.status_code}, Response: ${response.text}
    
    Log    Successfully updated template: ${template_name}    console=True
    
    RETURN    ${response.text}


Start Scan
    [Documentation]    Start an ad-hoc scan on a site
    ...    
    ...    Arguments:
    ...    - site_id: Site ID to scan
    ...    - engine_id: Optional engine ID (if not provided, uses site's default engine)
    ...    - scan_name: Optional custom name for the scan
    ...    - hosts: Optional list of specific hosts to scan (if not provided, scans all site assets)
    ...    
    ...    Returns: Dictionary with scan_id and scan details
    [Arguments]    ${site_id}    ${engine_id}=${EMPTY}    ${scan_name}=${EMPTY}    ${hosts}=${EMPTY}
    
    # Validate session
    ${session_valid}=    Run Keyword And Return Status    Should Not Be Equal    ${SESSION_ID}    ${EMPTY}
    
    IF    not ${session_valid}
        Login To Console
    END
    
    # Build scan request body
    ${scan_body}=    Create Dictionary
    
    IF    '${engine_id}' != '${EMPTY}'
        Set To Dictionary    ${scan_body}    engineId=${engine_id}
    END
    
    IF    '${scan_name}' != '${EMPTY}'
        Set To Dictionary    ${scan_body}    name=${scan_name}
    END
    
    IF    '${hosts}' != '${EMPTY}'
        Set To Dictionary    ${scan_body}    hosts=${hosts}
    END
    
    ${json_body}=    Evaluate    json.dumps($scan_body)    json
    
    # Prepare headers
    ${headers}=    Create Dictionary
    ...    nexposeCCSessionID=${SESSION_ID}
    ...    Cookie=nexposeCCSessionID=${SESSION_ID}
    ...    Content-Type=application/json
    
    Log    ========================================    console=True
    Log    STARTING SCAN FOR SITE: ${site_id}    console=True
    Log    Request Body: ${json_body}    console=True
    Log    ========================================    console=True
    
    # Send POST request to start scan
    ${response}=    POST
    ...    ${BASE_URL}/api/3/sites/${site_id}/scans
    ...    data=${json_body}
    ...    headers=${headers}    
    ...    verify=${False}
    
    Log    ========================================    console=True
    Log    START SCAN RESPONSE    console=True
    Log    Status Code: ${response.status_code}    console=True
    Log    Response Body: ${response.text}    console=True
    Log    ========================================    console=True
    
    Should Be Equal As Strings    ${response.status_code}    201    
    ...    msg=Failed to start scan for site ${site_id}. Status: ${response.status_code}, Response: ${response.text}
    
    # Parse response to extract scan ID
    ${response_json}=    Evaluate    json.loads($response.text)    json
    ${scan_id}=    Set Variable    ${response_json}[id]
    
    Log    ✓ Scan started successfully - Scan ID: ${scan_id}    console=True
    
    # Create return dictionary with scan details
    ${result}=    Create Dictionary
    ...    scan_id=${scan_id}
    ...    response=${response.text}
    
    RETURN    ${result}


Get Policy Surrogate Identifier
    [Documentation]    Get policy surrogate identifier for a specific policy
    ...    Takes a formatted policy string (benchmark_id:version:policy_id) and retrieves surrogate ID
    ...    Example: Get Policy Surrogate Identifier    xccdf_org.cisecurity.benchmarks_benchmark_CIS_RHEL_9:1.0.0:xccdf_org.cisecurity.benchmarks_profile_Level_1
    [Arguments]    ${policy_id_formatted}
    
    # Create GET request with session authentication
    ${headers}=    Create Dictionary    
    ...    Content-Type=application/json    
    ...    nexposeCCSessionID=${SESSION_ID}
    
    # URL encode the policy ID - import urllib.parse module explicitly
    ${encoded_policy_id}=    Evaluate    __import__('urllib.parse', fromlist=['quote']).quote(r'''${policy_id_formatted}''')
    
    # Build endpoint with query parameter
    ${params}=    Create Dictionary    id=${policy_id_formatted}
    
    Log    Getting surrogate identifier for policy: ${policy_id_formatted}    console=True
    
    # Use auto-reauth wrapper for API call
    ${response}=    login.API Call With Auto Reauth    
    ...    GET    
    ...    ${GLOBAL_NEXPOSE_DATA_POLICY_SURROGATE}    
    ...    headers=${headers}
    ...    params=${params}
    
    # Check if response is successful
    IF    ${response.status_code} != 200
        Log    Failed to get policy surrogate ID. Status: ${response.status_code}    console=True
        Log    Error Response: ${response.text}    console=True
        Fail    Failed to get policy surrogate identifier with status ${response.status_code}: ${response.text}
    END
    
    # Parse JSON response
    ${response_json}=    Set Variable    ${response.json()}
    
    # Extract the natural ID (surrogate identifier) from response
    # The response is typically just a number representing the policy's natural/surrogate ID
    ${natural_id}=    Set Variable    ${response_json}
    
    # Log the natural ID
    Log    Policy Natural ID (Surrogate): ${natural_id}    console=True
    
    # Return dictionary with both the formatted policy and its natural ID
    ${result}=    Create Dictionary
    ...    policy_id=${policy_id_formatted}
    ...    natural_id=${natural_id}
    ...    raw_response=${response_json}
    
    RETURN    ${result}


Generate XCCDF Report For Policy
    [Documentation]    Generate XCCDF report for a specific policy and site
    ...    Creates a policy compliance report and triggers immediate generation
    ...    Example: Generate XCCDF Report For Policy    site_id=9    policy_natural_id=190    report_name=My Policy Report
    [Arguments]    ${site_id}    ${policy_natural_id}    ${report_name}
    
    # Create XML request body for report generation
    ${report_xml}=    Set Variable    <?xml version="1.0" encoding="UTF-8"?>
    ...    <ReportSaveRequest session-id="${SESSION_ID}" generate-now="1">
    ...      <ReportConfig id="-1" format="xccdf-xml" name="${report_name}">
    ...        <Filters>
    ...          <filter type="site" id="${site_id}">${site_id}</filter>
    ...          <filter type="policy-listing" id="${policy_natural_id}">${policy_natural_id}</filter>
    ...        </Filters>
    ...        <Generate after-scan="0" schedule="0"/>
    ...        <Delivery>
    ...          <Storage storeOnServer="1"/>
    ...        </Delivery>
    ...      </ReportConfig>
    ...    </ReportSaveRequest>
    
    # Create headers with session ID
    ${headers}=    Create Dictionary    
    ...    Content-Type=text/xml; charset=UTF-8    
    ...    nexposeCCSessionID=${SESSION_ID}
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
    ${root}=    Parse XML    ${response.text}
    ${success}=    Get Element Attribute    ${root}    success
    
    Log    ========================================    console=True
    Log    📊 PARSED RESPONSE DETAILS    console=True
    Log    ========================================    console=True
    Log    API Success Flag: ${success}    console=True
    
    IF    '${success}' != '1'
        Log    ❌ Report generation failed. API returned success=${success}    console=True
        Fail    Report generation failed. API returned success=${success}
    END
    
    # Extract report ID from ReportConfig element
    ${report_config}=    Get Element    ${root}    ReportConfig
    ${report_id}=    Get Element Attribute    ${report_config}    id
    ${report_format}=    Get Element Attribute    ${report_config}    format
    ${report_name_response}=    Get Element Attribute    ${report_config}    name
    
    Log    ========================================    console=True
    Log    ✅ REPORT CREATION SUCCESS    console=True
    Log    ========================================    console=True
    Log    Report ID: ${report_id}    console=True
    Log    Report Format: ${report_format}    console=True
    Log    Report Name: ${report_name_response}    console=True
    Log    Site ID: ${site_id}    console=True
    Log    Policy Natural ID: ${policy_natural_id}    console=True
    Log    ========================================    console=True
    
    # Return dictionary with report details
    ${result}=    Create Dictionary
    ...    report_id=${report_id}
    ...    report_format=${report_format}
    ...    site_id=${site_id}
    ...    policy_natural_id=${policy_natural_id}
    ...    report_name=${report_name}
    ...    raw_response=${response.text}
    
    RETURN    ${result}

