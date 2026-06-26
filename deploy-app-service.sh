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
echo "Deployment of the App Service : ${APP_NAME}"
echo "========================================================="

# Check if the app service already exists
if az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" > /dev/null 2>&1; then
    echo "✅ App service '$APP_NAME' already exists in resource group '$RESOURCE_GROUP'."
    exit 0
fi

# App Service creation
echo "Creating the Web application on Azure..."
az webapp create \
    --resource-group "$RESOURCE_GROUP" \
    --plan "$APP_SERVICE_PLAN" \
    --name "$APP_NAME" \
    --runtime "$RUNTIME" \
    --tags "$TAGS"

# Activation of SCM Basic Auth Publishing Credentials
echo "Activation of SCM Basic Auth..."
az resource update \
    --resource-group "$RESOURCE_GROUP" \
    --name scm \
    --namespace Microsoft.Web \
    --resource-type basicPublishingCredentialsPolicies \
    --parent "sites/$APP_NAME" \
    --set properties.allow=true

# Preparation of the source code
echo "Preparing the index.php file..."
cat << 'EOF' > index.php
<?php
header('Content-Type: application/json');
echo json_encode([
    "message" => "Hello from AzureTech !",
    "service" => "Azure App Service (PaaS)",
    "runtime" => "PHP 8.2",
    "host"    => gethostname()
]);
EOF

# Using Python (included with the Azure CLI) to create a compatible ZIP file
echo "Compressing the index.php file into deploy.zip via Python..."
python -c "import zipfile; z = zipfile.ZipFile('deploy.zip', 'w', zipfile.ZIP_DEFLATED); z.write('index.php'); z.close()"

# Deployment of the zip archive
echo "Deploying the code to Azure..."
MSYS_NO_PATHCONV=1 az webapp deploy \
    --resource-group "$RESOURCE_GROUP" \
    --name "$APP_NAME" \
    --src-path "deploy.zip" \
    --type zip

# Local cleanup
rm -f index.php deploy.zip

echo "========================================================="
echo " Deployment completed successfully !"
echo " URL of your API : https://${APP_NAME}.azurewebsites.net"
echo "========================================================="
