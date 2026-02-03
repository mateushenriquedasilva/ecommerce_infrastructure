#!/bin/bash

# Configuration variables
RESOURCE_GROUP_NAME="rg-terraform-state"
STORAGE_ACCOUNT_NAME="sttfstate${RANDOM}"
CONTAINER_NAME="tfstate"
LOCATION="Canada Central"

# Create Resource Group
az group create --name $RESOURCE_GROUP_NAME --location "$LOCATION"

# Create Storage Account
az storage account create \ 
    --name $STORAGE_ACCOUNT_NAME \ 
    --resource-group $RESOURCE_GROUP_NAME \ 
    --location "$LOCATION" \ 
    --sku Standard_LRS \ 
    --encryption-services blob
    --min-tls-version TLS1_2

# Create Blob Container
az storage container create \
    --name $CONTAINER_NAME \
    --account-name $STORAGE_ACCOUNT_NAME \

echo "Initialization complete. Storage account '$STORAGE_ACCOUNT_NAME' with container '$CONTAINER_NAME' created in resource group '$RESOURCE_GROUP_NAME'." 