##############################################
# Kubernetes change IP script
##############################################

# version 1.0
# Created by Alexandru Mateescu
#########################
# help #
#########################
display_help() {
    echo
    echo "Usage: ./kubernetes-change-ip.sh IP (e.g ./kubernetes-change-ip.sh 192.168.211.0 ) " >&2
    echo
    echo
    # echo some stuff here for the -a or --add-options
    exit 1
}

while :
do
    case "$1" in
      -h | --help)
          display_help  # Call your function
          exit 0
          ;;
      -*)
          echo "Error: Unknown option: $1" >&2
          ## or call function display_help
          exit 1
          ;;
      *)  # No more options
          break
          ;;
    esac
done


#!/bin/bash
IP=$1

# Stop Services
systemctl stop kubelet docker

# Backup Kubernetes and kubelet
mv -f /etc/kubernetes /etc/kubernetes-backup
mv -f /var/lib/kubelet /var/lib/kubelet-backup

# Keep the certs we need
mkdir -p /etc/kubernetes
cp -r /etc/kubernetes-backup/pki /etc/kubernetes
rm -rf /etc/kubernetes/pki/{apiserver.*,etcd/peer.*}

# Start docker
systemctl start docker

# Init cluster with new ip address
kubeadm init --control-plane-endpoint $IP --ignore-preflight-errors=DirAvailable--var-lib-etcd

# Verify resutl
# kubectl cluster-info