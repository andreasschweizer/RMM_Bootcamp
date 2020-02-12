try{
    <#
        In diesem Block der Code, der eine Exception auslösen könnte
    #>
}
catch{
    <#
	Hier findet die Fehlerbehandlung statt, z.B. das Schreiben eines Logs
	Der letzte aufgezeichnete Fehler ist hier über die Variable $_ abrufbar,
	einzelne Eigenschaften daher nach diesem Muster: $_.Exception.Message
    #>
}
finally{
    <#
        Jede Anweisung in diesem Block wird immer ausgeführt, egal ob ein
	Fehler aufgetreten ist oder nicht. Dieser Block ist optional.
    #>
}
