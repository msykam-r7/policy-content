*** Settings ***
Documentation     Ubuntu 22.04 CIS Benchmark Compliance Testing
...               
...               Validates Ubuntu 22.04 LTS against CIS security benchmarks.

# Global Framework Imports
Resource          ${CURDIR}/../../../../common/global_imports.robot

# Suite-level tags
Force Tags        ubuntu    linux    cis    benchmark    compliance


*** Test Cases ***
Ubuntu 22.04 -CIS Benchmarks
    [Documentation]    Validates Ubuntu 22.04 against CIS Level 1 benchmark
    [Tags]    ubuntu    ubuntu2204    linux    cis    benchmark    level1    compliance    e2e
    
    # Generate unique identifiers for this test run
    ${timestamp}=    Evaluate    int(__import__('time').time())
    ${site_name}=    Set Variable    Ubuntu2204_CIS_Level1_${timestamp}
    ${template_name}=    Set Variable    ubuntu2204_cis_template_${timestamp}
    
    # Execute Ubuntu 22.04 CIS Level 1 compliance test
    ${results}=    Run Complete E2E Benchmark Test
    ...    os_identifier=CIS_Ubuntu_Ubuntu-22-04
    ...    vm_cred_types=compliance,server
    ...    os_benchmark_identifier=CIS_Ubuntu_Linux_22.04_LTS_STIG_Benchmark
    ...    version=1.0.0
    ...    scan_template=cis
    ...    server_service=ssh
    ...    scope=S
    ...    site_name=${site_name}
    ...    template_name=${template_name}
    ...    policy_list=all
    ...    csv_file=${EXECDIR}/testdata/validation_rules/CIS/Ubuntu/ubuntu_22.04_rules.csv.csv
  