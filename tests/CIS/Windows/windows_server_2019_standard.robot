*** Settings ***
Documentation     Windows Server 2019 CIS Benchmark Compliance Testing
...               
...               This test is PARALLEL-EXECUTION SAFE:
...               - Uses unique site and template names (timestamp + PID + random)
...               - Test-scoped session management
...               - No shared global resources

# Global Framework Imports
Resource          ${CURDIR}/../../../common/global_imports.robot

# Suite and Test Lifecycle
Suite Setup       Global Suite Setup
Suite Teardown    Global Suite Teardown
Test Setup        Global Test Setup
Test Teardown     Global Test Teardown

# Suite-level tags
Force Tags        windows    cis    benchmark    compliance


*** Test Cases ***
Windows 2019-CIS Benchmarks
    [Documentation]    Validates Windows Server 2019 against CIS Level 1 benchmark
    ...    
    ...    PARALLEL EXECUTION: Safe to run with other tests using pabot
    [Tags]    windows    windows2019    cis    benchmark    level1    compliance    e2e    parallel-safe
    
    # Initialize test session for parallel execution safety
    [Setup]    Initialize Test Session
    
    # Generate base names (will be made unique automatically by framework)
    ${site_name}=    Set Variable    Windows2019_CIS_Level1
    ${template_name}=    Set Variable    windows2019_cis_template
    
    # Execute Windows Server 2019 CIS Level 1 compliance test
    ${results}=    Run Complete E2E Benchmark Test
    ...    os_identifier=CIS_Microsoft_Windows-Server-2019
    ...    vm_cred_types=compliance,server
    ...    os_benchmark_identifier=Microsoft_Windows_Server_2019_Stand-alone
    ...    version=3.0.1
    ...    scan_template=cis
    ...    server_service=cifs
    ...    scope=S
    ...    site_name=${site_name}
    ...    template_name=${template_name}
    ...    policy_list=all
    ...    csv_file=${EXECDIR}/testdata/validation_rules/CIS/WindowsServer2019/level1_member_server.csv