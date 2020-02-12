# Quelle: https://gallery.technet.microsoft.com/Password-Expiry-Email-177c3e27
<# 
.Synopsis 
   Script to Automated Email Reminders when Users Passwords due to Expire. 
.DESCRIPTION 
   Script to Automated Email Reminders when Users Passwords due to Expire. 
   Robert Pearman / WindowsServerEssentials.com 
   Version 2.9 August 2018 
   Requires: Windows PowerShell Module for Active Directory 
   For assistance and ideas, visit the TechNet Gallery Q&A Page. http://gallery.technet.microsoft.com/Password-Expiry-Email-177c3e27/view/Discussions#content 
 
   Alternativley visit my youtube channel, https://www.youtube.com/robtitlerequired 
 
   Videos are available to cover most questions, some videos are based on the earlier version which used static variables, however most of the code 
   can still be applied to this version, for example for targeting groups, or email design. 
 
   Please take a look at the existing Q&A as many questions are simply repeating earlier ones, with the same answers! 
 
 
.EXAMPLE 
  PasswordChangeNotification.ps1 -smtpServer mail.domain.com -expireInDays 21 -from "IT Support <support@domain.com>" -Logging -LogPath "c:\logFiles" -testing -testRecipient support@domain.com 
   
  This example will use mail.domain.com as an smtp server, notify users whose password expires in less than 21 days, send mail from support@domain.com 
  Logging is enabled, log path is c:\logfiles 
  Testing is enabled, and test recipient is support@domain.com 
 
.EXAMPLE 
  PasswordChangeNotification.ps1 -smtpServer mail.domain.com -expireInDays 21 -from "IT Support <support@domain.com>" -reportTo myaddress@domain.com -interval 1,2,5,10,15 
   
  This example will use mail.domain.com as an smtp server, notify users whose password expires in less than 21 days, send mail from support@domain.com 
  Report is enabled, reports sent to myaddress@domain.com 
  Interval is used, and emails will be sent to people whose password expires in less than 21 days if the script is run, with 15, 10, 5, 2 or 1 days remaining untill password expires. 
 
#> 
$divertosupport = "supportadresse@diverto.ch"
$From = "mailadresse@diverto.ch"
#$SMTPServer = "diverto-ch.mail.protection.outlook.com"
$SMTPServer = "smtp.office365.com"
$SMTPPort = "587"
$Username = "mailadresse@diverto.ch"
$Password = $env:MailPasswort
[int]$expireInDays = $env:SiteTageBisAblauf
#$interval = $env:SiteIntervall
$interval = "30","20","10","5","1"
$Eskalation_x_Tage_vor_Ablauf = $env:SiteEskalieren_vor_Ablauf
$reportto = $env:SiteinternalSupportMail
$testRecipient = $divertosupport

# SMTP Server, Port und SSL setzten
$SMTPClient = New-Object Net.Mail.SmtpClient($SMTPServer,$SMTPPort) 
$SMTPClient.EnableSsl = $true 

# Setzten der Anmeldedaten für SMTP Authentifizierung
$SMTPClient.Credentials = New-Object System.Net.NetworkCredential($Username,$Password)

################################################################################################################### 
# Time / Date Info 
$start = [datetime]::Now 
$midnight = $start.Date.AddDays(1) 
$timeToMidnight = New-TimeSpan -Start $start -end $midnight.Date 
$midnight2 = $start.Date.AddDays(2) 
$timeToMidnight2 = New-TimeSpan -Start $start -end $midnight2.Date 
# System Settings 
$textEncoding = [System.Text.Encoding]::UTF8 
$today = $start 
# End System Settings 
 
# Load AD Module 
try{ 
    Import-Module ActiveDirectory -ErrorAction Stop 
} 
catch{ 
    Write-Warning "Unable to load Active Directory PowerShell Module" 
} 
# Set Output Formatting - Padding characters 
$padVal = "20" 
Write-Output "Script Loaded" 
Write-Output "*** Settings Summary ***" 
$smtpServerLabel = "SMTP Server".PadRight($padVal," ") 
$expireInDaysLabel = "Expire in Days".PadRight($padVal," ") 
$fromLabel = "From".PadRight($padVal," ") 
$testLabel = "Testing".PadRight($padVal," ") 
$testRecipientLabel = "Test Recipient".PadRight($padVal," ") 
$logLabel = "Logging".PadRight($padVal," ") 
$logPathLabel = "Log Path".PadRight($padVal," ") 
$reportToLabel = "Report Recipient".PadRight($padVal," ") 
$interValLabel = "Intervals".PadRight($padval," ") 
# Testing Values 
if($testing) 
{ 
    if(($testRecipient) -eq $null) 
    { 
        Write-Output "No Test Recipient Specified" 
        Exit 
    } 
} 

# Output Summary Information 
Write-Output "$smtpServerLabel : $smtpServer" 
Write-Output "$expireInDaysLabel : $expireInDays" 
Write-Output "$fromLabel : $from" 
Write-Output "$logLabel : $logging" 
Write-Output "$logPathLabel : $logPath" 
Write-Output "$testLabel : $testing" 
Write-Output "$testRecipientLabel : $testRecipient" 
Write-Output "$reportToLabel : $reportto" 
Write-Output "$interValLabel : $interval" 
Write-Output "*".PadRight(25,"*") 
# Get Users From AD who are Enabled, Passwords Expire and are Not Currently Expired 
# To target a specific OU - use the -searchBase Parameter -https://docs.microsoft.com/en-us/powershell/module/addsadministration/get-aduser 
# You can target specific group members using Get-AdGroupMember, explained here https://www.youtube.com/watch?v=4CX9qMcECVQ  
# based on earlier version but method still works here. 
$users = get-aduser -filter {(Enabled -eq $true) -and (PasswordNeverExpires -eq $false)} -properties Name, PasswordNeverExpires, PasswordExpired, PasswordLastSet, EmailAddress | where { $_.passwordexpired -eq $false } 
# Count Users 
$usersCount = ($users | Measure-Object).Count 
Write-Output "Found $usersCount User Objects" 
# Collect Domain Password Policy Information 
$defaultMaxPasswordAge = (Get-ADDefaultDomainPasswordPolicy -ErrorAction Stop).MaxPasswordAge.Days  
Write-Output "Domain Default Password Age: $defaultMaxPasswordAge" 
# Collect Users 
$colUsers = @() 
# Process Each User for Password Expiry 
Write-Output "Process User Objects" 
foreach ($user in $users) 
{ 
    # Store User information 
    $Name = $user.Name
    $emailaddress = $user.emailaddress 
    $passwordSetDate = $user.PasswordLastSet 
    $samAccountName = $user.SamAccountName 
    $pwdLastSet = $user.PasswordLastSet 
    # Check for Fine Grained Password 
    $maxPasswordAge = $defaultMaxPasswordAge 
    $PasswordPol = (Get-AduserResultantPasswordPolicy $user)  
    if (($PasswordPol) -ne $null) 
    { 
        $maxPasswordAge = ($PasswordPol).MaxPasswordAge.Days 
    } 
    # Create User Object 
    $userObj = New-Object System.Object 
    $expireson = $pwdLastSet.AddDays($maxPasswordAge) 
    $daysToExpire = New-TimeSpan -Start $today -End $Expireson 
    # Round Expiry Date Up or Down 
    if(($daysToExpire.Days -eq "0") -and ($daysToExpire.TotalHours -le $timeToMidnight.TotalHours)) 
    { 
        $userObj | Add-Member -Type NoteProperty -Name UserMessage -Value "today." 
    } 
    if(($daysToExpire.Days -eq "0") -and ($daysToExpire.TotalHours -gt $timeToMidnight.TotalHours) -or ($daysToExpire.Days -eq "1") -and ($daysToExpire.TotalHours -le $timeToMidnight2.TotalHours)) 
    { 
        $userObj | Add-Member -Type NoteProperty -Name UserMessage -Value "tomorrow." 
    } 
    if(($daysToExpire.Days -ge "1") -and ($daysToExpire.TotalHours -gt $timeToMidnight2.TotalHours)) 
    { 
        $days = $daysToExpire.TotalDays 
        $days = [math]::Round($days) 
        $userObj | Add-Member -Type NoteProperty -Name UserMessage -Value "in $days days." 
    } 
    $daysToExpire = [math]::Round($daysToExpire.TotalDays) 
    $userObj | Add-Member -Type NoteProperty -Name UserName -Value $samAccountName 
    $userObj | Add-Member -Type NoteProperty -Name Name -Value $Name 
    $userObj | Add-Member -Type NoteProperty -Name EmailAddress -Value $emailAddress 
    $userObj | Add-Member -Type NoteProperty -Name PasswordSet -Value $pwdLastSet 
    $userObj | Add-Member -Type NoteProperty -Name DaysToExpire -Value $daysToExpire 
    $userObj | Add-Member -Type NoteProperty -Name ExpiresOn -Value $expiresOn 
    # Add userObj to colusers array 
    $colUsers += $userObj 
} 
# Count Users 
$colUsersCount = ($colUsers | Measure-Object).Count 
Write-Output "$colusersCount Users processed" 
# Select Users to Notify 
$notifyUsers = $colUsers | where { $_.DaysToExpire -le $expireInDays} 
$notifiedUsers = @() 
$notifyCount = ($notifyUsers | Measure-Object).Count 
Write-Output "$notifyCount Users with expiring passwords within $expireInDays Days" 
# Process notifyusers 
foreach ($user in $notifyUsers) 
{ 
    # Email Address 
    $samAccountName = $user.UserName 
	$daysToExpire = [int]$user.DaysToExpire
    [array]$emailAddress = $user.EmailAddress 
    # Set Greeting Message 
    $name = $user.Name 
    $messageDays = $user.UserMessage 
    # Subject Setting 
    $subject="$name, Ihr Kennwort läuft in $daysToExpire Tagen aus" 
    # Email Body Set Here, Note You can use HTML, including Images. 
    # examples here https://youtu.be/iwvQ5tPqgW0  
    $body = "<html>
<head>
<style>
.Normal {font-size:15px;font-family:Calibri, Arial,Sans-Serif}
</style>
</head>
<body>

<p class=Normal>Sehr geehrte/r Frau / Herr $name<br>
<br>
Ihr Kennwort l&auml;uft in $daysToExpire Tagen aus.<br>
Bitte &auml;ndern Sie Ihr Kennwort rechtzeitig, damit Sie nicht den Zugriff auf die Dom&auml;ne verlieren.<br>
Um Ihr Kennwort zu &auml;ndern, dr&uuml;cken Sie CTRL ALT DEL und w&auml;hlen Sie Kennwort &auml;ndern.<br>
<br>
Wenn Sie eine Gesch&auml;ftsmail  $emailaddress  auf dem Handy eingerichtet haben, besteht die M&ouml;glichkeit, dass Sie aufgefordert werden das Kennwort dort zus&auml;tzlich zu &auml;ndern.<br><br>
_________________________<br>
<br>
<br>
Chère Madame / Monsieur $name<br>
<br>
Votre mot de passe expire dans $daysToExpire jours.<br>
Veuillez modifier votre mot de passe à temps pour ne pas perdre l'accès au domaine.<br>
Pour changer votre mot de passe, appuyez sur CTRL ALT DEL et sélectionnez Modifier le mot de passe.<br>
<br>
Si vous avez configuré un e-mail professionnel  $emailaddress  sur votre téléphone, vous pouvez être invité à y modifier votre mot de passe.<BR><br>
_________________________<br>
<br>
<br>
Dear $name<br>
<br>
Your password expires in $daysToExpire days.<br>
Please change your password in good time so that you do not lose access to the domain.<br>
To change your password, press CTRL ALT DEL and select Change Password.<br>
<br>
If you've set up a business email  $emailaddress  on your phone, you may be asked to change your password there too.<br>
<br>
<br>
<STRONG>Freundliche Grüsse, Cordialement, With kind regards</STRONG><br>
<br>
<STRONG>diverto gmbh</STRONG><br>
<BR>
Schulhausstrasse 6 | CH-3672 Oberdiessbach<BR>
<br>
Phone: +41 31 770 00 70<br>
<br>
<STRONG>Support</STRONG><br>
Phone: +41 31 770 00 10<br>
E-Mail: support@diverto.ch<br>
</p></BODY></HTML>"

	
    
    # If a user has no email address listed 
    if(($emailaddress) -eq $null) 
    { 
        $emailaddress = $testRecipient     
    }# End No Valid Email 
    $samLabel = $samAccountName.PadRight($padVal," ") 
    
        # If using interval paramter - follow this section 
        if($interval) 
        { 
             
            # check interval array for expiry days 
            if($interval -Contains $daysToExpire)
            {
                if ($daysToExpire -gt $Eskalation_x_Tage_vor_Ablauf)
                {
                #Nachricht wird erstellt
                    $mail = New-Object System.Net.Mail.Mailmessage $From, $emailaddress, $subject, $Body
                    $mail.IsBodyHTML = $true
                    #Nachricht wird gesendet
                   $SMTPClient.send($mail)
					Write-Output "Mail an $emailaddress gesendet. Ablauf in $daysToExpire Tagen"
                }
                else
                { 
                    $emailaddress += $reportto
                    $emailaddress += $divertosupport
                    foreach ($adr in $emailaddress)
                    {
                        #Nachricht wird erstellt
                        $mail = New-Object System.Net.Mail.Mailmessage $From, $adr, $subject, $Body
                        $mail.IsBodyHTML = $true
                        #Nachricht wird gesendet
                       $SMTPClient.send($mail)
						
                    }
Write-Output "Mail an $emailaddress, $reportto und $divertosupport gesendet.Ablauf in $daysToExpire Tagen"
                } 
			}
            else 
            { 
                # No Message sent 
                $user | Add-Member -MemberType NoteProperty -Name SendMail -Value "Skipped - Interval"
				Write-Output "Es wurde keine E-Mail gesendet an $emailaddress. Der Intervall stimmt nicht mit der Bedingung überein. Kennwort läuft ab in $daysToExpire Tagen"
				
            } 
         
		}
		 
   
}
$notifiedUsers | select UserName,Name,EmailAddress,PasswordSet,DaysToExpire,ExpiresOn | sort DaystoExpire | FT -autoSize 
 
$stop = [datetime]::Now 
$runTime = New-TimeSpan $start $stop 
Write-Output "Script Runtime: $runtime" 
# End 