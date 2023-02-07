#!/bin/bash
OLD_DIR="$(pwd)"
DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $DIR

ansible-playbook -i mgmt_host --private-key ./key.pem -u azureuser mgmt_setup.yml

cd $OLD_DIR