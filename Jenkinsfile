#!groovy

node('master') {

    currentBuild.result = "SUCCESS"

    try {

      stage('Checkout') {

        deleteDir()

        checkout([$class: 'GitSCM', branches: [[name: '*/master']], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'LocalBranch', localBranch: 'master']], submoduleCfg: [], userRemoteConfigs: [[credentialsId: '2e705f31-c6c1-4e5d-8568-49c1562dccbe', url: 'git@github.com:consort-it/ansible_spec_plus.git']]])

      }

      stage('Version') {

        sh "sed -i 's/^  gem.version.*/  gem.version       = \"1.0.${env.BUILD_NUMBER}\"/g' ansible_spec_plus.gemspec"

      }

      stage('Build') {

        sh "gem build ansible_spec_plus.gemspec"

      }

      stage('Release') {

        sh ""

      }

      // stage('Notification') {
      //
      //   GIT_AUTHOR = sh (
      //       script: 'git --no-pager show -s --format="%an <%ae>" HEAD',
      //       returnStdout: true
      //   ).trim()
      //
      //   GIT_COMMIT_MESSAGE = sh (
      //       script: 'git --no-pager show -s --format="%s" HEAD',
      //       returnStdout: true
      //   ).trim()
      //
      //   mail body: "${GIT_AUTHOR} hat erfolgreich folgende Änderung auf http://www.consort-academy.de deployt:\n\n${GIT_COMMIT_MESSAGE}\n\nSiehe ${env.BUILD_URL}",
      //             from: 'jenkins@consort-it.de',
      //             replyTo: 'jenkins@consort-it.de',
      //             subject: 'live deployment SUCCESSFUL',
      //             to: 'dev@consort-it.de'
      //
      // }

    }

    catch (err) {

      currentBuild.result = "FAILURE"

      // mail body: "${env.BUILD_URL}",
      //      from: 'jenkins@consort-it.de',
      //      replyTo: 'jenkins@consort-it.de',
      //      subject: 'live deployment FAILED',
      //      to: 'dev@consort-it.de'

      throw err

    }

}
