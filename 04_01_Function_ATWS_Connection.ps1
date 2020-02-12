$apiuser = $env:ATAPIuser01
$apiuserpw = $env:ATAPIuser01PW
$ApiKey = $env:ATAPIuser01TrackingID
$apiuserpw = $apiuserpw | ConvertTo-SecureString -asPlainText -Force
$PSACredentials = New-Object System.Management.Automation.PSCredential($apiuser,$apiuserpw)


function New-APIconnectionATWS () {
    #ATWS Connection
    ### START: LOAD MODULE / START CONECTION
    # Is there already a connection? If not connect!
    try {
    $connectionExists = Get-AtwsAccount -id 0 -ErrorAction SilentlyContinue
    }
    catch {
        Write-Output "Keine bestehende ATWS-Verbindung vorhanden"
    }
    if (!$connectionExists) {
        while ($null -eq $testconnection) {
            # Refresh all entities with picklists
            Import-Module Autotask -Force
            Connect-AtwsWebApi -Credential $PSACredentials -ApiTrackingIdentifier $ApiKey -NoDiskCache -UsePicklistLabels
            
            # check atws connection again
            $testconnection = Get-AtwsAccount -id 0 -ErrorAction SilentlyContinue
            if ($null -eq $testconnection) {
                if ($connectionTryCounter -eq 5) {
                    $ErrorActionPreference = "Stop"
                    Write-Output "[FEHLER] Es wurde $connectionTryCounter Mal versucht Autotask zu verbinden. Script wird abgebrochen!"
                    Write-Error "[FEHLER] Es wurde $connectionTryCounter Mal versucht Autotask zu verbinden. Script wird abgebrochen!"
                    exit 1
                }
                Install-PackageProvider -Name NuGet -Force
                Install-Module Autotask -Force
                Write-Output "[FEHLER] Verbindung zu Autotask fehlgeschlagen. In einer Minute wird es erneut versucht."
                Start-Sleep 60
            }
            else {
                Write-Output "[ERFOLGREICH] Verbindung Autotask erfolgreich."
            }
            $connectionTryCounter++
        }
    }
    else {
        Write-Output "[ERFOLGREICH] Verbindung Autotask besteht bereits."
    }
    ### END:LOAD MODULE / START CONECTION
}

# Autotask API verbinden
New-APIconnectionATWS