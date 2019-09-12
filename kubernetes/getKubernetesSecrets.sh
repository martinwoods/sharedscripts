#!/bin/bash

# Get all kubernetes secrets (except tokens) and output in JSON format
# Note: JSON will have additional empty values appended to ensure output is valid
# Also, any multi-line strings in the output will invalidate the JSON and need to be tidied up after.
secrets=$(kubectl get secrets -o name --show-labels=false | grep -v token)
echo "{\"cluster\":\"rim-dev\", \"secrets\": ["
for secret in $secrets
do
	echo "{\"name\": \"$secret\", \"values\": {"
	kubectl get $secret -o json | jq -r '. as $in | $in.data | keys[] | .+" "+$in.data[.] ' | xargs -l bash -c 'echo -e "\"$0\":\"$(echo $1 | base64 -d)\","'

	echo '"":""}},'

	
done
echo '{"":""}]}'
