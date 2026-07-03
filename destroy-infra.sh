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

# Check if the resource group exists
if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "✅ Resource group '$RESOURCE_GROUP' exists. Proceeding with resource deletion..."
else
    echo "❌ Error: Resource group '$RESOURCE_GROUP' does not exist."   

# List the resources in the resource group with the specified tag
    echo "Listing resources in resource group '$RESOURCE_GROUP' with tag '$TAGS'..."
    az resource list --resource-group "$RESOURCE_GROUP" --tag "$TAGS" --output table

    echo "No resources found to delete. Exiting."
    exit 0
fi

# Delete resources in the resource group with the specified tag
echo "Deleting resources in resource group '$RESOURCE_GROUP' with tag '$TAGS'..."
az resource list --resource-group "$RESOURCE_GROUP" --tag "$TAGS" --query "[].id" -o tsv | xargs -I {} az resource delete --ids {}

# Verification of the resource deletion
echo "Verifying the resource deletion..."
remaining_resources=$(az resource list --resource-group "$RESOURCE_GROUP" --tag "$TAGS" --query "[].id" -o tsv)
if [ -z "$remaining_resources" ]; then
    echo "✅ All resources with tag '$TAGS' in resource group '$RESOURCE_GROUP' have been successfully deleted."
else
    echo "❌ Error: Some resources with tag '$TAGS' in resource group '$RESOURCE_GROUP' could not be deleted. Remaining resources:"
    echo "$remaining_resources"
    exit 1
fi
