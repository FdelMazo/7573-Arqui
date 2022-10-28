#!/bin/bash
ansible-playbook -i ./vmss_hosts --private-key ./key.pem -u azureuser ./vmss_deploy.yml
true