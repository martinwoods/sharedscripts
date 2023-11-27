#!/bin/bash
# Description - Script for Kubernetes deployment
#
# SOR#20181018
# version 1.0 	- Initial Draft

# SOR#20181022
# version 2.0 	- Added further cleanup calls to delete users
#				        - Added call to user.sh script

# SOR#20181030
# version 3.0 	- Corrected typo in Alexandru Mateescu name when trying to delete his user

# SOR#20190102
# version 4.0 	- Updated URL for Kubernetes Dashboard yaml file

# SOR#20210205
# version 5.1 	- Updated URL for Helm to v2.17.0
#               - Updated Kubernetes Dashboard to v2.0.0
#               - Updated path to Hostpath hosted on Nexus
#               - Helm ClusterRoleBinding - changed apiVersion: rbac.authorization.k8s.io/v1beta1 to apiVersion: rbac.authorization.k8s.io/v1
#               - Kubernetes Dashboard ClusterRoleBinding - changed apiVersion: rbac.authorization.k8s.io/v1beta1 to apiVersion: rbac.authorization.k8s.io/v1

# SOR#20210226
# version 6.0   - Updated Helm to v3
#               - Added Ambassador
#               - Updated Nginx-ingress to v1.41.3
#               - Updated Hostpath to v0.2.10
#               - Updated Kubernetes Dashboard v2.2.0
#               - Added Redis
#               - Added Mongodb
#               - Added Elasticsearch
#               - Added Kafka
#               - Added Confluent REST Proxy
#               - Added KafkaREST

# PH#20221010
# version 6.1   - Updated the WeaveNet kubectl file download location

# PH#20221201
# version 6.2   - Removed the rimusz/hostpath-provisioner specified install version --version 0.2.10


#               - Updated the BitBucket URL

# PH#20221201
# version 6.3   - Updated the version of cp-kafka-rest to 1.4.1

# SOR#20230117
# version 6.4   - Set Elasticsearch to  7.17.3 (it was previously pulling 'v6.8.23')

# SR#20230719
# version 6.5 - Set kubernetes dashboard to 6.0.8 SR 18626

# AM#20231018
# version 6.6 - Set api server ciphers
##

# colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

############################################################
# Initialise Kubernetes
############################################################
echo -e "${GREEN}Initialising Kubernetes with kubadmn init command${NC}"
kubeadm init

echo -e "${GREEN}Exporting Kubernetes admin.conf file path${NC}"
export KUBECONFIG=/etc/kubernetes/admin.conf

############################################################
# Installing WeaveNet
############################################################
echo -e "${GREEN}Installing WeaveNet${NC}"
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

############################################################
# Wait for Kubernetes Cluster to load
############################################################
echo -e "${GREEN}Waiting 60 seconds for Kubernetes Cluster to load...${NC}"
sleep 60

############################################################
# Test Kubernetes Cluster
############################################################
echo -e "${GREEN}Testing Kubernetes Cluster${NC}"

echo -e "${GREEN}Display Nodes${NC}"
kubectl get nodes

echo -e "${GREEN}Display PODs${NC}"
kubectl get pods --all-namespaces

echo -e "${GREEN}Display Version${NC}"
kubectl version

echo -e "${GREEN}Display Cluster Info${NC}"
kubectl cluster-info

############################################################
# Untaint Master Node as this is a single node cluster
############################################################
echo -e "${GREEN}Untainting Master Node${NC}"
kubectl taint nodes --all node-role.kubernetes.io/master-

############################################################
# Install helm v3.x
############################################################
echo -e "${GREEN}Install helm (v3.13.2)${NC}"
echo "Downloading helm package..."
cd /root
wget https://get.helm.sh/helm-v3.13.2-linux-amd64.tar.gz

echo "Extracting helm package..."
tar -zxvf helm-v3.13.2-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/helm
PATH=$PATH:/usr/local/bin

echo "Confirming helm version..."
helm version

############################################################
# Install Ambassador
############################################################
echo -e "${GREEN}Install Ambassador${NC}"
echo "Adding datawire repo to Helm..."
helm repo add datawire https://www.getambassador.io
helm repo update

echo "Creating ambassador namespace..."
kubectl create namespace ambassador

echo "Creating CRDs"
kubectl apply -f https://app.getambassador.io/yaml/edge-stack/2.5.1/aes-crds.yaml

echo "Creating ambassador values yaml"
echo '
emissary-ingress:
  createDefaultListeners: true
  agent:
    enabled: false
  env:
    AES_ACME_LEADER_DISABLE: true
rateLimit:
  create: false
authService:
  create: false
' > ambassador.values.yaml
echo "Creating vector-dev.com values yaml"
echo '
apiVersion: getambassador.io/v2
kind: Host
metadata:
  name: vector-dev-host
  namespace: ambassador
spec:
  acmeProvider:
    authority: none
  ambassadorId:
  - default
  hostname: vector-dev.com
  requestPolicy:
    insecure:
      action: Route
  selector:
    matchLabels:
      hostname: vector-dev.com
  tlsSecret: {}
status:
  state: Ready
  tlsCertificateSource: None
' > vector-dev.com.values.yaml

echo "Creating Host CRD for host name vector-dev.com...."
kubectl apply -f vector-dev.com.values.yaml -n ambassador

echo "Installing Ambassador chart..."
helm install -n ambassador --set replicaCount=1 edge-stack datawire/edge-stack -f ambassador.values.yaml --version 7.6.1


############################################################
# Install Nginx Ingress
############################################################
echo -e "${GREEN}Installing Ingress-Ingress${NC}"
echo "Adding ingress-nginx repo to Helm..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

echo "Creating nginx-ingress namespace..."
kubectl create namespace nginx-ingress

echo "Installing Nginx Ingress chart..."
helm upgrade --install --namespace nginx-ingress nginx-ingress ingress-nginx/ingress-nginx --set tcp.6379=infrastructure/redis-master:6379,tcp.27017=infrastructure/mongodb:27017,tcp.9200=infrastructure/elasticsearch-master:9200,controller.hostNetwork=true,controller.watchIngressWithoutClass=true,controller.extraArgs.default-backend-service=ambassador/edge-stack --version 4.2.5


############################################################
# Install hostpath storage
############################################################
echo -e "${GREEN}Installing Hostpath Storage${NC}"
echo "Adding rimusz repo to Helm..."
helm repo add rimusz https://charts.rimusz.net
helm repo update

echo "Creating infrastructure namespace..."
kubectl create ns infrastructure

echo "Installing hostpath-provisioner chart..."
helm install my-hostpath-provisioner rimusz/hostpath-provisioner -n infrastructure

############################################################
# Install Kubernetes Dashboard
############################################################
echo -e "${GREEN}Installing Kubernetes Dashboard${NC}"
echo "Adding Kubernetes Dashboard repo to Helm..."
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update

echo "Creating kubernetes-dashboard namespace..."
kubectl create ns kubernetes-dashboard

echo "Installing kubernetes-dashboard chart..."
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard -n kubernetes-dashboard --set image.repository=nexus.retailinmotion.com:5000/kubernetesui/dashboard --set protocolHttp=true --set rbac.create=true --set serviceAccount.create=true --set service.type=NodePort --set service.nodePort=30080

echo "Creating kubernetes-dashboard roles, bindings, etc..."
kubectl -n kubernetes-dashboard create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:kubernetes-dashboard

############################################################
# Install redis
############################################################
echo -e "${GREEN}Installing redis${NC}"
echo "Adding stable repo to Helm..."
helm repo add stable https://charts.helm.sh/stable
helm repo update

echo "Installing redis chart..."
echo "
master:
  disableCommands: []
" | helm install --namespace infrastructure redis --set password=redis stable/redis --create-namespace

############################################################
# Install mongodb
############################################################
echo -e "${GREEN}Installing mongodb${NC}"
echo "Adding stable repo to Helm..."
helm repo add stable https://charts.helm.sh/stable
helm repo update

echo "Installing mongodb chart..."
helm install --namespace infrastructure mongodb --set mongodbRootPassword=mongodb,mongodbUsername=mongodb,mongodbPassword=mongodb,mongodbDatabase=admin,replicaSet.enabled=true,replicaSet.replicas.secondary=0,replicaSet.replicas.arbiter=0 stable/mongodb

############################################################
# Install Elasticsearch
############################################################
echo -e "${GREEN}Installing Elasticsearch${NC}"
echo "Adding elastic repo to Helm..."
helm repo add elastic https://helm.elastic.co

echo "Installing Elasticsearch chart..."
helm install --namespace infrastructure elasticsearch --version 7.17.3 --set replicas=1 elastic/elasticsearch --set clusterHealthCheckParams=wait_for_status=yellow&timeout=1s


############################################################
# Install Kafka
############################################################
echo -e "${GREEN}Installing Kafka${NC}"
echo "Adding incubator repo to Helm..."
helm repo add incubator https://charts.helm.sh/incubator
helm repo update

echo "Installing Kafka chart..."
echo '
configurationOverrides:
  "confluent.support.metrics.enable": false  # Disables confluent metric submission
  "advertised.listeners": |-
    EXTERNAL://kafka.infrastructure:$((31090 + ${KAFKA_BROKER_ID}))
  "listener.security.protocol.map": |-
    PLAINTEXT:PLAINTEXT,EXTERNAL:PLAINTEXT
' > kafka.yml

helm install kafka -n infrastructure incubator/kafka --set external.enabled=true,external.type=NodePort -f kafka.yml

############################################################
# Wait for Kafka to load
############################################################
echo -e "${GREEN}Waiting 180 seconds for Kafka to load...${NC}"
sleep 180

echo -e "${GREEN}Installing Nexus repo...${NC}"
helm repo add nexus https://nexus.retailinmotion.com/repository/helm-hosted

############################################################
# Install LocalStack
############################################################
helm repo update
echo -e "${GREEN}Installing LocalStack${NC}"
echo "Installing LocalStack chart..."
helm install localstack -n default nexus/localstack

############################################################
# Install Confluent REST Proxy
############################################################
helm repo update
echo -e "${GREEN}Installing Confluent REST Proxy${NC}"
echo "Installing Confluent REST Proxy chart..."
helm install schemaregistry -n infrastructure nexus/cp-schema-registry

############################################################
# Install kafkarest
############################################################
helm repo update
echo -e "${GREEN}Installing kafkarest${NC}"
echo "Installing kafkarest chart..."
helm install kafkarest -n infrastructure nexus/cp-kafka-rest --version 1.4.1

############################################################
# Call user.sh script to create SSH user account
############################################################
echo -e "${GREEN}Calling user.sh${NC}"
/root/create-user.sh

############################################################
# Clean up files 
############################################################
echo -e "${GREEN}Cleaning up old files...${NC}"
rm -f /root/*.yaml
rm -f /root/*.yml
rm -f /root/*.gz
rm -rf /root/linux*
rm -f /root/*.bash
rm -f /root/*.sh

############################################################
# flush iptables - this was causing issues with Kafka
############################################################
echo -e "${GREEN}Listing iptables...${NC}"
iptables -L -n -v

echo -e "${GREEN}Flushing iptables...${NC}"
iptables --flush
iptables -tnat --flush

echo -e "${GREEN}Listing iptables again...${NC}"
iptables -L -n -v

############################################################
# update api server ciphers
############################################################
echo -e "${GREEN}Downloading yq...${NC}"
wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64

echo -e "${GREEN}Making yq executable..${NC}"
chmod a+x /usr/local/bin/yq


echo -e "${GREEN}Checking the number of lines in the yaml file...${NC}"
lines=$(yq e '.spec.containers.[0].command' /etc/kubernetes/manifests/kube-apiserver.yaml | wc -l ) 
lines1=$((lines))
lines2=$((lines1+1))

echo -e "${GREEN}Insert lines after line ${lines1}...${NC}"
yq -i '.spec.containers[0].command.['"$lines1"'] = "--tls-min-version=VersionTLS12"' /etc/kubernetes/manifests/kube-apiserver.yaml
echo -e "${GREEN}Insert lines after line ${lines2}...${NC}"
yq -i '.spec.containers[0].command.['"$lines2"'] = "--tls-cipher-suites=TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"' /etc/kubernetes/manifests/kube-apiserver.yaml

############################################################
# Completed and Rebooting
############################################################
echo -e "${GREEN}Completed. Rebooting server......${NC}"
reboot