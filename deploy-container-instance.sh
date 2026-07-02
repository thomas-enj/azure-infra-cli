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
echo "Deployment of the Container Instance : ${ACI_NAME}"
echo "========================================================="

if [ -z "${ACI_DNS_LABEL:-}" ]; then
    ACI_DNS_LABEL="$ACI_NAME"
fi

# Check if the container instance already exists
if az container show --name "$ACI_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "✅ Container instance '$ACI_NAME' already exists in resource group '$RESOURCE_GROUP'."
    exit 0
fi

echo "Creating the container instance on Azure..."
az container create \
    --name "$ACI_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --image "$ACI_IMAGE" \
    --cpu "$ACI_CPU" \
    --memory "$ACI_MEMORY" \
    --os-type "$ACI_OS_TYPE" \
    --restart-policy "$ACI_RESTART_POLICY" \
    --ip-address "$ACI_IP_ADDRESS" \
    --ports "$ACI_PORTS" \
    --dns-name-label "$ACI_DNS_LABEL"

if [ -n "$TAGS" ]; then
    echo "Applying tags to the container instance..."
    az resource tag \
        --resource-group "$RESOURCE_GROUP" \
        --name "$ACI_NAME" \
        --resource-type "Microsoft.ContainerInstance/containerGroups" \
        --tags "$TAGS"
fi

# Récupération du nom de domaine complet (FQDN) de l'instance de conteneur
echo "Fetching the FQDN of the container instance..."
ACI_FQDN=$(az container show --name "$ACI_NAME" --resource-group "$RESOURCE_GROUP" --query ipAddress.fqdn -o tsv)
echo "FQDN of the container instance: $ACI_FQDN"

echo "========================================================="
echo " Deployment completed successfully !"
echo " To access your container instance, visit:"
echo " http://$ACI_FQDN:$ACI_PORTS"
echo "========================================================="
