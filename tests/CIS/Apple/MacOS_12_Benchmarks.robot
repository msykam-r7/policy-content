*** Settings ***
Documentation     Mac OS 12 CIS Benchmark Compliance Testing
...               
...               Validates Mac OS 12 (Monterey) against CIS security benchmarks.

# Global Framework Imports
Resource          ${CURDIR}/../../../common/global_imports.robot

# Suite and Test Lifecycle
Suite Setup       Global Suite Setup
Suite Teardown    Global Suite Teardown
Test Setup        Global Test Setup
Test Teardown     Global Test Teardown

# Suite-level tags
Force Tags        macos    apple    cis    benchmark    compliance


*** Test Cases ***
MacOS 12 -CIS Benchmarks
    [Documentation]    Validates Mac OS 12 against CIS Level 1 benchmark
    [Tags]    macos    macos12    apple    cis    benchmark    level1    compliance    e2e
    
    # Generate unique identifiers for this test run
    ${timestamp}=    Evaluate    int(__import__('time').time())
    ${site_name}=    Set Variable    MacOS12_CIS_Level1_${timestamp}
    ${template_name}=    Set Variable    macos12_cis_template_${timestamp}
    
    # Execute Mac OS 12 CIS Level 1 compliance test
    ${results}=    Run Complete E2E Benchmark Test
    ...    os_identifier=CIS_Macos_12
    ...    vm_cred_types=compliance,server
    ...    os_benchmark_identifier=CIS_Apple_macOS_12.0_Monterey_Benchmark
    ...    version=4.0.0
    ...    scan_template=cis
    ...    server_service=cifs
    ...    scope=S
    ...    site_name=${site_name}
    ...    template_name=${template_name}
    ...    policy_list=all
    ...    csv_file=${EMPTY}
    ...    skip_cleanup=${TRUE}