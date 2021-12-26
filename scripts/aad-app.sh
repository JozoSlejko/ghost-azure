#!/bin/bash
az login --service-principal -u $SpId -p $SpPassword --tenant $TenantId
echo "Creating ${SiteName} app..."
appId="$(az ad app create --display-name "${SiteName}" --homepage "https://${SiteName}.azurewebsites.net" --reply-urls "https://${SiteName}.azurewebsites.net/.auth/login/aad/callback" --query 'appId' -o tsv)"
appInfo="$(az ad app show --id ${appId})"
echo "App ID: ${appId}"
echo "App Info: ${appInfo}"
echo "Getting User.Read role"
role="$(az ad sp show --id 00000003-0000-0000-c000-000000000000 --query "oauth2Permissions[?value=='User.Read'].id" -o tsv)"
echo "Setting role: ${role} permission..."
az ad app permission add --id "${appId}" --api 00000003-0000-0000-c000-000000000000 --api-permissions "${role}=Scope"
echo "Creating service principal..."
az ad sp create --id ${appId}
echo "Granting permissions..."
az ad app permission grant --id ${appId} --api 00000003-0000-0000-c000-000000000000
echo "Set application password..."
az ad app credential reset --id ${appId} --password $AppPassword -o none
# Create output for appId
echo \{\"appId\":\"$appId\"\} > $AZ_SCRIPTS_OUTPUT_PATH