#!/bin/bash

set -e

# Check whether the variables.env file exists, then retrieve the variables
if [ -f variables.env ]; then
    echo "Loading variables..."
    set -a             # Activate automatic export
    source variables.env
    set +a             # Deactivate automatic export for the rest
    echo "Variables loaded!"
else
    echo "❌ Error: variables.env not found."
    exit 1
fi

echo "========================================================="
echo "Deployment of the VNet : ${VNET_NAME}"
echo "========================================================="

# Check if the VNet already exists
if az network vnet show --name "$VNET_NAME" --resource-group "$RESOURCE_GROUP" > /dev/null 2>&1; then
    echo "✅ VNet '$VNET_NAME' already exists in resource group '$RESOURCE_GROUP'."
    exit 0
fi

# VNet creation
echo "Creating the VNet on Azure..."
az network vnet create \
  --name           "$VNET_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location       "$AZURE_LOCATION" \
  --address-prefix "10.0.0.0/16" \
  --tags           $TAGS

# Frontend subnet creation
echo "Creating the subnet 'subnet-frontend' in VNet '$VNET_NAME'..."
az network vnet subnet create \
  --name           "subnet-frontend" \
  --vnet-name      "$VNET_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --address-prefix "10.0.1.0/24"

# Backend subnet creation
echo "Creating the subnet 'subnet-backend' in VNet '$VNET_NAME'..."
az network vnet subnet create \
  --name           "subnet-backend" \
  --vnet-name      "$VNET_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --address-prefix "10.0.2.0/24"

# Check subnets creation in the VNet
echo "Checking subnets in VNet '$VNET_NAME'..."
az network vnet subnet list \
  --vnet-name      "$VNET_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query          "[].{Nom:name, Plage:addressPrefix, Statut:provisioningState}" \
  --output         table

# Check VNet informations
echo "Checking VNet '$VNET_NAME' informations..."
az network vnet show \
  --name           "$VNET_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query          "{nom:name, adresses:addressSpace.addressPrefixes, subnets:subnets[].name}" \
  --output         json