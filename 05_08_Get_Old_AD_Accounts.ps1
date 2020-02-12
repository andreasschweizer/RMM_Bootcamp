<#
Copyright (C) 2019 Pascal Beetschen (diverto gmbh)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
<https://www.gnu.org/licenses/>.#>

<#
Beschreibung des Scripts:
Script erstellt ein Ticket, wenn aktive AD-Benutzer oder AD-Geräte seit einer gewissen Zeit nicht mehr angemeldet wurden.
Im Ticket werden weitere Informationen (auch im Ticketanhang) aufgelistet.

system requirements:
- windows server with AD-access
- Powershell Version 5 or higher

Editor:             Pascal Beetschen
Letzte Bearbeitung: 20.08.2019
#>

<# Variablen #>
$apiuser = $env:ATAPIuser01
$apiuserpw = $env:ATAPIuser01PW
$ApiKey = $env:ATAPIuser01TrackingID
$apiuserpw = $apiuserpw | ConvertTo-SecureString -asPlainText -Force
$PSACredentials = New-Object System.Management.Automation.PSCredential($apiuser,$apiuserpw)

$Date = Get-Date
$DateStr = $Date.ToString("dd_MM_yyyy")
$outputdir = "C:\divertoInstall\ADObjects"
$outputfile = "ADObjects_$DateStr.txt"
$outputfilepath = "$outputdir\$outputfile"

# Ordner erstellen, falls nötig
New-Item -ItemType Directory -Force -Path $outputdir
"Übersicht AD Objekte:" | Out-String -Width 4096 | Out-File $outputfilepath

$mybody = ""

$definitionOld = 90
$oldDate = (Get-Date).AddDays(-$definitionOld)


<# Funktionen #>
function CheckPowershell ($minVersion) {
    $myPSVersion = $PSVersionTable.PSVersion.Major
    if($myPSVersion -lt $minVersion){
        Write-Output "[FEHLER] Nötige Powershell Version $minVersion ist nicht installiert. Installierte Powershell Version: $myPSVersion. Script wird beendet"
        exit 1
    }
}


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

function New-Ticket ([string]$body) {
    # Body anpassen
    $body = "Server: $env:COMPUTERNAME`n$body"

    # Fälligkeit Ticket
    $DueDateTime = (Get-Date -Hour "14" -Minute "00" -Second "00").AddDays(3)

    # Firma anhand Seriennummer suchen
    $Serialnumber = (Get-WmiObject -Class Win32_BIOS).SerialNumber
    $myDevice = (Get-AtwsInstalledProduct -SerialNumber $Serialnumber -Active $true)
    $searchCustomerID = $myDevice.AccountID
    if($null -ne $searchCustomerID){
        if($searchCustomerID.Count -eq 1){
            Write-Output "[ERFOLGREICH] Firma konnte anhand Seriennummer eindeutig gefunden werden."
            $CustomerID = $searchCustomerID
        }
    }

    # Firma anhand Computernamen suchen
    if($null -eq $CustomerID){
        $myDevice = (Get-AtwsInstalledProduct -ReferenceTitle $env:COMPUTERNAME -Active $true)
        $searchCustomerID = $myDevice.AccountID
        if($null -ne $searchCustomerID){
            if($searchCustomerID.Count -eq 1){
                Write-Output "[ERFOLGREICH] Firma konnte anhand Gerätenamen eindeutig gefunden werden."
                $CustomerID = $searchCustomerID
            }
            else {
                Write-Output "[FEHLER] Firma konnte nicht eindeutig gefunden werden."
                Write-Output "Ticket wird auf default Autotask Account erstellt"
                $CustomerID = 0
            }
        }
        else {
            Write-Output "[FEHLER] Firma konnte nicht eindeutig gefunden werden."
            Write-Output "Ticket wird auf default Autotask Account erstellt"
            $CustomerID = 0
        }
    }

    if($null -eq $CustomerID)
    {
        Write-Output "Server / Gerät kann weder anhand von Seriennummer noch von Computernamen zugewiesen werden (mit Autotask)."
    }

    Write-Output "Firmen-ID: $CustomerID"

    # Ticket erstellen
    if($CustomerID -eq 0){
        $myTicket = New-AtwsTicket -AccountID $CustomerID -Title "AD Benutzer/Geräte seit $definitionOld Tagen inaktiv" -Description $body -Status Neu -Priority Niedrig -QueueID "1st Level" -DueDateTime $DueDateTime
    }
    else{
        # Wenn Kunde gefunden wurde - Gerät dem Ticket hinzufügen
        $myTicket = New-AtwsTicket -AccountID $CustomerID -Title "AD Benutzer/Geräte seit $definitionOld Tagen inaktiv" -Description $body -Status Neu -Priority Niedrig -QueueID "1st Level" -DueDateTime $DueDateTime -InstalledProductID $myDevice.ID
    }
    
    if($null -ne $myticket){
        Write-Output "[ERFOLGREICH] Autotask Ticket erfolgreich erstellt."

        $myTicketID = $myTicket.id
        # Anhang mit weiteren Infos zu den AD Benutzern an Ticket anfügen
        $myTicketAttachment = New-AtwsAttachment -Path $outputfilepath -TicketID $myTicketID -Title "ADObject details"
        # Erstellten Anhang überprüfen
        if($null -eq $myTicketAttachment){
            Write-Output "[FEHLER] Anhang konnte nicht an Ticket angehängt werden"
            Write-Output "Output hier ersichtlich oder via Textfile auf Gerät in folgendem Pfad: $outputfilepath"
            exit 1
        }
        else {
            Write-Output "[ERFOLGREICH] Anhang konnte an Ticket angehängt werden"
            exit 0
        }
    }
    else {
        Write-Output "[FEHLER] Autotask Ticket konnte nicht erstellt werden."
        exit 1
    }
}


<#
 __   __  _______  __   __  _______  _______  _______  _______  ___   ___     
|  | |  ||   _   ||  | |  ||       ||       ||       ||       ||   | |   |    
|  |_|  ||  |_|  ||  | |  ||    _  ||_     _||_     _||    ___||   | |   |    
|       ||       ||  |_|  ||   |_| |  |   |    |   |  |   |___ |   | |   |    
|       ||       ||       ||    ___|  |   |    |   |  |    ___||   | |   |___ 
|   _   ||   _   ||       ||   |      |   |    |   |  |   |___ |   | |       |
|__| |__||__| |__||_______||___|      |___|    |___|  |_______||___| |_______|
#>


CheckPowershell(5)

# Prüfung Zugriff auf Domain
$checkDomain = Get-ADDomain
if($null -eq $checkDomain){
    Write-Output "[FEHLER] Kein Zugriff auf Domäne. Script wird beendet"
    exit 1
}

# AD BENUTZER

$ADUsers = Get-ADUser -Properties Name, SamAccountName, mail, LastLogonDate, Distinguishedname -Filter 'Enabled -eq "True"'
Write-Output "Alle aktiven AD Benutzer:"
"Alle aktiven AD Benutzer:" >> $outputfilepath
if($null -ne $ADUsers)
{
    Write-Output $ADUsers | Sort-Object lastlogondate -Descending | Format-Table Name,SamAccountName,mail,lastlogondate -Wrap
    $ADUsers | Sort-Object lastlogondate -Descending | Format-Table Name,SamAccountName,mail,lastlogondate | Out-String -Width 4096 | Out-File -Append $outputfilepath
}
else
{
    Write-Output "Keine Benutzer gefunden"
    "Keine Benutzer gefunden" >> $outputfilepath
}

$activeADUsers = $ADUsers | Where-Object {$_.lastlogondate -gt $oldDate}
Write-Output "Benutzer, die in den letzten $definitionOld Tagen angemeldet waren:"
"Benutzer, die in den letzten $definitionOld Tagen angemeldet waren:" >> $outputfilepath
if($null -ne $activeADUsers)
{
    Write-Output $activeADUsers | Sort-Object lastlogondate -Descending | Format-Table Name,SamAccountName,mail,lastlogondate -Wrap
    $activeADUsers | Sort-Object lastlogondate -Descending | Format-Table Name,SamAccountName,mail,lastlogondate | Out-String -Width 4096 | Out-File -Append $outputfilepath
}
else
{
    Write-Output "Keine Benutzer gefunden"
    "Keine Benutzer gefunden" >> $outputfilepath
}

$oldADUsers = $ADUsers | Where-Object {$_.lastlogondate -le $oldDate}
Write-Output "Benutzer, die seit $definitionOld Tagen nicht mehr angemeldet waren:"
"Benutzer, die seit $definitionOld Tagen nicht mehr angemeldet waren:" >> $outputfilepath
if($null -ne $oldADUsers)
{
    Write-Output $oldADUsers | Sort-Object lastlogondate -Descending | Format-Table Name,SamAccountName,mail,lastlogondate,Distinguishedname -Wrap
    $oldADUsers | Sort-Object lastlogondate -Descending | Format-Table Name,SamAccountName,mail,lastlogondate,Distinguishedname | Out-String -Width 4096 | Out-File -Append $outputfilepath
    $mybody += "Benutzer, die seit $definitionOld Tagen nicht mehr angemeldet waren:"
    $mybody +=  $oldADUsers | Sort-Object lastlogondate -Descending | Format-Table SamAccountName,lastlogondate -Wrap | Out-String
}
else
{
    Write-Output "Keine Benutzer gefunden"
    "Keine Benutzer gefunden" >> $outputfilepath
}







# AD DEVICES

$ADDevices = Get-ADComputer -Properties Name, LastLogonDate, Distinguishedname -Filter 'Enabled -eq "True"'
Write-Output "Alle aktiven AD devices:"
"Alle aktiven AD Devices:" >> $outputfilepath
if($null -ne $ADDevices)
{
    Write-Output $ADDevices | Sort-Object lastlogondate -Descending | Format-Table Name,lastlogondate -Wrap
    $ADDevices | Sort-Object lastlogondate -Descending | Format-Table Name,lastlogondate | Out-String -Width 4096 | Out-File -Append $outputfilepath
}
else
{
    Write-Output "Keine Devices gefunden"
    "Keine Devices gefunden" >> $outputfilepath
}

$activeADDevices = $ADDevices | Where-Object {$_.lastlogondate -gt $oldDate}
Write-Output "Devices, die in den letzten $definitionOld Tagen angemeldet waren:"
"Devices, die in den letzten $definitionOld Tagen angemeldet waren:" >> $outputfilepath
if($null -ne $activeADDevices)
{
    Write-Output $activeADDevices | Sort-Object lastlogondate -Descending | Format-Table Name,lastlogondate -Wrap
    $activeADDevices | Sort-Object lastlogondate -Descending | Format-Table Name,lastlogondate | Out-String -Width 4096 | Out-File -Append $outputfilepath
}
else
{
    Write-Output "Keine Devices gefunden"
    "Keine Devices gefunden" >> $outputfilepath
}

$oldADDevices = $ADDevices | Where-Object {$_.lastlogondate -le $oldDate}
Write-Output "Devices, die seit $definitionOld Tagen nicht mehr angemeldet waren:"
"Devices, die seit $definitionOld Tagen nicht mehr angemeldet waren:" >> $outputfilepath
if($null -ne $oldADDevices)
{
    Write-Output $oldADDevices | Sort-Object lastlogondate -Descending | Format-Table Name,lastlogondate,Distinguishedname -Wrap
    $oldADDevices | Sort-Object lastlogondate -Descending | Format-Table Name,lastlogondate,Distinguishedname | Out-String -Width 4096 | Out-File -Append $outputfilepath
    $mybody += ""
    $mybody += "Geräte, die seit $definitionOld Tagen nicht mehr angemeldet waren:"
    $mybody +=  $oldADDevices | Sort-Object lastlogondate -Descending | Format-Table Name,lastlogondate -Wrap | Out-String
}
else
{
    Write-Output "Keine Devices gefunden"
    "Keine Devices gefunden" >> $outputfilepath
}


# Autotask Ticket erstellen, wenn alte Benutzer oder Devices gefunden wurden.
if($null -ne $oldADUsers -or $null -ne $oldADDevices){
    Write-Output ""
    Write-Output "Autotask Ticket wird erstellt."

    # Autotask verbinden
    New-APIconnectionATWS
    # Autotask Ticket erstellen
    New-Ticket($mybody)
}
else {
    Write-Output "Keine längere Zeit inaktiven Benutzer / Devices gefunden. Es wird kein Ticket erstellt."
    exit 0
}