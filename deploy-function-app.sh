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
echo "Deployment of the Function App : ${FUNCTION_APP_NAME}"
echo "========================================================="

# Check if the function app already exists
if az functionapp show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" > /dev/null 2>&1; then
    echo "✅ Function app '$FUNCTION_APP_NAME' already exists in resource group '$RESOURCE_GROUP'."
    exit 0
fi

# Checking if the storage account exists, if not, creating it by calling the deploy-storage-account.sh script
if ! az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" > /dev/null 2>&1; then
    echo "❌ Error: Storage account '$STORAGE_ACCOUNT_NAME' does not exist in resource group '$RESOURCE_GROUP'."
    echo "Attempting to create the storage account..."
    ./deploy-storage-account.sh
fi

# Waiting for the storage account to be fully provisioned before proceeding with the Function App creation
until az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" > /dev/null 2>&1; do
    echo "Storage account '$STORAGE_ACCOUNT_NAME' not ready yet. Retrying in 10 seconds..."
    sleep 10
done
echo "Storage account '$STORAGE_ACCOUNT_NAME' is ready."


# Function App creation
echo "Creating the Function application on Azure..."
az functionapp create \
    --resource-group "$RESOURCE_GROUP" \
    --storage-account "$STORAGE_ACCOUNT_NAME" \
    --consumption-plan-location "$AZURE_LOCATION" \
    --name "$FUNCTION_APP_NAME" \
    --os-type "$RUNTIME_OS" \
    --runtime "$RUNTIME_FUNCTION" \
    --runtime-version "$RUNTIME_VERSION" \
    --functions-version 4 \
    --tags "$TAGS"

echo "========================================================="
echo " Deployment completed successfully !"
echo "========================================================="