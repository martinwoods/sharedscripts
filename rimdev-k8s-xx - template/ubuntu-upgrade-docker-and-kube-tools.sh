# colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

############################################################
# Reset cluster 
############################################################
echo -e "${GREEN}Resetting Kubernetes cluster${NC}"
kubeadm reset -f

############################################################
# Remove old .kube files
############################################################
echo -e "${GREEN}Removing old .kube files${NC}"
rm -rf /root/.kube

############################################################
# Remove helm and helm files
############################################################
echo -e "${GREEN}Removing helm and helm files${NC}"
rm /usr/local/bin/helm
rm -rf /root/.helm
rm -rf /root/.cache/helm
rm -rf /root/.config/helm

############################################################
# Remove currently installed kube tools
############################################################
echo -e "${GREEN}Removing currently installed kube tools${NC}"
systemctl stop kubelet
apt-get purge kubelet kubeadm kubectl -y

############################################################
# Remove kubernetes files and folders
############################################################
echo -e "${GREEN}Removing kubernetes files and folders${NC}"
rm -rf /etc/cni/net.d
rm -rf /etc/kubernetes

############################################################
# Remove currently installed docker-ce tools
############################################################
echo -e "${GREEN}Removing currently installed docker-ce tools${NC}"
systemctl stop docker
systemctl stop containerd
apt-get purge docker-ce docker-ce-cli containerd.io -y
rm -rf /var/lib/docker/*
rm -f /etc/docker/daemon.json

cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

############################################################
# Install docker-ce tools
############################################################
echo -e "${GREEN}Installing docker-ce tools${NC}"
apt-get install docker-ce=5:20.10.18~3-0~ubuntu-focal docker-ce-cli=5:20.10.18~3-0~ubuntu-focal containerd.io=1.6.8-1 -y
# start and enable docker
systemctl enable docker
systemctl start docker

############################################################
# Install kube tools
############################################################
echo -e "${GREEN}Installing kube tools${NC}"
apt-get install kubectl=1.21.14-00 kubeadm=1.21.14-00 kubelet=1.21.14-00 -y
# start and enable kubelet
systemctl enable kubelet
systemctl start kubelet

############################################################
# Stop services and flush iptables
# see: https://github.com/kubernetes/kubeadm/issues/193#issuecomment-330060848
############################################################
systemctl stop kubelet
systemctl stop docker

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
# Start services 
############################################################
iptables --flush
iptables -tnat --flush
systemctl start kubelet
systemctl start docker

############################################################
# Display service status
############################################################
echo -e "${GREEN}Displaying Services status${NC}"
systemctl status docker
systemctl status kubelet

echo -e "${GREEN}Completed${NC}"