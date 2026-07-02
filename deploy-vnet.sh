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
if az network vnet show --name "$VNET_NAME" --resource-group "$RG" > /dev/null 2>&1; then
    echo "✅ VNet '$VNET_NAME' already exists in resource group '$RG'."
    exit 0
fi

# VNet creation
echo "Creating the VNet on Azure..."
az network vnet create \
  --name           "$VNET_NAME" \
  --resource-group "$RG" \
  --location       "$LOCATION" \
  --address-prefix "10.0.0.0/16" \
  --tags           $TAGS
