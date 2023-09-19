------------------------------------
Bicep deployment - Intro
------------------------------------

These scripts can deploy a full Data Solution environment to Azure via Bicep/ARM and Powershell.
It includes a Data Lake, a Key Vault, a Data Factory, a Databricks workspace and full integration between all of the components, so a developer should be ready to go.
It was created for the NC KPMG Customer Platform project in 2023 for creating dynamic dev/test environments for CICD but can be used for training too.

------------------------------------
Bicep deployment - Prereq
------------------------------------

Pre-req programs installed:
- Powershell v7
- curl.exe installed for API calls from CLI (might be installed in Powershell already?)
- Azure CLI (Not Powershell Azure, just Azure CLI, easier to read)

Pre-req Azure Account: 
- Setup and use a free account/tenant, create a Subscription and expense it, or use the customer Account and get a Subscription set up there.
- Have/obtain Owner rights on the Subscription, or enough to create RGs and anything inside these RGs
- NB: NCAPPS/netcompany.cloud does not allow us to deploy Bicep/ARM code with Managed Identities in it, so we cannot setup combination and thus it makes no sense to use the NCAPPS/netcompany.cloud Azure cloud options.
- 

Files and what happens:
- We first run Powershell files (.PS1) that setup variables and then run .bicep files which are "new Azure ARM" templates that deploy components to an Azure account with a subscription.
- Then we run Powershell files, that tie the now-deployed components together in a way that could not be done during the Bicep phase.

------------------------------------
Bicep deployment itself - Method
------------------------------------

- Open a powershell, type "pwsh", to convert to v.7
- Run "az login" to lock the CLI to a pre-existing Subscription

Stand in the infrastructure/azure dir (this dir this file should be in)

Run options,
- Run the deployment of the Bicep code,
--> Deploy_Env_Bicep_IaaS.ps1
- Run the deployment of all the post-Bicep deployment code
--> Deploy_Env_PostScripting_work.ps1

- (UNTESTED) Run everything, not done yet,
--- UNTESTED_Deploy_DevEnv_Databricks_DataLake.ps1
--- Runs all other PS1 files in order, but we have not tested if it works like this yet.


------------------------------------
Bicep deployment itself - Tech details
------------------------------------

First the PS1 file "Deploy_Env_Bicep_IaaS.ps1" sets up dynamic names for an RG, based on time, creates it and then deploys the Bicep file to this new RG.

The Bicep file then deploys
- A Storage Account, with hierachical namespacing and a Blob Container which then acts as a HDFS Datalake
- An Azure Key Vault(AKV), which can store the keys and passwords securely and then via RBAC can allow services and users to access these
- An Azure Data Factory(ADF), which can orchestrate any dataflows, including notebooks etc
- A Azure Databricks workspace
- User Managed Identities (UMI) that allow user-less services to speak to each other
- Rights assignments to the UMIs so the ADF can use the AKV and get the Lake key and can call Databricks for notebook access
- Rights assignements so Databricks can use the AKV later for secret scope
- Linked Services for ADF for tying the services together so ADF can make flows out of the box

Then when one runs the post processing PS1 file "Deploy_Env_PostScripting_work.ps1":
- Databricks is OAuth2 authenticated to deliver a token that can impersonate the caller of the script and create stuff via the Databricks API
- Databricks clusters are set up
- (In progress) Via this, a secret scope is created and integrated with the AKV, thus getting the Databricks workspace secure access to the AKVs Lake key
- (Later) Notebooks are imported from Git and deployed to the workspace
- (Later) Integrated with Git on maybe a separate branch or so.


------------------------------------
TODOs - Outstanding TODOs before the environments are considered done
------------------------------------

TODO General: (Nice to have)
-- Generic setup from a Git repo of the Databricks files currently used, the ARM files from the ADF and other in-progress files.
-- Integration back to Git of the working files (in ADF and in Databricks separately setup)

TODO Bicep - General:
-- (If it is possible) Split up the Bicep files in multiple files, such that all Bicep files are still part of the same deployment so it can "see" dependencies in each othes files (names of resource identifiers, variables and so on)


TODO Bicep - Azure Data Factory:
-- The whole ARM template for sample Databricks flows should be imported
-- Git enable back to a repo, where the ARMs lie (But since need to be airtight env, maybe create a new)
-- Enable the trigger so the deployed ADF is active and run the established flows (none made yet but eventually) at their schedules

TODO post-Bicep - Databricks tasks:
-- Fix the Secret Scope creation via API, so the Secret Scope is pointing at, and can use, the Azure Key Vault and the secret storing the key for the Datalake
-- Upload RASOs master notebook file from databricks and add dynamically the Azure Keyvault secret to it, that contains the Storage account key to access the data lake
-- Install libs for the Cluster definitions, ciso8601 and others
-- Linked Service to Databricks instance, needs to be patched post-Bicep, as the Cluster Definition needed has to be setup post-Databricks deployment and thus the Linked Service in the initial Bicep file has a placeholder ClusterID put in. This needs a Databricks API call, post-Cluster-creation, to update.








