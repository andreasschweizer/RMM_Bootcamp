# Download and install the module
Install-Module Autotask

# Connect to the Autotask Web Services API and load the module
# The first time you connect a disk cache will be created
$Credential = Get-Credential
$ApiKey = "KEY EINTRAGEN"
Import-Module Autotask -ArgumentList $Credential, $ApiKey