Class Grongier.HL7.Message Extends EnsLib.HL7.Message
{

/// Display Segments as HTML, using DocType info if available
Method OutputHTML() As %Status
{
	Set tSC=$$$OK
	Set tSeparators=..Separators  Set:""=tSeparators tSeparators=$$$HL7DefSeparators Set:""=$$$SEGTERM(tSeparators) tSeparators=tSeparators_..SegmentTerminator  Set $$$SEGTERM(tSeparators)=$ZStrip($$$SEGTERM(tSeparators),"*CW")
	Quit ..OutputToDevice(,tSeparators,"Grongier.HL7.Util.FormatHTMLv2")
}

/// Display Segments as HTML, using DocType info if available
Method OutputHTMLZen() As %Status
{
	Set tSC=$$$OK
	Set tSeparators=..Separators  Set:""=tSeparators tSeparators=$$$HL7DefSeparators Set:""=$$$SEGTERM(tSeparators) tSeparators=tSeparators_..SegmentTerminator  Set $$$SEGTERM(tSeparators)=$ZStrip($$$SEGTERM(tSeparators),"*CW")
	Quit ..OutputToDevice(,tSeparators,"Grongier.HL7.Util.FormatHTMLv2")
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}
