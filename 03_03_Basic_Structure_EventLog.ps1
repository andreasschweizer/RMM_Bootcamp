# Eventlog Creator Tool 
# by Tim Leuenberger, diverto gmbh
$ErrorActionPreference = 'Continue'


# Ist das Log bereits vorhanden? Wenn nicht, erstelle das Log
$logFilevorhanden = Get-EventLog -list | Where-Object {$_.logdisplayname -eq "divertoEvents"}
    if (! $logFilevorhanden) {
    New-EventLog -LogName "divertoEvents" -source "divNAS" }

#Counter für Eventlogsources, die nicht vorhanden sind
$EventcreatorCounter = 0


#Prüfe, ob die Eventsource bereits vorhanden ist
$divNAS = [System.Diagnostics.EventLog]::SourceExists("divNas") -eq $true
$divOther = [System.Diagnostics.EventLog]::SourceExists("divOther") -eq $true
$divGeneral = [System.Diagnostics.EventLog]::SourceExists("divGeneral") -eq $true
$divServer = [System.Diagnostics.EventLog]::SourceExists("divServer") -eq $true
$divWorkstation = [System.Diagnostics.EventLog]::SourceExists("divWorkstation") -eq $true
$divWebCheck = [System.Diagnostics.EventLog]::SourceExists("divWebCheck") -eq $true
$divStorage = [System.Diagnostics.EventLog]::SourceExists("divStorage") -eq $true
$divMail = [System.Diagnostics.EventLog]::SourceExists("divMail") -eq $true
$divNetwork = [System.Diagnostics.EventLog]::SourceExists("divNetwork") -eq $true
$divBackup = [System.Diagnostics.EventLog]::SourceExists("divBackup") -eq $true
$divAntivirus = [System.Diagnostics.EventLog]::SourceExists("divAntivirus") -eq $true


#Wenn die Eventsource nicht vorhanden ist, erstelle diese
if ($divNaS -eq $true) 
    {
    echo "Bereits vorhanden divNas"
    }
else 
    { 
    new-eventlog -source divNAS -logname "divertoEvents"
    $EventcreatorCounter ++
    $nas = "divNas"
    }

if ($divOther -eq $true) 
    {
    echo "Bereits vorhanden divOther"
    }
else 
    { 
    new-eventlog -source divOther -logname "divertoEvents"
    $EventcreatorCounter ++
    $other = "divOther"
    }

if ($divGeneral -eq $true) 
    {
    echo "Bereits vorhanden divGeneral"
    }
else 
    { 
    new-eventlog -source divGeneral -logname "divertoEvents"
    $EventcreatorCounter ++
    $General = "divGeneral"
    }

if ($divServer -eq $true) 
    {
    echo "Bereits vorhanden divServer"
    }
else 
    { 
    new-eventlog -source divServer -logname "divertoEvents"
    $EventcreatorCounter ++
    $Server = "divServer"
    }

if ($divWorkstation -eq $true) 
    {
    echo "Bereits vorhanden divWorkstation"
    }
else 
    { 
    new-eventlog -source divWorkstation -logname "divertoEvents"
    $EventcreatorCounter ++
    $Workstation = "divWorkstation"
    }

if ($divWebCheck -eq $true) 
    {
    echo "Bereits vorhanden divWebCheck"
    }
else 
    { 
    new-eventlog -source divWebCheck -logname "divertoEvents"
    $EventcreatorCounter ++
    $Webcheck = "divWebCheck"
    }

if ($divStorage -eq $true) 
    {
    echo "Bereits vorhanden divStorage"
    }
else 
    { 
    new-eventlog -source divStorage -logname "divertoEvents"
    $EventcreatorCounter ++
    $Storage = "divStorage"
    }

if ($divMail -eq $true) 
    {
    echo "Bereits vorhanden divMail"
    }
else 
    { 
    new-eventlog -source divMail -logname "divertoEvents"
    $EventcreatorCounter ++
    $Mail = "divMail"
    }

if ($divNetwork -eq $true) 
    {
    echo "Bereits vorhanden divNetwork"
    }
else 
    { 
    new-eventlog -source divNetwork -logname "divertoEvents"
    $EventcreatorCounter ++
    $network = "divNetwork"
    }

if ($divBackup -eq $true) 
    {
    echo "Bereits vorhanden divBackup"
    }
else 
    { 
    new-eventlog -source divBackup -logname "divertoEvents" 
    $EventcreatorCounter ++
    $backup = "divBackup"
    }

if ($divAntivirus -eq $true) 
    {
    echo "Bereits vorhanden divAntivirus"
    }
else 
    { 
    new-eventlog -source divAntivirus -logname "divertoEvents" 
    $EventcreatorCounter ++
    $antivirus = "divAntivirus"
    }


#Was wurde geändert / War alles aktuell?
if ($EventcreatorCounter -ne 0) 
    {
    Write-Host "Es wurden $EventcreatorCounter Eventsources hinzugefügt. Namentlich $nas $other $general $Server $Workstation $Webcheck $Storage $Mail $network $backup $antivirus"
    }
else 
    {
    Write-Host "Alle Eventlogs und EventSources sind aktuell - Es wurde nichts angepasst" 
    }