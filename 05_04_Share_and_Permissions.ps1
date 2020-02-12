$Kunde = $env:Kundenname

$KrzlB = $env:KuerzelGross

$KrzlS = $env:KuerzelKlein


#_________________________________________Go back to DVCLFIL01 to create shares    


    $PATHMain = "D:\$KrzlB" 
        if (!(Test-Path $PATHMain)) {New-Item -Path $PATHMain -ItemType Directory}
    $PATHSub1 = "D:\$KrzlB\Data"
        if (!(Test-Path $PATHSub1)) {New-Item -Path $PATHSub1 -ItemType Directory}
    $PATHSub2 = "D:\$KrzlB\Userhome"
    $PATHSub3 = "D:\$KrzlB\Userprofile"



#_________________________________________Erstellen der Freigabe userprofile$ mit Berechtigungen
$sharename = "$KrzlB$"
New-SmbShare -Name $sharename -Path $PATHMain | Grant-SmbShareAccess -AccountName domänen-admins -AccessRight Full -Force
Revoke-SmbShareAccess -Name $sharename -AccountName Jeder -Force
Grant-SmbShareAccess -Name $sharename -AccountName "G_AllUsers_$KrzlS" -AccessRight Full -Force


#_________________________________________Erstellen falls nicht vorhanden von S:\KRZL$\Data mit Berechtigungen

icacls $PATHSub1 /inheritance:d
icacls $PATHSub1  /remove:g benutzer /T
$acl1 = Get-Acl $PATHSub1
$Ar1 = New-Object System.Security.AccessControl.FileSystemAccessRule("G_AllUsers_$KrzlS","FullControl","ContainerInherit, ObjectInherit", "None", "Allow")
$acl1.SetAccessRule($Ar1)
$acl1 | Set-Acl $PATHSub1



#_________________________________________Erstellen falls nicht vorhanden von S:\KRZL$\Userhome mit Berechtigungen
if (Test-Path $PATHSub2){
echo "Der Ordner ist bereits vorhanden"
}
else {
echo "Der Ordner userhome ist noch nicht vorhanden und wird erstellt"
New-Item -ItemType Directory -Path $PATHSub2
icacls $PATHSub2 /inheritance:d
icacls $PATHSub2  /remove:g benutzer /T
$acl2 = Get-Acl $PATHSub2
$Ar2 = New-Object System.Security.AccessControl.FileSystemAccessRule("G_AllUsers_$KrzlS",@("ReadAndExecute", "ListDirectory", "ReadAttributes", "ReadExtendedAttributes", "CreateDirectories", "AppendData", "ReadPermissions"), "Allow")
$acl2.SetAccessRule($Ar2)
$acl2 | Set-Acl $PATHSub2
}

	
#_________________________________________Erstellen falls nicht vorhanden von S:\KRZL$\Userprofile mit Berechtigungen
if (Test-Path $PATHSub3){
echo "Der Ordner ist bereits vorhanden"
}
else {
echo "Der Ordner userprofile ist noch nicht vorhanden und wird erstellt"
New-Item -ItemType Directory -Path $PATHSub3
icacls $PATHSub3 /inheritance:d
icacls $PATHSub3  /remove:g benutzer /T
$acl3 = Get-Acl $PATHSub3
$Ar3 = New-Object System.Security.AccessControl.FileSystemAccessRule("G_AllUsers_$KrzlS",@("ReadAndExecute", "ListDirectory", "ReadAttributes", "ReadExtendedAttributes", "CreateDirectories", "AppendData", "ReadPermissions"), "Allow")
$acl3.SetAccessRule($Ar3)
$acl3 | Set-Acl $PATHSub3
}	

