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
echo "Deployment of the VNet : ${VNET_NAME}"
echo "========================================================="

# Check if the VNet already exists
if az network vnet show --name "$VNET_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "✅ VNet '$VNET_NAME' already exists in resource group '$RESOURCE_GROUP'."
    exit 0
fi

# VNet creation
echo "Creating the VNet on Azure..."
az network vnet create \
    --name "$VNET_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$AZURE_LOCATION" \
    --address-prefix "10.0.0.0/16" \
    --tags "$TAGS"

# Frontend subnet creation
echo "Creating the subnet 'subnet-frontend' in VNet '$VNET_NAME'..."
az network vnet subnet create \
    --name "subnet-frontend" \
    --vnet-name "$VNET_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --address-prefix "10.0.1.0/24"

# Backend subnet creation
echo "Creating the subnet 'subnet-backend' in VNet '$VNET_NAME'..."
az network vnet subnet create \
    --name "subnet-backend" \
    --vnet-name "$VNET_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --address-prefix "10.0.2.0/24"

# Check subnets creation in the VNet
echo "Checking subnets in VNet '$VNET_NAME'..."
az network vnet subnet list \
    --vnet-name "$VNET_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[].{Nom:name, Plage:addressPrefix, Statut:provisioningState}" \
    --output table

# Check VNet informations
echo "Checking VNet '$VNET_NAME' informations..."
az network vnet show \
    --name "$VNET_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "{nom:name, adresses:addressSpace.addressPrefixes, subnets:subnets[].name}" \
    --output json

echo "========================================================="
echo "Creation of the Network Security Group : ${NSG_NAME}"
echo "========================================================="

# Create the Network Security Group (NSG)
echo "Creating the Network Security Group (NSG) on Azure..."
az network nsg create \
    --name "$NSG_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$AZURE_LOCATION" \
    --tags "$TAGS"

# Show the NSG rules
echo "Checking the default rules of the NSG '$NSG_NAME'..."
az network nsg show \
    --name "$NSG_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "defaultSecurityRules[].{Nom:name, Priorite:priority, Direction:direction, Action:access, Port:destinationPortRange}" \
    --output table

# Create a rule to allow inbound HTTP traffic on port 80
echo "Creating a rule to allow inbound HTTP traffic on port 80 in NSG '$NSG_NAME'..."
az network nsg rule create \
    --name "Allow-HTTP" \
    --nsg-name "$NSG_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --priority 100 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefix "*" \
    --source-port-range "*" \
    --destination-address-prefix "*" \
    --destination-port-range "80" \
    --description "Allow inbound HTTP traffic"

# Create a rule to allow inbound HTTPS traffic on port 443
echo "Creating a rule to allow inbound HTTPS traffic on port 443 in NSG '$NSG_NAME'..."
az network nsg rule create \
    --name "Allow-HTTPS" \
    --nsg-name "$NSG_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --priority 110 \
    --direction Inbound \
    --access Allow \
    --protocol Tcp \
    --source-address-prefix "*" \
    --source-port-range "*" \
    --destination-address-prefix "*" \
    --destination-port-range "443" \
    --description "Allow inbound HTTPS traffic"

# Creation of a rule to deny all inbound traffic (as a security measure)
az network nsg rule create \
    --name "Deny-All-Inbound" \
    --nsg-name "$NSG_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --priority 4000 \
    --direction Inbound \
    --access Deny \
    --protocol "*" \
    --source-address-prefix "*" \
    --source-port-range "*" \
    --destination-address-prefix "*" \
    --destination-port-range "*" \
    --description "Deny all inbound traffic"

# Show the NSG rules after adding the new rules
echo "Checking the rules of the NSG '$NSG_NAME' after adding the new rules..."
az network nsg rule list \
    --nsg-name "$NSG_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[].{Nom:name, Priorite:priority, Direction:direction, Action:access, Port:destinationPortRange}" \
    --output table

echo "========================================================="
echo "Association of the NSG '$NSG_NAME' with the subnet 'subnet-frontend' in VNet '$VNET_NAME'"
echo "========================================================="

# Associate the NSG with the frontend subnet
echo "Associating the NSG '$NSG_NAME' with the subnet 'subnet-frontend' in VNet '$VNET_NAME'..."
az network vnet subnet update \
    --name "subnet-frontend" \
    --vnet-name "$VNET_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --network-security-group "$NSG_NAME"

# Check the association of the NSG with the frontend subnet
echo "Checking the association of the NSG '$NSG_NAME' with the subnet 'subnet-frontend' in VNet '$VNET_NAME'..."
az network vnet subnet show \
    --name "subnet-frontend" \
    --vnet-name "$VNET_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "{Subnet:name, NSG:networkSecurityGroup.id}" \
    --output json

# Comparing both subnets and their associated NSG
echo "Comparing both subnets and their associated NSG..."
az network vnet subnet list \
    --vnet-name "$VNET_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "[].{Nom:name, Plage:addressPrefix, NSG:networkSecurityGroup.id}" \
    --output table

echo "========================================================="
echo " Deployment completed successfully !"
echo "========================================================="
