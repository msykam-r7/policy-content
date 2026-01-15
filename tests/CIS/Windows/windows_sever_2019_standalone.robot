*** Settings ***
Documentation     Windows Server 2019 CIS Benchmark Compliance Testing
...               
...               This test suite validates Windows Server 2019 against CIS Level 1 benchmark.
...               It performs end-to-end compliance testing including scan execution and validation.

# Import global resources
Resource          ${CURDIR}/../../../common/global_imports.robot

# Suite Setup/Teardown using common keywords
Suite Setup       Global Suite Setup
Suite Teardown    Global Suite Teardown
Test Setup        Global Test Setup
Test Teardown     Global Test Teardown

# Force Tags for all tests in this suite
Force Tags        windows    windows2019    cis    benchmark    compliance


*** Test Cases ***
Windows 2019-CIS Benchmarks
    [Documentation]    Validates Windows Server 2019 against CIS Level 1 benchmark
    [Tags]    level1    e2e    critical
    
    # Generate unique identifiers for this test run
    ${timestamp}=    Evaluate    int(__import__('time').time())
    ${site_name}=    Set Variable    Windows2019_CIS_Level1_${timestamp}
    ${template_name}=    Set Variable    windows2019_cis_template_${timestamp}
    
    # Execute Windows Server 2019 CIS Level 1 compliance test
    ${results}=    Run Complete E2E Benchmark Test
    ...    os_identifier=CIS_Microsoft_Windows-Server-2019
    ...    vm_cred_types=compliance,server
    ...    os_benchmark_identifier=CIS_Microsoft_Windows_Server_2019_Stand-alone
    ...    version=3.0.0
    ...    scan_template=cis
    ...    server_service=cifs
    ...    scope=S
    ...    site_name=${site_name}
    ...    template_name=${template_name}
    ...    policy_list=all
    ...    csv_file=${EXECDIR}/testdata/validation_rules/CIS/WindowsServer2019/level1_member_server.csv 
    ...    skip_cleanup=${TRUE}