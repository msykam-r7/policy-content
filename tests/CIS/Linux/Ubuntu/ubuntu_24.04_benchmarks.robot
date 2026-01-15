*** Settings ***
Documentation     Ubuntu 24.04 CIS Benchmark Compliance Testing
...               
...               Validates Ubuntu 24.04 LTS against CIS security benchmarks.

# Global Framework Imports
Resource          ${CURDIR}/../../../../common/global_imports.robot

# Suite and Test Lifecycle
Suite Setup       Global Suite Setup
Suite Teardown    Global Suite Teardown
Test Setup        Global Test Setup
Test Teardown     Global Test Teardown

# Suite-level tags
Force Tags        ubuntu    linux    cis    benchmark    compliance


*** Test Cases ***
Ubuntu 24.04 -CIS Benchmarks
    [Documentation]    Validates Ubuntu 24.04 against CIS Level 1 benchmark
    [Tags]    ubuntu    ubuntu2404    linux    cis    benchmark    level1    compliance    e2e
    
    # Generate unique identifiers for this test run
    ${timestamp}=    Evaluate    int(__import__('time').time())
    ${site_name}=    Set Variable    Ubuntu2404_CIS_Level1_${timestamp}
    ${template_name}=    Set Variable    ubuntu2404_cis_template_${timestamp}
    
    # Execute Ubuntu 24.04 CIS Level 1 compliance test
    ${results}=    Run Complete E2E Benchmark Test
    ...    os_identifier=CIS_Ubuntu_Ubuntu-24-04
    ...    vm_cred_types=compliance,server
    ...    os_benchmark_identifier=Ubuntu_Linux_24.04_LTS_STIG_Benchmark
    ...    version=1.0.0
    ...    scan_template=cis
    ...    server_service=ssh
    ...    scope=S
    ...    site_name=${site_name}
    ...    template_name=${template_name}
    ...    policy_list=all
    ...    csv_file=${EXECDIR}/testdata/validation_rules/CIS/Ubuntu/ubuntu_stig/ubuntu20.04_rules.csv
    ...    skip_cleanup=${TRUE}