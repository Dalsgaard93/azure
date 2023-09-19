
# If running in the old shit powershell, go to 7.3.2+
# Then manually restart the script!
if($PSVersionTable.PSVersion.Major -lt  6) {pwsh}

# Run all the Bicep files from this PS file
.\Deploy_Env_Bicep_IaaS.ps1

# Run all the Post processing scripts from this PS file
.\Deploy_Env_PostScripting_work.ps1
