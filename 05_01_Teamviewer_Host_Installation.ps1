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

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.#>

<#
Beschreibung des Scripts:
Via Parameter auswählen was gemacht werden soll.
- TeamViewer Host installieren
- TeamViewer Passwort importieren / setzen
- oder beides

Editor:             Pascal Beetschen
Letzte Bearbeitung: 23.07.2019
#>

<# Funktionen #>
Function InstallTVHost
{
# TeamViewer Host installieren (Akuell Version 14) - Dank Out-Null wird gewartet, bis die Installation fertig ist.
Write-Output "TeamViewer Host wird nun installiert"
.\TeamViewerHostSetup.exe /S | Out-Null
}

Function SetTVPassword
{
# TeamViewer Passwort setzen (diverto Standard)
Write-Output "TeamViewer Host Passwort wird gesetzt"
regedit.exe /s .\Teamviewer_Settings.reg
# TeamViewer Dienst neustarten, damit die Anpassungen wirksam werden.
Write-Output "TeamViewer Dienst wird neugestartet"
Restart-Service "TeamViewer"
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



# Überprüft via Parameter, welche Tasks gemacht werden sollen.
switch($env:task)
{
    "install" {
        # Host installieren
        InstallTVHost
    }
    "setpw"{
        # diverto Standard TeamViewer Host Passwort setzen
        SetTVPassword
    }
    "install_setpw"{
        # Host installieren + Passwort setzen
        InstallTVHost
        SetTVPassword
    }
    default{
        Write-Output "Switch Variable stimmt nicht mehr mit RMM überein. Bitte Script / RMM überprüfen!"
        exit 1
    }
}