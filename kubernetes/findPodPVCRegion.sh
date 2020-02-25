#!/bin/bash
 
# Given the name of a kubernetes pod, find any attached persistent volume claims
# and for each claim, check what AWS zone it requires and what are the eligible nodes where it could be scheduled
# Useful for identifying which nodes may need to have some resources freed if a pod is stuck in pending state due to a volume claim in the required zone


if [ "$#" -ne 1 ]
then
	echo "Error: Must specify pod name and volume name"
	echo "$0 pod-name"
	exit 1
else
	podName=$1

	echo "Getting AWS Region for volumes attached to $podName"

	# Get a list of claims attached to this pod
	claims=$(kubectl get pods $podName -o jsonpath="{.spec.volumes[*].persistentVolumeClaim.claimName}")
	count=0
	# check each claim to find the volume bound to it and the associated zone/region
	# There is most likely only one claim, but there can be multiple
	for claimName in $claims
	do
		((count=$count+1))
		echo "----- Found claim $claimName"
		volumeName=$(kubectl get pvc $claimName -o jsonpath={.spec.volumeName})
		echo -e "\tVolume name is $volumeName"
	
		zone=$(kubectl get pv $volumeName -o jsonpath="{.spec.nodeAffinity.required.nodeSelectorTerms[*].matchExpressions[?(@.key=='failure-domain.beta.kubernetes.io/zone')].values[0]}")
		region=$(kubectl get pv $volumeName -o jsonpath="{.spec.nodeAffinity.required.nodeSelectorTerms[*].matchExpressions[?(@.key=='failure-domain.beta.kubernetes.io/region')].values[0]}")

		echo -e "\tPod $podName has PVC in $region region, $zone zone"

		
		# Once we know the zone, check what nodes are in this zone and output the list of pods on that node
		# These pods can then be considered for eviction (manually) to make space for the pod which requires the PVC
		echo -e "\r\n\t===== Eligible nodes and pods running on them ====="
		for node in $(kubectl get nodes -l failure-domain.beta.kubernetes.io/zone=$zone --no-headers -o custom-columns=name:{.metadata.name})
		do 
			podsRaw=$(kubectl get pods -ocustom-columns='Pod Name':{.metadata.name} --no-headers --all-namespaces --field-selector spec.nodeName=${node}) 
			pods=$(echo -e "$podsRaw" | awk -vORS=, '{print " " $1 }') 
			podCount=$(echo -e "$podsRaw" | wc -l)
			lifeCycle=$(kubectl get nodes $node -o jsonpath="{.metadata.labels.lifecycle}")

			echo -e "\tNode: \t$node"
			echo -e "\tLife-Cycle: \t$lifeCycle"
			echo -e "\tPods: \t$pods"
			echo -e "\tTotal Pods: \t$podCount\r\n"
		done
	done
	
	# If we didn't find anything, let the user know
	if [ $count -eq 0 ] 
	then 
		echo "Unable to find any persistentVolumeClaim attached to $podName"
		exit 0
	fi
fi
