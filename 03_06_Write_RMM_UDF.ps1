$registryPath = "HKLM:\Software\Centrastage"
$Name = "custom10“
New-Item -Path $registryPath –Forc
New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType STRING -Force