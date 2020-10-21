Class EnsLib.HL7.Util.FormatHTMLv2Anonymize Extends EnsLib.HL7.Util.FormatHTMLv2
{

ClassMethod OutputSegment(pSegObj As EnsLib.EDI.Segment, Output pStatus As %Status, pIOStream As %IO.I.CharacterStream, pSeparators As %String, pSegNum As %String, pSegPath As %String, pParentDoc As EnsLib.EDI.Document, ByRef pSequenceNumber As %String) As %Boolean
{
    set tSegObj = pSegObj.%ConstructClone()
    
    if tSegObj.Name = "PID" {

        $$$ThrowOnError(tSegObj.SetValueAt("***","5.2")) //Given Name
        $$$ThrowOnError(tSegObj.SetValueAt("***","5.1")) //Family Name

    }

    quit ##super(tSegObj , .pStatus , pIOStream , pSeparators , pSegNum , pSegPath , pParentDoc, .pSequenceNumber)
}

}
