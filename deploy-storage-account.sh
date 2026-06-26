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
echo "Deployment of the Storage Account : ${STORAGE_ACCOUNT_NAME}"
echo "========================================================="

# Check if the storage account already exists
if az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" > /dev/null 2>&1; then
    echo "✅ Storage account '$STORAGE_ACCOUNT_NAME' already exists in resource group '$RESOURCE_GROUP'."
    exit 0
fi

# Storage Account creation
echo "Creating the Storage Account on Azure..."
az storage account create \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$AZURE_LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --allow-blob-public-access true \
    --tags "$TAGS"

# Verification of the Storage Account creation
echo "Verifying the Storage Account creation..."
az storage account show \
    --name "$STORAGE_ACCOUNT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "{name:name, location:location, sku:sku.name, provisioningState:provisioningState}" \
    --output table

echo "========================================================="
echo " Deployment completed successfully !"
echo "========================================================="
