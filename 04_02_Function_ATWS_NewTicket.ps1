function New-Ticket ([string]$body) {
    # Body anpassen
    $body = $body

    $mydate = Get-Date -format "dd.MM.yyyy"
    $ticketTitle = "divertocloud drive Nutzungsbericht - $mydate"

    # Fälligkeit Ticket
    $DueDateTime = (Get-Date -Hour "14" -Minute "00" -Second "00").AddDays(3)

    $myTicket = New-AtwsTicket -AccountID 0 -Title $ticketTitle -Description $body -Status Neu -Priority Niedrig -QueueID "1st Level" -TicketCategory "Vertragsticket" -DueDateTime $DueDateTime
        
    if($null -ne $myticket){
        Write-Output "[ERFOLGREICH] Autotask Ticket erfolgreich erstellt."

        $myTicketID = $myTicket.id
        # Anhang mit weiteren Infos zu den AD Benutzern an Ticket anfügen
        $myTicketAttachment = New-AtwsAttachment -Path $outputfile -TicketID $myTicketID -Title "divertocloud drive details"
        # Erstellten Anhang überprüfen
        if($null -eq $myTicketAttachment){
            Write-Output "[FEHLER] Anhang konnte nicht an Ticket angehängt werden"
            Write-Output "Output hier ersichtlich oder via Textfile auf Gerät in folgendem Pfad: $outputfile"
            exit 1
        }
        else {
            Write-Output "[ERFOLGREICH] Anhang konnte an Ticket angehängt werden"
            exit 0
        }
    }
    else {
        Write-Output "[FEHLER] Autotask Ticket konnte nicht erstellt werden."
        exit 1
    }
}


### Aufrufen der Funktion
New-Ticket($ticketbody)