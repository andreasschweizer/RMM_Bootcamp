#Funktionen

#Überprüft ob 
Function Test-RegistryKey
{
    param
    (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Path
    ) 
    process
    {
        if (Test-Path $Path)
        {
            $true
        }
        else
        {
        $false
        }
    }
}

#----------------------------------------------------------------------------------------------------------------------------

#Alle existierenden Hashtags

$AlleHashtags = "#MIT, #3PP, #TMP"

#----------------------------------------------------------------------------------------------------------------------------

#Basisordner erstellen

if(-Not (Test-RegistryKey -Path 'HKLM:\Software\diverto\'))
{
New-Item HKLM:\Software\diverto\ -Force
}
if(-Not (Test-RegistryKey -Path 'HKLM:\Software\diverto\Basic\'))
{
New-Item HKLM:\Software\diverto\Basic\ -Force
}
if(-Not (Test-RegistryKey -Path 'HKLM:\Software\diverto\Basic\Checklist\'))
{
New-Item HKLM:\Software\diverto\Basic\Checklist\ -Force
}
if(-Not (Test-RegistryKey -Path 'HKLM:\Software\diverto\Basic\Data\'))
{
New-Item HKLM:\Software\diverto\Basic\Data\ -Force
}

#----------------------------------------------------------------------------------------------------------------------------

#Alle existierenden Hashtags in die Registry als Werte abspeichern und auf 0 setzen, wenn sie nicht vorhanden sind.
#Unter: HKLM:\Software\diverto

$AlleHashtagsSplit = $AlleHashtags.Split(",")
Try
{
$AlleHashtagsArray = $AlleHashtagsSplit.Replace("#","")
$AlleHashtagsArray = $AlleHashtagsArray.Replace(" ","")
}
Catch
{
$AlleHashtagsArray = $AlleHashtagsSplit -replace '#',''
$AlleHashtagsArray = $AlleHashtagsArray -replace ' ',''
}
Set-Location HKLM:\Software\diverto

for ($i=0; $i -lt $AlleHashtagsArray.Count; $i++)
{
$crPath = "HKLM:\Software\diverto\" + $AlleHashtagsArray[$i]
if(-Not (Test-RegistryKey -Path $crPath))
{
New-Item HKLM:\Software\diverto\ -Name $AlleHashtagsArray[$i] -Force
}
New-ItemProperty -Type String -Path HKLM:\Software\diverto -Name $AlleHashtagsArray[$i] -value "0" -Force
}

#----------------------------------------------------------------------------------------------------------------------------

#Die in AEM hinterlegte Beschreibung z.B. "#MIT, #3PP" wird in der Registry als Ordnerstruktur erstellt.
#HKLM:\Software\diverto\MIT und HKLM:\Software\diverto\3PP
#Die Werte unter HKLM:\Software\diverto werden auf "1" aktualisiert (1 = Aktiv, 0 = Nicht aktiv)

$AEMSiteBeschreibung = (Get-ChildItem Env:CS_PROFILE_DESC).Value
$AktiveHashtagsSplit = $AEMSiteBeschreibung.Split(",")
Try
{
$AktiveHashtagsArray = $AktiveHashtagsSplit.Replace("#","")
$AktiveHashtagsArray = $AktiveHashtagsArray.Replace(" ","")
}
Catch
{
$AktiveHashtagsArray = $AktiveHashtagsSplit -replace '#',''
$AktiveHashtagsArray = $AktiveHashtagsArray -replace ' ',''
}
for ($i=0; $i -lt $AktiveHashtagsArray.Count; $i++)
{
#Werte auf 1 aktualisieren
New-ItemProperty -Type String -Path HKLM:\Software\diverto -Name $AktiveHashtagsArray[$i] -value "1" -Force
}


#----------------------------------------------------------------------------------------------------------------------------