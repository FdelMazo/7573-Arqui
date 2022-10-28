#!/bin/bash

DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -r "./terraform.tfvars" ]; then
  echo "Could not find 'terraform.tfvars'. Are you sure you're running this from the project's root dir?"
  exit 1
fi

if [ ! -d "./.terraform" ]; then
  echo "Could not find '.terraform/'. Initializing terraform..."
  terraform init
fi

# Sign in to Azure
echo "##### Logging into Azure #####"
az login

# Create infrastructure. This also sets the python IP in the node app so that they can communicate
# The -auto-approve flag makes it not to ask for plan approval. Use at your own risk!
echo "##### Applying terraform infrastructure #####"
terraform apply -auto-approve

# Next, copy the python app so it can be deployed
echo "##### Copying python source code #####"
$DIR/python/copy

# Then, we set up the management vm and deploy the python app
echo "##### Setting up the management VM and managed nodes #####"
$DIR/ansible/setup.sh

# Finally, we update the node instances code with the src code that we push through the management vm
echo "##### Deploying node app to VMSS #####"
$DIR/ansible/deploy.sh

echo "##### Finished #####"