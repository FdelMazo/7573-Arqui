#!/bin/bash
ansible-playbook -i python_host --private-key ./key.pem -u azureuser ./python_setup.yml
true