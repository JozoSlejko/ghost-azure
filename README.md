# Ghost on Azure

[Ghost](https://ghost.org/) deployment on [Azure Web App for Containers](https://azure.microsoft.com/en-us/services/app-service/containers/).

## Getting Started

This is an Azure Web app deployed as a container . It uses [the official Ghost Docker image version 4.29.0-alpine](https://hub.docker.com/_/ghost) and [Azure Database for MySQL](https://azure.microsoft.com/en-us/services/mysql/) to store the application data.

The Azure Web app configuration is provided as a ready-to-use template that deploys and configures all requires Azure resources:

* Azure Web app and App Hosting plan for running the container
* Azure Key Vault for storing secrets such as database passwords
* Log Analytics workspace and Application Insights component for monitoring the application
* Azure Database for MySQL server
* Azure Storage Account and File Share for persisting Ghost content
* [Azure Front Door](https://docs.microsoft.com/en-us/azure/frontdoor/) endpoint with a [WAF policy](https://docs.microsoft.com/en-us/azure/web-application-firewall/afds/afds-overview) for securing the traffic to the Web app

All resources have their diagnostic settings configured to stream resource logs and metrics to the Log Analytics workspace.
