*** Settings ***
Documentation     Amazon Linux 2 CIS Benchmark Compliance Testing
...               
...               Validates Amazon Linux 2 against CIS security benchmarks.

# Global Framework Imports
Resource          ${CURDIR}/../../../../common/global_imports.robot

# Suite and Test Lifecycle
Suite Setup       Global Suite Setup
Suite Teardown    Global Suite Teardown
Test Setup        Global Test Setup
Test Teardown     Global Test Teardown

# Suite-level tags
Force Tags        amazonlinux    linux    cis    benchmark    compliance


*** Test Cases ***
Amazon Linux 2 -CIS Benchmarks
    [Documentation]    Validates Amazon Linux 2 against CIS Level 1 benchmark
    [Tags]    amazonlinux    amazonlinux2    linux    cis    benchmark    level1    compliance    e2e
    
    # Generate unique identifiers for this test run
    ${timestamp}=    Evaluate    int(__import__('time').time())
    ${site_name}=    Set Variable    amazonlinux2_CIS_Level1_${timestamp}
    ${template_name}=    Set Variable    amazonlinux2_cis_template_${timestamp}
    
    # Execute Amazon Linux 2 CIS Level 1 compliance test
    ${results}=    Run Complete E2E Benchmark Test
    ...    os_identifier=CIS_Amazon-Linux_2
    ...    vm_cred_types=compliance,server
    ...    os_benchmark_identifier=CIS_Amazon_Linux_2_Benchmark
    ...    version=3.0.0
    ...    scan_template=cis
    ...    server_service=ssh
    ...    scope=S
    ...    site_name=${site_name}
    ...    template_name=${template_name}
    ...    policy_list=all
    ...    csv_file=${EXECDIR}/testdata/validation_rules/CIS/RHEL9/level1_server.csv
    ...    skip_cleanup=${TRUE}