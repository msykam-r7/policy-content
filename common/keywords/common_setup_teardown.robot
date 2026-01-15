*** Settings ***
Documentation     Common setup and teardown keywords for test lifecycle management
...               Handles resource cleanup (sites, templates) for CI/CD environments
...               Includes orphaned resource cleanup for failed/killed previous runs

Library           DateTime
Library           OperatingSystem
Library           Collections
Library           String

*** Keywords ***
Global Suite Setup
    [Documentation]    Common setup executed at the beginning of each test suite
    ...                Includes cleanup of orphaned resources from previous failed runs
    
    # Cleanup orphaned resources from previous failed/killed runs
    Cleanup Orphaned Resources
    
    # Create results directories if needed
    Create Results Directory Structure
    
    # Validate environment prerequisites
    Validate Environment Prerequisites
    
    # Load test data
    Initialize Test Data
    
    Log    Suite setup completed for ${SUITE_NAME}    INFO

Global Suite Teardown
    [Documentation]    Common teardown executed at the end of each test suite
    
    # Cleanup test resources if required
    Run Keyword If    ${CLEANUP_REQUIRED}    Cleanup Test Resources
    
    Log    Suite teardown completed for ${SUITE_NAME}    INFO

Global Test Setup
    [Documentation]    Common setup executed before each test case
    
    Log    Test setup started: ${TEST_NAME}    INFO

Global Test Teardown
    [Documentation]    Common teardown executed after each test case
    ...                Cleans up site and scan template created during test
    ...                regardless of test pass/fail status
    ...                
    ...                PARALLEL TESTING NOTE:
    ...                Uses Test Variables (${TEST_SITE_ID}, ${TEST_TEMPLATE_ID}) for parallel safety
    ...                Falls back to Global Variables for backward compatibility
    
    Log    Test teardown started: ${TEST_NAME} (Status: ${TEST_STATUS})    INFO
    
    # ALWAYS cleanup site and scan template (pass or fail)
    # This ensures resources are cleaned up even if test fails
    Cleanup Site And Template Resources
    
    Log    Test teardown completed: ${TEST_NAME}    INFO

Cleanup Site And Template Resources
    [Documentation]    Deletes the scan template and site created during test execution
    ...                Template is deleted FIRST, then Site (correct order)
    ...                This runs regardless of test pass/fail status
    ...                
    ...                PARALLEL SAFE: Checks both Test Variables (preferred) and Global Variables (fallback)
    
    # Get Template ID - Check Test Variable first (parallel safe), then Global Variable (fallback)
    ${template_id}=    Get Resource ID For Cleanup    SCAN_TEMPLATE_ID    TEST_TEMPLATE_ID
    
    # Get Site ID - Check Test Variable first (parallel safe), then Global Variable (fallback)
    ${site_id}=    Get Resource ID For Cleanup    SITE_ID    TEST_SITE_ID
    
    # Delete Scan Template FIRST (before site)
    Run Keyword If    '${template_id}' != '${EMPTY}'    Delete Template Resource    ${template_id}
    
    # Delete Site SECOND (after template)
    Run Keyword If    '${site_id}' != '${EMPTY}'    Delete Site Resource    ${site_id}
    
    # Clear variables after cleanup (both test and global for safety)
    Clear Cleanup Variables

Get Resource ID For Cleanup
    [Documentation]    Gets resource ID checking Test Variable first, then Global Variable
    ...                This ensures parallel safety while maintaining backward compatibility
    [Arguments]        ${global_var_name}    ${test_var_name}
    
    # First check Test Variable (parallel safe)
    ${test_var_exists}=    Run Keyword And Return Status    Variable Should Exist    ${${test_var_name}}
    IF    ${test_var_exists}
        ${test_var_value}=    Get Variable Value    ${${test_var_name}}    ${EMPTY}
        IF    '${test_var_value}' != '${EMPTY}'
            RETURN    ${test_var_value}
        END
    END
    
    # Fallback to Global Variable (backward compatibility)
    ${global_var_exists}=    Run Keyword And Return Status    Variable Should Exist    ${${global_var_name}}
    IF    ${global_var_exists}
        ${global_var_value}=    Get Variable Value    ${${global_var_name}}    ${EMPTY}
        IF    '${global_var_value}' != '${EMPTY}'
            RETURN    ${global_var_value}
        END
    END
    
    RETURN    ${EMPTY}

Clear Cleanup Variables
    [Documentation]    Clears both Test and Global cleanup variables
    
    # Clear Test Variables (if they exist)
    ${test_site_exists}=    Run Keyword And Return Status    Variable Should Exist    ${TEST_SITE_ID}
    Run Keyword If    ${test_site_exists}    Set Test Variable    ${TEST_SITE_ID}    ${EMPTY}
    
    ${test_template_exists}=    Run Keyword And Return Status    Variable Should Exist    ${TEST_TEMPLATE_ID}
    Run Keyword If    ${test_template_exists}    Set Test Variable    ${TEST_TEMPLATE_ID}    ${EMPTY}
    
    # Clear Global Variables (if they exist)
    ${global_site_exists}=    Run Keyword And Return Status    Variable Should Exist    ${SITE_ID}
    Run Keyword If    ${global_site_exists}    Set Global Variable    ${SITE_ID}    ${EMPTY}
    
    ${global_template_exists}=    Run Keyword And Return Status    Variable Should Exist    ${SCAN_TEMPLATE_ID}
    Run Keyword If    ${global_template_exists}    Set Global Variable    ${SCAN_TEMPLATE_ID}    ${EMPTY}

Delete Site Resource
    [Documentation]    Safely deletes a site from Nexpose
    [Arguments]        ${site_id}
    
    TRY
        ${session_exists}=    Run Keyword And Return Status    Variable Should Exist    ${SESSION_ID}
        
        IF    ${session_exists}
            ${response}=    DELETE On Session    nexpose    /api/3/sites/${site_id}    expected_status=any
            Log    Site ${site_id} deleted (status: ${response.status_code})    INFO
        ELSE
            Reestablish Session For Cleanup
            ${response}=    DELETE On Session    nexpose    /api/3/sites/${site_id}    expected_status=any
            Log    Site ${site_id} deleted after session reconnect    INFO
        END
    EXCEPT    AS    ${error}
        Log    Failed to delete site ${site_id}: ${error}    WARN
    END

Delete Template Resource
    [Documentation]    Safely deletes a scan template from Nexpose
    [Arguments]        ${template_id}
    
    TRY
        ${session_exists}=    Run Keyword And Return Status    Variable Should Exist    ${SESSION_ID}
        
        IF    ${session_exists}
            ${response}=    DELETE On Session    nexpose    /api/3/scan_templates/${template_id}    expected_status=any
            Log    Scan Template ${template_id} deleted (status: ${response.status_code})    INFO
        ELSE
            Reestablish Session For Cleanup
            ${response}=    DELETE On Session    nexpose    /api/3/scan_templates/${template_id}    expected_status=any
            Log    Scan Template ${template_id} deleted after session reconnect    INFO
        END
    EXCEPT    AS    ${error}
        Log    Failed to delete scan template ${template_id}: ${error}    WARN
    END

Reestablish Session For Cleanup
    [Documentation]    Re-establishes API session for cleanup operations
    
    TRY
        Create Session    nexpose    ${NEXPOSE_URL}    
        ...    auth=${NEXPOSE_AUTH}    
        ...    verify=${False}    
        ...    disable_warnings=1
        Log    Session re-established for cleanup    INFO
    EXCEPT    AS    ${error}
        Log    Failed to re-establish session: ${error}    WARN
    END

Create Results Directory Structure
    [Documentation]    Creates standardized directory structure for test results
    
    Create Directory    ${RESULTS_DIR}
    Create Directory    ${REPORTS_DIR}
    Create Directory    ${LOGS_DIR}
    Create Directory    ${SCREENSHOTS_DIR}
    Create Directory    ${RESULTS_DIR}/artifacts
    Create Directory    ${RESULTS_DIR}/data

Validate Environment Prerequisites
    [Documentation]    Validates that all environment prerequisites are met
    
    # Validate required directories exist (use OperatingSystem explicitly to avoid SSHLibrary conflict)
    OperatingSystem.Directory Should Exist    ${CIS_POLICY_DIR}
    OperatingSystem.Directory Should Exist    ${PAYLOADS_DIR}
    OperatingSystem.File Should Exist         ${VM_CONFIG_FILE}
    
    # Validate network connectivity (if not in dry run mode)
    Run Keyword If    not ${DRY_RUN}    Validate Network Connectivity

Validate Network Connectivity
    [Documentation]    Validates network connectivity to required services
    
    Log    Validating network connectivity to ${NEXPOSE_HOST}:${NEXPOSE_PORT}    INFO

Initialize Test Data
    [Documentation]    Initializes common test data and variables
    
    ${vm_config}=     Get File    ${VM_CONFIG_FILE}
    Set Global Variable    ${VM_CONFIG_DATA}    ${vm_config}

Cleanup Test Resources
    [Documentation]    Cleans up resources created during test suite execution
    
    Run Keyword If    ${AUTO_DELETE_RESOURCES}    Log    Temporary resources cleanup completed    INFO

# ============================================================================
# ORPHANED RESOURCE CLEANUP
# Handles resources left behind from failed/killed previous test runs
# ============================================================================

Cleanup Orphaned Resources
    [Documentation]    Cleans up orphaned sites and templates from previous failed runs
    ...                Searches for resources matching test naming patterns and deletes them
    ...                This runs at suite start to ensure clean state
    
    Log    Checking for orphaned resources from previous runs...    INFO
    
    TRY
        # Establish session for cleanup
        Establish Cleanup Session
        
        # IMPORTANT: Delete templates FIRST, then sites
        # Templates may be associated with sites, so delete templates before sites
        
        # Clean up orphaned scan templates FIRST (matching test naming patterns)
        Cleanup Orphaned Templates
        
        # Clean up orphaned sites SECOND (after templates are deleted)
        Cleanup Orphaned Sites
        
        Log    Orphaned resource cleanup completed    INFO
    EXCEPT    AS    ${error}
        Log    Orphaned resource cleanup skipped: ${error}    WARN
    END

Establish Cleanup Session
    [Documentation]    Creates API session for cleanup operations
    
    ${session_exists}=    Run Keyword And Return Status    Variable Should Exist    ${SESSION_ID}
    Return From Keyword If    ${session_exists}
    
    TRY
        Create Session    nexpose_cleanup    ${NEXPOSE_URL}
        ...    auth=${NEXPOSE_AUTH}
        ...    verify=${False}
        ...    disable_warnings=1
        Set Suite Variable    ${CLEANUP_SESSION}    nexpose_cleanup
        Log    Cleanup session established    INFO
    EXCEPT    AS    ${error}
        Log    Could not establish cleanup session: ${error}    WARN
        Fail    Cannot perform cleanup without session
    END

Cleanup Orphaned Sites
    [Documentation]    Finds and deletes sites matching test naming patterns
    ...                Patterns: *_CIS_*, *_benchmark_*, *_test_*
    
    TRY
        ${session}=    Get Variable Value    ${SESSION_ID}    nexpose_cleanup
        ${response}=    GET On Session    nexpose    /api/3/sites    expected_status=any
        
        Return From Keyword If    ${response.status_code} != 200
        
        ${sites}=    Set Variable    ${response.json()}
        ${resources}=    Get From Dictionary    ${sites}    resources    default=@{EMPTY}
        
        FOR    ${site}    IN    @{resources}
            ${site_name}=    Get From Dictionary    ${site}    name    default=
            ${site_id}=    Get From Dictionary    ${site}    id    default=0
            
            # Check if site matches test naming patterns (orphaned test resources)
            ${is_orphaned}=    Is Orphaned Test Resource    ${site_name}
            
            IF    ${is_orphaned}
                Log    Found orphaned site: ${site_name} (ID: ${site_id})    WARN
                Delete Site Resource    ${site_id}
            END
        END
    EXCEPT    AS    ${error}
        Log    Could not cleanup orphaned sites: ${error}    WARN
    END

Cleanup Orphaned Templates
    [Documentation]    Finds and deletes scan templates matching test naming patterns
    ...                Patterns: *_cis_template_*, *_benchmark_template_*, *_test_template_*
    
    TRY
        ${session}=    Get Variable Value    ${SESSION_ID}    nexpose_cleanup
        ${response}=    GET On Session    nexpose    /api/3/scan_templates    expected_status=any
        
        Return From Keyword If    ${response.status_code} != 200
        
        ${templates}=    Set Variable    ${response.json()}
        ${resources}=    Get From Dictionary    ${templates}    resources    default=@{EMPTY}
        
        FOR    ${template}    IN    @{resources}
            ${template_id}=    Get From Dictionary    ${template}    id    default=
            ${template_name}=    Get From Dictionary    ${template}    name    default=${template_id}
            
            # Check if template matches test naming patterns (orphaned test resources)
            ${is_orphaned}=    Is Orphaned Test Template    ${template_id}
            
            IF    ${is_orphaned}
                Log    Found orphaned template: ${template_name} (ID: ${template_id})    WARN
                Delete Template Resource    ${template_id}
            END
        END
    EXCEPT    AS    ${error}
        Log    Could not cleanup orphaned templates: ${error}    WARN
    END

Is Orphaned Test Resource
    [Documentation]    Checks if a resource name matches test naming patterns
    ...                Returns True if it's likely an orphaned test resource
    [Arguments]        ${resource_name}
    
    # Patterns that indicate test-created resources
    @{patterns}=    Create List
    ...    _CIS_Level
    ...    _CIS_Benchmark
    ...    _benchmark_
    ...    _test_site_
    ...    Ubuntu2204_CIS_
    ...    RHEL_CIS_
    ...    Windows_CIS_
    ...    MacOS_CIS_
    
    FOR    ${pattern}    IN    @{patterns}
        ${matches}=    Run Keyword And Return Status    Should Contain    ${resource_name}    ${pattern}
        Return From Keyword If    ${matches}    ${TRUE}
    END
    
    RETURN    ${FALSE}

Is Orphaned Test Template
    [Documentation]    Checks if a template ID matches test naming patterns
    ...                Returns True if it's likely an orphaned test template
    [Arguments]        ${template_id}
    
    # Patterns that indicate test-created templates
    @{patterns}=    Create List
    ...    _cis_template_
    ...    _benchmark_template_
    ...    _test_template_
    ...    ubuntu2204_cis_
    ...    rhel_cis_
    ...    windows_cis_
    ...    macos_cis_
    
    ${template_id_lower}=    Convert To Lower Case    ${template_id}
    
    FOR    ${pattern}    IN    @{patterns}
        ${matches}=    Run Keyword And Return Status    Should Contain    ${template_id_lower}    ${pattern}
        Return From Keyword If    ${matches}    ${TRUE}
    END
    
    RETURN    ${FALSE}