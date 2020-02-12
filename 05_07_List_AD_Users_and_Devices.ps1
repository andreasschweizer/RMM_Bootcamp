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
- Auflistung aktive AD-User/Geräte
- Ausnahmen definierbar
- OU Parameter möglich (Dann werden nur User/Geräte unterhalb der OU angezeigt)

Editor:             Pascal beetschen
Letzte Bearbeitung: 26.08.2019
#>

<#
Systemvoraussetzungen:
- windows server with AD-access
- Powershell Version 5 or higher
#>

<# Variablen #>
$stringuserExceptions = $env:userExceptions
$userExceptions = $stringuserExceptions.Split(",")

$stringdeviceExceptions = $env:deviceExceptions
$deviceExceptions = $stringdeviceExceptions.Split(",")

$searchOU = $env:searchOU

<# Funktionen #>
function CheckPowershell ($minVersion) {
    $myPSVersion = $PSVersionTable.PSVersion.Major
    if($myPSVersion -lt $minVersion){
        Write-Output "[FEHLER] Nötige Powershell Version $minVersion ist nicht installiert. Installierte Powershell Version: $myPSVersion. Script wird beendet"
        exit 1
    }
    else {
        Write-output "[ERFOLGREICH] Powershell Version kompatibel."
    }
}

function CheckADAccess {
    $checkDomain = Get-ADDomain
    if($null -eq $checkDomain){
        Write-Output "[FEHLER] Kein Zugriff auf Domäne. Script wird beendet"
        exit 1
    }
    else {
        Write-Output "[ERFOLGREICH] Zugriff auf Domäne möglich."
        Write-Output ""
    }
}

function GetOU ($canonicalname){
    $OUArray = $null
    $myOU = $null
    $OUArray = $canonicalname.Split("/")
    for($i = 0; $i -lt $OUArray.Count -1; $i++)
    {
        $myOU += $OUArray[$i]
        $myOU += "/"
    }
    return $myOU
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

# Powershell Version überprüfen
CheckPowershell(5)

# Zugriff auf Domain überprüfen
CheckADAccess

# Suchbasis ausgeben
if($null -eq $searchOU -or $searchOU -eq ""){
    Write-Output "Searchbase: complete forest"
}
else{
    Write-Output "Searchbase: $searchOU"
}


#
# AD BENUTZER
#

# AD Benutzer anhand searchOU Parameter suchen
if($null -eq $searchOU -or $searchOU -eq ""){
    $ADUsers = Get-ADUser -Properties * -Filter 'Enabled -eq "True"'
}
else {
    $ADUsers = Get-ADUser -Properties * -SearchBase $searchOU -SearchScope Subtree -Filter 'Enabled -eq "True"'
}


if($null -ne $ADUsers){
    # Ausnahmen entfernen
    $tempADUsers = $ADUsers
    $ADUsers = @()
    foreach($tempADUser in $tempADUsers){
        if($tempADUser.SamAccountName -notin $userExceptions){
            $ADUsers += $tempADUser
        }
        else{
            $exceptionUser = $tempADUser.SamAccountName
            Write-Output "Ausnahme gegriffen: $exceptionUser"
        }
    }
}
else{
    Write-Output "[WARNUNG] Keine AD User gefunden."
}

# Prüfung wird nochmals durchgeführt, da es nun sein könnte, dass plötzlich keine Benutzer mehr vorhanden sind. (Nach Ausnahmen entfernen)
if($null -ne $ADUsers)
{
# OUs auslesen
$allUserOUs = @()
foreach($ADUser in $ADUsers){
    $ADUserOU = GetOU($ADUser.canonicalname)
    if($ADUserOU -notin $allUserOUs){
        $allUserOUs += $ADUserOU
    }
}

# Übersicht ausgeben
$allUserOUsamount = $allUserOUs.Count
$ADUsersamount = $ADUsers.Count
Write-Output "Es wurden $ADUsersamount User in $allUserOUsamount OUs gefunden:"
Write-Output ""

# OUs sortieren
$allUserOUs = $allUserOUs | Sort-Object

# Ausgabe Objekte sortiert nach OU
foreach($UserOU in $allUserOUs){
    $ADUsersSameOU = @()
    Write-Output "OU: $UserOU"
    foreach($ADUser in $ADUsers){
        if((GetOU($ADUser.canonicalname)) -eq $UserOU){
            $ADUsersSameOU += $ADUser
        }
    }
    Write-Output $ADUsersSameOU | Sort-Object lastlogondate -Descending | Format-Table Name,SamAccountName,mail,lastlogondate | Out-String -Width 8192
}

}
else {
    Write-Output "[WARNUNG] Keine AD User gefunden."
}


Write-Output ""



#
# AD DEVICES
#

# AD DEVICES anhand searchOU Parameter suchen
if($null -eq $searchOU -or $searchOU -eq ""){
    $ADDevices = Get-ADComputer -Properties * -Filter 'Enabled -eq "True"'
}
else {
    $ADDevices = Get-ADComputer -Properties * -SearchBase $searchOU -SearchScope Subtree -Filter 'Enabled -eq "True"'
}


if($null -ne $ADDevices){
    # Ausnahmen entfernen
    $tempADDevices = $ADDevices
    $ADDevices = @()
    foreach($tempADDevice in $tempADDevices){
        if($tempADDevice.Name -notin $deviceExceptions){
            $ADDevices += $tempADDevice
        }
        else{
            $exceptionDevice = $tempADDevice.Name
            Write-Output "Ausnahme gegriffen: $exceptionDevice"
        }
    }
}
else{
    Write-Output "[WARNUNG] Keine AD devices gefunden."
}

# Prüfung wird nochmals durchgeführt, da es nun sein könnte, dass plötzlich keine devices mehr vorhanden sind. (Nach Ausnahmen entfernen)
if($null -ne $ADDevices)
{
# OUs auslesen
$allDeviceOUs = @()
foreach($ADDevice in $ADDevices){
    $ADDeviceOU = GetOU($ADDevice.canonicalname)
    if($ADDeviceOU -notin $allDeviceOUs){
        $allDeviceOUs += $ADDeviceOU
    }
}

# Übersicht ausgeben
$allDeviceOUsamount = $allDeviceOUs.Count
$ADDevicesamount = $ADDevices.Count
Write-Output "Es wurden $ADDevicesamount devices in $allDeviceOUsamount OUs gefunden:"
Write-Output ""

# OUs sortieren
$allDeviceOUs = $allDeviceOUs | Sort-Object

# Ausgabe Objekte sortiert nach OU
foreach($DeviceOU in $allDeviceOUs){
    $ADDevicesSameOU = @()
    Write-Output "OU: $DeviceOU"
    foreach($ADDevice in $ADDevices){
        if((GetOU($ADDevice.canonicalname)) -eq $DeviceOU){
            $ADDevicesSameOU += $ADDevice
        }
    }
    Write-Output $ADDevicesSameOU | Sort-Object lastlogondate -Descending | Format-Table Name,lastlogondate | Out-String -Width 8192
}

}
else {
    Write-Output "[WARNUNG] Keine AD devices gefunden."
}