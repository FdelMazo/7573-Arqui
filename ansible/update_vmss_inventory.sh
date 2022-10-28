#!/bin/bash
az vmss nic list --resource-group tp2_resource_group --vmss-name tp2vmss --query [].ipConfigurations[].privateIpAddress -o tsv | tr "\t" "\n" > ./vmss/vmss_hosts