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

# Fetching the storage connection string
echo "Fetching storage connection string..."
STORAGE_CONNECTION=$(az storage account show-connection-string --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP" --query connectionString -o tsv)

# Retrieving the App Service Plan ID using the exact path
APP_PLAN=$(az appservice plan show \
  --name           "$APP_PLAN_NAME" \
  --resource-group "$RG_SHARED" \
  --query          "id" -o tsv)
echo "App Service Plan ID: $APP_PLAN"

# Function App creation
echo "Creating the Function application on Azure..."
MSYS_NO_PATHCONV=1 az functionapp create \
    --resource-group "$RESOURCE_GROUP" \
    --storage-account "$STORAGE_ACCOUNT_NAME" \
    --plan "$APP_PLAN" \
    --name "$FUNCTION_APP_NAME" \
    --os-type "$RUNTIME_OS" \
    --runtime "$RUNTIME_FUNCTION" \
    --runtime-version "$RUNTIME_VERSION" \
    --functions-version 4 \
    --tags "$TAGS"

# Function App configuration settings
echo "Configuring application settings on Azure..."
az functionapp config appsettings set \
    --name "$FUNCTION_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --settings "AzureWebJobsStorage=$STORAGE_CONNECTION" \
               "FUNCTIONS_EXTENSION_VERSION=~4" \
               "FUNCTIONS_WORKER_RUNTIME=python" \
               "SCM_DO_BUILD_DURING_DEPLOYMENT=true"

# Activation of SCM Basic Auth Publishing Credentials
echo "Activation of SCM Basic Auth..."
az resource update \
    --resource-group "$RESOURCE_GROUP" \
    --name scm \
    --namespace Microsoft.Web \
    --resource-type basicPublishingCredentialsPolicies \
    --parent "sites/$FUNCTION_APP_NAME" \
    --set properties.allow=true

echo "⏳ Waiting 30 seconds for Azure SCM/Kudu container to wake up..."
sleep 30

# Preparation of the source code
echo "Preparing the function files..."
cat << 'EOF' > function_app.py
import azure.functions as func
import json

app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)

@app.route(route="hello")
def hello(req: func.HttpRequest) -> func.HttpResponse:
    response = {
        "message": "Hello from AzureTech !",
        "service": "Azure Functions (Serverless)",
        "runtime": "Python 3.11",
        "trigger": "HTTP"
    }
    return func.HttpResponse(
        json.dumps(response),
        mimetype="application/json",
        status_code=200
    )
EOF

cat << 'EOF' > host.json
{
  "version": "2.0",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "excludedTypes": "Request"
      }
    }
  },
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[4.*, 5.0.0)"
  }
}
EOF

cat << 'EOF' > requirements.txt
azure-functions
EOF

# Using Python to create a compatible ZIP file with all 3 files
echo "Compressing files into deploy-function-app.zip via Python..."
python -c "
import zipfile
with zipfile.ZipFile('deploy-function-app.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    z.write('function_app.py')
    z.write('host.json')
    z.write('requirements.txt')
"

# Deployment of the zip archive
echo "Deploying the code to Azure..."
MSYS_NO_PATHCONV=1 az functionapp deployment source config-zip \
    --resource-group "$RESOURCE_GROUP" \
    --name "$FUNCTION_APP_NAME" \
    --src "deploy-function-app.zip"

# Local cleanup
echo "Cleaning up local temporary files..."
rm -f function_app.py host.json requirements.txt deploy-function-app.zip

echo "========================================================="
echo " Deployment completed successfully !"
echo " Your Function App is now live at:"
echo " https://${FUNCTION_APP_NAME}.azurewebsites.net/api/hello"
echo "========================================================="