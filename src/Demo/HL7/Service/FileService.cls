/* Copyright (c) 2020 by InterSystems Corporation.
   Cambridge, Massachusetts, U.S.A.  All rights reserved.
   Confidential property of InterSystems Corporation. */

Class Demo.HL7.Service.FileService Extends Grongier.HL7.Service.Standard
{

Parameter ADAPTER = "EnsLib.File.InboundAdapter";

/// ConfigName(s) of the operations or processes to which reply (e.g. ACK) messages should be forwarded.
Property AckTargetConfigNames As %String;

Parameter SETTINGS = "AckTargetConfigNames:Basic:selector?multiSelect=1&context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId}";

/* (override default value for Setting inherited from base class) */
/// Control of ACK handling; options:
/// - Never : Do not send back any ACK
/// - Immediate : Send back (commit) ACK reply message immediately upon receipt of the inbound message
/// - Application : If message passes validation, wait for ACK from target config item and forward it back when it arrives
/// - MSH-determined : Send back ACK reply messages as requested in the MSH header of the incoming message
Property AckMode As %String(DISPLAYLIST = ",Never,Immediate,Application,MSH-determined", VALUELIST = ",Never,Immed,App,Msh") [ InitialExpression = "Never", Required ];

/// End-Segment marker character(s)
Property SegTerminator As %String [ InitialExpression = {$C(13,10)} ];

Parameter OpenTimeout As %Numeric = 5;

Parameter ReadTimeout As %Numeric = 1;

Method OnInit() As %Status
{
	Set tSC=##super()  Quit:$$$ISERR(tSC) tSC
	Set (..%Parser.StartTimeout,..%Parser.ReadTimeout)=..#ReadTimeout
	If $$$XOR(""=..AckTargetConfigNames,"Never"=..AckMode) {
		If ""=..AckTargetConfigNames { $$$LOGWARNING("No ACK Target Config Name configured for AckMode '"_..AckMode_"'") }
		Else { $$$LOGWARNING("ACK Target ConfigName(s) '"_..AckTargetConfigNames_"' configured for AckMode '"_..AckMode_"'") }
	}
	Quit $$$OK
}

Method OnProcessInput(pFileStream As %CharacterStream, Output pOutput As %RegisteredObject) As %Status
{
	Set tInputFilename=$tr(pFileStream.Filename,"/","\"), tInputFilename=$P(tInputFilename,"\",$L(tInputFilename,"\")) 
	$$$sysTRACE("Got File "_tInputFilename)

	Set tIOStream=##class(%IO.FileStream).%New()  $$$ASSERT($IsObject(tIOStream))
	Do tIOStream.Open(pFileStream.Filename,,..#OpenTimeout,,.tSC)  Quit:$$$ISERR(tSC) tSC

	Do ..%Parser.Reset()
	While 'tIOStream.AtEnd { ; Loop over docs in the file
		Set tIOStreamPos = tIOStream.Position
		Set tSC1=..%Parser.ParseFramedIOStream(tIOStream,,1)
		If $$$ISERR(tSC1) {
			Set tSC=$$$ADDSC(tSC,tSC1)
			If ($$$StatusText(tSC1)["<TRANSLATE>") {
				Set tSC2 = $$$ERROR($$$EnsErrGeneral,"Incorrect Character Encoding/Translation Table used for file.("_tIOStream.CharEncoding_"/"_tIOStream.TranslationTable_")")
				// !!! quit on fatal errors only
				Set tSC=$$$ADDSC(tSC2,tSC)
				Quit
			}
			// !!! quit on fatal errors only and prevent looping
			Quit:($$$StatusEquals(tSC1,$$$EnsErrGeneral)||(tIOStreamPos=tIOStream.Position))
		}
	}
	Do ..%Parser.Reset() ; release the file
	Quit tSC
}

Method SendReply(pReplyDocument As EnsLib.EDI.Document, pOriginalDoc As EnsLib.EDI.Document = {$$$NULLOREF}) As %Status
{
	If ""=..AckTargetConfigNames {
		$$$sysTRACE("ACK "_pReplyDocument_$S($IsObject(pReplyDocument):"/"_pReplyDocument.%Id(),1:"")_" not sent because no ACK Target Config Name is configured")
		Quit $$$OK
	}
	Set pReplyDocument.IsMutable=0
	Set tSC=$$$OK  For iTarget=1:1:$L(..AckTargetConfigNames, ",") { Set tOneTarget=$ZStrip($P(..AckTargetConfigNames,",",iTarget),"<>W")  Continue:""=tOneTarget
		Set tSC1=..SendRequestAsync(tOneTarget,pReplyDocument) Quit:$$$ISERR(tSC)
		Set:$$$ISERR(tSC1) tSC=$$$ADDSC(tSC,tSC1)
	}
	Quit tSC
}

/// Return the segment terminator string that the Parser and the OutputTo...() methods will use.
Method GetSegmentTerminator() As %String
{
	Quit ..SegTerminator
}

ClassMethod OnGetConnections(Output pArray As %String, pItem As Ens.Config.Item)
{
	Do ##super(.pArray,pItem)
	If pItem.GetModifiedSetting("AckTargetConfigNames",.tValue) {
		For i=1:1:$L(tValue,",") { Set tOne=$ZStrip($P(tValue,",",i),"<>W")  Continue:""=tOne  Set pArray(tOne)="" }
	}
}

}
