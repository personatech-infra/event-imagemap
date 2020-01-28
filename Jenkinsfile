#!/usr/bin/env groovy
// Monobuild configuration for personatech

// Log Rotation
properties([
  buildDiscarder(
    logRotator(
      artifactDaysToKeepStr: '',
      artifactNumToKeepStr: '',
      daysToKeepStr: '30',
      numToKeepStr: '100'
    )
  )
])

// Generate unique slave labels
def k8s_label = "maps-${UUID.randomUUID().toString()}"

pipeline {

  environment {
    CLOUDSDK_CORE_DISABLE_PROMPTS = '1'
    GIT_COMMIT_SHORT = sh(script: "printf \$(git rev-parse --short ${GIT_COMMIT})", returnStdout: true)
    APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE = "true"
    LANG = "en_US.UTF-8"
    LANGUAGE = "en_US:en"
    LC_ALL = "en_US.UTF-8"
  } // environment

  agent {
    kubernetes {
      label k8s_label
      defaultContainer 'jnlp'
      yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: ruby
    image: gcr.io/pt-development-220816/ruby:latest
    imagePullPolicy: Always
    resources:
      requests:
        memory: "1024Mi"
        cpu: "2000m"
      limits:
      requests:
        memory: "1024Mi"
        cpu: "2000m"
    command:
    - "tail"
    - "-f"
    - "/dev/null"
  - name: node
    image: node:11.7-alpine
    imagePullPolicy: Always
    resources:
      requests:
        memory: "1024Mi"
        cpu: "2000m"
      limits:
      requests:
        memory: "1024Mi"
        cpu: "2000m"
    command:
    - "tail"
    - "-f"
    - "/dev/null"
"""
    } // kubernetes
  } // agent

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
  } // options

  stages {
    // It doesn't look like there's a linter, or tests currently ?
    //   stage('maps') {
    //     when { not { changeset 'config/**' } }
    //     steps {
    //       container('node') {
    //         sh 'npm install'
    //         sh 'npm run test'
    //         sh 'npm run lint'
    //       } //container
    //     } //steps 
    //   } //stage
    // } // stage

    stage('Staging: Deploy Preparation') {
      when {
        allOf {
          branch 'staging'
          not { changeRequest() }
        }
      }
      steps {
        container(name: 'ruby', shell: '/bin/bash') {
          withEnv(["CLUSTER=gke_pt-staging_us-central1_staging", "REVISION=$GIT_COMMIT_SHORT", "KUBECONFIG=~/.kube/config"]) {
            ansiColor('xterm') {
              configFileProvider([configFile(fileId: '9097dae8-46b2-4e97-8121-a8b4e3bbd656', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                  // DEBUG: Output gcloud command line version
                  sh 'gcloud version --format=json | jq -r .'
                  sh 'kubectl version --short --client'
                  sh 'gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS'
                  sh 'gcloud container -q clusters get-credentials staging --region us-central1 --project pt-staging'
              } // configFileProvider
            } // anisColor
          } // withEnv
        } // container
      } // steps
    } // stage

    stage('Staging: Image Build') {
      when {
        allOf {
          branch 'staging'
          not { changeRequest() }
        }
      }
      steps {
        container('ruby') {
          withEnv(["REVISION=$GIT_COMMIT_SHORT"]) {
            configFileProvider([configFile(fileId: '9097dae8-46b2-4e97-8121-a8b4e3bbd656', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
              sh 'gcloud builds submit . --machine-type=n1-highcpu-32 --project pt-development-220816 --timeout=20m -t gcr.io/pt-staging/maps:$REVISION'
            } // configFileProvider
          } // withEnv
        } // container
      } // steps
    } // stage

    stage('Staging: Deploy') {
      when {
        allOf {
          branch 'staging'
          not { changeRequest() }
        }
      }
      stage('maps') {
        steps {
          container(name: 'ruby', shell: '/bin/bash') {
            withEnv(["CLUSTER=gke_pt-staging_us-central1_staging", "REVISION=$GIT_COMMIT_SHORT", "KUBECONFIG=~/.kube/config", "APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=true", "LANG=en_US.UTF-8", "LANGUAGE=en_US:en", "LC_ALL=en_US.UTF-8"]) {
              ansiColor('xterm') {
                configFileProvider([configFile(fileId: '9097dae8-46b2-4e97-8121-a8b4e3bbd656', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                  dir("config/deploy") {
                    sh 'gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS'
                    sh 'gcloud container -q clusters get-credentials staging --region us-central1 --project pt-staging'
                    sh '''
                      cp pt-staging/secrets.ejson . || true
                      REVISION=$GIT_COMMIT_SHORT kubernetes-deploy maps ${CLUSTER} --template-dir=. --bindings=@pt-staging/bindings.yaml
                    '''
                  }
                } // configFileProvider
              } // anisColor
            } // withEnv
          } // container
        } // steps
      } // stage
    } // stage
  } // stages

  post { 
    success {
      slackSend color: '#326de6', message: "Success ${env.JOB_NAME} ${env.BUILD_NUMBER} (<${env.BUILD_URL}|Open>)"
    } // success
    failure {
      slackSend color: '#8B0000', message: "Failure ${env.JOB_NAME} ${env.BUILD_NUMBER} (<${env.BUILD_URL}|Open>)"
    } // failure

  } // post

} // pipeline



