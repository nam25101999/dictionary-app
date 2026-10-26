pipeline {
    agent any

    environment {
        COMPOSE_FILE = 'docker-compose.yml:docker-compose.prod.yml'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Test') {
            steps {
                dir('backend') {
                    sh 'mvn -B verify'
                }

                dir('frontend') {
                    sh 'npm ci && npm run build'
                }
            }
        }

        stage('Smoke Test') {
            steps {
                sh 'bash scripts/smoke-test.sh'
            }
        }

        stage('Pull Images') {
            steps {
                sh 'docker compose -f docker-compose.yml -f docker-compose.prod.yml pull'
            }
        }

        stage('Deploy') {
            steps {
                sh 'docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --no-build'
            }
        }

        stage('Verify') {
            steps {
                sh 'bash scripts/verify-deployment.sh'
            }
        }
    }

    post {
        failure {
            echo 'Pipeline failed! Check logs for details.'
        }
        success {
            echo 'Pipeline completed successfully!'
        }
    }
}
