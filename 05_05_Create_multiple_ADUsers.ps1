#_________________________________________ACCESS DVCLADS01 for AD Manipulations

#$cred=Get-Credential
#$sess = New-PSSession -Credential $cred -ComputerName dvclads01
#Enter-PSSession $sess

Import-Module ActiveDirectory

#Store the data from ADUsers.csv in the $ADUsers variable
$ADUsers = Import-csv C:\divertoInstall\UserImport\divertocloud-User-Import.csv

#Loop through each row containing user details in the CSV file 
foreach ($User in $ADUsers)
{
	#Read user data from each field in each row and assign the data to a variable as below
		
	$Username 	= $User.username
	$Password 	= $User.password
	$Firstname 	= $User.firstname
	$Lastname 	= $User.lastname
	$OU 		= $User.ou #This field refers to the OU the user account is to be created in
    $email      = $User.email
    $Password   = $User.Password


	#Check to see if the user already exists in AD
	if (Get-ADUser -F {SamAccountName -eq $Username})
	{
		 #If user does exist, give a warning
		 Write-Warning "A user account with username $Username already exist in Active Directory."
	}
	else
	{
		#User does not exist then proceed to create the new user account
		
        #Account will be created in the OU provided by the $OU variable read from the CSV file
		New-ADUser `
            -SamAccountName $Username `
            -UserPrincipalName "$email" `
            -Name "$Firstname $Lastname" `
            -GivenName $Firstname `
            -Surname $Lastname `
            -Enabled $True `
            -DisplayName "$Lastname, $Firstname" `
            -Path $OU `
            -EmailAddress $email `
            -AccountPassword (convertto-securestring $Password -AsPlainText -Force) -ChangePasswordAtLogon $false -passwordNeverExpires $true 
            
	}
}
# Proxyadressen
Set-ADUser $Username -Add @{Proxyaddresses="SMTP:$email"}

write-host "All Users created successfully as long as you saw no error" -ForegroundColor Green