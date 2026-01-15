*** Settings ***
Documentation     Parallel Execution Utilities
...               
...               This resource provides utilities for safe parallel test execution:
...               - Process-safe unique name generation (timestamp + PID + random)
...               - Test-isolated working directories
...               - Session management helpers
...               
...               USAGE:
...               Import this resource in your test files and use Generate Unique Name
...               keyword for all resources (sites, templates, reports) that need unique names.

Library           OperatingSystem
Library           DateTime
Resource          login.robot


*** Variables ***
${TEST_SESSION_ID}    ${EMPTY}    # Test-scoped session ID (set in test setup)


*** Keywords ***
Generate Unique Name
    [Documentation]    Generate a globally unique name for parallel execution safety
    ...    
    ...    Combines:
    ...    - Unix timestamp (seconds precision)
    ...    - Process ID (ensures uniqueness across parallel processes)
    ...    - Random 4-digit number (prevents same-second collisions)
    ...    
    ...    Arguments:
    ...    - prefix: Name prefix (e.g., "windows2019_cis_template", "CIS_Site")
    ...    
    ...    Returns: Unique name string
    ...    
    ...    Example: ${name}=    Generate Unique Name    windows2019_cis_template
    ...    Result:  windows2019_cis_template_1703345678_12345_7843
    [Arguments]    ${prefix}
    
    ${timestamp}=    Evaluate    int(__import__('time').time())
    ${pid}=    Evaluate    __import__('os').getpid()
    ${random}=    Evaluate    __import__('random').randint(1000, 9999)
    
    ${unique_name}=    Set Variable    ${prefix}_${timestamp}_${pid}_${random}
    
    Log    Generated unique name: ${unique_name}    console=True
    
    RETURN    ${unique_name}


Generate Short Unique ID
    [Documentation]    Generate a shorter unique ID using timestamp + random
    ...    
    ...    Useful for suffixes where full PID makes names too long.
    ...    
    ...    Returns: Unique ID string (e.g., "1703345678_7843")
    
    ${timestamp}=    Evaluate    int(__import__('time').time())
    ${random}=    Evaluate    __import__('random').randint(1000, 9999)
    
    ${unique_id}=    Set Variable    ${timestamp}_${random}
    
    RETURN    ${unique_id}


Create Test Working Directory
    [Documentation]    Create an isolated working directory for this test execution
    ...    
    ...    Creates: ${EXECDIR}/results/test_${timestamp}_${pid}
    ...    
    ...    This directory can be used for:
    ...    - Temporary template files
    ...    - Policy JSON files
    ...    - Test-specific data
    ...    
    ...    Returns: Absolute path to created directory
    
    ${test_id}=    Generate Short Unique ID
    ${test_dir}=    Set Variable    ${EXECDIR}/results/test_${test_id}
    
    Create Directory    ${test_dir}
    Create Directory    ${test_dir}/templates
    Create Directory    ${test_dir}/policies
    Create Directory    ${test_dir}/reports
    
    Log    Created test working directory: ${test_dir}    console=True
    
    RETURN    ${test_dir}


Get Test Session ID
    [Documentation]    Get the current test's session ID
    ...    
    ...    This keyword retrieves the session ID from test scope.
    ...    If not found, it will fail with a clear error message.
    ...    
    ...    Returns: Session ID string
    
    ${session_exists}=    Run Keyword And Return Status    Variable Should Exist    ${TEST_SESSION_ID}
    
    IF    not ${session_exists}
        Fail    TEST_SESSION_ID not found. Did you call 'Initialize Test Session' in test setup?
    END
    
    RETURN    ${TEST_SESSION_ID}


Initialize Test Session
    [Documentation]    Initialize a test-scoped session (call in Test Setup)
    ...    
    ...    This keyword should be called in [Setup] of each test case.
    ...    It creates a new login session and stores it in test scope.
    ...    
    ...    Example:
    ...    [Setup]    Initialize Test Session
    
    # Login using the login resource
    ${session_id}=    Login To Console
    
    Set Test Variable    ${TEST_SESSION_ID}    ${session_id}
    
    ${pid}=    Evaluate    __import__('os').getpid()
    
    Log    ========================================    console=True
    Log    TEST SESSION INITIALIZED    console=True
    Log    Session ID: ${TEST_SESSION_ID}    console=True
    Log    Process ID: ${pid}    console=True
    Log    ========================================    console=True
    
    RETURN    ${session_id}


Cleanup Test Session
    [Documentation]    Cleanup test-scoped session (call in Test Teardown)
    ...    
    ...    This keyword should be called in [Teardown] of each test case.
    ...    It performs session cleanup if needed.
    ...    
    ...    Arguments:
    ...    - site_id: Site ID to cleanup (optional)
    ...    - template_id: Template ID to cleanup (optional)
    
    [Arguments]    ${site_id}=${EMPTY}    ${template_id}=${EMPTY}
    
    Log    ========================================    console=True
    Log    CLEANING UP TEST SESSION    console=True
    Log    Session ID: ${TEST_SESSION_ID}    console=True
    
    IF    '${site_id}' != '${EMPTY}'
        Log    Cleaning up Site ID: ${site_id}    console=True
    END
    
    IF    '${template_id}' != '${EMPTY}'
        Log    Cleaning up Template ID: ${template_id}    console=True
    END
    
    Log    ========================================    console=True


Generate Unique Site Name
    [Documentation]    Generate unique site name for parallel execution
    ...    
    ...    Arguments:
    ...    - os_name: OS name (e.g., "RHEL9", "Windows2019")
    ...    - benchmark: Benchmark type (e.g., "CIS", "DISA")
    ...    - level: Level (e.g., "Level1", "Level2")
    ...    
    ...    Returns: Unique site name
    [Arguments]    ${os_name}    ${benchmark}    ${level}
    
    ${prefix}=    Set Variable    ${os_name}_${benchmark}_${level}
    ${site_name}=    Generate Unique Name    ${prefix}
    
    RETURN    ${site_name}


Generate Unique Template Name
    [Documentation]    Generate unique template name for parallel execution
    ...    
    ...    Arguments:
    ...    - os_name: OS name (e.g., "rhel9", "windows2019")
    ...    - benchmark: Benchmark type (e.g., "cis", "disa")
    ...    
    ...    Returns: Unique template name
    [Arguments]    ${os_name}    ${benchmark}
    
    ${prefix}=    Set Variable    ${os_name}_${benchmark}_template
    ${template_name}=    Generate Unique Name    ${prefix}
    
    RETURN    ${template_name}


Generate Unique Report Name
    [Documentation]    Generate unique report name for parallel execution
    ...    
    ...    Arguments:
    ...    - policy_name: Policy name (e.g., "Level_1", "Member_Server")
    ...    
    ...    Returns: Unique report name
    [Arguments]    ${policy_name}
    
    ${prefix}=    Set Variable    XCCDF_Report_${policy_name}
    ${report_name}=    Generate Unique Name    ${prefix}
    
    RETURN    ${report_name}
