#!/bin/bash
OLD_DIR="$(pwd)"
DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd $DIR

../node/zip
./update_vmss_inventory.sh
ansible-playbook -i mgmt_host --private-key ./key.pem -u azureuser mgmt_update_vmss.yml

cd $OLD_DIR