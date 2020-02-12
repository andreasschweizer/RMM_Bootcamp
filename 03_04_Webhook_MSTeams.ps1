if($env:TeamsBenachrichtigung -eq $true)
{
#Teams Mitteilung - Ab PowerShell 3.0 möglich.
$uri = "https://outlook.office.com/webhook/54d28b52-a536-4190-82f8-75c2cf338700@d79a146a-b6bf-4ec5-9e09-23eaaaf958d0/IncomingWebhook/2781223ea2f2489a802ef36bc666657f/35918cfa-15f9-4?9d-bf77-c7d4f7c88513"
$timeanddate = Get-Date
$body = ConvertTo-JSON @{ text = "Ger&auml;t: $env:computername<br />Aktion: In 5 Minuten neustarten<br />Datum & Zeit: $timeanddate <br />Ticketnummer: $env:Ticketnummer <br />Initiiert durch $env:MitarbeiterKRZL<br /><br />Um die Aktion abzubrechen, muss der Prozess powershell.exe auf dem Ger&auml;t beendet werden: <a href='https://pinotage.centrastage.net/csm/search?qs=$env:computername'>Auf Ger&auml;t verbinden</a>"}
Invoke-RestMethod -uri $uri -Method Post -body $body -ContentType 'application/json'
}