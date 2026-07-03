#!/bin/bash

set -e

# Check whether the variables.env file exists, then retrieve the variables
if [ -f variables.env ]; then
    echo "Loading variables..."
    set -a # Activate automatic export
    # shellcheck source=/dev/null
    source variables.env
    set +a # Deactivate automatic export for the rest
    echo "Variables loaded!"
else
    echo "❌ Error: variables.env not found."
    exit 1
fi

echo "========================================================="
echo "Destruction of all resources with the tag ${TAGS} in resource group ${RESOURCE_GROUP}"
echo "========================================================="

# Clear any default resource groups that might interfere in the runner environment
az configure --defaults group="" >/dev/null 2>&1 || true

# Check if the resource group exists
if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "✅ Resource group '$RESOURCE_GROUP' exists. Proceeding with resource deletion..."
else
    echo "❌ Error: Resource group '$RESOURCE_GROUP' does not exist."
    exit 1
fi

# Parse the tag key and value
TAG_KEY=$(echo "$TAGS" | cut -d'=' -f1)
TAG_VALUE=$(echo "$TAGS" | cut -d'=' -f2)

echo "Fetching resources to delete..."
# Safely filter by both Resource Group and Tags
RESOURCES_TO_DELETE=$(az resource list --query "[?resourceGroup=='$RESOURCE_GROUP' && tags.'$TAG_KEY'=='$TAG_VALUE'].id" -o tsv)

if [ -z "$RESOURCES_TO_DELETE" ]; then
    echo "No resources found with tag '$TAGS' in group '$RESOURCE_GROUP'. Exiting."
    exit 0
fi

# Delete resources in the resource group with the specified tag
echo "Deleting resources in resource group '$RESOURCE_GROUP' with tag '$TAGS'..."
echo "$RESOURCES_TO_DELETE" | xargs -I "{}" az resource delete --ids "{}"

# Verification of the resource deletion
echo "Verifying the resource deletion..."
remaining_resources=$(az resource list --query "[?resourceGroup=='$RESOURCE_GROUP' && tags.'$TAG_KEY'=='$TAG_VALUE'].id" -o tsv)

if [ -z "$remaining_resources" ]; then
    echo "✅ All resources with tag '$TAGS' in resource group '$RESOURCE_GROUP' have been successfully deleted."
else
    echo "❌ Error: Some resources with tag '$TAGS' in resource group '$RESOURCE_GROUP' could not be deleted. Remaining resources:"
    echo "$remaining_resources"
    exit 1
fi
