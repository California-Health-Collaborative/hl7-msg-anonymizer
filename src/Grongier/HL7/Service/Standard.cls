/* Copyright (c) 2020 by InterSystems Corporation.
   Cambridge, Massachusetts, U.S.A.  All rights reserved.
   Confidential property of InterSystems Corporation. */

Include EnsHL7

Class Grongier.HL7.Service.Standard Extends (Ens.BusinessService, EnsLib.HL7.Util.IOFraming, EnsLib.EDI.ServiceInterface) [ Abstract, ClassType = "", Inheritance = right, ProcedureBlock, System = 4 ]
{

Parameter DOCCLASS As %String = "Grongier.HL7.Message";

/// Configuration item(s) to which to send messages
Property TargetConfigNames As %String(MAXLEN = 2000);

/// Store a set of searchable properties associated with each HL7 message processed. <br/>
/// These records will be stored in the named SearchTable class, if any.
Property SearchTableClass As %String(MAXLEN = 128) [ InitialExpression = "EnsLib.HL7.SearchTable" ];

/// Colon-separated LocalFacility:LocalApplication codes representing this (receiving) facility and application <br/>
/// These are used in constructing reply ACK message headers as SendingFacility and SendApplication. <br/>
/// The '@' symbol represents using the corresponding field from the incoming message. <br/>
/// If your ID must contain a literal @ symbol, escape it with backslash: '\@'
Property LocalFacilityApplication As %String [ InitialExpression = "ISC:EnsembleHL7" ];

/* (override comments, display lists and defaults for setting inherited from base class) */
/// HL7 inbound message framing protocol. The options are: <br/><ul>
/// <li>Flexible: Determine framing style from the content of received data of each message received. </li>
/// <li>Flexible!: Determine framing style from the content of received data of the first message and require subsequent messages to have that same framing style. </li>
/// <li>None: No framing - Each line that begins with 'MSH' is the start of a new message. </li>
/// <li>MLLP: Minimal Lower Level Protocol - Frame each HL7 message with ASCII code 11 prefix and ASCII code 28,13 suffix. </li>
/// <li>MLLPN/M: Minimal Lower Level Protocol - Frame each HL7 message with ASCII code N prefix, and ASCII code M suffix followed by an additional ASCII code 13. </li>
/// <li>AsciiLF: Frame messages with ASCII code 10 (Line Feed) separating each message from the subsequent one. </li>
/// <li>AsciiCR: Frame messages with an extra ASCII code 13 (Carriage Return) separating each message from the subsequent one. </li>
/// <li>AsciiM: Frame messages with ASCII code M suffix character(s) separating each message from the subsequent one. </li>
/// <li>AsciiN/M: Frame messages with ASCII code N prefix character(s) before each message and ASCII code M suffix character(s), but no trailing ASCII code 13 as in MLLPN/M. </li>
/// <li>LLP: Lower Level Protocol - (Obsolete) Frame each HL7 message in a redundant checksum block. </li></ul><p/>
/// Notes: <br/>
/// - ASCII code N is a sequence of one or more characters represented by their ASCII code, separated by comma in case of more than one character. <br/>
/// - All ASCII codes should be given in decimal. <br/>
/// - ASCII code 120 (character 'x') is not allowed as a framing character. <br/>
Property Framing As %String(DISPLAYLIST = ",Flexible,Flexible!,None,MLLP,MLLP11/28,AsciiLF,AsciiCR,Ascii11,Ascii11/28,LLP") [ InitialExpression = "Flexible" ];

/// Control of ACK handling. The options are: <br/><ul>
/// <li>Never: Do not send back any ACK. <br/>
/// <li>Immediate: Send back (commit) ACK reply message immediately upon receipt of the inbound message. </li>
/// <li>Application: If message passes validation, wait for ACK from target config item and forward it back when it arrives. </li>
/// <li>MSH-determined: Send back ACK reply messages as requested in the MSH header of the incoming message. </li>
/// <li>Byte: Send back an immediate single ACK-code byte instead of an ACK message. Byte ASCII code 6 = 'OK', ASCII code 21 = 'Error' </li></ul>
Property AckMode As %String(DISPLAYLIST = ",Never,Immediate,Application,MSH-determined,Byte", VALUELIST = ",Never,Immed,App,Msh,Byte") [ InitialExpression = "Immed", Required ];

/// If 'true' and the HL7 message VersionID is 2.3 or higher, use the 'enhanced-mode' ACK 'Commit' codes ('Cx') in MSA:1 ('AcknowledgmentCode'). (Otherwise use the legacy-mode 'Ax' codes.)
Property UseAckCommitCodes As %Boolean [ InitialExpression = 1 ];

/// Ignore inbound ACK messages to avoid ACK feedback loop.
Property IgnoreInboundAck As %Boolean [ InitialExpression = 1 ];

/// Add ERR error code segment when generating NACK messages; otherwise do not embed internal error state information in NACK messages
Property AddNackERR As %Boolean;

/// Controls the error code in MSA:1 of the NACK message this service generates when there is an error processing the incoming message.<br/><br/>
/// The default 'ContentE' behavior is to return code 'E' for errors with the message content, and code 'R' for system errors encountered while attempting to process the message.<br/><br/>
/// This distinction is important because system errors are expected to be solved so that if the remote client tries again at a later time they may not occur, while message content &amp; validation errors are expected to require correction at the source and not to be worth retrying in the same form.<br/><br/>
/// However some client systems may expect or require a different error behavior. Therefore 3 additional behaviors are offered. The 4 behaviors are as follows: <br/><ul>
/// <li>ContentE = Use MSA error code 'E' to report errors in message content and code 'R' to reject due to (retryable) system errors. </li>
/// <li>ContentR = Return 'R' for content errors, 'E' for system errors. </li>
/// <li>AllE = Return 'E' for all content and system errors. </li>
/// <li>AllR = Return 'R' for all content and system errors. </li></ul><p/>
/// Earlier versions of Ensemble used the behavior 'ContentR' exclusively.
Property NackErrorCode As %String(VALUELIST = ",ContentE,ContentR,AllE,AllR") [ InitialExpression = "ContentE" ];

/// How to treat received batch documents: <br/><ul>
/// <li>Whole Batch: Don't process child documents individually; accumulate and send the whole batch as one composite document. </li>
/// <li>Single-Session Batch: Forward all documents in the batch as part of a single session, including final parent document objects containing batch header and trailer segments. </li>
/// <li>Multi-Session Batch: Forward each document in the batch in its own session, followed by final parent document objects containing the batch header and trailer segments. </li>
/// <li>Individual: Forward each child document in the batch in its own session; do not forward parent batch document objects. </li></ul>
Property BatchHandling As %String(DISPLAYLIST = ",Whole Batch,Single-Session Batch,Multi-Session Batch,Individual", VALUELIST = ",Whole,1Session,Batch,Indiv") [ InitialExpression = "1Session", Required ];

/// Category to apply to incoming message types to produce a complete DocType specification.<p/>
/// Combines with the document type Name (MSH:9) to produce a MessageType specification which is then used 
/// to look up a MessageStructure/DocType in the MessageTypes section of the given HL7 schema category.<p/>
/// This setting may also contain multiple comma-separated type Names followed by = and then a 
/// DocTypeCategory or full DocType value to apply to HL7 messages containing that type Name.<p/>
/// A trailing asterisk (*) at the end of a given partial type Name will match any types with that beginning part.<p/>
/// For example: MessageSchemaCategory='2.3.1, ADT_*=2.5, BAR_P10=2.4, ORM_O01_6=2.4:RDE_O01' <br>
/// Note that a DocType assignment may be needed for Validation or SearchTableClass indexing.
Property MessageSchemaCategory As %String(MAXLEN = 1000);

/// How to resolve a DocType based on the message type from MSH:9.  The options are: <br/><ul>
/// <li>Standard: Combine the effective MessageSchemaCategory value with a message structure name looked up for the MSH:9 message type value in the corresponding schema category. This is the default. </li>
/// <li>Ignore 9.3: Like 'Standard' but if MSH:9 has 3 or more pieces, ignore the additional ones. The standard behavior is to use piece 3 as part of the type name if it has no sub-pieces because some schemas contain 3-part type names. </li>
/// <li>Use 9.3: Like 'Standard' but if MSH:9 has 3 or more pieces, use the additional piece as the literal name of the document structure within the applicable schema category. Use with caution because messages may arrive with MSH:9.3 values for which no structure is present in the chosen schema category. </li>
/// <li>Literal: Combine the effective MessageSchemaCategory value with the literal MSH:9 message type value interpreted as the name of a message structure. Use only with custom schemas where every message type has a corresponding structure definition. </li></ul>
Property DocTypeResolution As %String(DISPLAYLIST = ",Standard,Ignore 9.3,Use 9.3,Literal", VALUELIST = ",Std,Ign,Use,Lit") [ InitialExpression = "Std", Required ];

Parameter SETTINGS = "TargetConfigNames:Basic:selector?multiSelect=1&context={Ens.ContextSearch/ProductionItems?targets=1&productionName=@productionId},SearchTableClass::selector?context={Ens.ContextSearch/SearchTableClasses?host=EnsLib.HL7.Service.Standard},LocalFacilityApplication,Framing:Connection:selector?context={Ens.ContextSearch/getDisplayList?host=@currHostId&prop=Framing},AckMode,UseAckCommitCodes,IgnoreInboundAck,AddNackERR,NackErrorCode,BatchHandling,MessageSchemaCategory:Basic:selector?context={Ens.ContextSearch/SchemaCategories?host=EnsLib.HL7.Service.Standard},DefCharEncoding::selector?context={Ens.ContextSearch/CharacterSets},DocTypeResolution,SaveReplies";

/// In Reply/ACK messages, use the ControlId of the message we are replying to, rather than constructing a new unique one
Parameter UseOriginalControlId As %Boolean = 1;

/* Used in AckIn... subclasses */
/// In addition to forwarding a full ACK message according to the AckMode setting, return immediate 1-byte ACKs on this Service's TCP connection.
Property ImmediateByteAck As %Boolean;

/// For batch documents, don't process child Message documents individually; accumulate and send the whole batch at once.
Property %ForwardBatchWhole As %Boolean [ Internal ];

/// When processing child documents individually, forward batch header/trailer segment shell documents in addition to the child message documents they contain.
Property %ForwardBatchHeaders As %Boolean [ InitialExpression = 1, Internal ];

/// For Batch messages, forward every message in the batch as part of a single session.
Property %SingleBatchSession As %Boolean [ Internal ];

/// Send individual ACK reply documents for messages in a batch, rather than constructing a batch wrapper for the replies.
Property NoBatchReply As %Boolean [ InitialExpression = 0 ];

/// Stop processing a batch document if an error occurs. Otherwise accumulate all errors and report them as a group.
Property QuitOnError As %Boolean [ InitialExpression = 0 ];

/// Comma-separated string specifying types of validation to perform. Make it a setting in your subclass if you override OnValidate() and need to provide options.
Property Validation As %String;

/// [Deprecated] The <property>SaveReplies</property> property/setting should be used instead.
/// If SearchTableClass is set, use it to index any replies (including OK ACKs unless IndexACKs=false).
Parameter IndexReplies As %Boolean = 0;

/// [Deprecated] The <property>SaveReplies</property> property/setting should be used instead.
/// Index OK ACKs if IndexReplies is also true and SearchTable class is given.
Parameter IndexACKs As %Boolean = 0;

/// Save a copy of reply messages sent back to the remote system. Also optionally index them using the configured SearchTableClass, if any. 
/// The options for this setting are as follows: <br/><ul>
/// <li>None: Don't save or index any reply messages. This is the default behavior, unless <parameter>IndexReplies</parameter> or 
/// <parameter>IndexACKs</parameter> has been overridden in this class. </li>
/// <li>NotOKs: Save replies that are not a simple OK ACK message, e.g. error NACKS and query responses. </li>
/// <li>All: Save a copy of all reply messages sent back to the remote system. </li>
/// <li>IndexNotOKs: Save replies that are not a simple OK ACK message and index them using the configured SearchTable. </li>
/// <li>IndexAll: Save a copy of all reply messages and index them using the configured SearchTable. </li></ul>
Property SaveReplies As %String(VALUELIST = ",None,NotOKs,All,IndexNotOKs,IndexAll") [ InitialExpression = {$select(..#IndexReplies: "Index"_$select(..#IndexACKs: "All", 1: "NotOKs"), 1: "None")} ];

Property %Parser As Grongier.HL7.Parser [ Internal ];

/// This holds Reply Documents as EnsLib.EDI.Document.
Property %ReplyDocuments [ InitialExpression = 0, Internal, MultiDimensional ];

/// Is the current message the first in a batch? (used for starting a new session on the first message in a batch)
Property %isNewBatch As %Boolean [ InitialExpression = 1, Internal ];

Method OnInit() As %Status
{
	Set ..%Parser=##class(Grongier.HL7.Parser).%New($this)
	If "!"=$E(..Framing,*) { Set ..%Parser.Framing=$E(..Framing,1,*-1), ..%Parser.RememberFlex=1}
	Else { Set ..%Parser.Framing=..Framing }
	Set ..%Parser.DefCharEncoding=..DefCharEncoding
	Set:""=..AckMode ..AckMode="Immed"
	Set:""=..NackErrorCode ..NackErrorCode="ContentR" ; for back-compatibility with earlier-configured services
	Set:""=..BatchHandling ..BatchHandling="1Session"

	Set ..%ForwardBatchWhole=$Case(..BatchHandling, "Whole":1, :0)
	Set ..%ForwardBatchHeaders=$Case(..BatchHandling, "Whole":0, "Indiv":0, :1)
	Set ..%SingleBatchSession=$Case(..BatchHandling, "1Session":1, :0)

	#; for back-compatibility, kill ESN if older version had initialized it to -1
	Kill:-1=$G($$$ExpectedSequenceNumber) $$$ExpectedSequenceNumber

	If ""=..TargetConfigNames { $$$LOGWARNING("No Target Config Name configured") }
	Quit $$$OK
}

/// Note: pDocIn is not declared as Grongier.HL7.Message so that subclasses can handle other types and transform them before calling ##super().
Method OnProcessInput(pDocIn As %RegisteredObject, Output pDocOut As %RegisteredObject) As %Status
{
	$$$ASSERT(0_"Subclass Responsibility")
}

/// Override this method to implement your own custom method for handling an incoming ACK Message.
/// Returning nonzero means you are handling it and the normal framework should ignore it.
Method OnInboundAck(pDoc As EnsLib.EDI.Document, pMSH As EnsLib.HL7.Segment, ByRef pSC As %Status) As %Boolean
{
	If ..IgnoreInboundAck {
		$$$LOGWARNING("Not processing inbound "_pDoc.Name_" message "_pDoc_"/"_pDoc.%Id())
		Set pDoc.IsMutable=0
		Quit 1
	}
	Quit 0
}

/// Override this method to implement your own custom method for validating an incoming Document.
/// Return non-zero to prevent default validation of the message (if any).
Method OnValidate(pDoc As EnsLib.EDI.Document, pValSpec As %String, Output pStatus As %Status) As %Boolean
{
	Quit 0
}

/// Override this method to implement your own custom method for resolving the DocType of an incoming message.
/// Returning nonzero means you are overriding the framework's standard DocType resolution.
Method OnResolveDocType(pDoc As EnsLib.EDI.Document, ByRef pDocType As %String) As %Boolean
{
	Quit 0
}

Method standardOnProcessInput(pDocIn As Grongier.HL7.Message, Output pDocOut As Grongier.HL7.Message) As %Status
{
	Set (tSC,tSCVal)=$$$OK, pDocOut=$$$NULLOREF
	$$$ASSERT($$$IsdefObject(pDocIn) && pDocIn.%IsA("EnsLib.HL7.Message"))
	$$$sysTRACE("Got Message "_pDocIn_" / "_pDocIn.%Id())
	Set tMSH=pDocIn.getSegmentByIndex(1,.tSC)
	If $$$ISOK(tSC) {
		If $Case(tMSH.Name,"FHS":1,"BHS":1,:0) { Set tMSH=$$$NULLOREF }
		ElseIf $Case(tMSH.GetValueAt("9.1"),"ACK":1,"ADR":1,:0) {
			Quit:..OnInboundAck(pDocIn,tMSH,.tSC) tSC
		}
		Set tSCVal=..resolveAndIndex(pDocIn,tMSH)
	}
	Set tReplyCode=..getReplyCode(tMSH,tSC,tSCVal,0), tResponse=$$$NULLOREF
	If $$$ISOK(tSC)&&$$$ISOK(tSCVal)&&(""'=..TargetConfigNames) {
		Set pDocIn.IsMutable=0
		If $Case(..AckMode,"Never":1,"Immed":1,"Byte":1,"Msh":'$IsObject(tMSH)||$Case(tMSH.GetValueAt(16),"AL":0,"SU":0,"ER":0,:1),:0) { ; ApplicationAcknowledgmentType="NEver"
			#; Send Async; no reply required
			$$$SyncCommitSet(tSyncCommit)
			For iTarget=1:1:$L(..TargetConfigNames, ",") { Set tOneTarget=$ZStrip($P(..TargetConfigNames,",",iTarget),"<>W")  Continue:""=tOneTarget
				$$$sysTRACE("Sending HL7 Message "_pDocIn_" / "_pDocIn.%Id()_" from "_pDocIn.Source_" to '"_tOneTarget_"'")
				Set tSC1=..SendRequestAsync(tOneTarget,pDocIn)  Set:$$$ISERR(tSC1) tSC=$$$ADDSC(tSC,tSC1)
			}
			$$$SyncCommitClear(tSyncCommit)
			If $$$ISOK(tSC) { $$$sysTRACE("After async forwarding HL7 Message "_pDocIn.%Id()_", reply code='"_tReplyCode_"'") }
			ElseIf ""'=tReplyCode { Set tReplyCode=..getReplyCode(tMSH,tSC,tSCVal,0) } ; get a new code since we have a new error

			If ..ImmediateByteAck {
				#; $$$ASSERT(..AckMode'="Byte") : would result in double Ack, but the 2 settings should never coincide
				Set tReplyCode1=$S(""'=tReplyCode:tReplyCode, 1:..getReplyCode(tMSH,tSC,tSCVal,-1)) ; force a code
				Do ..reportReply(pDocIn,tReplyCode1,.tSC,-1)
			}
		} Else {
			#; Send Synchronous; reply required - for Application ACK mode (either explicit or MSH-requested)
			If ""'=tReplyCode||..ImmediateByteAck {
				$$$sysTRACE("forcing early Commit ACK; waiting for Application reply")
				$$$SyncCommitSet(tSyncCommit)
				Set tSC=pDocIn.%Save() ; save the message because we're going to ACK it.
				$$$SyncCommitClear(tSyncCommit)
				If $$$ISERR(tSC) {
					$$$LOGERROR("Failed to save message "_pDocIn_" / "_pDocIn.%Id()_" : "_$$$StatusDisplayString(tSC))
					Set tReplyCode=..getReplyCode(tMSH,tSC,tSCVal,0) ; get a new code since we have a new error
				}
				Set:""=tReplyCode tReplyCode=..getReplyCode(tMSH,tSC,tSCVal,-1) ; force a code
				Do ..reportReply(pDocIn,tReplyCode,.tSC,1-(2*..ImmediateByteAck))
				Set tReplyCode=""
			}
			If $$$ISOK(tSC) {
				If 1'=$L(..TargetConfigNames, ",") $$$LOGWARNING("More than one target config name specified for synchronous forwarding: "_..TargetConfigNames)
				$$$sysTRACE("Sending "_pDocIn_"/"_pDocIn.%Id()_" from "_pDocIn.Source_" to '"_..TargetConfigNames_"'")
				Set tSC=..SendRequestSync(..TargetConfigNames,pDocIn,.tResponse)
			}
			If '$IsObject(tResponse) { ; no reply message - we must construct one
				Set tReplyCode=..getReplyCode(tMSH,tSC,tSCVal,1) ; get an App reply code to construct
				Set tTxt="Constructing ACK with code "_tReplyCode_" because SendRequestSync() of "_pDocIn_"/"_pDocIn.%Id()_" returned with no response object and status: "_$$$StatusDisplayString(tSC)
				If $$$ISERR(tSC) { $$$LOGWARNING(tTxt) } Else { $$$sysTRACE(tTxt) }
			} Else {
				If "Msh"=..AckMode&&$IsObject(tMSH)&&
					$Case(tMSH.GetValueAt(16), ; ApplicationAcknowledgmentType
						"SU":"A"'=$E(tResponse.GetValueAt("2:1"),2),
						"ER":"A"=$E(tResponse.GetValueAt("2:1"),2),
						:0) { ; Don't return Ack if MSH-mode MSH values restrict it
							Set tResponse=$$$NULLOREF
				}
				If '$IsObject(tResponse) { $$$sysTRACE("Not returning Application ACK for message "_pDocIn_"; AckMode="_..AckMode_"; tReplyCode='"_tReplyCode_"', MSH:AccAckTyp='"_$S($IsObject(tMSH):tMSH.GetValueAt(15),1:"null")_"'") }
				Else { $$$sysTRACE("Returning reply message "_tResponse.%Id()_" ("_tResponse.Name_") received from message "_pDocIn.%Id()_" forwarded to "_..TargetConfigNames) }
			}
		}
	} Else { ; not forwarding due to error or no target
		If ""=tReplyCode {
			Set tReplyCode=..getReplyCode(tMSH,tSC,tSCVal,1) ; see if we need an App reply code - if so we have to fake it because we didn't call the app
		}
		If (""'=tReplyCode||..ImmediateByteAck)&&$$$ISOK(tSC)&&$$$ISOK(tSCVal) {
			$$$SyncCommitSet(tSyncCommit)
			Set pDocIn.IsMutable=0, tSC=pDocIn.%Save() ; save the message because we're going to ACK it.
			$$$SyncCommitClear(tSyncCommit)
			If $$$ISERR(tSC) {
				$$$LOGERROR("Failed to save message "_pDocIn_" / "_pDocIn.%Id()_" : "_$$$StatusDisplayString(tSC))
				Set tReplyCode=..getReplyCode(tMSH,tSC,tSCVal,-1) ; get a new code since we have a new error
			}
		}
		If ..ImmediateByteAck {
			#; $$$ASSERT(..AckMode'="Byte") : would result in double Ack, but the 2 settings should never coincide
			Set tReplyCode1=$S(""'=tReplyCode:tReplyCode, 1:..getReplyCode(tMSH,tSC,tSCVal,-1)) ; force a code
			Do ..reportReply(pDocIn,tReplyCode1,.tSC,-1)
		}
		If ""=tReplyCode { $$$sysTRACE("Not returning ACK for message "_pDocIn_"/"_pDocIn.%Id()_"; AckMode="_..AckMode_"; tReplyCode='"_tReplyCode_"', MSH:AccAckTyp='"_$S($IsObject(tMSH):tMSH.GetValueAt(15),1:"null")_"'"_$S($$$ISERR(tSC):" status "_$$$StatusDisplayString(tSC),1:"")) }
		Else { $$$sysTRACE("Returning ACK code "_tReplyCode_" but not forwarding message "_pDocIn_"/"_pDocIn.%Id()_$S($$$ISERR(tSC):" status "_$$$StatusDisplayString(tSC),1:"")) }
	}
	If $IsObject(tResponse) {
		Set pDocOut=..reportReply(pDocIn,tResponse,.tSC)
		Set tReplyCode=tResponse.GetValueAt("2:1")
	} ElseIf ""'=tReplyCode {
		Set tSC=$$$ADDSC(tSC,tSCVal)
		Set pDocOut=..reportReply(pDocIn,tReplyCode,.tSC)
	}
	#; Increment SequenceNumber if not a rejection ACK and not a query for the SequenceNumber (ie. 0)
	If $Case($E(tReplyCode,2),"R":(..NackErrorCode'="ContentR"),"E":(..NackErrorCode'="ContentE"),:1)&&$G($$$ExpectedSequenceNumber)&&$IsObject(tMSH)&&tMSH.GetValueAt(13) {
		Set $$$ExpectedSequenceNumber = $$$ExpectedSequenceNumber+1
		$$$catTRACE("protocol","Incremented ESN to "_$$$ExpectedSequenceNumber)
	}
	Quit tSC
}

/// Accept only specified document names; resolve DocType and perform requested validation if any.
Method resolveAndIndex(pDoc As Grongier.HL7.Message, pMSH As EnsLib.HL7.Segment) As %Status
{
	Set tDocType=..resolveDocType(pDoc)
	Do pDoc.PokeDocType(tDocType)

	#; Do further validation if required
	Set tSC=$$$OK
	If ""=..Validation||'..OnValidate(pDoc,..Validation,.tSC)||("s"=$E(..Validation)&&$$$ISOK(tSC)) {
		#; do default validation - Validate sequence number if we have an ESN and if OnValidate() abdicated or ..Validation starts with "s"
		If ""'=$G($$$ExpectedSequenceNumber)&&$IsObject(pMSH) {
			Set tSeqNum=pMSH.GetValueAt(13)
			If (tSeqNum<-1) {
				Set tSC=$$$EnsError($$$EnsErrGeneral,"Invalid Sequence Number Format:"_tSeqNum)
			} ElseIf tSeqNum=-1 {
				$$$sysTRACE("Incoming Sequence Number requests reset ("_tSeqNum_"); Resetting Expected Sequence Number from "_$$$ExpectedSequenceNumber_" to 0 ")
				Set $$$ExpectedSequenceNumber=0
				Set tSC=$$$ERROR($$$EnsEDIHL7ErrAckSeqNum) ; special code to ACK OK but not forward the message
			} ElseIf 0=tSeqNum {
				$$$sysTRACE("Incoming Sequence Number Query (0): our Expected Sequence Number = "_$$$ExpectedSequenceNumber)
				Set tSC=$$$ERROR($$$EnsEDIHL7ErrAckSeqNum) ; special code to ACK OK but not forward the message
				#; the query will be satisfied when we build the ACK
			} Else {
				$$$catTRACE("protocol","Incoming Sequence Number: "_tSeqNum)
				If 0=$$$ExpectedSequenceNumber&&(""'=tSeqNum) {
					#; We have a reset ESN and they sent one
					$$$LOGINFO("Setting ESN from 0 to received value "_tSeqNum)
					Set $$$ExpectedSequenceNumber=tSeqNum
				} ElseIf tSeqNum'=$$$ExpectedSequenceNumber {
					#; Require that client's and our Sequence Number match
					Set tSC=$$$EnsError($$$EnsErrGeneral,"Incoming Sequence Number "_tSeqNum_" doesn't match ESN "_$$$ExpectedSequenceNumber)
				}			
				#; else - successful match of sequence number - we will increment our Expected Sequence Number if we ACK OK
			}
			$$$catTRACE("protocol","resolveAndIndex OK with Expected Sequence Number "_$$$ExpectedSequenceNumber)
		}
	}
	Quit:$$$ISERR(tSC) tSC

	If ""'=..SearchTableClass {
		TRY {		
			Set tSCStore=$zobjclassmethod(..SearchTableClass,"IndexDoc",pDoc)
			If $$$ISERR(tSCStore) $$$LOGWARNING("Failed to construct SearchTable entries for message "_pDoc_"/"_pDoc.%Id()_" with DocType='"_pDoc.DocType_"' using class '"_..SearchTableClass_"' "_$$$StatusDisplayString(tSCStore))
		} CATCH errobj { $$$LOGWARNING("Failed to invoke SearchTable method "_..SearchTableClass_".IndexDoc() for message "_pDoc_"/"_pDoc.%Id()_" with DocType='"_pDoc.DocType_"' : "_errobj.AsSystemError()) }
	}
	Quit tSC
}

/// Return the DocType that this service will assign to this document.
Method resolveDocType(pDoc As Grongier.HL7.Message, pMSH As EnsLib.HL7.Segment = {$$$NULLOREF}) As %String
{
	Set tDocType=pDoc.DocType, tDefCat=""
	If ""=tDocType {
		If $IsObject(pMSH) {
			Set tMSHType=pMSH.GetValueAt(9,":_~\&")  Set:""=tMSHType tMSHType=pDoc.Name
		} Else { Set tMSHType=pDoc.Name }
		#; Match with the DocType specified if any in MessageSchemaCategory for the received Message's type name
		Set tAcceptTypes=..MessageSchemaCategory, tNameFound=tMSHType, tUNameFound=$ZCVT(tNameFound,"U")
		Set nTypes=$S(""=$ZStrip(tAcceptTypes,"<>W"):0, 1:$L(tAcceptTypes,","))
		Set (tVal,tDef)=""
		For i=1:1:nTypes { Set tType=$P(tAcceptTypes,",",i) Continue:""=tType
			Set tVal=$ZStrip($P(tType,"=",2),"<>W")
			Set tName=$ZStrip($P(tType,"=",1),"<>W"), tNameLen=$L(tName), tUName=$ZCVT(tName,"U")
			If ""=tVal {
				Set:""=tDef tDef=tName
			} Else {
				#; Quit on match; accept trailing wildcard also
				If tUNameFound=tUName
				 || ("*"=$E(tName,tNameLen) && ($E(tUName,1,tNameLen-1)=$E(tUNameFound,1,tNameLen-1))) {
					If tVal[":" { Set tDocType=tVal }
					Else { Set tDocType=##class(EnsLib.HL7.Schema).ResolveSchemaTypeToDocType(tVal,tNameFound,,..DocTypeResolution) }
					Quit
				}
				Set tVal=""
			}
		}
		If ""'=tDocType {
			If tVal[":" {
				$$$sysTRACE("Using DocType='"_tDocType_"' for type name '"_tNameFound_"' matching '"_tUName_"' in MessageSchemaCategory list; calling OnResolveDocType()")
			} Else {
				$$$sysTRACE("Using DocType='"_tDocType_"' from schema category '"_tVal_"' for type name '"_tNameFound_"' matching '"_tUName_"' in MessageSchemaCategory list; calling OnResolveDocType()")
				Set tDefCat=tVal
			}
		} ElseIf ""'=tVal {
			$$$sysTRACE("No DocType returned from ResolveSchemaTypeToDocType() using schema category "_tVal_" found for type name '"_tNameFound_"' matching '"_tUName_"' in MessageSchemaCategory list; calling OnResolveDocType()")
		} ElseIf ""'=tDef {
			If tDef[":" {
				Set tDocType=tDef
				$$$sysTRACE("Using default DocType='"_tDocType_"' from MessageSchemaCategory list; type name '"_tNameFound_"' not matched specifically; calling OnResolveDocType()")
			} Else {
				Set tDocType=##class(EnsLib.HL7.Schema).ResolveSchemaTypeToDocType(tDef,tNameFound,,..DocTypeResolution)
				If ""'=tDocType {
					$$$sysTRACE("Using DocType='"_tDocType_"' returned from ResolveSchemaTypeToDocType() using default schema category in MessageSchemaCategory list '"_tAcceptTypes_"'; type name '"_tNameFound_"' not matched specifically; calling OnResolveDocType()")
					Set tDefCat=tDef
				} Else {
					$$$sysTRACE("No DocType returned from ResolveSchemaTypeToDocType() using default schema category '"_tDef_"' in MessageSchemaCategory list '"_tAcceptTypes_"'; type name '"_tNameFound_"' not matched specifically; calling OnResolveDocType()")
				}
			}
		} Else {
			$$$sysTRACE("No match or default DocType found for type name '"_tNameFound_"' in MessageSchemaCategory list '"_tAcceptTypes_"'; calling OnResolveDocType()")
		}
	} Else {
		$$$sysTRACE("Accepted message with DocType='"_tDocType_"'; calling OnResolveDocType()")
	}
	Set ttDocType=tDocType  If ..OnResolveDocType(pDoc,.ttDocType) {
		Set ttDocType=$Get(ttDocType)
		Set tDocType=ttDocType
		$$$sysTRACE("OnResolveDocType returned DocType="_tDocType)
	}
	Do:tDocType=ttDocType&&(""'=tDocType)&&(""'=tDefCat) pDoc.PokeTypeCategory(tDefCat)
	Quit tDocType
}

/// pAppAck=0 means 'Immediate' reply; =-1 means 'Immediate Commit Ack'; =1 means 'Application' reply.
/// Return empty string if no ACK needed for the specified mode, or the code for the appropriate type of reply.
Method getReplyCode(pMSH As EnsLib.HL7.Segment, pSC As %Status, pSCVal As %Status, pAppACK As %Boolean) As %String
{
	If pAppACK>-1&&$IsObject(pMSH) { Set tAckType=pMSH.GetValueAt($S(pAppACK:16,1:15)), tVersionID=pMSH.GetValueAt("12.1") }
	Else { Set (tAckType,tVersionID)="" }
	#; Choose the appropriate Status character
	Set tCode=$S($$$ISERR(pSCVal)&&'$$$StatusEquals(pSCVal,$$$EnsEDIHL7ErrAckSeqNum):$Case(..NackErrorCode,"ContentR":"R","AllR":"R",:"E"), $$$ISERR(pSC):$Case(..NackErrorCode,"ErrorR":"R","AllR":"R",:"E"), 1:"A") ; Reject / Error / Accept
	#; $$$ASSERT('(pAppACK=-1&&'..ImmediateByteAck)) Quit "" ; not needed because we'll never be called with this value
	#; Send no ACK if the MSH requests not to
	Quit:pAppACK>-1&&$Case(..AckMode,"Never":1,"Immed":pAppACK,"App":'pAppACK,"Msh":$Case(tAckType,"AL":0,"ER":(tCode="A"),"SU":(tCode'="A"),:1),:0) ""
	Quit $S(..UseAckCommitCodes&&(+tVersionID>=2.3):"C",1:"A")_tCode ; Commit / Application
}

/// pEarlyAck'=0 means early (commit/immediate) ACK; <0 means Byte ACK.
Method reportReply(pOriginalDoc As EnsLib.EDI.Document, pReplyCode As %String, ByRef pSC As %Status, pEarlyAck As %Integer = 0) As EnsLib.EDI.Document
{
	Set tSC=pSC
	If $IsObject(pReplyCode) {
		Set pSC=$$$OK, tReplyDoc=$S(..AckMode'="Byte":pReplyCode, 1:$S("A"=$E(pReplyCode.GetValueAt("2:1"),2):$C($$$SingleByteAckAcceptAscii),1:$C($$$SingleByteAckErrorAscii)))
		$$$sysTRACE("Reporting reply document "_tReplyDoc_" for document "_pOriginalDoc_$S('$IsObject(pOriginalDoc):"",1:" / "_pOriginalDoc.%Id()))
	} Else {
		Set tReplyDoc=..constructReply(pOriginalDoc,pReplyCode,.pSC,pEarlyAck)  If $$$ISERR(pSC) $$$LOGSTATUS(pSC)  Quit $$$NULLOREF
		$$$sysTRACE("Constructed reply document "_tReplyDoc_" for document "_pOriginalDoc_$S('$IsObject(pOriginalDoc):"",1:" / "_pOriginalDoc.%Id())_"; status: "_$$$StatusDisplayString(tSC))
	}
	Quit:""=tReplyDoc $$$NULLOREF
	If $IsObject(tReplyDoc) && (..SaveReplies '= "None") {
		Set tIsOKACK = $select("ACK"'=$piece(tReplyDoc.GetValueAt("1:9.1"),"_"): 0, 1: $case(..getACKCode(tReplyDoc), "AA":1, "CA":1, :0))
		Set tDoAll = ("All" = $extract(..SaveReplies,*-2,*))
		#; Save the reply if we are saving/indexing all replies, OR this is not an OK ACK
		If tDoAll || ('tIsOKACK){
			#; Index the reply if we are indexing the reply type
			If (""'=..SearchTableClass) && ("Index" = $extract(..SaveReplies,1,5)) {
				Set tSCStore=$classmethod(..SearchTableClass,"IndexDoc",tReplyDoc)
				If $$$ISERR(tSCStore) $$$LOGWARNING("Failed to construct SearchTable entries for reply message "_tReplyDoc_" / "_tReplyDoc.%Id()_" with DocType='"_tReplyDoc.DocType_"' using class '"_..SearchTableClass_"' "_$$$StatusDisplayString(tSCStore))
			}
			Else {
				Set tSCSave = tReplyDoc.%Save()
				If $$$ISERR(tSCSave) $$$LOGWARNING("Failed to save reply message "_tReplyDoc_" / "_tReplyDoc.%Id()_" with DocType='"_tReplyDoc.DocType_"': "_$$$StatusDisplayString(tSCSave))
			}
		}
	}
	If ""'=pOriginalDoc.ParentId && '..NoBatchReply {
		#; Remember individual reply docs for final batch reply
		Set ..%ReplyDocuments=$G(..%ReplyDocuments)+1, ..%ReplyDocuments(..%ReplyDocuments)=tReplyDoc
	} ElseIf ..NoBatchReply && $IsObject(tReplyDoc) && tReplyDoc.ChildCount {
		Set pSC=tReplyDoc.GetChildIdsArray(.tChildArray,tReplyDoc.%Id(),1)  If $$$ISERR(pSC) $$$LOGSTATUS(pSC)  Quit $$$NULLOREF
		For i=1:1:tChildArray { Set tChildId=tChildArray(i)
			Set tReply=tReplyDoc.%OpenId(tChildId)
			Set pSC=..SendReply(tReply,pOriginalDoc) Quit:$$$ISERR(pSC)
		}
	} ElseIf pEarlyAck {
		Set pSC=..SendEarlyReply(tReplyDoc,pOriginalDoc)
	} Else {
		Set pSC=..SendReply(tReplyDoc,pOriginalDoc)
	}
	If $$$ISERR(pSC) $$$LOGSTATUS(pSC)
	Quit $$$NULLOREF ; default behavior is not to return the reply doc from OnProcessInput()
}

Method constructReply(pOriginalDoc As EnsLib.EDI.Document, pReplyCode As %String, ByRef pSC As %Status, pEarlyAck As %Integer) As EnsLib.EDI.Document
{
	Set tSC=pSC, pSC=..OnConstructReply(.tReplyDoc, pOriginalDoc,.pReplyCode,.tSC,pEarlyAck)  If $$$ISERR(pSC) $$$LOGSTATUS(pSC) Quit $$$NULLOREF
	If '$D(tReplyDoc) {
		If $Case(pOriginalDoc.Name,"FHS":1,"BHS":1,:0) {
			If "" '= pOriginalDoc.ParentId { ; top doc
				Set tReplyDoc=$$$NULLOREF
			} Else {
				If ..%ForwardBatchWhole=1 { ; no need to check for %ForwardBatchWhole>1 because this is runtime
					#; Make ACKs for all children
					If '$Case(..AckMode,"Byte":1 ,:pEarlyAck<0) {
						Set pSC=pOriginalDoc.GetChildIdsArray(.tChildArray,pOriginalDoc.%Id(),1)
						Set i="" For { Set i=$O(tChildArray(i),1,tChildId)  Quit:""=i
							Set tChild=pOriginalDoc.%OpenId(tChildId)
							Set tRepliesArray=i, tRepliesArray(i)=..constructReply(tChild,$S(..UseAckCommitCodes&&(+tChild.GetValueAt("1:12.1")>=2.3):"C",1:"A")_"A",.pSC,pEarlyAck)  If $$$ISERR(pSC) $$$LOGSTATUS(pSC) Quit
						}
					}
				} Else {
					Merge tRepliesArray=..%ReplyDocuments  Kill ..%ReplyDocuments  Set ..%ReplyDocuments=0
				}
				Set:$$$ISOK(pSC) tReplyDoc=..constructBatchReply(pOriginalDoc,.tRepliesArray,.pSC,pEarlyAck)
			}
		} Else {
			Set tIsErr=("A"'=$E(pReplyCode,2))
			If $Case(..AckMode,"Byte":1, :pEarlyAck<0) {
				Set tReplyDoc=$S(tIsErr:$C($$$SingleByteAckErrorAscii),1:$C($$$SingleByteAckAcceptAscii))
			} Else {
				Set tReplyDoc=pOriginalDoc.NewReplyDocument(,..LocalFacilityApplication)
				Set tReplyDoc.Source=pOriginalDoc.%Id()
				Do:..#UseOriginalControlId tReplyDoc.SetValueAt(pOriginalDoc.GetValueAt("1:10"),"1:10") ; copy the control id to the ack control id
				Set tAckMSA=##class(EnsLib.HL7.Segment).%New($LB("",1))
				Set tAckMSA.Separators=tReplyDoc.Separators
				Do tAckMSA.SetValueAt("MSA",0)
				Do tAckMSA.SetValueAt(pReplyCode,1)
				Do tAckMSA.SetValueAt(pOriginalDoc.GetValueAt("1:10"),2)
				Do:$G($$$ExpectedSequenceNumber) tAckMSA.SetValueAt($$$ExpectedSequenceNumber,4)
				#; Deprecated since v2.1 - Do tAckMSA.SetValueAt($S(pForwardMsg:"D",1:"F"),5//"DelayedAcknowledgmentType")
				Do tReplyDoc.AppendSegment(tAckMSA)
				If ..AddNackERR&&tIsErr {
					// Now build an ERR segment in case of error
					Set tAckERR=##class(EnsLib.HL7.Segment).%New($LB("",1))
					Set tAckERR.Separators=tReplyDoc.Separators
					Do tAckERR.SetValueAt("ERR",0)
					#;Do tAckERR.SetValueAt("207"_tAckERR.CS_"Application internal error",3) 
					Do tAckERR.SetValueAt("E",4)  // It's an error
					Do tAckERR.SetValueAt($P($system.Status.GetErrorCodes(tSC),","),5)
					Do tAckERR.SetValueAt(tAckERR.Escape($$$StatusDisplayString(tSC)),8)
					Do tReplyDoc.AppendSegment(tAckERR)
				}
				Set tReplyDoc.IsMutable=0
			}
		}
	}
	Set:$IsObject(tReplyDoc) tReplyDoc.OriginalDocId=pOriginalDoc.%Id()
	$$$sysTRACE("Constructed reply document '"_tReplyDoc_"' for original document "_pOriginalDoc_" / "_pOriginalDoc.%Id()_" reflecting status: "_$$$StatusDisplayString(tSC))
	Quit $G(tReplyDoc,$$$NULLOREF)
}

/// Override this method to construct a customized reply document. Inputs are the original document and
/// the reply code and the status code that the framework produced in processing the original document.
/// If you change the status code but do not construct a reply document, the framework will use the new value to construct a standard reply document. <br/>
/// If you construct a non-HL7 object it must still have a property called 'Envelope'.  Piece:2 of this value will be written verbatim.
Method OnConstructReply(Output pReplyDoc As EnsLib.EDI.Document, pOriginalDoc As EnsLib.EDI.Document, ByRef pReplyCode As %String, ByRef pSC As %Status, pEarlyAck As %Boolean) As %Status
{
	Quit $$$OK
}

Method constructBatchReply(pOriginalDoc As EnsLib.EDI.Document, ByRef pChildArray, ByRef pSC As %Status, pEarlyAck As %Boolean) As EnsLib.EDI.Document
{
	Set tSC=pSC, pSC=..OnConstructBatchReply(.tReplyDoc,pOriginalDoc,.pChildArray,.tSC,pEarlyAck) If $$$ISERR(pSC) $$$LOGSTATUS(pSC) Quit $$$NULLOREF
	If '$D(tReplyDoc) {
		Quit:0=$G(pChildArray,0) $$$NULLOREF
		If (+pChildArray'=pChildArray) Set pSC=$$$ERROR($$$EnsErrGeneral,"Child Reply Document Array has unexpected top node: '"_pChildArray_"'")  Quit $$$NULLOREF
		If $Case(..AckMode,"Byte":1,:0) {
			Set tNext=1, tIsErr=$$$ISERR(tSC)
		} Else {
			Set tReply1=$G(pChildArray(1))
			Set:'$IsObject(tReply1) tReply1=##class(Grongier.HL7.Message).%OpenId(tReply1)
			Quit:'$IsObject(tReply1) $$$NULLOREF
			Set tNext=2
			#; construct Batch parent document
			Set tReplyDoc=##class(Grongier.HL7.Message).%New($LB("",tReply1.Separators,tReply1.Source))
			Set tFS=$E(tReply1.Separators), tCS=$E(tReply1.Separators,3)
			Set tCategory = tReply1.DocTypeCategory
			Set tMsgCat = tReply1.MessageTypeCategory
			Set tBHSType= $S(tCategory="":"",1:tCategory_":BHS")
			Set tBHS=##class(EnsLib.HL7.Segment).%New($LB("",1,tBHSType,tReply1.Separators_"BHS"_tFS))
			Do tReplyDoc.setSegmentByIndex(tBHS,1,0)
			Set tHolder=##class(EnsLib.HL7.Segment).%New($LB("",1,"",tReply1.Separators_"MessageDocsRef"_tFS_2_tFS_$G(pChildArray)))
			Do tReplyDoc.setSegmentByIndex(tHolder,2,0)
			Set tBTSType=$S(tCategory="":"",1:tCategory_":BTS")
			Set tBTS=##class(EnsLib.HL7.Segment).%New($LB("",1,tBTSType,tReply1.Separators_"BTS"_tFS_$G(pChildArray)))
			Do tReplyDoc.setSegmentByIndex(tBTS,3,0)
			If ((""'=tMsgCat)||(""'=tCategory)) {
				Do:""'=tMsgCat tReplyDoc.PokeTypeCategory(tMsgCat)
				Set tReplyBHSType = ##class(EnsLib.HL7.Schema).ResolveSchemaTypeToDocType($S(""'=tMsgCat:tMsgCat,""'=tCategory:tCategory,1:""),"BHS")
				Do:""'=tReplyBHSType tReplyDoc.PokeDocType(tReplyBHSType)
			}
			Set tReply1.ParentId=tReplyDoc.getId()_":2"
			Do tReply1.%Save()
		}
		For i=tNext:1:pChildArray { Set tReply=pChildArray(i)
			Set:'$IsObject(tReply) tReply=##class(Grongier.HL7.Message).%OpenId(tReply)  $$$ASSERT($IsObject(tReply))
			If $Case(..AckMode,"Byte":1,:0) {
				Set:'tIsErr tIsErr=("A"'=tReply.GetValueAt("2:1"))
			} Else {
				Set tReply.ParentId=tReplyDoc.getId()_":2"
				Do tReply.%Save()
			}
		}
		If $Case(..AckMode,"Byte":1,:0) {
			Set tReplyDoc=$S('tIsErr:$C($$$SingleByteAckAcceptAscii),1:$C($$$SingleByteAckErrorAscii))
		} Else {
			If pOriginalDoc.Name'="FHS" {
				Do tReplyDoc.%Save()
			} Else {
				#; construct File Batch parent document
				Set tReply=tReplyDoc, tReplyDoc=##class(Grongier.HL7.Message).%New($LB("",tReply1.Separators,tReply1.Source))
				Set tFHSType=$S(tCategory="":"",1:tCategory_":FHS")
				Set tFHS=##class(EnsLib.HL7.Segment).%New($LB("",1,tFHSType,tReply1.Separators_"FHS"_tFS))
				Do tReplyDoc.setSegmentByIndex(tFHS,1,0)
				Set tHolder=##class(EnsLib.HL7.Segment).%New($LB("",1,"",tReply1.Separators_"BHSDocsRef"_tFS_2_tFS_1))
				Do tReplyDoc.setSegmentByIndex(tHolder,2,0)
				Set tFTSType=$S(tCategory="":"",1:tCategory_":FTS")
				Set tFTS=##class(EnsLib.HL7.Segment).%New($LB("",1,tFTSType,tReply1.Separators_"FTS"_tFS_1))
				Do tReplyDoc.setSegmentByIndex(tFTS,3,0)
				If ((""'=tMsgCat)||(""'=tCategory)) {
					Do:""'=tMsgCat tReplyDoc.PokeTypeCategory(tMsgCat)
					Set tReplyFHSType = ##class(EnsLib.HL7.Schema).ResolveSchemaTypeToDocType($S(""'=tMsgCat:tMsgCat,""'=tCategory:tCategory,1:""),"FHS")
					Do:""'=tReplyFHSType tReplyDoc.PokeDocType(tReplyFHSType)
				}
				Do tReplyDoc.%Save()
				Set tReply.ParentId=tReplyDoc.%Id()_":2"
				Do tReply.%Save()
			}
		}
	}
	$$$sysTRACE("Constructed batch reply document '"_tReplyDoc_" / "_tReplyDoc.%Id()_"' for original document "_pOriginalDoc_" / "_pOriginalDoc.%Id()_"; status: "_$$$StatusDisplayString(pSC))
	Quit tReplyDoc
}

/// Override this method to construct a customized batch reply document. Inputs are the original document and
/// the child reply array and the status code that the framework produced in processing the original document. <br/>
/// If you construct a non-HL7 object it must still have a property called 'Envelope'.  Piece:2 of this value will be written verbatim.
Method OnConstructBatchReply(Output pReplyDoc As EnsLib.EDI.Document, pOriginalDoc As EnsLib.EDI.Document, ByRef pChildArray, ByRef pSC As %Status, pEarlyAck As %Boolean) As %Status
{
	Quit $$$OK
}

Method SendReply(pReplyDocument As EnsLib.EDI.Document, pOriginalDoc As EnsLib.EDI.Document) As %Status
{
	Quit $$$EnsError($$$EnsErrGeneral, "Service does not support Reply; Document "_pReplyDocument)
}

Method SendEarlyReply(pReplyDocument As EnsLib.EDI.Document, pOriginalDoc As EnsLib.EDI.Document) As %Status
{
	Quit ..SendReply(.pReplyDocument,.pOriginalDoc)
}

/// Callbacks from Parser:
/// 
/// Called by the Parser at the end of a document
Method OnDocumentEnd(pDocument As EnsLib.EDI.Document, pSource As %String, pStatus As %Status) As %Status
{
	Set tSC=$$$OK
	#;$$$ASSERT(pDocument=..%Parser.%CurrentDocument)
	#; Ignore bad status; let OnProcessInput() do what it can

	// Ignore errors; we use the default Reply Document object
	If ""=pDocument.ParentId { ; top parent
		If ..%ForwardBatchWhole=1 {
			If '..%PreserveSession {
				#; We do not want to clean %SuperSession if set before %SessionId
				If '..%SuperSessionCreatedBeforeSession  Set ..%SuperSession = ""
				Set ..%SessionId=""  Kill $$$JobSessionId
			}
			Set tSC=..standardOnProcessInput(pDocument,.tDocOut)
		} ElseIf '..%ForwardBatchWhole {
			Set tIsHdr=$Case(pDocument.Name, "FHS":1, "BHS":1, :0)
			If 'tIsHdr || ..%ForwardBatchHeaders {
				If tIsHdr {
					If '..%PreserveSession && ('..%SingleBatchSession || ..%isNewBatch) {
						#; We do not want to clean %SuperSession if set before %SessionId
						If '..%SuperSessionCreatedBeforeSession  Set ..%SuperSession = ""
						Set ..%SessionId=""  Kill $$$JobSessionId 
					}
				} Else {
					If '..%PreserveSession {
						#; We do not want to clean %SuperSession if set before %SessionId
						If '..%SuperSessionCreatedBeforeSession  Set ..%SuperSession = ""
						Set ..%SessionId=""  Kill $$$JobSessionId 
					}
				}
				Set tSC=..standardOnProcessInput(pDocument,.tDocOut)
			}
			Else { 
				Do ..reportReply(pDocument,"AA",.tSC) ; top batch doc - reply but don't process
				Set tDocType = ..resolveDocType(pDocument) ; still set docType
				Do pDocument.PokeDocType(tDocType)
				Set tSC = pDocument.%Save()
				#; Log warning if no children as expected
				Try {
					If tIsHdr && 'pDocument.ChildCount {
						#; Only expect either ascii 13 and or ascii 10 but translate other control characters
						#dim tDisplayTerminator = $TR(..GetSegmentTerminator(),$C(1,2,9,11,28),"12tse")
						Set tDisplayTerminator = $Replace(tDisplayTerminator,$C(10),"Line Feed,")
						Set tDisplayTerminator = $Replace(tDisplayTerminator,$C(13),"Carriage Return,")
						If $Extract(tDisplayTerminator,*)="," Set $Extract(tDisplayTerminator,*)=""
						$$$LOGWARNING("No child documents found in batch document using Segment terminator of "_tDisplayTerminator_" from source: "_pDocument.Source)
					}
				} Catch {}
			}
		} ; Else (If ..%ForwardBatchWhole>1) do nothing; this value means don't let Service process the document; we're in ImportFrom...()
		Set ..%isNewBatch=1
	} ElseIf '..%ForwardBatchWhole && ($Case(pDocument.Name, "FHS":0, "BHS":0, :1) || ..%ForwardBatchHeaders) { ; Not top parent
		If '..%SingleBatchSession || ('..%PreserveSession && ..%isNewBatch) {
			#; We do not want to clean %SuperSession if set before %SessionId
			If '..%SuperSessionCreatedBeforeSession  Set ..%SuperSession = ""
			Set ..%SessionId=""  Kill $$$JobSessionId
		}
		Set tSC=..standardOnProcessInput(pDocument,.tDocOut)
		Set ..%isNewBatch=0
	} ElseIf (""'=pDocument.ParentId && ..%ForwardBatchWhole) || ($Case(pDocument.Name, "FHS":1, "BHS":1, :0) && '..%ForwardBatchHeaders) { ; Still set docType for child documents and unsent headers
		Set tDocType=..resolveDocType(pDocument)
		Do pDocument.PokeDocType(tDocType)
		Set tSC = pDocument.%Save()
	}
	If $$$ISERR(tSC) && $$$StatusEquals(tSC,$$$EnsErrGeneral) Set pStatus=$$$ADDSC(pStatus,tSC) // !!! quit on fatal errors only
	Quit:'..QuitOnError&&$$$ISOK(tSC) $$$OK
	Quit pStatus
}

/// Return the segment terminator string that the Parser and the document.ImportFromIOStream() method will use.
Method GetSegmentTerminator() As %String
{
	Quit $C($$$HL7DefSegTerminatorAscii)
}

ClassMethod GetRequestClassList() As %String [ CodeMode = objectgenerator, GenerateAfter = OnProcessInput ]
{
	Set tSignature=$$$comMemberKeyGet(%class.Name,$$$cCLASSmethod,"standardOnProcessInput",$$$cMETHformalspecparsed)
	Set tClass=$lg($lg(tSignature,1),2)
	Set tSignature=$$$comMemberKeyGet(%class.Name,$$$cCLASSmethod,"OnProcessInput",$$$cMETHformalspecparsed)
	Set tClass=tClass_""","""_$lg($lg(tSignature,1),2)
	Do %code.WriteLine(" Quit $lb("""_tClass_""")")
	Quit $$$OK
}

ClassMethod GetResponseClassList(pRequest As %String = "") As %String [ CodeMode = objectgenerator, GenerateAfter = OnProcessInput ]
{
	Set tSignature=$$$comMemberKeyGet(%class.Name,$$$cCLASSmethod,"standardOnProcessInput",$$$cMETHformalspecparsed)
	Set tRequest1=$lg($lg(tSignature,1),2)
	Set tClass1=$lg($lg(tSignature,2),2)
	Set tSignature=$$$comMemberKeyGet(%class.Name,$$$cCLASSmethod,"OnProcessInput",$$$cMETHformalspecparsed)
	Set tRequest2=$lg($lg(tSignature,1),2)
	Set tClass2=$lg($lg(tSignature,2),2)

	Set tClass12=tClass1_$S(tClass1=tClass2:"",1:""","""_tClass2)
	If tRequest1=tRequest2 {
		Set (tClass1,tClass2)=tClass12
	}
	Do %code.WriteLine(" Quit:pRequest="""" $lb("""_tClass12_""")")
	Do %code.WriteLine(" Quit:pRequest="""_tRequest1_""" $lb("""_tClass1_""")")
	Do %code.WriteLine(" Quit:pRequest="""_tRequest2_""" $lb("""_tClass2_""")")
	Do %code.WriteLine(" Quit $lb("""")")
	Quit $$$OK
}

/// Return an array of connections for drawing lines on the config diagram.
ClassMethod OnGetConnections(Output pArray As %String, pItem As Ens.Config.Item)
{
	Do ##super(.pArray,pItem)
	If pItem.GetModifiedSetting("TargetConfigNames",.tValue) {
		For i=1:1:$L(tValue,",") { Set tOne=$ZStrip($P(tValue,",",i),"<>W")  Continue:""=tOne  Set pArray(tOne)="" }
	}
}

/// Add discarded characters to IO Archive.
Method IOLogDiscard(pSC As %Status, pNote As %String, pDiscard As %GlobalCharacterStream)
{
	Set tIOLogEntry = ..IOLogEntry, ..IOLogEntry=$$$NULLOREF ; Save a separate entry for the unexpected input
	$$$NEWINIOLOGENTRY(pSC,pNote,pDiscard)
	$$$CLOSEIOLOGENTRY($$$OK,"",$$$NULLOREF)
	Set ..IOLogEntry = tIOLogEntry
}

/// Helper method to get the ACK code from a response.
Method getACKCode(pReply As Grongier.HL7.Message = "") As %String [ Private ]
{
	#; Get MSA code if not already cached
	If '$IsObject(pReply) Quit "_"
	Set tReply = pReply
	While $Case(tReply.Name,"FHS":1,"BHS":1,:0) {
		Set tReply=tReply.NextChild()
		If '$IsObject(tReply) Set tReply=pReply Quit
	}
	Set tMSA=tReply.GetSegmentAt(2)
	Set tAckCode=$S($IsObject(tMSA)&&("MSA"=tMSA.GetValueAt(0)):$ZStrip(tMSA.GetValueAt(1),"<>W"), 1:"~NoMSA")
	If ""=tAckCode Set tAckCode="_"
	Quit $ZCVT(tAckCode,"U")
}

/// Method to convert comma delimited numbers to characters.
/// Used by FTPService and available for other services.
Method AsciiOrHexAsChars(pAsciiOrHex As %String = "") As %String [ Internal ]
{
	#dim tChars = ""
	#dim c, tChar
	Try {
		For c = 1:1:$L(pAsciiOrHex,",") {
			Set tChar = $P(pAsciiOrHex,",",c)
			Set:(tChar'="") tChars = tChars_$C($S($ZCVT($E(tChar),"L")="x":$S($L(tChar)>1:$ZH($E(tChar,2,*)_""),1:""),1:tChar))
		}
	} Catch {
	}
	Quit tChars
}

}
