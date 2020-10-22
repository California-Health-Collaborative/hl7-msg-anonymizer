Class EnsLib.HL7.Util.FormatHTMLv2Anonymize Extends EnsLib.HL7.Util.FormatHTMLv2
{

ClassMethod OutputSegment(pSegObj As EnsLib.EDI.Segment, Output pStatus As %Status, pIOStream As %IO.I.CharacterStream, pSeparators As %String, pSegNum As %String, pSegPath As %String, pParentDoc As EnsLib.EDI.Document, ByRef pSequenceNumber As %String) As %Boolean
{
    set tSegObj = pSegObj.%ConstructClone()
    
    if tSegObj.Name = "PID" {

        // Names
        $$$ThrowOnError(..Anonymize(tSegObj,"5.3")) 
        $$$ThrowOnError(..Anonymize(tSegObj,"5.2")) 
        $$$ThrowOnError(..Anonymize(tSegObj,"5.1")) 

        // Birthday
        $$$ThrowOnError(..Anonymize(tSegObj,"7"))

        // Adress
        $$$ThrowOnError(..Anonymize(tSegObj,"11.1"))
        $$$ThrowOnError(..Anonymize(tSegObj,"11.2"))
        $$$ThrowOnError(..Anonymize(tSegObj,"11.3"))
        $$$ThrowOnError(..Anonymize(tSegObj,"11.4"))
        $$$ThrowOnError(..Anonymize(tSegObj,"11.5"))
        $$$ThrowOnError(..Anonymize(tSegObj,"11.6"))

        //SSN
        $$$ThrowOnError(..Anonymize(tSegObj,"19"))

    }

    quit ##super(tSegObj , .pStatus , pIOStream , pSeparators , pSegNum , pSegPath , pParentDoc, .pSequenceNumber)
}

ClassMethod Anonymize(pSegment As EnsLib.EDI.Segment, pPosition As %String) As %Status
{

    set sc = $$$OK

    set tLen = $LENGTH(pSegment.GetValueAt(pPosition))

    set value = ""
    for i=1:1:tLen {
        set value = value _ "*"
    }

    if value '= "" {
        set sc = pSegment.SetValueAt(value,pPosition)
    }


    Quit sc
}

}
