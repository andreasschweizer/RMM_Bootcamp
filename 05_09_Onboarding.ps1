<#
Copyright (C) 2019 Pascal Beetschen, Sascha Spring, Tim Leuenberger (diverto gmbh)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
<https://www.gnu.org/licenses/>.#>

#Version 1.3.7 (Ticketcreation Shortcuts)

#ACHTUNG: Gerät wird während der Installation neugestartet!

#-eq gleich
#-ne ungleich
#-lt kleiner
#-le kleiner oder gleich
#-gt größer
#-ge größer oder gleich

Write-Output "diverto_Grundinstallation Skript gestartet"

#----------------------------------------------------------------------------------------------------------------------------
# Zwingende Teile vom Skript, welche am Anfang ausgeführt werden müssen
#----------------------------------------------------------------------------------------------------------------------------

#Log erstellen
$divOnboarding = [System.Diagnostics.EventLog]::SourceExists("divOnboarding")
if ($divOnboarding -eq $true)
{
    Write-Output "EventLog divOnboarding ist bereits vorhanden"
}
else 
{ 
    new-eventlog -source divOnboarding -logname "divertoEvents"
}

#Powershell Version Prüfung -> OK
Write-Output "Powershell wird auf Version geprüft`n"

$PSVersion = $PSVersionTable.PSVersion.Major
Write-Output "Powershell Version: $PSVersion"

if ($PSVersion -lt 5)
{
Write-Output "Zu alte Powershell Version. Bitte installieren Sie mindestens Powershell v5."
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 500 -Message "Zu alte Powershell Version. Bitte installieren Sie mindestens Powershell v5."
exit 1
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Variable, ob das Skript bereits komplett durchlaufen ist
try
{
$ScriptFinished = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Data -Name ScriptFinished
}
catch
{
$ScriptFinished = 1
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Data -Name "ScriptFinished" -value $ScriptFinished -Force
Write-Output "ScriptFinished-Wert konnte nicht ausgelesen werden, er wird nun auf 1 gesetzt. Falls bereits eine Warnung im AEM besteht, muss diese manuell abgeschlossen werden."
}

#Wenn Wert auf 0, dann ist die Grundinstallation bereits abgeschlossen, das Skript wird beendet.
if($ScriptFinished -eq 0)
{
Write-Output "Grundinstallation / Onboarding bereits abgeschlossen, Skript wird beendet."
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 3002 -Message "Grundinstallation / Onboarding bereits abgeschlossen, Skript wird beendet."
exit 0
}

#Wie viele Male soll neugestartet werden / Wie viele Male wurde bereits neugestartet. (Auslesen der Variablen)
try
{
$CurrentReboots = [int](Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Data -Name CurrentReboots)
$RequiredReboots = [int](Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Data -Name RequiredReboots)
}
catch
{
$CurrentReboots = 0
$RequiredReboots = 1
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Data -Name "CurrentReboots" -value $CurrentReboots -Force
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Data -Name "RequiredReboots" -value $RequiredReboots -Force
}

#Ticketnummer definieren
try
{
$TicketNumber = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Data -Name TicketNumber
}
catch
{
$TicketNumber = "Ticketnummer unbekannt - "
}


#----------------------------------------------------------------------------------------------------------------------------
# Sobald alle nötigen Reboots durchgeführt wurden und keine weiteren Tasks mehr ausgeführt werden, ist die Grundinstallation abgeschlossen und die E-Mail wird versendet.
#----------------------------------------------------------------------------------------------------------------------------

if($CurrentReboots -eq $RequiredReboots)
{
$Summary = Get-Content C:\divertoInstall\OnBoarding_Summary.txt
Remove-Item C:\divertoInstall\OnBoarding_Summary.txt -Force -Recurse


if(Test-Path C:\divertoInstall\OnBoarding_Summary_Error.txt)
{
$Summary_Error = Get-Content C:\divertoInstall\OnBoarding_Summary_Error.txt
Remove-Item C:\divertoInstall\OnBoarding_Summary_Error.txt -Force -Recurse
}
else
{
$Summary_Error = "Es sind keine Probleme aufgetreten."    
}


$ScriptFinished = 0
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Data -Name "ScriptFinished" -value $ScriptFinished -Force
Write-Output "Grundinstallation ist nun abgeschlossen. Ticket / Projektaufgabe Notiz wird erstellt."

##### Auslösung Ticketnotiz auf Ticket #####
#######
# Autotask Modul installieren / importieren
Set-ExecutionPolicy Bypass -Force

# Autotask Modul installieren / importieren
Write-Output "Autotask Powershell Modul wird installiert."
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-PackageProvider NuGet -Force
Install-Module -Name Autotask -RequiredVersion 1.6.1.10
Import-Module Autotask -Force
$VerbosePreference ="Continue"
$ATusername = $env:ATAPIuser01
$ATsecpassword = $env:ATAPIuser01PW | ConvertTo-SecureString -asPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential($ATusername,$ATsecpassword)
$ApiKey = $env:ATAPIuser01TrackingID
# Verbindung mit Autotask
Connect-AtwsWebAPI -Credential $Credentials -ApiTrackingIdentifier $ApiKey -NoDiskCache
Set-ExecutionPolicy Restricted -Force
# Verbindung testen
$testconnection = Get-AtwsAccount -id 0
if($null -eq $testconnection)
{
    Write-Output "[FEHLER] Verbindung zu Autotask fehlgeschlagen"
    exit 1
}
else {
    Write-Output "[ERFOLGREICH] Verbindung Autotask erfolgreich."
}


#Effektive Auslösung Ticketnotiz auf Ticket
$title = "Grundinstallation für $env:Computername abgeschlossen"
$body = "Grundinstallation abgeschlossen.`n`nProbleme / Fehlermeldungen:`n$Summary_Error`n`nAbgeschlossene Tasks:`n$Summary"
#Überprüfung ob es sich um ein Ticket oder Projektaufgabe handelt.
if((Get-AtwsTicket -TicketNumber $TicketNumber).Count -gt 0)
{
Write-Host "Ticket wurde gefunden. Benachrichtigung wird ausgelöst."
New-AtwsTicketNote -TicketID (Get-AtwsTicket -TicketNumber $TicketNumber).id -Title $title -Description $body -NoteType "Interne Notizen" -Publish "Internal Project Team"
}else{Write-Host "Ticket konnte nicht gefunden werden"}
if((Get-AtwsTask -TaskNumber $TicketNumber).Count -gt 0)
{
Write-Host "Projektaufgabe wurde gefunden. Benachrichtigung wird ausgelöst."
New-AtwsTaskNote -TaskID (Get-AtwsTask -TaskNumber $TicketNumber).id -Title $title -Description $body -NoteType 'Interne Notizen' -Publish "Internal Project Team"
}else{Write-Host "Projektaufgabe konnte nicht gefunden werden"}
#######

Start-Sleep 5

exit 0
}


#----------------------------------------------------------------------------------------------------------------------------
# FUNKTIONEN
#----------------------------------------------------------------------------------------------------------------------------

#Startet das Gerät neu
function DoReboot{
$Script:CurrentReboots = $CurrentReboots + 1
$Script:RequiredReboots = $RequiredReboots + 1
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Data -Name "CurrentReboots" -value $CurrentReboots -Force
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Data -Name "RequiredReboots" -value $RequiredReboots -Force
shutdown -r -t 5
exit 0
}

#Checkliste wird aus den verschiedenen Tasks zusammengestellt
#Variable ChecklistDoReboot = 1 -> Ein Task erfordert einen Neustart. Nachfolgende Tasks werden nicht in Checkliste aufgelistet
#Variable ChecklistDoReboot = 0 -> Kein Task benötigt einen Reboot. Nachfolgende Tasks werden in Checkliste aufgelistet
function GetChecklist{
if($Script:ChecklistDoReboot -eq "1") {return}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name folderDivertoInstall) -eq "1") { $Script:Checklist = $Checklist + "`n" + "folderDivertoInstall"}
if($Script:ChecklistDoReboot -eq "1") {return}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingLocalAdmin) -eq "1") { $Script:Checklist = $Checklist + "`n" + "settingLocalAdmin"}
if($Script:ChecklistDoReboot -eq "1") {return}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingDeviceName) -eq "1") { $Script:Checklist = $Checklist + "`n" + "settingDeviceName"
$Script:ChecklistDoReboot = "1"}
if($Script:ChecklistDoReboot -eq "1") {return}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name programNinite) -eq "1") { $Script:Checklist = $Checklist + "`n" + "programNinite"
$Script:ChecklistDoReboot = "1"}
if($Script:ChecklistDoReboot -eq "1") {return}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingLanguage) -eq "1") { $Script:Checklist = $Checklist + "`n" + "settingLanguage"}
if($Script:ChecklistDoReboot -eq "1") {return}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingSSDNoDefrag) -eq "1") { $Script:Checklist = $Checklist + "`n" + "settingSSDNoDefrag"}
if($Script:ChecklistDoReboot -eq "1") {return}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name checkWinActivation) -eq "1") { $Script:Checklist = $Checklist + "`n" + "checkWinActivation"}
if($Script:ChecklistDoReboot -eq "1") {return}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name checkDrivers) -eq "1") { $Script:Checklist = $Checklist + "`n" + "checkDrivers"}
if($Script:ChecklistDoReboot -eq "1") {return}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingSearchProvider) -eq "1") { $Script:Checklist = $Checklist + "`n" + "settingSearchProvider"}
if($Script:ChecklistDoReboot -eq "1") {return}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingStartPageGoogle) -eq "1") { $Script:Checklist = $Checklist + "`n" + "settingStartPageGoogle"}
if($Script:ChecklistDoReboot -eq "1") {return}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingWallpaperDiverto) -eq "1") { $Script:Checklist = $Checklist + "`n" + "settingWallpaperDiverto"}
if($Script:ChecklistDoReboot -eq "1") {return}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingDesktopIcons) -eq "1") { $Script:Checklist = $Checklist + "`n" + "settingDesktopIcons"}
if($Script:ChecklistDoReboot -eq "1") {return}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingFolderoptions) -eq "1") { $Script:Checklist = $Checklist + "`n" + "settingFolderoptions"}
if($Script:ChecklistDoReboot -eq "1") {return}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingUAC) -eq "1") { $Script:Checklist = $Checklist + "`n" + "settingUAC"}
if($Script:ChecklistDoReboot -eq "1") {return}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name newUser) -eq "1") { $Script:Checklist = $Checklist + "`n" + "newUser"}
if($Script:ChecklistDoReboot -eq "1") {return}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name deleteUserUser) -eq "1") { $Script:Checklist = $Checklist + "`n" + "deleteUserUser"}
if($Script:ChecklistDoReboot -eq "1") {return}
}


#Funktion für Logs, bzw. Summary, welches zum Schluss per E-Mail versendet wird.
function LogSummary($LogLine, $LogError){
#$curTime = Get-Date -format "[dd.MM HH:mm:ss]"

#evtl. <br /> nach LogLines einfügen, damit Mail Absätze hat.
if($LogError) {Write-Output "- $LogLine<br />" >> C:\divertoInstall\OnBoarding_Summary_Error.txt}
else {Write-Output "- $LogLine<br />" >> C:\divertoInstall\OnBoarding_Summary.txt}
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Registry Prüfung -> OK
Write-Output "Registry wird auf Basiszustand geprüft`n"

if ((Test-Path "HKLM:\SOFTWARE\diverto\Basic") -And (Test-Path "HKLM:\SOFTWARE\diverto\Basic\Checklist") -And (Test-Path "HKLM:\SOFTWARE\diverto\Basic\Data"))
{
Write-Output "Basisschlüssel existieren (Pfad HKLM\SOFTWARE\diverto\)`nBasic`nBasic\Checklist`nBasic\Data"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 501 -Message "Basisschlüssel existieren (Pfad HKLM\SOFTWARE\diverto\)`nBasic`nBasic\Checklist`nBasic\Data"
}
else
{
Write-Output "FEHLER! Basisschlüssel können nicht gefunden werden! (Pfad HKLM\SOFTWARE\diverto\)`nBasic`nBasic\Checklist`nBasic\Data"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 501 -Message "FEHLER! Basisschlüssel können nicht gefunden werden! (Pfad HKLM\SOFTWARE\diverto\)`nBasic`nBasic\Checklist`nBasic\Data"
exit 1
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Parameter Zuweisung -> OK
Write-Output "Parameter werden zugewiesen`n"

#PCNAME
try
{
$PcName = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Data -Name PcName
}
catch
{
Write-Output "Parameter PcName konnte nicht gefunden werden. (Pfad HKLM:\SOFTWARE\diverto\Basic\Data)"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Warning -EventId 502 -Message "Parameter PcName konnte nicht gefunden werden. (Pfad HKLM:\SOFTWARE\diverto\Basic\Data)"
$PcName = ""
}

#Username
try
{
$parUsername = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Data -Name Username
}
catch
{
Write-Output "Parameter Username konnte nicht gefunden werden. (Pfad HKLM:\SOFTWARE\diverto\Basic\Data)"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Warning -EventId 502 -Message "Parameter Username konnte nicht gefunden werden. (Pfad HKLM:\SOFTWARE\diverto\Basic\Data)"
$parUsername = ""
}

#Ninite
try
{
$Niniteapps = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Data -Name Niniteapps
}
catch
{
Write-Output "Parameter Niniteapps konnte nicht gefunden werden. (Pfad HKLM:\SOFTWARE\diverto\Basic\Data)"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Warning -EventId 502 -Message "Parameter Niniteapps konnte nicht gefunden werden. (Pfad HKLM:\SOFTWARE\diverto\Basic\Data)"
$Niniteapps = ""
}

#Ticketnummer
try
{
New-ItemProperty -Path "HKLM:\Software\Centrastage"  -Name "custom4" -Value $TicketNumber -PropertyType STRING -Force | Out-Null
}
catch
{
Write-Output "Ticketnummer konnte nicht in Registry geschrieben werden"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Warning -EventId 502 -Message "Ticketnummer konnte nicht in Registry geschrieben werden"
}

Write-Output "Parameter wurden zugewiesen"

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Parameter Prüfung -> OK
Write-Output "Parameter werden überprüft`n"


#Überprüfung Parameter "PcName"
if ($PcName.Length -eq "")
{
Write-Output "Der Parameter für den Computernamen ist leer. Der Computername wird im Skript nicht geändert."
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Warning -EventId 503 -Message "Der Parameter für den Computernamen ist leer. Der Computername wird im Skript nicht geändert."
New-ItemProperty -Type String -Path HKLM:\Software\diverto\Basic\Checklist -Name "settingDeviceName" -value "2" -Force
}
if ($PcName.Length -gt 15)
{
$PcName = ""
Write-Output "Der Parameter für den Computernamen ist zu lang (maximal 15 Zeichen). Der Computername wird im Skript nicht geändert."
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Warning -EventId 503 -Message "Der Parameter für den Computernamen ist zu lang (maximal 15 Zeichen). Der Computername wird im Skript nicht geändert."
New-ItemProperty -Type String -Path HKLM:\Software\diverto\Basic\Checklist -Name "settingDeviceName" -value "2" -Force
New-ItemProperty -Type String -Path HKLM:\Software\diverto\Basic\Data -Name "PcName" -value "" -Force
}

#Überprüfung Parameter "Username"
if ($parUsername.Length -eq "")
{
Write-Output "Der Parameter für den Benutzername ist leer. Der Benutzer wird im Skript nicht erstellt."
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Warning -EventId 503 -Message "Der Parameter für den Benutzername ist leer. Der Benutzer wird im Skript nicht erstellt."
New-ItemProperty -Type String -Path HKLM:\Software\diverto\Basic\Checklist -Name "newUser" -value "2" -Force
}
if ($parUsername.Length -gt 20)
{
$parUsername = ""
Write-Output "Der Parameter für den Benutzername ist zu lang (maximal 20 Zeichen). Der Benutzer wird im Skript nicht erstellt."
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Warning -EventId 503 -Message "Der Parameter für den Benutzername ist zu lang (maximal 20 Zeichen). Der Benutzer wird im Skript nicht erstellt."
New-ItemProperty -Type String -Path HKLM:\Software\diverto\Basic\Checklist -Name "newUser" -value "2" -Force
New-ItemProperty -Type String -Path HKLM:\Software\diverto\Basic\Data -Name "Username" -value "" -Force
}

#Überprüfung Parameter "Niniteapps"
if ($Niniteapps.Length -eq "")
{
Write-Output "Es sind keine Parameter für NinitePro.exe hinterlegt. Der Ninite Prozess wird übersprungen."
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Warning -EventId 503 -Message "Es sind keine Parameter für NinitePro.exe hinterlegt. Der Ninite Prozess wird übersprungen."
New-ItemProperty -Type String -Path HKLM:\Software\diverto\Basic\Checklist -Name "programNinite" -value "2" -Force
}

Write-Output "`n"

Write-Output "Parameter wurden überprüft`n"

Write-Output "Folgende Parameter werden verwendet:"
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingDeviceName) -eq "1"){ Write-Output "PcName: $PcName"}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name newUser) -eq "1") { Write-Output "Neuer Benutzer: $parUsername"}
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name programNinite) -eq "1") { Write-Output "Niniteapps: $Niniteapps"}
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 503 -Message "PcName: $PCNAME`nNeuer Benutzer: $parUsername`nNiniteapps: $Niniteapps"

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Checkliste Prüfung -> OK
Write-Output "Checkliste wird überprüft`n"

#Checkliste ist am Anfang leer
$Checklist = ""
#Sobald ein Task mit nötigem Reboot ausgeführt wird, wird dieser Wert auf 1 geändert, damit die restlichen Checklisteneinträge nicht aufgelistet werden (In Funktion ersichtlich)
$ChecklistDoReboot = "0"
#Funktion aufrufen, welche Checkliste zusammenstellt
GetChecklist
Write-Output "Folgende Tasks werden ausgeführt:`n"
Write-Output $Checklist
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 504 -Message "Tasks:`n$Checklist"

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------
# TASKS STARTEN
#----------------------------------------------------------------------------------------------------------------------------

#divertoInstall Ordner erstellen - OK
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name folderDivertoInstall) -eq "1")
{
Write-Output "divertoInstall Ordner wird erstellt (C:\divertoInstall)`n"

try
{
New-Item -Path "C:\" -Name "divertoInstall" -ItemType directory -Force

New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name folderDivertoInstall -value "0" -Force
Write-Output "divertoInstall Ordner wurde erstellt"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 510 -Message "divertoInstall Ordner wurde erstellt"
LogSummary "divertoInstall Ordner wurde erstellt"
}
catch
{
Write-Output "divertoInstall Ordner konnte nicht erstellt werden"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 510 -Message "divertoInstall Ordner konnte nicht erstellt werden"
LogSummary "divertoInstall Ordner konnte nicht erstellt werden" Error
}
}
else
{
Write-Output "Task: `"divertoInstall Ordner erstellen`" wird übersprungen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 510 -Message "Task: `"divertoinstall Ordner erstellen`" wird übersprungen"
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#lokaler Administrator freischalten - OK
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingLocalAdmin) -eq "1")
{
Write-Output "lokaler Administrator wird freigeschaltet`n"

try
{
Enable-LocalUser -Name Administrator
$Password = $env:PW_local_admin
$PasswordSecure = ConvertTo-SecureString $Password -AsPlainText -Force
Set-LocalUser -Name Administrator -Password $PasswordSecure

New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingLocalAdmin -value "0" -Force
Write-Output "lokaler Administrator wurde freigeschaltet"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 511 -Message "lokaler Administrator wurde freigeschaltet"
LogSummary "lokaler Administrator wurde freigeschaltet"
}
catch
{
Write-Output "lokaler Administrator konnte nicht freigeschaltet werden"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 511 -Message "lokaler Administrator konnte nicht freigeschaltet werden"
LogSummary "lokaler Administrator konnte nicht freigeschaltet werden" Error
}
}
else
{
Write-Output "Task: `"lokaler Administrator freischalten`" wird übersprungen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 511 -Message "Task: `"lokaler Administrator freischalten`" wird übersprungen"
}

#Falls der Benutzer "User" existiert, wird diesem ein Passwort gegeben, damit er nicht automatisch angemeldet wird und dieser später gelöscht werden kann.
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name deleteUserUser) -eq "1")
{
try
{
net user User "Start123."
}
catch
{}
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Computername ändern - OK
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingDeviceName) -eq "1")
{
Write-Output "Computername wird in $PcName geändert`n"

try
{
if ((Get-ItemPropertyValue -Path HKLM:\SYSTEM\ControlSet001\Control\ComputerName\ActiveComputerName -Name ComputerName) -eq $PcName)
{
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingDeviceName -value "0" -Force
Write-Output "Task: `"Computername ändern`" wird übersprungen, da der aktuelle Computername mit dem gewünschten Computernamen übereinstimmt"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 512 -Message "Task: `"Computername ändern`" wird übersprungen, da der aktuelle Computername mit dem gewünschten Computernamen übereinstimmt"
}
else
{
Rename-Computer -NewName $PcName
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingDeviceName -value "0" -Force
Write-Output "Computername wurde in $PcName geändert`n"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 512 -Message "Computername wurde in $PcName geändert`n"
LogSummary "Computername wurde in $PcName geändert"
Write-Output "Gerät wird neugestartet, da der Computername geändert wurde"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Warning -EventId 512 -Message "Gerät wird neugestartet, da der Computername geändert wurde"
DoReboot
}
}
catch
{
Write-Output "Computername konnte nicht geändert werden"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 512 -Message "Computername konnte nicht geändert werden"
LogSummary "Computername konnte nicht geändert werden" Error
}
}
else
{
Write-Output "Task: `"Computername ändern`" wird übersprungen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 512 -Message "Task: `"Computername ändern`" wird übersprungen"
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Ninite Apps installieren - OK
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name programNinite) -eq "1")
{
Write-Output "Ninite Apps werden installiert`n"

Copy-Item .\NinitePro.exe C:\divertoInstall\NinitePro.exe -Recurse -Force

try
{
$pinfo = New-Object System.Diagnostics.ProcessStartInfo
#$pinfo.CreateNoWindow = $true
$pinfo.FileName = "C:\divertoInstall\NinitePro.exe"
#$pinfo.WindowStyle = 'Hidden'
$pinfo.UseShellExecute = $false
$pinfo.Arguments = "/select $Niniteapps /silent C:\Users\Administrator\Desktop\report.txt /disableautoupdate /disableshortcuts /allusers"
$p = New-Object System.Diagnostics.Process
$p.StartInfo = $pinfo
$p.Start() | Out-Null
Write-Output "Ninite wurde mit folgenden Programm-Parametern gestartet: $Niniteapps`n"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 513 -Message "Ninite wurde mit folgenden Programm-Parametern gestartet: $Niniteapps`n"
$p.WaitForExit()

$code = $p.ExitCode
Write-Output "Ninite Exitcode: $code"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 513 -Message "Ninite Exitcode: $code"

if($code -ne 0)
{
Write-Output "Ninite wurde mit einem Fehler beendet`n"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 513 -Message "Ninite wurde mit einem Fehler beendet`n"
Dies ist ein Fehler
}

New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name programNinite -value "0" -Force
Write-Output "Ninite Apps wurden erfolgreich installiert"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 513 -Message "Ninite Apps wurden erfolgreich installiert"
LogSummary "Ninite Apps wurden erfolgreich installiert"


#Standardprogramme werden definiert - Chrome & Adobe Acrobat
Copy-Item .\DefaultApps.xml C:\divertoInstall\DefaultApps.xml -Recurse -Force
Dism.exe /Online /Import-DefaultAppAssociations:C:\divertoInstall\DefaultApps.xml
Write-Output "Chrome / Adobe Acrobat wurden als Standardprogramme eingestellt"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 513 -Message "Chrome / Adobe Acrobat wurden als Standardprogramme eingestellt"
LogSummary "Chrome / Adobe Acrobat wurden als Standardprogramme eingestellt"


Write-Output "Gerät wird neugestartet, da Ninite Apps installiert wurden"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Warning -EventId 513 -Message "Gerät wird neugestartet, da Ninite Apps installiert wurden"
DoReboot
}
catch
{
Write-Output "Ninite Apps konnten nicht installiert werden"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 513 -Message "Ninite Apps konnten nicht installiert werden"
LogSummary "Ninite Apps konnten nicht installiert werden & Standardprogramme konnnten nicht eingestellt werden" Error
}
}
else
{
Write-Output "Task: `"Ninite Apps installieren`" wird übersprungen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 513 -Message "Task: `"Ninite Apps installieren`" wird übersprungen"
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Spracheinstellungen anpassen (Deutsch Schweiz) - OK
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingLanguage) -eq "1") {
Write-Output "Spracheinstellungen werden auf Deutsch (Schweiz) umgestellt`n"

Import-Module international
try
{
#Installierte Sprachen herausfinden: (Tastatur-ID)
$LongStringSprache = dism /online /get-intl | Select-String -Pattern ":00"
#String "verschönern"
$BrauchbarerStringSprache = $LongStringSprache -replace ".*: "

#4 mögliche Sprachen herauslesen (erweiterbar)
$1 = $BrauchbarerStringSprache -replace ",.*"
$2 = $BrauchbarerStringSprache -replace "$1, " -replace ",.*"
$3 = $BrauchbarerStringSprache -replace "$1, $2, " -replace ",.*"
$4 = $BrauchbarerString -replace "$1, $2, $3, " -replace ",.*"

#XML File schreiben, mit dem die Sprache geändert werden kann
Write-Output '<gs:GlobalizationServices xmlns:gs="urn:longhornGlobalizationUnattend">' >C:\divertoInstall\local2.xml
Write-Output '<!--User List-->' >>C:\divertoInstall\local2.xml
Write-Output '<gs:UserList>' >>C:\divertoInstall\local2.xml
Write-Output '<gs:User UserID="Current" CopySettingsToDefaultUserAcct="true" CopySettingsToSystemAcct="true"/>' >>C:\divertoInstall\local2.xml
Write-Output '</gs:UserList>' >>C:\divertoInstall\local2.xml
Write-Output '<!--Keyboard preferences-->' >>C:\divertoInstall\local2.xml
Write-Output '<gs:InputPreferences>' >>C:\divertoInstall\local2.xml
Write-Output '<!--Add keyboard CH(Deutsch - Schweiz)-->' >>C:\divertoInstall\local2.xml
Write-Output '<gs:InputLanguageID Action="add" ID="0807:00000807" Default="true"/>' >>C:\divertoInstall\local2.xml
Write-Output '<gs:InputLanguageID Action="remove" ID="100c:0000100c"/>' >>C:\divertoInstall\local2.xml

#If-Abfragen: Es sollen alle Sprachen entfernt werden ausser Deutsch(Schweiz)
if($1-ne"0807:00000807" -and $1-ne""){ $XMLStringIDSprache = '<gs:InputLanguageID Action="remove" ID="'+$1+'"/>'
Write-Output $XMLStringIDSprache >>C:\divertoInstall\local2.xml}
if($2-ne"0807:00000807" -and $2-ne"" -and $2-ne$1){ $XMLStringIDSprache = '<gs:InputLanguageID Action="remove" ID="'+$2+'"/>'
Write-Output $XMLStringIDSprache >>C:\divertoInstall\local2.xml}
if($3-ne"0807:00000807" -and $3-ne"" -and $3-ne$1 -and $3-ne$2){ $XMLStringIDSprache = '<gs:InputLanguageID Action="remove" ID="'+$3+'"/>'
Write-Output $XMLStringIDSprache >>C:\divertoInstall\local2.xml}
if($4-ne"0807:00000807" -and $4-ne"" -and $4-ne$1 -and $4-ne$2 -and $4-ne$3){ $XMLStringIDSprache = '<gs:InputLanguageID Action="remove" ID="'+$4+'"/>'
Write-Output $XMLStringIDSprache >>C:\divertoInstall\local2.xml}
Write-Output '</gs:InputPreferences>' >>C:\divertoInstall\local2.xml
Write-Output '<!--Locale-->' >>C:\divertoInstall\local2.xml
Write-Output '<gs:LocationPreferences>' >>C:\divertoInstall\local2.xml
Write-Output '<gs:GeoID Value="223"/>' >>C:\divertoInstall\local2.xml
Write-Output '</gs:LocationPreferences>' >>C:\divertoInstall\local2.xml
Write-Output '<!--User Locale-->' >>C:\divertoInstall\local2.xml
Write-Output '<gs:UserLocale>' >>C:\divertoInstall\local2.xml
Write-Output '<gs:Locale Name="de-CH" SetAsCurrent="true"/>' >>C:\divertoInstall\local2.xml
Write-Output '</gs:UserLocale>' >>C:\divertoInstall\local2.xml
Write-Output '</gs:GlobalizationServices>' >>C:\divertoInstall\local2.xml

#Spracheinstellungen in Systemsteuerung anpassen mit erstelltem XML-File
control 'intl.cpl,,/f:"C:\divertoInstall\local2.xml"'

New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingLanguage -value "0" -Force
Write-Output "Spracheinstellungen wurden auf Deutsch (Schweiz) umgestellt"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 514 -Message "Spracheinstellungen wurden auf Deutsch (Schweiz) umgestellt"
LogSummary "Spracheinstellungen wurden auf Deutsch (Schweiz) umgestellt"
}
catch
{
Write-Output "Spracheinstellungen konnten nicht auf Deutsch (Schweiz) umgestellt werden"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 514 -Message "Spracheinstellungen konnten nicht auf Deutsch (Schweiz) umgestellt werden"
LogSummary "Spracheinstellungen konnten nicht auf Deutsch (Schweiz) umgestellt werden" Error
}
}
else
{
Write-Output "Task: `"Spracheinstellungen anpassen (Deutsch Schweiz)`" wird übersprungen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 514 -Message "Task: `"Spracheinstellungen anpassen (Deutsch Schweiz)`" wird übersprungen"
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Standardsuchanbierer auf Google anpassen - OK
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingSearchProvider) -eq "1")
{
Write-Output "diverto wird in Chrome als Favorit hinzugefügt & Suchprovider im Internet Explorer wird auf Google geändert`n"

try
{
#Chrome - diverto als Favorit - Lesezeichenleiste einblenden
mkdir "C:\Users\Default\AppData\Local\Google\Chrome\User Data\Default\" -Force
Copy-Item ".\Bookmarks" "C:\Users\Default\AppData\Local\Google\Chrome\User Data\Default\Bookmarks" -Recurse -Force
#Damit das Symbol korrekt angezeigt wird
Copy-Item ".\Favicons" "C:\Users\Default\AppData\Local\Google\Chrome\User Data\Default\Favicons" -Recurse -Force
Write-Output "diverto wurde in Chrome als Favorit hinzugefügt"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 515 -Message "diverto wurde in Chrome als Favorit hinzugefügt"
LogSummary "diverto wurde in Chrome als Favorit hinzugefügt"


#Standardsuchanbieter auf Google wechseln
reg LOAD "HKey_users\DefaultProfiles" "C:\Users\Default\ntuser.dat"

reg add "HKEY_USERS\DefaultProfiles\SOFTWARE\Microsoft\Internet Explorer\SearchScopes" /v "DefaultScope" /t REG_SZ /d "{523578E1-643D-43BB-8840-A021BF2B23AB}" /f
reg add "HKEY_USERS\DefaultProfiles\SOFTWARE\Microsoft\Internet Explorer\SearchScopes\{523578E1-643D-43BB-8840-A021BF2B23AB}" /v "DisplayName" /t REG_SZ /d "Google" /f
reg add "HKEY_USERS\DefaultProfiles\SOFTWARE\Microsoft\Internet Explorer\SearchScopes\{523578E1-643D-43BB-8840-A021BF2B23AB}" /v "URL" /t REG_SZ /d "http://www.google.com/search?q={searchTerms}&sourceid=ie7&rls=com.microsoft:{language}:{referrer:source}&ie={inputEncoding?}&oe={outputEncoding?}" /f
reg add "HKEY_USERS\DefaultProfiles\SOFTWARE\Microsoft\Internet Explorer\SearchScopes\{523578E1-643D-43BB-8840-A021BF2B23AB}" /v "SuggestionsURL" /t REG_SZ /d "http://clients5.google.com/complete/search?q={searchTerms}&hl=en-gb&gl=gb&client=ie8&mw={ie:maxWidth}&sh={ie:sectionHeight}&rh={ie:rowHeight}&inputencoding={inputEncoding}&outputencoding={outputEncoding}" /f
reg add "HKEY_USERS\DefaultProfiles\SOFTWARE\Microsoft\Internet Explorer\SearchScopes\{523578E1-643D-43BB-8840-A021BF2B23AB}" /v "OSDFileURL" /t REG_SZ /d "http://www.iegallery.com/en-gb/AddOns/DownloadAddOn?resourceId=14045" /f
reg add "HKEY_USERS\DefaultProfiles\SOFTWARE\Microsoft\Internet Explorer\SearchScopes\{523578E1-643D-43BB-8840-A021BF2B23AB}" /v "FaviconURL" /t REG_SZ /d "http://www.google.com/favicon.ico" /f 

reg UNLOAD "HKey_users\DefaultProfiles"

New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingSearchProvider -value "0" -Force
Write-Output "Suchprovider im Internet Explorer wurde auf Google geändert"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 515 -Message "Suchprovider im Internet Explorer wurde auf Google geändert"
LogSummary "Suchprovider im Internet Explorer wurde auf Google geändert"
}
catch
{
Write-Output "diverto als Chrome Favorit oder Suchprovider im Internet Explorer konnte nicht auf Google geändert werden"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 515 -Message "diverto als Chrome Favorit oder Suchprovider im Internet Explorer konnte nicht auf Google geändert werden"
LogSummary "diverto als Chrome Favorit oder Suchprovider im Internet Explorer konnte nicht auf Google geändert werden" Error
}
}
else
{
Write-Output "Task: `"diverto als Chrome Favorit & Standardsuchanbierer auf Google (IE) anpassen`" wird übersprungen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 515 -Message "Task: `"diverto als Chrome Favorit & Standardsuchanbierer auf Google (IE) anpassen`" wird übersprungen"
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Google als Startseite - OK
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingStartPageGoogle) -eq "1")
{
Write-Output "Startseite im Internet Explorer wird auf Google geändert`n"

try
{
reg LOAD "HKey_users\DefaultProfiles" "C:\Users\Default\ntuser.dat"

#Startseite
reg add "HKEY_USERS\DefaultProfiles\SOFTWARE\Microsoft\Internet Explorer\Main" /v "Start Page" /t REG_SZ /d "www.google.ch" /f
#Favoritenleiste
reg add "HKEY_USERS\DefaultProfiles\SOFTWARE\Microsoft\Internet Explorer\MINIE" /v "LinksBandEnabled" /t REG_DWORD /d "1" /f

reg UNLOAD "HKey_users\DefaultProfiles"

New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingStartPageGoogle -value "0" -Force
Write-Output "Startseite im Internet Explorer wurde auf Google geändert"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 516 -Message "Startseite im Internet Explorer wurde auf Google geändert"
LogSummary "Startseite im Internet Explorer wurde auf Google geändert"
}
catch
{
Write-Output "Startseite im Internet Explorer konnte nicht auf Google geändert werden"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 516 -Message "Startseite im Internet Explorer konnte nicht auf Google geändert werden"
LogSummary "Startseite im Internet Explorer konnte nicht auf Google geändert werden" Error
}
}
else
{
Write-Output "Task: `"Google als Startseite`" wird übersprungen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 516 -Message "Task: `"Google als Startseite`" wird übersprungen"
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Überprüfen ob eine SSD eingebaut ist - OK
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingSSDNoDefrag) -eq "1")
{
Write-Output "Es wird überprüft, ob eine SSD eingebaut ist`n"

try
{
if((get-physicaldisk).MediaType -match 'ssd')
{
Disable-ScheduledTask -TaskName 'ScheduledDefrag' -Taskpath 'Microsoft\Windows\Defrag'

New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingSSDNoDefrag -value "0" -Force
Write-Output "SSD ist eingebaut. Automatische Defragmentierung wurde ausgeschalten"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 517 -Message "SSD ist eingebaut. Automatische Defragmentierung wurde ausgeschalten"
LogSummary "SSD ist eingebaut. Automatische Defragmentierung wurde ausgeschalten"
}
else
{
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingSSDNoDefrag -value "0" -Force
Write-Output "Keine SSD ist eingebaut. Automatische Defragmentierung wird nicht ausgeschalten"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 517 -Message "Keine SSD ist eingebaut. Automatische Defragmentierung wird nicht ausgeschalten"
LogSummary "Keine SSD ist eingebaut. Automatische Defragmentierung wird nicht ausgeschalten"
}
}
catch
{
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingSSDNoDefrag -value "2" -Force
Write-Output "Festplatte kann nicht auf Typ überprüft werden. Automatische Defragmentierung wird nicht ausgeschalten. Bitte überprüfen Sie manuell, ob eine SSD eingebaut ist."
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 517 -Message "Festplatte kann nicht auf Typ überprüft werden. Automatische Defragmentierung wird nicht ausgeschalten. Bitte überprüfen Sie manuell, ob eine SSD eingebaut ist."
LogSummary "Festplatte kann nicht auf Typ überprüft werden. Automatische Defragmentierung wird nicht ausgeschalten. Bitte überprüfen Sie manuell, ob eine SSD eingebaut ist." Error
}
}
else
{
Write-Output "Task: `"Überprüfen ob eine SSD eingebaut ist`" wird übersprungen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 517 -Message "Task: `"Überprüfen ob eine SSD eingebaut ist`" wird übersprungen"
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Hintergrundbild anpassen - OK (Hintergrundbild erst bei zweiter Anmeldung ersichtlich)

if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingWallpaperDiverto) -eq "1")
{
Write-Output "diverto Wallpaper wird als Hintergrund eingestellt`n"

try{
#diverto Wallpaper (Hintergrundbild) auf C:\divertoInstall kopieren
Copy-Item .\divertoWP.png C:\divertoInstall\divertoWP.png -Recurse -Force

#Kopiert Batch Datei, welche das divertoWP als Desktophintergrund setzt und die Startup Verknüpfung löscht. (Damit es nicht erneut ausgeführt wird)
Copy-Item .\divertoWP.bat C:\divertoInstall\divertoWP.bat -Recurse -Force

#Kopiert Link, welche beim ersten Anmelden die vorherige Batchdatei ausführt. Die Batchdatei löscht die .lnk Datei dann wieder.
New-Item -Path "C:\Users\Default\Appdata\Roaming\Microsoft\Windows\Start Menu\Programs\" -Name "Startup" -ItemType directory -Force
Copy-Item .\divertoWPLink.bat "C:\Users\Default\Appdata\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\divertoWPLink.bat" -Recurse -Force

#Wallpaper in Registry anpassen
#reg add "HKEY_USERS\DefaultProfiles\Control Panel\Desktop" /v "WallPaper" /t REG_SZ /d "C:\divertoInstall\divertoWP.png" /f
#Hintergrund Anzeigeoption auf "Angepasst"
#reg add "HKEY_USERS\DefaultProfiles\Control Panel\Desktop" /v "WallpaperStyle" /t REG_SZ /d "6" /f

New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingWallpaperDiverto -value "0" -Force
Write-Output "diverto Wallpaper wurde als Hintergrund für neue Benutzer eingestellt"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 518 -Message "diverto Wallpaper wurde als Hintergrund für neue Benutzer eingestellt"
LogSummary "diverto Wallpaper wurde als Hintergrund für neue Benutzer eingestellt"
}
catch
{
Write-Output "Hintergrundbild konnte nicht angepasst werden"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 518 -Message "Hintergrundbild konnte nicht angepasst werden"
LogSummary "Hintergrundbild konnte nicht angepasst werden" Error
}
}
else
{
Write-Output "Task: `"Hintergrundbild anpassen`" wird übersprungen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 518 -Message "Task: `"Hintergrundbild anpassen`" wird übersprungen"
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Überprüfen ob Windows aktiviert ist - OK
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name checkWinActivation) -eq "1")
{
Write-Output "Es wird überprüft, ob Windows aktiviert ist`n"

try
{
#Prüfen ob Windows aktiviert ist
$WindowsAktivierungTest = (get-wmiobject -query "SELECT * FROM SoftwareLicensingProduct WHERE PartialProductKey <> null AND ApplicationId='55c92734-d682-4d71-983e-d6ec3f16059f' AND LicenseIsAddon=False").LicenseStatus
if($WindowsAktivierungTest -like "1")
{
#Windows aktiviert
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name checkWinActivation -value "0" -Force
Write-Output "Windows ist aktiviert"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 519 -Message "Windows ist aktiviert"
LogSummary "Windows ist aktiviert"
}
elseif($WindowsAktivierungTest -like "0")
{
#Windows nicht aktiviert
Write-Output "Windows ist nicht aktiviert. Automatische Aktivierung wird durchgeführt."
LogSummary "Windows ist nicht aktiviert. Automatische Aktivierung wird durchgeführt."
#Automatische Aktivierung probieren
Start-Process "cscript" "//B `"%windir%\system32\slmgr.vbs`" /ato" -Wait
$WindowsAktivierungTest2 = (get-wmiobject -query "SELECT * FROM SoftwareLicensingProduct WHERE PartialProductKey <> null AND ApplicationId='55c92734-d682-4d71-983e-d6ec3f16059f' AND LicenseIsAddon=False").LicenseStatus
if($WindowsAktivierungTest2 -like "1")
{
#Windows aktiviert
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name checkWinActivation -value "0" -Force
Write-Output "Windows konnte erfolgreich aktiviert werden."
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 519 -Message "Windows konnte erfolgreich aktiviert werden."
LogSummary "Windows konnte erfolgreich aktiviert werden."
}
elseif($WindowsAktivierungTest2 -like "0")
{
#Windows Aktivierung fehlgeschlagen
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name checkWinActivation -value "2" -Force
Write-Output "Windows konnte nicht aktiviert werden. Bitte manuell überprüfen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 519 -Message "Windows konnte nicht aktiviert werden. Bitte manuell überprüfen"
LogSummary "Windows konnte nicht aktiviert werden. Bitte manuell überprüfen" Error
}
else
{
#Windows Aktivierung kann nicht überprüft werden, nach automatischem Aktivierungsversuch
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name checkWinActivation -value "2" -Force
Write-Output "Windows Aktivierung nicht erkannt. Bitte manuell überprüfen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 519 -Message "Windows Aktivierung nicht erkannt. Bitte manuell überprüfen"
LogSummary "Windows Aktivierung nicht erkannt. Bitte manuell überprüfen" Error
}
}
else
{
#Windows Aktivierung kann nicht überprüft werden
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name checkWinActivation -value "2" -Force
Write-Output "Windows Aktivierung nicht erkannt. Bitte manuell überprüfen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 519 -Message "Windows Aktivierung nicht erkannt. Bitte manuell überprüfen"
LogSummary "Windows Aktivierung nicht erkannt. Bitte manuell überprüfen" Error
}
}
catch
{
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name checkWinActivation -value "2" -Force
Write-Output "Windows Aktivierung nicht erkannt. Bitte manuell überprüfen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 519 -Message "Windows Aktivierung nicht erkannt. Bitte manuell überprüfen"
LogSummary "Windows Aktivierung nicht erkannt. Bitte manuell überprüfen" Error
}
}
else
{
Write-Output "Task: `"Überprüfen ob Windows aktiviert ist`" wird übersprungen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 519 -Message "Task: `"Überprüfen ob Windows aktiviert ist`" wird übersprungen"
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Treiber aktualisieren - OK
#Doku über Dell Command Update 2.0
#0 = OK/Success
#1 = Reboot Required
#2 = Fatal Error
#3 = Error
#4 = Invalid System

if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name checkDrivers) -eq "1")
{
Write-Output "Treiber werden aktualisiert`n"

##Überprüfung auf Dell Gerät
if((wmic csproduct get Vendor) -like "*Dell*")
{
#Überprüfung ob Dell Command Update bereits verwendet werden kann.
if(Test-path -Path "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe")
{
#Dell Command Update vorhanden und kann gebraucht werden.
}
else
{
#Dell Command Update nicht vorhanden... wird installiert
Invoke-WebRequest -Uri "https://downloads.dell.com/FOLDER05312739M/1/Dell-Command-Update_Y2KWD_WIN_3.0.1_A00.EXE" -OutFile "C:\divertoInstall\DellCommandUpdate_Install.exe"
C:\divertoInstall\DellCommandUpdate_Install.exe /s | Out-Null
}

###Dell Command Update wird nun verwendet###
$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.CreateNoWindow = $true
$pinfo.FileName = "C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe"
$pinfo.WindowStyle = 'Hidden'
$pinfo.UseShellExecute = $true
$pinfo.Arguments = "/silent /log C:\Windows\Temp\logdriver"
$p = New-Object System.Diagnostics.Process
$p.StartInfo = $pinfo
$p.Start() | Out-Null
Write-Output "Treiber Updates werden gesucht und installiert"
$p.WaitForExit()
Write-Output "Exitcode: "$p.ExitCode
    
switch ($p.ExitCode) 
{ 
0{Write-Output "Exitcode = OK/Success"
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name checkDrivers -value "0" -Force}
1{Write-Output "Exitcode = Unsuccessful"
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name checkDrivers -value "2" -Force
Dies ist ein Fehler}
2{Write-Output "Exitcode = Reboot Required"
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name checkDrivers -value "0" -Force
Write-Output "Gerät wird neugestartet, da Treiber aktualisiert wurden."
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Warning -EventId 520 -Message "Gerät wird neugestartet, da Treiber aktualisiert wurden."
DoReboot}
default{Write-Output "Unbekannter Exitcode."
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name checkDrivers -value "2" -Force
Dies ist ein Fehler}
}
Write-Output "Log Dell Command Update: C:\Windows\Temp\logdriver\ActivityLog.xml"


}
else
{
#Kein Dell Gerät...
Write-Output "Treiber Informationen werden gesucht..."
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 520 -Message "Dell Command Update hat Fehler zurückgegeben. Es wird nun versucht Informationen zu den fehlenden Treiber zu suchen.`n"
$CountFehlendeTreiber = 0
#Treiberprobleme zählen
$CountFehlendeTreiber = (Get-WmiObject "Win32_PNPEntity" | Where-Object{$_.ConfigManagerErrorcode -notlike "0"} | Measure-Object).Count
#Wenn Treiberprobleme gefunden
if($CountFehlendeTreiber -gt 0)
{
#Reset Wert bekannte Treiber
$BekannteTreiber = ""
#Namen aller Treiberobjekte in $BekannteTreiber schreiben
(Get-WmiObject "Win32_PNPEntity" | Where-Object{$_.ConfigManagerErrorcode -notlike "0"} | Where-Object{$_.Name -notlike ""}) | ForEach-Object {$BekannteTreiber = $BekannteTreiber + "`n" + $_.Name}
#Reset Wert unbekannte Treiber
$UnbekannteTreiber = ""
#Hardware-IDs aller Treiberobjekte in $Unbekannte Treiber schreiben
(Get-WmiObject "Win32_PNPEntity" | Where-Object{$_.ConfigManagerErrorcode -notlike "0"} | Where-Object{$_.Name -like ""}) | ForEach-Object {$UnbekannteTreiber = $UnbekannteTreiber + "`n" + $_.HardwareID}
#Fehlende Treiber werden ins Event-Log geschrieben
Write-Output "Treiberprobleme: $CountFehlendeTreiber`n`nBekannte Treiber:`n$BekannteTreiber `n`nUnbekannte Treiber (Hardware-IDs):`n $UnbekannteTreiber"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 520 -Message "Treiberprobleme: $CountFehlendeTreiber`n`nBekannte Treiber:`n$BekannteTreiber `n`nUnbekannte Treiber (Hardware-IDs):`n $UnbekannteTreiber"
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name checkDrivers -value "2" -Force
}
else
{
#Keine Treiber fehlen.
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name checkDrivers -value "0" -Force
Write-Output "Keine Treiberprobleme gefunden"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 520 -Message "Keine Treiberprobleme gefunden"
LogSummary "Keine Treiberprobleme gefunden"
}
}
}
else
{
Write-Output "Task: `"Treiber aktualisieren`" wird übersprungen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 520 -Message "Task: `"Treiber aktualisieren`" wird übersprungen"
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Desktopsymbole / Taskleiste anpassen / (Windows Start-Kacheln) - OK

#Computer {20D04FE0-3AEA-1069-A2D8-08002B30309D}"
#Systemsteuerung {5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}"
#Papierkorb {645FF040-5081-101B-9F08-00AA002F954E}"
#Benutzerdaten {59031a47-3f72-44a7-89c5-5595fe6b30ee}"
#Netzwerk {F02C1A0D-BE21-4350-88B0-7367FC96EF3C}"

#Werte
#0 = Symbol sichtbar
#1 = Symbol versteckt

if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingDesktopIcons) -eq "1")
{
Write-Output "Folgende Desktopsymbole werden angezeigt: Computer, Papierkorb, Benutzerdateien und CreateTicket-Shortcut`n"
Write-Output "Folgende Taskleistensymbole werden angezeigt: Windows-Explorer, Edge, Google Chrome, CreateTicket-Shortcut`n"

try
{
reg LOAD "HKey_users\DefaultProfiles" "C:\Users\Default\ntuser.dat"

#Computer
reg add "HKEY_USERS\DefaultProfiles\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /v "{20D04FE0-3AEA-1069-A2D8-08002B30309D}" /t REG_DWORD /d "0" /f
#Papierkorb
reg add "HKEY_USERS\DefaultProfiles\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /v "{645FF040-5081-101B-9F08-00AA002F954E}" /t REG_DWORD /d "0" /f
#Benutzerdaten
reg add "HKEY_USERS\DefaultProfiles\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /v "{59031a47-3f72-44a7-89c5-5595fe6b30ee}" /t REG_DWORD /d "0" /f
#Systemsteuerung
reg add "HKEY_USERS\DefaultProfiles\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /v "{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}" /t REG_DWORD /d "1" /f
#Netzwerk
reg add "HKEY_USERS\DefaultProfiles\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /v "{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}" /t REG_DWORD /d "1" /f

#Google Chrome auf Desktop bei neuen Benutzern (Nur wenn Chrome zum Zeitpunkt "Skriptausführung" installiert war)
if (Test-Path("C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"))
{
$ChromeLinkPath = "C:\Users\Default\Desktop\Google Chrome.lnk"
$ChromeTargetPath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
$link = (New-Object -ComObject WScript.Shell).CreateShortcut($ChromeLinkPath)
$link.TargetPath = $ChromeTargetPath
$link.Save()
}

#Taskleiste Runonce Einstellung für neue User definieren
Copy-Item .\Taskbar.reg C:\divertoInstall\Taskbar.reg -Recurse -Force
reg import C:\divertoInstall\taskbar.reg
#Taskleistensymbole auf C:\ kopieren
Expand-Archive .\Managetaskbar.zip -DestinationPath C:\divertoInstall

# "Ein neues Support Ticket erstellen" auf Desktop kopieren
Copy-Item -Path "C:\divertoInstall\Managetaskbar\QuickLaunch\User Pinned\TaskBar\Ein neues Support Ticket erstellen.lnk" -Destination "C:\Users\Default\Desktop\Ein neues Support Ticket erstellen.lnk" -Recurse -Force

#Windows Start-Kacheln anpassen -> Aufs Eis gelegt, da es nicht ohne den Wert LockedStartLayout geht, was aber bewirkt, dass das Startmenü nicht mehr bearbeitet werden kann.
#Copy-Item .\divertoStartLayout.xml C:\divertoInstall\divertoStartLayout.xml -Recurse -Force
#reg add "HKEY_USERS\DefaultProfiles\Software\Policies\Microsoft\Windows\Explorer" /v "StartLayoutFile" /t REG_SZ /d "C:\divertoInstall\divertoStartLayout.xml" /f
#reg add "HKEY_USERS\DefaultProfiles\Software\Policies\Microsoft\Windows\Explorer" /v "LockedStartLayout" /t REG_DWORD /d "0" /f

reg UNLOAD "HKey_users\DefaultProfiles"

New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingDesktopIcons -value "0" -Force
Write-Output "Desktopsymbole / Taskleiste wurden angepasst."
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 521 -Message "Desktopsymbole / Taskleiste wurden angepasst."
LogSummary "Desktopsymbole / Taskleiste wurden angepasst."
}
catch
{
Write-Output "Desktopsymbole / Taskleiste konnten nicht angepasst werden"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 521 -Message "Desktopsymbole / Taskleiste konnten nicht angepasst werden"
LogSummary "Desktopsymbole / Taskleiste konnten nicht angepasst werden" Error
}
}
else
{
Write-Output "Task: `"Desktopsymbole / Taskleiste / Windwos Start-Kacheln anpassen`" wird übersprungen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 521 -Message "Task: `"Desktopsymbole / Taskleiste`" wird übersprungen"
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Ordneroptionen anpassen - OK

#Erweiterungen bei bekannten Dateitypen werden angezeigt
#HideFileExt = 0

#Versteckte Dateien und Ordner werden ausgeblendet
#Hidden = 2

if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingFolderoptions) -eq "1")
{
Write-Output "Ordneroptionen werden angepasst. Dateierweiterungen anzeigen, versteckte Dateien/Ordner ausblenden.`n"

try
{
reg LOAD "HKey_users\DefaultProfiles" "C:\Users\Default\ntuser.dat"

#Dateierweiterungen anzeigen
reg add "HKEY_USERS\DefaultProfiles\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "HideFileExt" /t REG_DWORD /d "0" /f
#Versteckte Dateien und Ordner ausblenden
reg add "HKEY_USERS\DefaultProfiles\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "Hidden" /t REG_DWORD /d "2" /f

reg UNLOAD "HKey_users\DefaultProfiles"

New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingFolderoptions -value "0" -Force
Write-Output "Ordneroptionen wurden angepassst"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 522 -Message "Ordneroptionen wurden angepassst"
LogSummary "Ordneroptionen wurden angepassst"
}
catch
{
Write-Output "Ordneroptionen konnten nicht angepasst werden"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 522 -Message "Ordneroptionen konnten nicht angepasst werden"
LogSummary "Ordneroptionen konnten nicht angepasst werden" Error
}
}
else
{
Write-Output "Task: `"Ordneroptionen anpassen`" wird übersprungen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 522 -Message "Task: `"Ordneroptionen anpassen`" wird übersprungen"
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Benutzerkontensteuerung anpassen - OK

#Die Benutzerkontensteuerung wird auf Stufe 3 angepasst

#ConsentPromptBehaviorAdmin = 5
#PromptOnSecureDesktop = 1

if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingUAC) -eq "1")
{
Write-Output "Benutzerkontensteuerung wird auf Stufe 3 angepasst`n"

try
{
#Einstellung in Registry anpassen
reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v "ConsentPromptBehaviorAdmin" /t REG_DWORD /d "5" /f
reg add "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System" /v "PromptOnSecureDesktop" /t REG_DWORD /d "1" /f

New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name settingUAC -value "0" -Force
Write-Output "Benutzerkontensteuerung wurde angepassst"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 523 -Message "Benutzerkontensteuerung wurde angepassst"
LogSummary "Benutzerkontensteuerung wurde angepassst"
}
catch
{
Write-Output "Benutzerkontensteuerung konnte nicht angepasst werden"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 523 -Message "Benutzerkontensteuerung konnte nicht angepasst werden"
LogSummary "Benutzerkontensteuerung konnte nicht angepasst werden" Error
}
}
else
{
Write-Output "Task: `"Benutzerkontensteuerung anpassen`" wird übersprungen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 523 -Message "Task: `"Benutzerkontensteuerung anpassen`" wird übersprungen"
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Neuer Benutzer erstellen - OK
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name newUser) -eq "1")
{
Write-Output "Neuer Benutzer $parUsername wird erstellt (Mit Administratoren Rechten und ohne Passwort)`n"

try
{
#Erstellt Benutzer
New-LocalUser -Name $parUsername -AccountNeverExpires -NoPassword
#Setzt Häkchen korrekt (Passwort läuft nie ab)
Set-LocalUser -Name $parUsername -PasswordNeverExpires $true
#Fügt den Benutzer zu der Gruppe "Administratoren" hinzu
Add-LocalGroupMember -Member $parUsername -Name Administratoren 

New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name newUser -value "0" -Force
Write-Output "Benutzer $parUsername wurde erfolgreich erstellt"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 524 -Message "Benutzer $parUsername wurde erfolgreich erstellt"
LogSummary "Benutzer $parUsername wurde erfolgreich erstellt"
}
catch
{
Write-Output "Neuer Benutzer $parUsername konnte nicht erstellt werden"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 524 -Message "Neuer Benutzer $parUsername konnte nicht erstellt werden"
LogSummary "Neuer Benutzer $parUsername konnte nicht erstellt werden" Error
}
}
else
{
Write-Output "Task: `"Neuer Benutzer`" wird übersprungen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 524 -Message "Task: `"Neuer Benutzer`" wird übersprungen"
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------

#Benutzer "User" löschen - OK
if ((Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name deleteUserUser) -eq "1")
{

try
{
#Überprüft, ob Administrator aktiviert wurde
if((get-LocalUser -name Administrator | Where-Object Enabled -like True).Count -like 1)
{
Write-Output "Lokaler Administrator wurde aktiviert. Benutzer User wird nun gelöscht.`n"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 525 -Message "Lokaler Administrator wurde aktiviert. Benutzer User wird nun gelöscht."

#Benutzer "User" wird abgemeldet
$sessionID_User = ((quser | Where-Object { $_ -match "User" }) -split ' +')[2]
#Wenn Benutzer angemeldet ist
if($sessionID_User){logoff $sessionID_User}

#Benutzer "User" wird hier gelöscht
Net user /delete user
cmd /c rmdir C:\Users\user\appdata /S /Q
cmd /c rmdir C:\Users\user /S /Q

New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name deleteUserUser -value "0" -Force
Write-Output "Benutzer User konnte erfolgreich gelöscht werden."
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 525 -Message "Benutzer User konnte erfolgreich gelöscht werden"
LogSummary "Benutzer User konnte erfolgreich gelöscht werden"
}
else
{
#Existenz von lokalem Adminitrator kann nicht überprüft werden. Benutzer "User" wird nicht gelöscht.
New-ItemProperty -Type String -Path HKLM:\SOFTWARE\diverto\Basic\Checklist -Name deleteUserUser -value "2" -Force
Write-Output "Existenz von lokalem Adminitrator kann nicht überprüft werden. Benutzer User wird nicht gelöscht."
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 525 -Message "Existenz von lokalem Adminitrator kann nicht überprüft werden. Benutzer User wird nicht gelöscht."
LogSummary "Existenz von lokalem Adminitrator kann nicht überprüft werden. Benutzer User wird nicht gelöscht." Error
}
}
catch
{
Write-Output "Benutzer User konnte nicht gelöscht werden"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Error -EventId 525 -Message "Benutzer User konnte nicht gelöscht werden"
LogSummary "Benutzer User konnte nicht gelöscht werden" Error
}
}
else
{
Write-Output "Task: `"Benutzer User löschen`" wird übersprungen"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Information -EventId 525 -Message "Task: `"Benutzer User löschen`" wird übersprungen"
}

Write-Output "`n"

#----------------------------------------------------------------------------------------------------------------------------


#Abschluss
#Hier sind abschliessende Commands für bspw. Bereinigung

try
{
Remove-Item C:\divertoInstall\local2.xml -Force -Recurse
Remove-Item C:\divertoInstall\NinitePro.exe -Force -Recurse
Remove-Item C:\divertoInstall\NiniteDownloads -Force -Recurse
Remove-Item C:\divertoInstall\AEM_Agent.exe -Force -Recurse
Remove-Item C:\divertoInstall\Taskbar.reg -Force -Recurse
Write-Output "Temporärdaten in C:\divertoInstall wurden zum Abschluss bereinigt."
LogSummary "Temporärdaten in C:\divertoInstall wurden zum Abschluss bereinigt."
}
catch
{
}

#Beim nächstn Ausführen sollten die CurrentReboots gleich sein wie die RequiredReboots, deshalb wird dann sofort die E-Mail versandt aus dem Code.
Write-Output "Gerät wird zum Abschluss neugestartet"
Write-EventLog -LogName divertoEvents -Source divOnboarding -EntryType Warning -EventId 530 -Message "Gerät wird zum Abschluss neugestartet"
$Script:RequiredReboots = $RequiredReboots - 1
DoReboot
