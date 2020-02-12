# NO MFA
Import-Module MSOnline 
$username = $env:AdminUser
$secpassword = $env:AdminPasswort | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($username,$secpassword)   
$O365Session = New-PSSession –ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell -Credential $credential -Authentication Basic -AllowRedirection
Import-PSSession $O365Session -AllowClobber
Connect-MsolService -Credential $credential

# MFA
# Microsoft Exchange Online Powershell Modul verwenden!
# Connect-EXOPSSession
# Connect-MsolService


#Abfrage ob Benutzer per CSV oder manuell erstellt werden soll
$varModus = $env:Modus
switch ( $varModus )
            {
                "1" { $ModusCSV = $true   }
                "2" { $ModusCSV = $false    }
            }


#Wenn per CSV gewählt wurde:
    If ($ModusCSV)
    {
        $host.Runspace.ThreadOptions = "ReuseThread"

        #Funktion zum importieren der CSV Datei für Benutzererstellung.
        function Add-Office365Users
        {
            param ($sInputFile)
          try 
          {
                # CSV Datei einlesen
                $bFileExists = (Test-Path $sInputFile -PathType Leaf) 
                
                if ($bFileExists) 
                { 
                    "`nLade $sInputFile für den Prozess..." 
                    $tblUsers = Import-CSV $sInputFile            
                } 
                
                else 
                { 
                    Write-Host "$sInputFile Datei nicht gefunden. Import wird abgebrochen!" -foregroundcolor Red
                    exit 
                }         
        
                # Benutzer hinzufügen
                Write-Host "`nFüge Office 365 Benutzer hinzu ..." -foregroundcolor Green    
                foreach ($user in $tblUsers) 
                { 
                $Lizenz = $user.Lizenz
                $licenseToAssign = ((Get-MsolAccountSku) | Where-Object -Property "AccountSkuId" -like "*$Lizenz*").AccountSkuId
                    "Hinzufügen von " + $user.Anzeigename.ToString()            
                    New-MsolUser -UserPrincipalName $user.Mailadresse -DisplayName $user.Anzeigename -FirstName $user.Vorname -LastName $user.Nachname -UsageLocation $user.Landescode -LicenseAssignment $licenseToAssign -Password $user.Passwort
                } 

                Write-Host "-----------------------------------------------------------"  -foregroundcolor Green
                Write-Host "Alle Benutzer hinzugefügt. Der Prozess ist nun beendet." -foregroundcolor Green
                Write-Host "-----------------------------------------------------------"  -foregroundcolor Green
                
 # Standardeinstellungen machen
                Write-Host "`nMache die Standardeinstellungen für jedes Postfach des CSVs...`nDieser Vorgang dauert jenach Anzahl Postfächer 3-10Minuten`nBitte warten..." -foregroundcolor Green 
                Start-Sleep 900
                $tblUsers = Import-CSV $sInputFile            
                                         
        
                  
                foreach ($user in $tblUsers) 
                { 
                $useremail = $user.Mailadresse

                    write-host Sprache und Regionseinstellungen werden gesetzt... !kann mehrere Minuten dauern! -foreground "magenta"
                    set-mailbox $useremail -language de-ch
                    Set-MailboxRegionalConfiguration $useremail -Language 2055 -DateFormat "dd.MM.yyyy" -TimeZone "W. Europe Standard Time" -timeformat "HH:mm" -LocalizeDefaultFolderName:$true
                    write-host Sprache und Regionseinstellungen anzeigen für Kontrolle... -foreground "magenta"
                    Get-MailboxRegionalConfiguration $useremail

                    write-host Kalenderberechtigungen werden gesetzt... -foreground "magenta"
                    Set-MailboxFolderPermission $useremail":\Kalender" -User Default -AccessRights Reviewer
                    write-host Kalenderberechtigungen anzeigen für Kontrolle... -foreground "magenta"
                    get-MailboxFolderPermission $useremail":\Kalender" -user Default |Select-Object Identity,user,accessrights

                    write-host Einstellungen für Ablaufen des Kennworts werden gesetzt... -foreground "magenta"
                    Get-MsolUser -UserPrincipalName $useremail | set-msoluser –PasswordNeverExpires $True
                    write-host Einstellungen für Ablaufen des Kennworts anzeigen für Kontrolle... -foreground "magenta"
                    Get-MsolUser -UserPrincipalName $useremail | Select-Object DisplayName,PasswordNeverExpires

                }
       
      }
      catch {
                write-host -f red $_.Exception.ToString() 
                exit 
           }      
      } 
           
     
      


        
        $sInputFile="C:\divertoInstall\PS_UsersToAddOffice365.csv"

        #Benutzer hinzufügen
    Add-Office365Users -sInputFile $sInputFile
    
}

else {
#Wenn manuell gewählt wurde:
write-host "`n`n"
write-host "Das Script braucht jeweils 3min.`nEs setzt für den neuen Benutzer alle Standardeinstellungen.`nDas Script kann beendet werden nach 1min - dann müssen aber alle Standardeinstellungen noch gemacht werden (per anderem Script)`nEs ist empfohlen, dass Script bis zum Abschluss nicht abzubrechen.`n`n"


    $Displayname = $env:Anzeigename
    $Vorname = $env:Vorname
    $Nachname = $env:Nachname
    $Kennwort = $env:UserKennwort

    
        
    $Userprincipal = $env:Mailadresse
        $varLizenz = $env:Lizenz

            switch ( $varLizenz )
            {
                "1" { $license = ((Get-MsolAccountSku) | Where-Object -Property "AccountSkuId" -like "*O365_BUSINESS*").AccountSkuId    }
                "2" { $license = ((Get-MsolAccountSku) | Where-Object -Property "AccountSkuId" -like "*O365_BUSINESS_ESSENTIALS*").AccountSkuId    }
                "3" { $license = ((Get-MsolAccountSku) | Where-Object -Property "AccountSkuId" -like "*O365_BUSINESS_PREMIUM*").AccountSkuId    }
                "4" { $license = ((Get-MsolAccountSku) | Where-Object -Property "AccountSkuId" -like "*EXCHANGESTANDARD*").AccountSkuId    }
                "5" { $license = ((Get-MsolAccountSku) | Where-Object -Property "AccountSkuId" -like "*PROJECTESSENTIALS*").AccountSkuId    }
                "6" { $license = ((Get-MsolAccountSku) | Where-Object -Property "AccountSkuId" -like "*PROJECTPREMIUM*").AccountSkuId    }
                "7" { $license = ((Get-MsolAccountSku) | Where-Object -Property "AccountSkuId" -like "*PROJECTPROFESSIONAL*").AccountSkuId    }
                "8" { $license = ((Get-MsolAccountSku) | Where-Object -Property "AccountSkuId" -like "*ENTERPRISEPA*").AccountSkuId    }
        
            }

                  
        

      
write-host "Der Benutzer wird nun erstellt mit der Lizenz $license" -foreground "green"

       try {
       New-MsolUser -DisplayName $Displayname -FirstName $Vorname -LastName $Nachname -UserPrincipalName $Userprincipal -UsageLocation "CH" -LicenseAssignment $license -Password $Kennwort -ErrorAction Stop
       }
       catch
       {
       write-host "`n`nDer Benutzer konnte leider nicht erstellt werden`nHäufige Probleme sind:`n- Es ist keine Lizenz mehr vorhanden`n- Die Mailadresse ist nicht korrekt (Domäne?)`n Office365 ist ausgelastet`n`n" -foreground "red" 
       
       exit
       }


write-host "`n`nDer Benutzer wurde erstellt." -foreground "green"

 
write-host "`nPostfächer werden nun vorbereitet.`nDieser Vorgang dauert 3min. Bitte warten" -foreground "green"

Start-Sleep 180

$useremail = $Userprincipal

write-host Sprache und Regionseinstellungen werden gesetzt... !kann mehrere Minuten dauern! -foreground "magenta"
set-mailbox $useremail -language de-ch
Set-MailboxRegionalConfiguration $useremail -Language 2055 -DateFormat "dd.MM.yyyy" -TimeZone "W. Europe Standard Time" -timeformat "HH:mm" -LocalizeDefaultFolderName:$true
write-host Sprache und Regionseinstellungen anzeigen für Kontrolle... -foreground "magenta"
Get-MailboxRegionalConfiguration $useremail

write-host Kalenderberechtigungen werden gesetzt... -foreground "magenta"
Set-MailboxFolderPermission $useremail":\Kalender" -User Default -AccessRights Reviewer
write-host Kalenderberechtigungen anzeigen für Kontrolle... -foreground "magenta"
get-MailboxFolderPermission $useremail":\Kalender" -user Default |Select-Object Identity,user,accessrights

write-host Einstellungen für ablaufen des Kennworts werden gesetzt... -foreground "magenta"
Get-MsolUser -UserPrincipalName $useremail | set-msoluser –PasswordNeverExpires $True
write-host Einstellungen für ablaufen des Kennworts anzeigen für Kontrolle... -foreground "magenta"
Get-MsolUser -UserPrincipalName $useremail | SelctO DisplayName,PasswordNeverExpires

}