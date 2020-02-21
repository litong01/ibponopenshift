#!/bin/bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#
set -e

read -d '' ibpscc << EOF || true
allowHostDirVolumePlugin: true
allowHostIPC: true
allowHostNetwork: true
allowHostPID: true
allowHostPorts: true
allowPrivilegeEscalation: true
allowPrivilegedContainer: true
allowedCapabilities:
- NET_BIND_SERVICE
- CHOWN
- DAC_OVERRIDE
- SETGID
- SETUID
- FOWNER
apiVersion: security.openshift.io/v1
defaultAddCapabilities: null
fsGroup:
  type: RunAsAny
groups:
- system:cluster-admins
- system:authenticated
kind: SecurityContextConstraints
metadata:
  name: ibpscc
readOnlyRootFilesystem: false
requiredDropCapabilities: null
runAsUser:
  type: RunAsAny
seLinuxContext:
  type: RunAsAny
supplementalGroups:
  type: RunAsAny
volumes:
- "*"
EOF

read -d '' ibproles << EOF || true
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  creationTimestamp: null
  name: ibpclusterrole
rules:
- apiGroups:
  - apiextensions.k8s.io
  resources:
  - persistentvolumeclaims
  - persistentvolumes
  - customresourcedefinitions
  verbs:
  - '*'
- apiGroups:
  - "*"
  resources:
  - pods
  - services
  - endpoints
  - persistentvolumeclaims
  - persistentvolumes
  - events
  - configmaps
  - secrets
  - ingresses
  - roles
  - rolebindings
  - serviceaccounts
  - nodes
  - routes
  - routes/custom-host
  verbs:
  - '*'
- apiGroups:
  - ""
  resources:
  - namespaces
  - nodes
  verbs:
  - get
- apiGroups:
  - apps
  resources:
  - deployments
  - daemonsets
  - replicasets
  - statefulsets
  verbs:
  - '*'
- apiGroups:
  - monitoring.coreos.com
  resources:
  - servicemonitors
  verbs:
  - get
  - create
- apiGroups:
  - apps
  resourceNames:
  - ibp-operator
  resources:
  - deployments/finalizers
  verbs:
  - update
- apiGroups:
  - ibp.com
  resources:
  - '*'
  - ibpservices
  - ibpcas
  - ibppeers
  - ibpfabproxies
  - ibporderers
  verbs:
  - '*'
- apiGroups:
  - ibp.com
  resources:
  - '*'
  verbs:
  - '*'
- apiGroups:
  - config.openshift.io
  resources:
  - '*'
  verbs:
  - '*'

---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: ibpclusterrolebinding
subjects:
- kind: ServiceAccount
  name: default
  namespace: $PROJECT_NAME
roleRef:
  kind: ClusterRole
  name: ibpclusterrole
  apiGroup: rbac.authorization.k8s.io
EOF

read -d '' ibpoperator << EOF || true
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ibp-operator
  labels:
    release: "operator"
    helm.sh/chart: "ibm-ibp"
    app.kubernetes.io/name: "ibp"
    app.kubernetes.io/instance: "ibpoperator"
    app.kubernetes.io/managed-by: "ibp-operator"
spec:
  replicas: 1
  strategy:
    type: "Recreate"
  selector:
    matchLabels:
      name: ibp-operator
  template:
    metadata:
      labels:
        name: ibp-operator
        release: "operator"
        helm.sh/chart: "ibm-ibp"
        app.kubernetes.io/name: "ibp"
        app.kubernetes.io/instance: "ibpoperator"
        app.kubernetes.io/managed-by: "ibp-operator"
      annotations:
        productName: "IBM Blockchain Platform"
        productID: "54283fa24f1a4e8589964e6e92626ec4"
        productVersion: "2.1.2"
    spec:
      hostIPC: false
      hostNetwork: false
      hostPID: false
      serviceAccountName: default
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: beta.kubernetes.io/arch
                operator: In
                values:
                - amd64
      imagePullSecrets:
        - name: docker-key-secret
      containers:
        - name: ibp-operator
          image: $IMAGE_SERVER/cp/$IMAGE_NAME
          command:
          - ibp-operator
          imagePullPolicy: Always
          securityContext:
            privileged: false
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false
            runAsNonRoot: false
            runAsUser: 1001
            capabilities:
              drop:
              - ALL
              add:
              - CHOWN
              - FOWNER
          livenessProbe:
            tcpSocket:
              port: 8383
            initialDelaySeconds: 10
            timeoutSeconds: 5
            failureThreshold: 5
          readinessProbe:
            tcpSocket:
              port: 8383
            initialDelaySeconds: 10
            timeoutSeconds: 5
            periodSeconds: 5
          env:
            - name: WATCH_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: OPERATOR_NAME
              value: "ibp-operator"
            - name: CLUSTERTYPE
              value: OPENSHIFT
          resources:
            requests:
              cpu: 100m
              memory: 200Mi
            limits:
              cpu: 100m
              memory: 200Mi
EOF

read -d '' ibpconsole << EOF || true
apiVersion: ibp.com/v1alpha1
kind: IBPConsole
metadata:
  name: ibpconsole
spec:
  license: accept
  serviceAccountName: default
  email: "$EMAIL_ADDRESS"
  password: "$CONSOLE_PASSWORD"
  registryURL: $IMAGE_SERVER/cp
  imagePullSecret: "docker-key-secret"
  networkinfo:
    domain: $DOMAIN_URL
  storage:
    console:
      class: $STORAGE_CLASS
      size: 10Gi
EOF


function isValidateCMD() {
  if [ -z $MODE ] || [[ '-h' == "$MODE" ]] || [[ '--help' == "$MODE" ]]; then
    printHelp
    exit
  fi
  if [[ ! 'up' == "$MODE" ]] && [[ ! 'down' == "$MODE" ]]; then
    printHelp
    exit
  fi
}

function printHelp() {
  echo "Usage: "
  echo "  ibptool <mode> [options]"
  echo "    <mode> - up or down"
  echo ""
  echo "      - 'up' - set up IBP on OpenShift"
  echo "      - 'down' - remove IBP from OpenShift"
  echo ""
  echo "    options:"
  echo "    -n|--project-name         - project name"
  echo "    -k|--entitlement-key      - entitlement key"
  echo "    -e|--email-address        - entitlement key owner email address"
  echo "    -p|--console-password     - ibp console password"
  echo "    -s|--image-server         - ibp container image server"
  echo "    -i|--image-name           - ibp operator image name"
  echo "    -c|--storage-class        - storage class name"
  echo "    -d|--domain-url           - domain url"
  echo "    -h|--help                 - print this message"
  echo
}

function ibpup() {
  echo "1. Create os project"
  oc create namespace $PROJECT_NAME

  echo "2. Apply the security context constraint"
  echo "$ibpscc" | envsubst > ibp-scc.yaml
  oc apply -f ibp-scc.yaml
  sleep 3

  echo "3. Add security context constraint to user"
  oc adm policy add-scc-to-user ibpscc system:serviceaccounts:$PROJECT_NAME
  oc adm policy add-scc-to-group ibpscc system:serviceaccounts:$PROJECT_NAME
  sleep 3

  echo "4. Apply ClusterRole and ClusterRoleBinding"
  echo "$ibproles" | envsubst > ibp-clusterroles.yaml
  oc apply -f ibp-clusterroles.yaml

  echo "6. Apply ClusterRole to user"
  oc adm policy add-cluster-role-to-user ibpclusterrole system:serviceaccounts:$PROJECT_NAME
  sleep 3

  echo "7. Create secret for entitlement"
  oc create secret docker-registry docker-key-secret \
    --docker-server=$IMAGE_SERVER --docker-username=$EMAIL_ADDRESS \
    --docker-password=$ENTITLEMENT_KEY --docker-email=$EMAIL_ADDRESS \
    -n $PROJECT_NAME

  echo "7. Deploy the operator"
  echo "$ibpoperator" | envsubst > ibp-operator.yaml
  oc apply -f ibp-operator.yaml -n $PROJECT_NAME
  while : ; do
    sleep 3
    res=$(oc -n $PROJECT_NAME get pods | grep "^ibp-operator-" | grep "Running" | grep "1/1" || true)
    if [[ ! -z $res ]]; then
      break
    fi
    echo 'Waiting for ibp operator to be ready...'
  done

  echo "8. Deploy the IBP Console"
  echo "$ibpconsole" | envsubst > ibp-console.yaml
  oc apply -f ibp-console.yaml -n $PROJECT_NAME
  while : ; do
    sleep 3
    res=$(oc -n $PROJECT_NAME get pods | grep "^ibpconsole-" | grep "Running" | grep "4/4" || true)
    if [[ ! -z $res ]]; then
      break
    fi
    echo 'Waiting for ibp console to be ready...'
  done
  sleep 3

  echo ""
  echo ""
  echo -e "\e[32mAccess IBP Console at the following address:"
  echo -e "\e[32mhttps://$PROJECT_NAME-ibpconsole-console.$DOMAIN_URL"
  echo ""
}

function ibpdown() {
  echo "1. Remove the IBP Console"
  echo "$ibpconsole" | envsubst > ibp-console.yaml
  oc -n $PROJECT_NAME delete -f ibp-console.yaml

  echo "2. Remove ibp operator"
  echo "$ibpoperator" | envsubst > ibp-operator.yaml
  oc -n $PROJECT_NAME delete -f ibp-operator.yaml

  echo "3. remove secret for entitlement"
  oc -n $PROJECT_NAME delete secret docker-key-secret

  echo "4. Remove ClusterRole from user, Cluster Role Binding and Cluster Role"
  oc adm policy remove-cluster-role-from-user ibpclusterrole system:serviceaccounts:$PROJECT_NAME
  echo "$ibproles" | envsubst > ibp-clusterroles.yaml
  oc delete -f ibp-clusterroles.yaml

  echo "5. Remove SecurityContextConstraint from user"
  oc adm policy remove-scc-from-group ibpscc system:serviceaccounts:$PROJECT_NAME
  oc adm policy remove-scc-from-user ibpscc system:serviceaccounts:$PROJECT_NAME

  echo "6. remove the security context constraint"
  echo "$ibpscc" | envsubst > ibp-scc.yaml
  oc delete -f ibp-scc.yaml

  echo "7. remove os project"
  oc delete project $PROJECT_NAME
}

MODE=$1
isValidateCMD

shift

while [[ $# -gt 0 ]]; do
optkey="$1"

case $optkey in
  -h|--help)
    printHelp; exit 0;;
  -n|--project-name)
    export PROJECT_NAME="$2";shift;shift;;
  -k|--entitlement-key)
    export ENTITLEMENT_KEY="$2";shift;shift;;
  -e|--email-address)
    export EMAIL_ADDRESS="$2";shift;shift;;
  -p|--console-password)
    export CONSOLE_PASSWORD="$2";shift;shift;;
  -s|--image-server)
    export IMAGE_SERVER="$2";shift;shift;;
  -i|--image-name)
    export IMAGE_NAME="$2";shift;shift;;
  -c|--storage-class)
    export STORAGE_CLASS="$2";shift;shift;;
  -d|--domain-url)
    export DOMAIN_URL="$2";shift;shift;;
  *) # unknown option
    echo "$1 is a not supported option"; exit 1;;
esac
done

declare -a params=("PROJECT_NAME" "ENTITLEMENT_KEY" "EMAIL_ADDRESS" \
  "CONSOLE_PASSWORD" "IMAGE_SERVER" "IMAGE_NAME" "STORAGE_CLASS" "DOMAIN_URL")
for value in ${params[@]}; do
    eval "tt=${!value}"
    if [ -z ${tt} ]; then
      echo "$value was not set"
      exit 1
    fi
done

echo "Your current settings for IBP"
echo "PROJECT_NAME=$PROJECT_NAME"
echo "ENTITLEMENT_KEY=$ENTITLEMENT_KEY"
echo "EMAIL_ADDRESS=$EMAIL_ADDRESS"
echo "CONSOLE_PASSWORD=$CONSOLE_PASSWORD"
echo "IMAGE_SERVER=$IMAGE_SERVER"
echo "IMAGE_NAME=$IMAGE_NAME"
echo "STORAGE_CLASS=$STORAGE_CLASS"
echo "DOMAIN_URL=$DOMAIN_URL"

if [[ 'up' == "$MODE" ]]; then
   ibpup
elif [[ 'down' == "$MODE" ]]; then
   ibpdown
fi
