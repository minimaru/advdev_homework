#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/redhat-gpte-devopsautomation/advdev_homework_template.git na311.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Set up Jenkins with sufficient resources
# TBD
oc new-app jenkins-persistent --param ENABLE_OAUTH=true --param VOLUME_CAPACITY=2Gi --param DISABLE_ADMINISTRATIVE_MONITORS=true -n ${GUID}-jenkins

# Create custom agent container image with skopeo
# TBD
oc new-build --name=jenkins-agent-appdev --strategy=docker --dockerfile=- <<EOF
  FROM quay.io/openshift/origin-jenkins-agent-maven:4.1.0
  USER root
  RUN curl https://copr.fedorainfracloud.org/coprs/alsadi/dumb-init/repo/epel-7/alsadi-dumb-init-epel-7.repo -o /etc/yum.repos.d/alsadi-dumb-init-epel-7.repo && \
      curl https://raw.githubusercontent.com/cloudrouter/centos-repo/master/CentOS-Base.repo -o /etc/yum.repos.d/CentOS-Base.repo && \
      curl http://mirror.centos.org/centos-7/7/os/x86_64/RPM-GPG-KEY-CentOS-7 -o /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
  RUN DISABLES="--disablerepo=rhel-server-extras --disablerepo=rhel-server --disablerepo=rhel-fast-datapath --disablerepo=rhel-server-optional --disablerepo=rhel-server-ose --disablerepo=rhel-server-rhscl" && \
      yum \$DISABLES -y --setopt=tsflags=nodocs install skopeo && yum clean all
  USER 1001
EOF

# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`
# TBD
oc create -f - <<EOF
kind: BuildConfig
apiVersion: v1
metadata:
  name: tasks-pipeline
spec:
  source:
    type: Git
    git:
      uri: $REPO
    contextDir: openshift-tasks
  strategy:
    type: JenkinsPipeline
    jenkinsPipelineStrategy:
      env:
      - name: GUID
        value: $GUID
      jenkinsfilePath: Jenkinsfile
EOF

# Make sure that Jenkins is fully up and running before proceeding!
while : ; do
  echo "Checking if Jenkins is Ready..."
  AVAILABLE_REPLICAS=$(oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}')
  if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
    echo "...Yes. Jenkins is ready."
    break
  fi
  echo "...no. Sleeping 10 seconds."
  sleep 10
done
