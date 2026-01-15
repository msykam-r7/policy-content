pipeline {
    agent any
    
    triggers {
        // Nightly run at 2 AM every day - runs on Staging only
        cron('0 2 * * *')
    }
    
    parameters {
        choice(name: 'ENVIRONMENT', choices: ['staging', 'prod', 'prod-us', 'prod-eu'], description: 'Target environment')
        string(name: 'NEXPOSE_HOST_IP', defaultValue: '', description: 'Nexpose Console Host IP/URL (leave empty to use default for environment)')
        string(name: 'VM_IP', defaultValue: '', description: 'Target VM IP to scan (overrides vm_config.json)')
        choice(name: 'TEST_SUITE', choices: ['regression', 'smoke', 'all'], description: 'Test suite to run')
        string(name: 'TEST_PATH', defaultValue: 'tests/', description: 'Path to tests (e.g., tests/CIS/Linux/Ubuntu/ubuntu_22.04_benchmarks.robot)')
    }
    
    environment {
        // Credentials from Jenkins Credentials Store
        NEXPOSE_USERNAME = credentials('nexpose-username')
        NEXPOSE_PASSWORD = credentials('nexpose-password')
        
        // Default hosts per environment (change these to your actual IPs)
        STAGING_HOST = 'staging-nexpose.rapid7.local'
        PROD_HOST = 'prod-nexpose.rapid7.com'
        PROD_US_HOST = 'us-nexpose.rapid7.com'
        PROD_EU_HOST = 'eu-nexpose.rapid7.com'
    }
    
    stages {
        stage('Setup') {
            steps {
                echo "Setting up Robot Framework environment..."
                sh 'chmod +x setup.sh'
                sh './setup.sh'
            }
        }
        
        stage('Set Environment') {
            steps {
                script {
                    // For nightly (cron triggered), always use staging
                    def isNightly = currentBuild.getBuildCauses('hudson.triggers.TimerTrigger$TimerTriggerCause')
                    def targetEnv = isNightly ? 'staging' : params.ENVIRONMENT
                    
                    env.TARGET_ENV = targetEnv
                    
                    // Use parameter IP if provided, otherwise use default for environment
                    if (params.NEXPOSE_HOST_IP?.trim()) {
                        env.NEXPOSE_HOST = params.NEXPOSE_HOST_IP
                    } else {
                        switch(targetEnv) {
                            case 'staging':
                                env.NEXPOSE_HOST = env.STAGING_HOST
                                break
                            case 'prod':
                                env.NEXPOSE_HOST = env.PROD_HOST
                                break
                            case 'prod-us':
                                env.NEXPOSE_HOST = env.PROD_US_HOST
                                break
                            case 'prod-eu':
                                env.NEXPOSE_HOST = env.PROD_EU_HOST
                                break
                        }
                    }
                }
                echo "=========================================="
                echo "Target Environment: ${env.TARGET_ENV}"
                echo "Target Host: ${env.NEXPOSE_HOST}"
                echo "Test Suite: ${params.TEST_SUITE}"
                echo "=========================================="
            }
        }
        
        stage('Run Tests') {
            steps {
                script {
                    def includeTag = params.TEST_SUITE == 'all' ? '' : "--include ${params.TEST_SUITE}"
                    def vmIpVar = params.VM_IP?.trim() ? "--variable VM_IP:${params.VM_IP}" : ''
                    
                    sh """
                        robot --profile ${env.TARGET_ENV} \
                              ${includeTag} \
                              ${vmIpVar} \
                              --outputdir results/${env.TARGET_ENV} \
                              ${params.TEST_PATH}
                    """
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'results/**/*', allowEmptyArchive: true
                    
                    robot outputPath: "results/${env.TARGET_ENV}",
                          passThreshold: 80.0,
                          unstableThreshold: 60.0
                }
            }
        }
    }
    
    post {
        failure {
            echo "Tests failed! Check the Robot Framework reports."
        }
        success {
            echo "All tests passed!"
        }
    }
}
