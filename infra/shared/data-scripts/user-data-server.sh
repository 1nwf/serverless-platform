#!/bin/bash

set -e

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sudo bash /ops/shared/scripts/server.sh "${cloud_env}" "${server_count}" '${retry_join}' "${nomad_binary}"

ACL_DIRECTORY="/ops/shared/config"
NOMAD_BOOTSTRAP_TOKEN="/tmp/nomad_bootstrap"
NOMAD_USER_TOKEN="/tmp/nomad_user_token"

sudo systemctl restart nomad

echo "Finished server setup"

echo "ACL bootstrap begin"

# Wait for nomad servers to come up and bootstrap nomad ACL
for i in {1..12}; do
    # capture stdout and stderr
    set +e
    sleep 5
    OUTPUT=$(nomad acl bootstrap 2>&1)
    if [ $? -ne 0 ]; then
        echo "nomad acl bootstrap: $OUTPUT"
        if [[ "$OUTPUT" = *"No cluster leader"* ]]; then
            echo "nomad no cluster leader"
            continue
        else
            echo "nomad already bootstrapped"
            exit 0
        fi
    fi
    set -e

    echo "$OUTPUT" | grep -i secret | awk -F '=' '{print $2}' | xargs | awk 'NF' > $NOMAD_BOOTSTRAP_TOKEN
    if [ -s $NOMAD_BOOTSTRAP_TOKEN ]; then
        echo "nomad bootstrapped"
        break
    fi
done

nomad acl policy apply -token "$(cat $NOMAD_BOOTSTRAP_TOKEN)" -description "Policy to allow reading of agents and nodes and listing and submitting jobs in all namespaces." node-read-job-submit $ACL_DIRECTORY/nomad-acl-user.hcl
nomad acl token create -token "$(cat $NOMAD_BOOTSTRAP_TOKEN)" -name "read-token" -policy node-read-job-submit | grep -i secret | awk -F "=" '{print $2}' | xargs > $NOMAD_USER_TOKEN
cat $NOMAD_BOOTSTRAP_TOKEN > /ops/shared/config/bootstrap.token
echo "ACL bootstrap end"

