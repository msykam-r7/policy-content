*** Settings ***
Documentation     Windows 10 DISA STIG Compliance Testing
...               
...               Validates Windows 10 against DISA STIG security baseline.

# Global Framework Imports
Resource          ${CURDIR}/../../common/global_imports.robot

# Suite and Test Lifecycle
Suite Setup       Global Suite Setup
Suite Teardown    Global Suite Teardown
Test Setup        Global Test Setup
Test Teardown     Global Test Teardown

# Suite-level tags
Force Tags        windows    disa    stig    benchmark    compliance


*** Test Cases ***
Windows 10 - DISA STIG Compliance Test
    [Documentation]    Validates Windows 10 against DISA STIG baseline
    [Tags]    windows    windows10    disa    stig    benchmark    compliance    e2e
    
    # Generate unique identifiers for this test run
    ${timestamp}=    Evaluate    int(__import__('time').time())
    ${site_name}=    Set Variable    Windows10_DISA_STIG_${timestamp}
    ${template_name}=    Set Variable    windows10_disa_template_${timestamp}
    
    # Execute Windows 10 DISA STIG compliance test
    ${results}=    Run Complete E2E Benchmark Test
    ...    os_identifier=CIS_Microsoft_Windows-10
    ...    vm_cred_types=compliance,server
    ...    os_benchmark_identifier=MS_Windows_10_STIG
    ...    version=3
    ...    scan_template=disa
    ...    server_service=ssh
    ...    scope=S
    ...    site_name=${site_name}
    ...    template_name=${template_name}
    ...    policy_list=all
    ...    csv_file=${EXECDIR}/testdata/validation_rules/DISA/Windows10/stig_baseline.csv


