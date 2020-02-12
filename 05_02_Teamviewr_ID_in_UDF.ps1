<#
Copyright (C) 2018 Jasper Golze (ITcares)
Modified 2019 Pascal Beetschen (diverto gmbh)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.#>

<#
Beschreibung des Scripts:
TeamViewer Konsolen ID wird von Registry ausgelesen und in RMM Benutzerdefiniertes Feld 5 geschrieben.
Funktioniert für sämtliche Versionen ab TeamViewer 6.

Editor:             Beetschen Pascal
Letzte Bearbeitung: 19.07.2019
#>

<# Variablen #>
$RMMRegistryPath = 'HKLM:\SOFTWARE\CentraStage'
$RMM_UDF = $env:UDF
$TeamViewerVersions = @('6','7','8','9','')


<#
 __   __  _______  __   __  _______  _______  _______  _______  ___   ___     
|  | |  ||   _   ||  | |  ||       ||       ||       ||       ||   | |   |    
|  |_|  ||  |_|  ||  | |  ||    _  ||_     _||_     _||    ___||   | |   |    
|       ||       ||  |_|  ||   |_| |  |   |    |   |  |   |___ |   | |   |    
|       ||       ||       ||    ___|  |   |    |   |  |    ___||   | |   |___ 
|   _   ||   _   ||       ||   |      |   |    |   |  |   |___ |   | |       |
|__| |__||__| |__||_______||___|      |___|    |___|  |_______||___| |_______|
#>


# Prüfung ob 32 Bit oder 64 Bit
# 4 = 32Bit
# 8 = 64Bit
If([IntPtr]::Size -eq 4) {
    $RegPath='HKLM:\SOFTWARE\TeamViewer'    
} else {
    $RegPath='HKLM:\SOFTWARE\Wow6432Node\TeamViewer'
}

# Fehlermeldungen unterdrücken, da für jede mögliche TeamViewer Version die ID gesucht wird.
$ErrorActionPreference= 'silentlycontinue'
foreach ($TeamViewerVersion in $TeamViewerVersions) {
    if ($null -ne (Get-Item -Path $RegPath$TeamViewerVersion).GetValue('ClientID')) {
        # Gefundene ID wird gesetzt
        $TeamViewerID=(Get-Item -Path $RegPath$TeamViewerVersion).GetValue('ClientID')
    }
    # Zum Teil sind die IDs in einem Key weiter unten. Z.B. HKLM:\SOFTWARE\Wow6432Node\TeamViewer\Version9\...
    if ($null -ne (Get-Item -Path "$RegPath\Version$TeamViewerVersion").GetValue('ClientID')) {
        # Gefundene ID wird gesetzt
        $TeamViewerID=(Get-Item -Path "$RegPath\Version$TeamViewerVersion").GetValue('ClientID')
    }
}
Write-Output "The Teamviewer ID of $ENV:COMPUTERNAME is '$TeamViewerID'" 
New-ItemProperty -PropertyType String -Path $RMMRegistryPath -Name $RMM_UDF -value $TeamViewerID -Force