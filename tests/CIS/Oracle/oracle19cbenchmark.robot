*** Settings ***
Documentation     Oracle Database 19c CIS Benchmark Compliance Testing
...               
...               Validates Oracle 19c database against CIS security benchmarks.

# Global Framework Imports
Resource          ${CURDIR}/../../../common/global_imports.robot

# Suite and Test Lifecycle
Suite Setup       Global Suite Setup
Suite Teardown    Global Suite Teardown
Test Setup        Global Test Setup
Test Teardown     Global Test Teardown

# Suite-level tags
Force Tags        oracle    database    cis    benchmark    compliance


*** Test Cases ***
Oracle 19c - CIS Benchmark Level 1 Database Compliance Test
    [Documentation]    Validates Oracle 19c database against CIS Level 1 benchmark
    [Tags]    oracle    oracle19c    database    cis    benchmark    compliance    e2e
    
    # Generate unique identifiers for this test run
    ${timestamp}=    Evaluate    int(__import__('time').time())
    ${site_name}=    Set Variable    Oracle19c_CIS_Level1_${timestamp}
    ${template_name}=    Set Variable    oracle19c_cis_template_${timestamp}
    
    # Execute Oracle 19c CIS Level 1 Database compliance test
    ${results}=    Run Complete E2E Benchmark Test
    ...    os_identifier=CIS_ORACLE_19C
    ...    vm_cred_types=compliance,server,database
    ...    os_benchmark_identifier=CIS_Oracle_Database_19c_Benchmark
    ...    version=1.2.0
    ...    scan_template=cis
    ...    server_service=ssh
    ...    db_service=oracle
    ...    scope=S
    ...    site_name=${site_name}
    ...    template_name=${template_name}
    ...    policy_list=all
    ...    csv_file=${EXECDIR}/testdata/validation_rules/CIS/Oracle19c/level1_database.csv


