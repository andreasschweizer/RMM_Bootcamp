$regwert = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\diverto\Basic\Data -Name Testvalue

if($regwert -eq 1)
{
Write-Host "<-Start Result->"
Write-Host "CSMON_ResultMessage=Testvalue hat den Wert 1 und gibt einen Fehler zur�ck"
Write-Host "<-End Result->"

Write-Host "<-Start Diagnostic->"
Write-Host "Hier k�nnen zus�tzliche Infos stehen"
Write-Host "Auch mehrere Zeilen"
Write-Host "<-End Diagnostic->"
exit 1
} else {
Write-Host "CSMON_ResultMessage=Testvalue hat nicht den Wert 1 und gibt keinen Fehler zur�ck"
exit 0
}