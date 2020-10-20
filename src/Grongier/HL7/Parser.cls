/* Copyright (c) 2020 by InterSystems Corporation.
   Cambridge, Massachusetts, U.S.A.  All rights reserved.
   Confidential property of InterSystems Corporation. */

Include EnsHL7

/// This is the HL7 v2.x file format parser
Class Grongier.HL7.Parser Extends %RegisteredObject [ ClassType = "", ProcedureBlock, System = 4 ]
{

/// Don't consider a blank line to indicate the end of a document
Property IgnoreBlankLines As %Boolean;

/// Number of seconds to wait for the start of a document to be available on the input stream
Property StartTimeout As %Numeric(MINVAL = -1) [ InitialExpression = 5 ];

/// Number of seconds to wait for each read of document data inside a started document to be available on the input stream
Property ReadTimeout As %Numeric(MINVAL = -1) [ InitialExpression = 5 ];

/// See your HL7 Config Items for a description of accepted values.
Property Framing As %String;

/// Default Character Encoding to use when reading or writing HL7 messages. <p/>
/// If MSH field 18 (Character Set) is empty, this encoding will be used. Choices you can use for this setting include:<p/>
/// <ul>
/// <li>Native - use the default character encoding of the installed locale of the IRIS server</li>
/// <li>latin1 - the ISO Latin1 8-bit encoding; this is the default</li>
/// <li>ISO-8859-1 - the ISO Latin1 8-bit encoding</li>
/// <li>UTF-8 - the Unicode 8-bit encoding</li>
/// <li>Unicode - the Unicode 16-bit encoding  (Little-Endian)</li>
/// <li>UnicodeBig - the Unicode 16-bit encoding (Big-Endian)</li>
/// <li>Any other NLS definitions installed on this IRIS server</li>
/// <li>@&lt;ttable&gt; - &lt;ttable&gt; means a raw InterSystems character translation table name. A prefix of '@' means to use the named table.</li>
/// </ul>
/// Putting ! before the encoding name will force the use of the named encoding and will ignore any value found in MSH:18. <p/>
Property DefCharEncoding As %String;

/// Set this if you want to make an interface that is set to Framing='Flexible' continue with the Framing style it detects in the first message it receives.
/// This can increase performance, reduce latency due to timeouts and ensure consistent behavior after initialization.
/// However, it will also reduce the ability of the interface to interpret changing input formats in successive messages from the same source or from different sources on sequential connections.
Property RememberFlex As %Boolean [ InitialExpression = 0 ];

Property Done As %Boolean [ Calculated, ReadOnly ];

Property %Stream As %IO.I.CharacterStream;

/* Implementation Notes:
    The properties ..%inFraming and ..%outFraming represent a parse of the ..Framing Setting value, and if it is 'Flexible' they represent the
     memory of the detected framing style.
    The local variables tInFraming or tOutFraming, tPrefix and tSuffix represent a decomposition of ..%inFraming or ..%outFraming.
    The composed form is [<prefix>][x<suffix>][xx<framing>]. <framing> can be "f" for 'flexible'. Thus for example standard MLLP framing is
     represented by ..%inFraming=$C(11)_"x"_$C(28,13) while AsciiLF framing is "x"_$C(10) and 'None' is represented by "".
*/
/// pre-parse of Framing setting
Property %inFraming As %String;

/// Framing to use on output if input framing is "Flexible"
Property %outFraming As %String;

/// Lookahead line left over from previous document parse
Property %LookaheadLine As %String;

/// Lookahead buffer for line terminator of unframed MSH
Property %LookaheadLineTerminator As %String;

/// Lookahead buffer for line terminator of unframed MSH
Property %LookaheadLineIsNew As %Boolean;

/// EndBlock character(s) to look for as message end marker
Property %EndBlock As %String;

/// Count of Segments tallied during parse
Property %SegmentCount As %Integer;

Property %LineCount As %Integer;

Property %CharCount As %Integer;

/// The config provider
Property %ServiceInterface As EnsLib.EDI.ServiceInterface;

/// The current Document
Property %CurrentDocument As EnsLib.EDI.Document;

/// The segment position within the current parent Document
Property %CurrentParentSegIndex As %String;

/// List of enclosing parent objects ordered from outermost to immediate
///  As EnsLib.EDI.Document 
Property %CurrentParents [ InitialExpression = 0, MultiDimensional ];

/// List of enclosing parent objects ordered from immediate to outermost
Property %ParentIds As %String;

/// List of counts of nested documents, ordered from outer to innermost
Property %NumChildren As %Integer [ MultiDimensional ];

Method DoneGet() As %Boolean [ CodeMode = expression ]
{
""=..%LookaheadLine&&('$IsObject(..%Stream)||..%Stream.AtEnd)
}

/// Parse a complete document from the stream, including any nested documents inside it
Method ParseIOStream(pIOStream As %IO.I.CharacterStream, ByRef pMsg As Grongier.HL7.Message, pInbound As %Boolean = 0, pFramed As %Boolean = 0) As %Status
{
#define MapCtlChars(%s)	$TR(%s,$C(1,2,9,10,11,13,28),"12tlsre")
#define MapCtlLine(%s)	($$$MapCtlChars($E(%s,1,1000))_$S($L(%s)>1000:"...",1:""))
#define MapCtlLineZB(%s,%zb)	($$$MapCtlLine(%s)_"+"_$$$MapCtlChars(%zb))

	$$$ASSERT($IsObject(pIOStream))
	If pFramed { Set tLineTerminator=pIOStream.LineTerminator }
	Else { Set tLineTerminator=..%ServiceInterface.GetSegmentTerminator(), pIOStream.LineTerminator=tLineTerminator }

	If (""=$G(pMsg)) || $IsObject(pMsg) { Set tMsgClass="Grongier.HL7.Message" }
	Else { Set tMsgClass=pMsg }

	Set (tSC,tSC1)=$$$OK, (pMsg,tDoc)=$$$NULLOREF, ..%Stream=pIOStream, tLine=..%LookaheadLine, tZB=..%LookaheadLineTerminator
	Set tParentDoc=..%CurrentDocument, tParentDocPos=..%CurrentParentSegIndex
	Set tEndBlock=..%EndBlock, ..%EndBlock="", tLLP=("L"=$E(tEndBlock,*))  Set:tLLP tEndBlock=$E(tEndBlock,1,*-1)
	If ""'=tLine {
		If ..%LookaheadLineIsNew {
			If "!"=$E(..DefCharEncoding) { ; fix MSH line encoding if forced charset
				Set tEnc=$E(..DefCharEncoding,2,*)  If tEnc'=pIOStream.CharEncoding {
					Set tTab=##class(%IO.I.TranslationDevice).GetCharEncodingTable(tEnc)
					If tTab'=""&&(tTab'=##class(%IO.I.TranslationDevice).GetCharEncodingTable(pIOStream.CharEncoding)) {
						Set pIOStream.CharEncoding=tEnc
						Set tLine=$ZCVT(tLine,"I",tTab)
					}
				}
			}
			Set ..%LineCount=..%LineCount+1, ..%CharCount=..%CharCount+$L(tLine)+$L(tZB)
			Set ..%LookaheadLineIsNew=0
		}
		Set tStartTimeout=..ReadTimeout
	} Else {
		Set tStartTimeout=..StartTimeout
		If "!"=$E(..DefCharEncoding) { ; fix stream encoding if forced charset
			Set tEnc=$E(..DefCharEncoding,2,*)  If tEnc'=pIOStream.CharEncoding {
				Set tTab=##class(%IO.I.TranslationDevice).GetCharEncodingTable(tEnc)
				If tTab'=""&&(tTab'=##class(%IO.I.TranslationDevice).GetCharEncodingTable(pIOStream.CharEncoding)) {
					Set pIOStream.CharEncoding=tEnc
				}
			}
		}
	}
	
	#; Max read length for first segment is maximum string length less 5 for separators
	Set tMaxReadLen = $$$HL7MaxReadLen
	Set tSubIndex=1, (tFirstPiece,tSegDone)=1, (tBuf,tMSHZB)="", tSeparators="     "

	/*	This is used when ..ReadTimeout is 0 and reading from a TCP device
		It is set to 1 when we detect a partial read of a segment and remains 1 until next first piece
	*/
	#dim tPartialSegReadTimeoutZero

	Do { ; While 0
		#; Process any preceding stuff in the stream
		Set tSC=..%ServiceInterface.OnPreDocument(pIOStream,.tLine)  Quit:$$$ISERR(tSC)||(""=tLine&&pIOStream.AtEnd)

		#; Read any blank lines to end, just to make sure there is an actual document beginning there
		While ""=tLine && 'pIOStream.AtEnd {
			Kill tZB  Set tTimeout=tStartTimeout, tLine=pIOStream.ReadLine(tMaxReadLen,.tTimeout,.tSC,.tZB)  Quit:$$$ISERR(tSC)
			If (tStartTimeout&&(tTimeout=tStartTimeout)) { Set tSC=$$$ERROR($$$EnsErrTCPTerminatedReadTimeoutExpired,tStartTimeout,"EndData="_$A($E(tLineTerminator))_$S(""=$E(tLineTerminator,2):"",1:","_$A($E(tLineTerminator,2))),tLine) }
			If ""'=tLine||(""'=tZB) { Set ..%LineCount=..%LineCount+1, ..%CharCount=..%CharCount+$L(tLine)+$L(tZB)
				$$$catTRACE("parse","Got prefix line '"_$$$MapCtlLineZB(tLine,tZB)_"'")
			}
			Set tStartTimeout=..ReadTimeout ; already started so go to read mode
		}
		Quit:""=tLine
		If '$IsObject(tParentDoc) {
			Set (tNumBatches,..%SegmentCount)=0
		}
		Set tFS=$E($ZStrip($E(tLine,1,1+$$$MAXSEGNAME),"*AN")) ; separator is first non-alphanumeric char
		Set (tSegName,tFirstSeg)=$S(""=tFS:"", 1:$P(tLine,tFS))
		Set tSeparators=tFS_$P(tLine,tFS,2)
		Set:$L(tSeparators)'=5 tSeparators=$E(tSeparators,1,5)_$E($$$HL7DefFS_$C(17,18,19,20),$L(tSeparators)+1,5)

		#; Count the documents we encounter, nested
		If $IsObject(tParentDoc) {
			#; child document
			Set tParentRef=tParentDoc.getId()_":"_tParentDocPos, tParentIds=$LB(tParentRef)_..%ParentIds
		} Else { Set (tParentRef,tParentIds)="" }
		Set tSubsc="",tLevels=1+$LL(tParentIds)  For i=1:1:tLevels-1  Set tSubsc=""""_$LI(tParentIds,i)_""","_tSubsc
		Set tRef=$S(""=tSubsc:"..%NumChildren",1:"..%NumChildren("_$E(tSubsc,1,*-1)_")")
		Set tLevelDocs=$G(@tRef)+1

		#; Find the encoding to use - declared in MSH or overridden from DefCharEncoding setting
		Set tMSHEncoding=$S("!"=$E(..DefCharEncoding):$E(..DefCharEncoding,2,*), 1:$TR($ZStrip($P(tLine,tFS,18),"<>CW"),$$$RSSEP(tSeparators)))  Set:""=tMSHEncoding tMSHEncoding=..DefCharEncoding
		If ""=tMSHEncoding || (""=##class(%IO.I.TranslationDevice).GetCharEncodingTable(tMSHEncoding)) {
			If ""'=tMSHEncoding $$$LOGWARNING("No translation table found for specified character encoding '"_tMSHEncoding_"'; Using 'ISO-8859-1' ('Latin1')")
			Set tMSHEncoding="ISO-8859-1"
		} ElseIf tMSHEncoding'=pIOStream.CharEncoding {
			Set tTab=##class(%IO.I.TranslationDevice).GetCharEncodingTable(tMSHEncoding)
			If tTab'=""&&(tTab'=##class(%IO.I.TranslationDevice).GetCharEncodingTable(pIOStream.CharEncoding)) {
				Set tLine=$ZCVT(tLine,"I",tTab)
			}
		}
		$$$catTRACE("parse","Using "_tMSHEncoding_" header line #"_..%LineCount_" '"_$$$MapCtlLine(tLine)_"'")
		Set tJK=$$$JobKey

		#; Relocate all old-style segments of all msg objects that reference the current segment. (Opening one will do them all)
		If $G($$$EnsConfig("HL7Segs-Compat")) {
			Lock +$$$vaSegmentGbl(tJK):2
			If $Test {
				Set data=$G($$$vaSegmentGbl(tJK))
				Set:data'=+data msg=##class(Grongier.HL7.Message).%OpenId($O($$$vaSegmentGbl(tJK,0,"")))  Kill msg
				Lock -$$$vaSegmentGbl(tJK)
			}
		}
		#; Store the data for the first segment
		If '$D(%topSegIndex) {
			Set %topSegIndex=$G($$$vaSegmentGbl(tJK))
			#; Cleanup: kill any leftover uncommitted stored segments
			Set kSI=%topSegIndex For { Set kSI=$O($$$vaSegmentGbl(tJK,kSI))  Quit:""=kSI
			  Kill $$$vaSegmentGbl(tJK,kSI) }
		}
		Set tIndex=tJK_","_$I(%topSegIndex), $$$vaSegment(tIndex)=tSeparators_tLine, $$$vaOpenSegmentPPG(tIndex)=1, tLine="", ..%SegmentCount=..%SegmentCount+1
		Set pIOStream.CharEncoding=tMSHEncoding
		Set tMSHZB=tZB  Set:""=tZB (tMSHZB,tZB)=$E(tLineTerminator)

		#; Instantiate a document to hold the segment and any to follow; make the previously current document (if any) our parent document
		Set tDocPos=$S(""=tParentIds:pIOStream.Name,1:"")_$S(..%LineCount<=2:"", 1:$C(13,10)_" Document# "_tLevelDocs_", level "_tLevels_", @Line "_..%LineCount)
		Set tDoc=$classmethod(tMsgClass,"%New",$LB($LB(tIndex),tSeparators,tDocPos,tParentRef))  If '$IsObject(tDoc) Set tSC=%objlasterror Quit // Fatal Error
		If $IsObject(tParentDoc) {
			Set ..%CurrentParents=..%CurrentParents+1, ..%CurrentParents(..%CurrentParents)=tParentDoc
			Set ..%ParentIds=tParentIds
		}
		Set ..%CurrentDocument=tDoc, tSegNum=2 ; tSegNum is current segment of current document

		If $Case(tSegName,"MSH":0,"FHS":0,"BHS":0,:1) {
			Set tDocPos=pIOStream.Name_$C(13,10)_" Document# "_+tLevelDocs_", level "_tLevels_", @Line "_..%LineCount
			Set tSC=$$$ERROR($$$EnsEDIHL7ErrGeneral,"Segment ("_$E(tLine,1,100)_$S($L(tLine)>100:"...",1:"")_") is not MSH or FHS or BHS at start of message at "_tDocPos)
			Quit
		}
		#; Count the documents we encounter, nested
		Set tTypeName=tDoc.Name  Set:""=tTypeName tTypeName="?"
		Set tReft="..%NumChildren("_tSubsc_""""_tTypeName_""")"
		Set tLevelTypeDocs=$G(@tReft)+1
		Set @tRef=tLevelDocs, @tReft=tLevelTypeDocs
		
		#; Notify the Service of the new document beginning
		Set tSC1=..%ServiceInterface.OnDocumentStart(tDoc,tDocPos,tSC)  Quit:$$$ISERR(tSC1) // Fatal Error

		#; Parse the rest of the segments in the current document
		#;$$$catTRACE("parse","+ %CurrentParents="_..%CurrentParents_", tDoc="_$G(tDoc)_", tParentDoc="_tParentDoc)
		Set (tEOF,iRef)=0, iRefSegId="0,0"
		While $$$ISOK(tSC)&&(""'=tLine||'(pIOStream.AtEnd||tEOF))&&(tMSHZB=tZB||'tSegDone) { ; loop over segs in the doc until no more data or ZB changed outside of multiline seg
			If ""=tLine {
				#; Read a segment line buffer
				Kill tZB  Set tTimeout=..ReadTimeout, tLine=pIOStream.ReadLine(tMaxReadLen,.tTimeout,.tSC,.tZB)  Quit:$$$ISERR(tSC)
				If (..ReadTimeout&&(tTimeout=..ReadTimeout)) { Set tSC=$$$ERROR($$$EnsErrTCPTerminatedReadTimeoutExpired,..ReadTimeout,"EndData="_$A($E(tLineTerminator))_$S(""=$E(tLineTerminator,2):"",1:","_$A($E(tLineTerminator,2))),tLine) }
				Set:""'=tLine||(""'=tZB) ..%LineCount=..%LineCount+1, ..%CharCount=..%CharCount+$L(tLine)+$L(tZB)
				#;$$$catTRACE("parse","At line "_..%LineCount_", for EndBlock '"_$$$MapCtlChars(tEndBlock)_"' got line '"_$$$MapCtlLineZB(tLine,tZB)_"'")
				Set eb=$Case(tEndBlock
						,"":0
						,tZB:(""=tLine)
						,$E(tLine,    *+1-$L(tEndBlock),*):1
						,$E(tLine_tZB,*+1-$L(tEndBlock),*):1+$L(tZB)
						,:0)
				If eb {
					Set:eb>1 tZB=""
					Set tEOF=1, ..%EndBlock=tEndBlock, $E(tLine,$L(tLine)+eb-$L(..%EndBlock),$L(tLine))=""
					$$$catTRACE("parse","detected EndBlock '"_$$$MapCtlChars(..%EndBlock)_"' with line '"_$$$MapCtlLineZB(tLine,tZB)_"'")
					If tFirstPiece {
						Quit:""=tLine
						If $L(tLine)<=$S(tLLP:8,1:3) { ; 8=$L("12345xxx") - LLP endblock ; 3=seg name length
							If ($L(tLine)'=8) {
								If ((tLine=$C(10))&&(pIOStream.LineTerminator=$C(13))) {
									Set tLine = ""
								} Else {
									$$$LOGWARNING("returning unexpected "_$L(tLine)_"-char end block '"_$$$MapCtlChars(tLine)_"' interpreted as End-of-Message for current message")
								}
							}
							Set ..%EndBlock=tLine_..%EndBlock, tLine=""
							Quit
						}
					}
				} ElseIf tFirstPiece {
					Continue:""=tLine&&..IgnoreBlankLines
					Set tNoCtl6=$ZStrip($E(tLine,1,6),"<C") ; 6 = $L($C(28,11)_"MSH"_tFS)
					If $Case($E(tNoCtl6,1,4)
							,"MSH"_tFS:$Case(tFirstSeg,"FHS":0,"BHS":0,:1)
							,"BHS"_tFS:$Case(tFirstSeg,"FHS":0,:1)
							,"FHS"_tFS:1
							,"FTS"_tFS:$Case(tFirstSeg,"BHS":1,:0)
							,:0) {
						Set:$E(tNoCtl6)'=$E(tLine) ..%EndBlock=$E(tLine), $E(tLine)=""
						Set tEOF=1
						If ""=tParentDoc||($L(tNoCtl6)<6) Set tSC=$$$ERROR($$$EnsErrDocImport,"Returning unused unexpected "_$L(tLine)_"-char segment '"_$$$MapCtlLine(tLine)_"' interpreted as End-of-Message for current Message")
						Quit
					} ElseIf $L(tLine)<=6&&(tLine'[tFS)&&'(tLine?2U1UN) { ; room for LLP prefix
						If (""'=tLine||$Case(tEndBlock,"":0,tZB:0,:1)) {
							If ((tLine=$C(10))&&(pIOStream.LineTerminator=$C(13))) {
								Set tLine = ""
							} Else {
								$$$LOGWARNING("Returning unused unexpected "_$L(tLine)_"-char segment '"_$$$MapCtlLine(tLine)_"' interpreted as End-of-Message for current message")
							}
						}
						Set tEOF=1, ..%EndBlock=tLine_tZB, tLine=""
						Quit
					}
				}
				Set tSegDone=(""'=tZB && (pIOStream.LineTerminator[$E(tZB))) || tEOF || $$$ISERR(tSC)
			}
			#; Store the latest chunk to the current segment, or start a new one.
			If tFirstPiece  {
				If ""'=tLine {
					Set tPrevSeg=tSegName, tSegName=$P($E(tLine,1,$$$MAXSEGNAME),tFS)
					Set tDocPos=pIOStream.Name_$C(13,10)_" Document# "_tLevelDocs_", level "_tLevels_", segment "_tSegNum_", @Line "_..%LineCount
					If '(tSegName?1(2U1UN,1"Z"1.4(1UN,1"_")1UN)) {
						#; Check for leading LF that may be a result of segment terminator being non standard CR LF and remove
						If ((pIOStream.LineTerminator=$C(13)) && ($E(tLine)=$C(10))) {
							Set tLine = $E(tLine,2,*),tSegName=$P($E(tLine,1,$$$MAXSEGNAME),tFS)
							If '(tSegName?1(2U1UN,1"Z"1.4(1UN,1"_")1UN))  $$$catTRACE("parse","Badly formed segment name after removing leading LineFeed character '"_tSegName_"' in message "_tDoc.%Id()_" at "_tDocPos_" ("_$$$MapCtlLine(tLine)_")")
						} Else {
							 $$$catTRACE("parse","Badly formed segment name '"_tSegName_"' in message "_tDoc.%Id()_" at "_tDocPos_" ("_$$$MapCtlLine(tLine)_")")
						}
					}
					#; Drill down & start a new doc, pop up, or keep adding segments to the current doc
					If $Case(tSegName,"MSH":1,"BHS":1, "FHS":1,:0) { ; drill down
						Set tGroupName=$S("MSH"=tSegName:"MessageDocsRef", 1:tSegName_"DocsRef")
						If tPrevSeg'=tGroupName {
							#; Create a placeholder segment for the child document(s)
							If $G($$$EnsConfig("HL7Segs-Compat")) {
								#; Relocate all old-style segments of all msg objects that reference the current segment. (Opening one will do them all)
								Lock +$$$vaSegmentGbl(tJK):2
								If $Test {
									Set data=$G($$$vaSegmentGbl(tJK))
									Set:data'=+data msg=##class(Grongier.HL7.Message).%OpenId($O($$$vaSegmentGbl(tJK,0,"")))  Kill msg
									Lock -$$$vaSegmentGbl(tJK)
								}
							}
							Set tIndex=tJK_","_$I(%topSegIndex)
							Set iRef=$$$vaMobj(tDoc,"runtimeIndex")+1, iRefSegId=tIndex, tSegNum=tSegNum+1
							Set $$$vaSegment(tIndex)=tSeparators_tGroupName_tFS_iRef_tFS
							Set $$$vaOpenSegmentPPG(tIndex)=1
							Set $$$vaMobj(tDoc,"runtimeIndex")=iRef, $$$vaMobja(tDoc,"runtimeIndex",iRef)=tIndex
							Set ..%CurrentParentSegIndex=iRef
						}
						Set tPrevSeg=tSegName, tSegName=tGroupName

						#; parse the nested child document
						Set $$$vaSegmentGbl(tJK)=%topSegIndex ; commit ahead of %Save
						Set tSC=tDoc.%Save()  Quit:$$$ISERR(tSC) ; save the doc-in-progress so children will have access to its content.
						Set ..%LookaheadLine=tLine, ..%LookaheadLineTerminator=tZB
						Set tSC=..ParseIOStream(pIOStream,,pInbound)
						Set %topSegIndex=$$$vaSegmentGbl(tJK) ; restore after Kill in recursive call
						Set tLine=..%LookaheadLine, tZB=..%LookaheadLineTerminator
						Set:""'=tZB tMSHZB=tZB ; don't break loop if batch header had different terminator from lookahead segment
						Set tFirstPiece=1, tSegDone=(""'=tZB && (pIOStream.LineTerminator[$E(tZB))) || tEOF || $$$ISERR(tSC)
						If (..ReadTimeout=0) Kill tPartialSegReadTimeoutZero
						Set:$$$ISERR(tSC)&&$$$StatusEquals(tSC,$$$EnsErrDocImport) tSC=$$$OK
						Quit:$$$ISERR(tSC)
						Continue
					} ElseIf $Case(tSegName,"BTS":"BHS"'=tFirstSeg, "FTS":"FHS"'=tFirstSeg, :0) { ; BTS,FTS are normal segs for Batch groups; BHS,FHS should not appear within after position 1
						Set tSegName="" ; pop up if we see an out-of-context segment
						Quit
					}
					#; Relocate all old-style segments of all msg objects that reference the current segment. (Opening one will do them all)
					If $G($$$EnsConfig("HL7Segs-Compat")) {
						Lock +$$$vaSegmentGbl(tJK):2
						If $Test {
							Set data=$G($$$vaSegmentGbl(tJK))
							Set:data'=+data msg=##class(Grongier.HL7.Message).%OpenId($O($$$vaSegmentGbl(tJK,0,"")))  Kill msg
							Lock -$$$vaSegmentGbl(tJK)
						}
					}
					#; Store the data for the current segment and add it to the message
					Set tIndex=tJK_","_$I(%topSegIndex)
					Set tBuf=..split(tSeparators,.tLine,tSeparators)
					Set $$$vaSegment(tIndex)=tLine, $$$vaOpenSegmentPPG=1, tLine="", tSegNum=tSegNum+1, ..%SegmentCount=..%SegmentCount+1
					Set $$$vaMobj(tDoc,"runtimeIndex")=$$$vaMobj(tDoc,"runtimeIndex")+1, $$$vaMobja(tDoc,"runtimeIndex",$$$vaMobj(tDoc,"runtimeIndex"))=tIndex

					#; Add the child count to the reference placeholder segment - if we are on the next segment after the group
					If tPrevSeg["DocsRef" {
						Set tSubscx=tSubsc_""""_tDoc.%Id()_":"_..%CurrentParentSegIndex_""""
						Set tRefx="..%NumChildren("_tSubscx_")"
						Set $$$vaSegment(iRefSegId)=$$$vaSegment(iRefSegId)_$G(@tRefx)
					}
					If 'tSegDone {
						Set tFirstPiece=0
						/*	If the segment is split across multiple TCP ReadLine calls
							it may be due to ReadTimeOut=0 and may not include a 'long'
							field requiring it to be split.
							Leave set to 1 if already 1 and ..ReadTimeout=0 to account for multisplits of one segment
						*/
						If (..ReadTimeout=0) {
							If (tZB="") && (pIOStream.Name["|TCP|") {
								Set tPartialSegReadTimeoutZero = 1
							}
						}
						Continue
					}
				} Else { ; empty line
					$$$ASSERT(tSegDone)
				}
			} Else { ; Not tFirstPiece
				#; If remaining data from previous piece of seg
				Set tBuf=..split(tBuf,.tLine,tSeparators)
				Continue:""=tLine
				/* If the segment is split across multiple TCP ReadLine calls
					it may be due to ReadTimeOut=0 then append to root node if we can.
					tPartialSegReadTimeoutZero can only be set if ..ReadTimeout=0
					Leave set to 1 if already 1 to account for multisplits of one segment
				*/
				If $Get(tPartialSegReadTimeoutZero) && (tSubIndex=1) && (($L($$$vaSegment(tIndex))+$L(tLine))<$$$HL7MaxSegLen) {
					Set $$$vaSegment(tIndex)=$$$vaSegment(tIndex)_tLine
				} Else {
					Set $$$vaSegmentExt(tIndex,tSubIndex)=tLine
					Set tSubIndex=tSubIndex+1
					#; Cleanup if could not append
					If $Get(tPartialSegReadTimeoutZero) Kill tPartialSegReadTimeoutZero
				}
				Set tLine=""
				Continue:'tSegDone
				Set tFirstPiece=1
				Set tSubIndex=1
				If (..ReadTimeout=0) Kill tPartialSegReadTimeoutZero
			}
			#; Now (if we didn't Continue) we have a complete segment stored in the Segment global
			$$$ASSERT(tSegDone)
			If ""'=tBuf {
				;$$$ASSERT('$D($$$vaSegmentExt(tIndex,tSubIndex)))
				Set $$$vaSegmentExt(tIndex,tSubIndex)=tBuf, tBuf="" ; save the last bit
			}
			; No Quit:$Case(tSegName, "BTS":"BHS"=tFirstSeg, "FTS":"FHS"=tFirstSeg, :0) ; get suffix and/or allow more segs after
		} ; done doc
		#;$$$catTRACE("parse","- %CurrentParents="_..%CurrentParents_", tDoc="_tDoc_", tParentDoc="_tParentDoc)
		#; Add the child count to the reference placeholder segment - if the file ended in the child document
		If tSegName["DocsRef" {
			Set tSubscx=tSubsc_tDoc.%Id()_","
			Set tRefx="..%NumChildren("_tSubscx_""""_$P(tSegName,"DocsRef")_""")"
			Set $$$vaSegment(iRefSegId)=$$$vaSegment(iRefSegId)_$G(@tRefx)
		}
		#; Save if child or re-save if has children
		If $G(%topSegIndex) Set $$$vaSegmentGbl(tJK)=%topSegIndex  Kill %topSegIndex ; commit ahead of %Save() and callbacks
		If $IsObject(tParentDoc)||($D(tRefx)&&+$G(@tRefx)) {
			Set tSC=tDoc.%Save()  Quit:$$$ISERR(tSC) ; save the doc-in-progress so children will have access to its content.
			Do tDoc.%SetModified(1)  Set tSC1=tDoc.%Save()  Quit:$$$ISERR(tSC1) // Fatal Error
		}
		If 'pFramed { // otherwise ParseFramedIOStream will call it
			Set tDocPos=pIOStream.Name_$C(13,10)_" Document# "_tLevelDocs_", level "_tLevels_", @Line "_..%LineCount
			Set tSC1=..%ServiceInterface.OnDocumentEnd(tDoc,tDocPos,tSC1)  Quit:$$$ISERR(tSC1) // Fatal Error

			#; Process any trailing stuff in the stream
			#; Read any blank lines to end, just to see if there is another document beginning there
			While ""=tLine && 'pIOStream.AtEnd {
				Kill tZB  Set tLine=pIOStream.ReadLine(tMaxReadLen,0,.tSC1,.tZB)  Quit:$$$ISERR(tSC1)
				Quit:""=tLine&&(""=tZB)
				If (tZB=""),(pIOStream.Name["|TCP|") {
					#;This means we got a partial line with Timeout of 0 so try another timed read using item's read timeout.	
					$$$catTRACE("parse","Got partial trailing line '"_$$$MapCtlLine(tLine)_"'")	
					Set tLookAheadTimeout=..ReadTimeout
					Kill tZB  Set tRestOfLine=pIOStream.ReadLine((tMaxReadLen-$L(tLine)),.tLookAheadTimeout,.tSC1,.tZB)
					Quit:$$$ISERR(tSC1)
					Set tLine = tLine_tRestOfLine
					If (tZB="") {
						#; We timed out again using Read timeout setting discard up to now
						$$$LOGWARNING("Discarding received timedout incomplete pre-fetch MSH data("_$L(tLine)_") '"_$$$MapCtlLine(tLine)_"'")
						Set tLine = ""
					} Else {
						$$$catTRACE("parse","Got remainder of trailing line '"_$$$MapCtlLineZB(tRestOfLine,tZB)_"'")
						Set ..%LineCount=..%LineCount+1, ..%CharCount=..%CharCount+$L(tLine)+$L(tZB)
						$$$catTRACE("parse","Got trailing line '"_$$$MapCtlLineZB(tLine,tZB)_"'")
					}
				} Else {
					Set ..%LineCount=..%LineCount+1, ..%CharCount=..%CharCount+$L(tLine)+$L(tZB)
					$$$catTRACE("parse","Got trailing line '"_$$$MapCtlLineZB(tLine,tZB)_"'")
				}
			}
			Quit:$$$ISERR(tSC1)&&($$$StatusText(tSC1)'["<READ>") ; swallow disconnect error- save the data we got
			Set tSC1=..%ServiceInterface.OnPostDocument(pIOStream,.tLine)
		}
	} While 0
	Set:$$$ISERR(tSC1)&&(tSC'=tSC1) tSC=$$$ADDSC(tSC,tSC1)
	Set:""=tEndBlock&&(""'=tMSHZB&&(tMSHZB'=tZB)&&tSegDone) ..%EndBlock=tZB
	Set ..%LookaheadLine=tLine
	Set ..%LookaheadLineTerminator=tZB
	If $IsObject(tDoc) {
		Set ..%CurrentDocument=$G(..%CurrentParents(..%CurrentParents),$$$NULLOREF)
		Kill ..%CurrentParents(..%CurrentParents)
		Set ..%CurrentParents=..%CurrentParents-1
		$$$ASSERT('$IsObject(..%CurrentDocument)||(..%CurrentDocument.%Id()=$P($LI(..%ParentIds),":")))
		Set ..%ParentIds=$LI(..%ParentIds,2,$LL(..%ParentIds))
		Set pMsg=tDoc
		If $G(%topSegIndex) Set $$$vaSegmentGbl(tJK)=%topSegIndex  Kill %topSegIndex ; commit before exit
	}
	Set ..%CurrentParentSegIndex=tParentDocPos
	Quit tSC
}

/// merge prev buf with current buf, return new trailing overflow buf. Split on delimiter boundary if possible
/// return next subscript for the extra remnant</Description>
ClassMethod split(pPrev As %String, ByRef pBuf As %String, pDelims As %String) As %String
{
	Set tMaxSeg = $$$HL7MaxSegLen
	Set tPrevLen=$L(pPrev)  If tPrevLen+$L(pBuf)<=tMaxSeg { Set pBuf=pPrev_pBuf Quit ""}
	#; find the last piece delimiter before pPrev len of the end
	Set tExtra=$E(pBuf,tMaxSeg-tPrevLen+1,*), pBuf=pPrev_$E(pBuf,1,tMaxSeg-tPrevLen)
	Quit tExtra
}

/* LLP NAK Qualifier byte values:
	X = Checksum found wrong in previous data block received.
	B = Data too long for input buffer in previous block received.
	G = Error not covered elsewhere.
	C = Character count wrong in previous data block received. 
*/
/// Read an HL7 Message from the given IO Stream
/// Returned %Status codes are not logged, except for Exceptions
Method ParseFramedIOStream(pIOStream As %IO.I.CharacterStream, ByRef pMsg As Grongier.HL7.Message, pInbound As %Boolean = 0, ByRef pIOLogEntry As Ens.Util.IOLog = {$$$NULLOREF}) As %Status
{
#define MapCtlChars(%s)	$TR(%s,$C(1,2,9,10,11,13,28),"12tlsre")
#define MapCtlLine(%s)	($$$MapCtlChars($E(%s,1,1000))_$S($L(%s)>1000:"...",1:""))
#define MapCtlLineZB(%s,%zb)	($$$MapCtlLine(%s)_"+"_$$$MapCtlChars(%zb))
	If (""=$G(pMsg)) || $IsObject(pMsg) { Set tMsgClass="Grongier.HL7.Message" }
	Else { Set tMsgClass=pMsg }
	Set $ZT="Trap",$EC="", tSC=$$$OK, pMsg=$$$NULLOREF, tLine=..%LookaheadLine, tZB=..%LookaheadLineTerminator
	If ""'=tLine {
		If ..%LookaheadLineIsNew {
			If "!"=$E(..DefCharEncoding) { ; fix MSH line encoding if forced charset
				Set tEnc=$E(..DefCharEncoding,2,*)  If tEnc'=pIOStream.CharEncoding {
					Set tTab=##class(%IO.I.TranslationDevice).GetCharEncodingTable(tEnc)
					If tTab'=""&&(tTab'=##class(%IO.I.TranslationDevice).GetCharEncodingTable(pIOStream.CharEncoding)) {
						Set pIOStream.CharEncoding=tEnc
						Set tLine=$ZCVT(tLine,"I",tTab)
					}
				}
			}
			Set ..%LineCount=..%LineCount+1, ..%CharCount=..%CharCount+$L(tLine)+$L(tZB)
			Set ..%LookaheadLineIsNew=0, ..%LookaheadLine=""
		}
		Set tStartTimeout=..ReadTimeout
	} Else {
		Set tStartTimeout=..StartTimeout
		If "!"=$E(..DefCharEncoding) { ; fix stream encoding if forced charset
			Set tEnc=$E(..DefCharEncoding,2,*)  If tEnc'=pIOStream.CharEncoding {
				Set tTab=##class(%IO.I.TranslationDevice).GetCharEncodingTable(tEnc)
				If tTab'=""&&(tTab'=##class(%IO.I.TranslationDevice).GetCharEncodingTable(pIOStream.CharEncoding)) {
					Set pIOStream.CharEncoding=tEnc
				}
			}
		}
	}
	If "uninitialized"=..%inFraming {
		Set ..%inFraming=..applyFraming(..Framing)
		Set:"uninitialized"=..%outFraming ..%outFraming=..%inFraming
	}
	Set tPrefix=$P(..%inFraming,"xx"), tInFraming=$E(..%inFraming,$L(tPrefix)+3,*), tSuffix=$P(tPrefix,"x",2), tPrefix=$P(tPrefix,"x")
	Set:""=..IgnoreBlankLines&&(""'=$TR(tSuffix,$C(13,10))) ..IgnoreBlankLines=1

	Set tLineTerminator=..%ServiceInterface.GetSegmentTerminator(), tSuff=$E(tSuffix,1,*-("LLP"=$P(..%inFraming,"xx",2)))
	Set:tLineTerminator'[$E(tSuff,*) tLineTerminator=tLineTerminator_$E(tSuff,*)
	Set pIOStream.LineTerminator=tLineTerminator

	#; Read the first seg plus any prefix chars
	Set seg1pos=0, (tPreJunk,tPreFound,tPrev,tSeg1)=""
	Set tMaxReadLen = $$$HL7MaxReadLen
	Do { ; until we get an MSH/FHS/BHS or suffix or timeout or EOF
		If ""'=tLine {
			Set ..%LookaheadLine="", tTimedOut=0
			$$$catTRACE("parse","Trying pre-fetched header line #"_..%LineCount_" '"_$$$MapCtlLine(tLine)_"'; framing='"_$$$MapCtlChars(..%inFraming)_"'")
		} Else {
			$$$catTRACE("parse","Beginning header read for terminator '"_$A($E(tLineTerminator))_$S(""=$E(tLineTerminator,2):"",1:","_$A($E(tLineTerminator,2)))_"' with timeout "_tStartTimeout_" on "_pIOStream.Name_" using "_$s(pIOStream.%Extends("%IO.I.TranslationDevice"): "table '"_pIOStream.TranslationTable_"'", 1: "no translation table and CharEncoding '"_pIOStream.CharEncoding_"'"))
			Kill tZB  Set tTimeout=tStartTimeout, tLine=pIOStream.ReadLine(tMaxReadLen,.tTimeout,.tSC,.tZB), tCharsLen=$L(tLine)+$L(tZB)  ; No Quit; will break at end of loop
			Set tTimedOut='pIOStream.AtEnd&&('tCharsLen||(tStartTimeout&&(tTimeout=tStartTimeout))), tTimedOutTime=tStartTimeout
			Set:tCharsLen ..%LineCount=..%LineCount+1, ..%CharCount=..%CharCount+tCharsLen
			If ""'=tLine $$$catTRACE("parse","Got header line #"_..%LineCount_" '"_$$$MapCtlLine(tLine)_"'; framing='"_$$$MapCtlChars(..%inFraming)_"'")
		}  Set tStartTimeout=..ReadTimeout ; already started so go to read mode
		Set:""'=tLine tLine=$E(tPrev,*-(tMaxReadLen-$L(tLine)),*)_tLine, tPrev=""

		#; Find MSH/BHS/FHS but don't count it if FS doesn't appear again within 6 chars
		#;Need to check if 'MSH' is text in an FHS or BHS segment. Likewise for BHS as text in FHS
		#;Minimum segment before MHS would be:
		#;FHSxxxxxxrMSH where x = one of the 6 FS and r = CR which puts $F(MSH) @ 14
		Set seg1pos=$F(tLine,"MSH")
		#; If no MSH or room for BHS or FHS need to look for them
		If 'seg1pos||(seg1pos>13) {
			Set segBpos = $F(tLine,"BHS")
			If segBpos&&('seg1pos||(segBpos<(seg1pos-9))) {
	 			#;Now check if feasible separators for BHS
	 			Set tSeps=$E(tLine,segBpos,segBpos+6), tSeps=$E($P(tSeps,$E(tSeps),2),1,4) ; throw away any extra separator
				Set:$L(tSeps)>4||(tSeps'=$ZStrip(tSeps,"*AN")) segBpos=0
				If (segBpos'=0) Set seg1pos = segBpos
			}
			If 'seg1pos||(seg1pos>13) {
	 			;Still room to hold an FHS
	 			Set segFpos=$F(tLine,"FHS")
	 			If segFpos&&('seg1pos||(segFpos<(seg1pos-9))) {
	 				#;Now check if feasible separators for FHS
	 				Set tSeps=$E(tLine,segFpos,segFpos+6), tSeps=$E($P(tSeps,$E(tSeps),2),1,4) ; throw away any extra separator
					Set:$L(tSeps)>4||(tSeps'=$ZStrip(tSeps,"*AN")) segFpos=0
					If (segFpos'=0) Set seg1pos = segFpos
				}
	 		}
			#;Now check if feasible separators for MSH. Keep separate from below to avoid extra If for non batches
			If seg1pos&&'segBpos&&'segFpos {
				Set tSeps=$E(tLine,seg1pos,seg1pos+6), tSeps=$E($P(tSeps,$E(tSeps),2),1,4) ; throw away any extra separator
				Set:$L(tSeps)>4||(tSeps'=$ZStrip(tSeps,"*AN")) seg1pos=0
			}
		} Else {
			#;Now check if feasible separators for MSH
			Set tSeps=$E(tLine,seg1pos,seg1pos+6), tSeps=$E($P(tSeps,$E(tSeps),2),1,4) ; throw away any extra separator
			Set:$L(tSeps)>4||(tSeps'=$ZStrip(tSeps,"*AN")) seg1pos=0
		}
		#; Finished looking for MSH, BHS & FHS
		If 'seg1pos {
			#; check for non-MSH containing messages such as LLP and 1-byte ACKs
			#; (let the LLP prefix go around again, whether for MSH or 1-byte ACK)
			If ("f"=tInFraming || ($L(tPrefix) && ($E(tLine)=$E(tPrefix))))
			 && $Case(tLine,$C(11)_"N21":0, $C(11)_"D21":0, :1) {
				Set tEnvelope=""
				If $Case(tInFraming,"f":1, "LLP":1, :0)
				 && ($C(11)_"N21"_$C(13)=$E(tLine,1,5)) {
					$$$ASSERT($Case($E(tPrefix),"":1,$C(11):1,:0))
					Set tLF=($C(10)=$E(tLine,6))
					If $C(28)=$E(tLine,15+tLF) {
						Set tEnvelope="ACK_LLP_"_$E(tLine,6+tLF)_":"_$E(tLine,1,5)_$E(tLine,6+tLF,15+tLF)_tZB, $E(tLine,1,15+tLF)=""
						Set tPrefix=$C(11)_"D21"_$C(13), tSuffix=$C(28,13)_"L"
						Set tPreFound=$C(11)_"N21"_$C(13)
						#; don't do LLP checksum check - no need in TCP; Set tSuffFound=$E(tLine,7+tLF,15+tLF)_tZB
						Set tCode="AE", tDesc="LLPDU NACK '"_$E(tEnvelope,9)_"' ("_$Case($E(tEnvelope,9)
							,"X":"Checksum found wrong in previous data block received"
							,"B":"Data too long for input Buffer in previous block received"
							,"C":"Character count wrong in previous data block received"
							,:"'General' error not covered elsewhere"
							)_")"
					}
				} ElseIf $L(tLine)>=2 { ; not LLP NACK; try for 1-byte ACK
					If ("f"=tInFraming) && ($L(tLine)>=3) {
						If $Case($E(tLine,2), $E(tLine,1):0, $E(tLine,3):0, $C($$$SingleByteAckAcceptAscii):1, $C($$$SingleByteAckErrorAscii):1, :0)
						 && $Case($E(tLine,4), "":1, $E(tLine,1):1, :0) {
							Set (tPrefix,tPreFound)=$E(tLine)
							Set tSuffix=$S($L(tLine)<=5:$E(tLine,3,*)_tZB, 1:$E(tLine,3))
							Set tEnvelope="ACK_1_"_$A($E(tLine,2))_":"_$E(tLine,2), $E(tLine,1,2+$L(tSuffix))=""
						 }
					} Else {
						If $Case($E(tLine,2), $C($$$SingleByteAckAcceptAscii):1, $C($$$SingleByteAckErrorAscii):1, :0)
						 && (tSuffix=$E(tLine_tZB,3,2+$L(tSuffix))) {
							Set tPreFound=$E(tLine)
							Set tEnvelope="ACK_1_"_$A($E(tLine,2))_":"_$E(tLine,2), $E(tLine,1,2+$L(tSuffix))=""
						 }
					}
					Set:""'=tEnvelope tCode="A"_$S($C($$$SingleByteAckAcceptAscii)=$E(tEnvelope,*):"A",1:"E"), tDesc="1-byte "_$S("AA"=tCode:"",1:"(N)")_"ACK '"_$A($E(tEnvelope,*))_"'"
				}
				If ""'=tEnvelope {
					#; Create a message object to represent the 1-byte ACK
					Set ..%NumChildren=..%NumChildren+1
					Set tDocPos=pIOStream.Name_$S(..%LineCount<=2:"", 1:$C(13,10)_" Document# "_..%NumChildren_", level 0, @Line "_..%LineCount)
					Set pMsg=$classmethod(tMsgClass,"%New",$LB(,,tDocPos))  If '$IsObject(pMsg) Set tSC=%objlasterror Quit // Fatal Error
					Do pMsg.SetValueAt("MSH"_$$$HL7DefFS_$$$HL7DefFS_$$$HL7DefFS_$$$HL7DefFS_$$$HL7DefFS_$$$HL7DefFS_$$$HL7DefFS_$$$HL7DefFS_$TR($P(tEnvelope,":"),"_",$$$HL7DefCS)_$$$HL7DefFS_"00"_$$$HL7DefFS_$$$HL7DefFS_"2.1",1) ; set 00 control id, 2.1 version
					Set tAckMSA=##class(EnsLib.HL7.Segment).%New($LB("",1))
					Do tAckMSA.SetValueAt("MSA"_$$$HL7DefFS_tCode_$$$HL7DefFS_"00"_$$$HL7DefFS_tDesc)
					Do pMsg.AppendSegment(tAckMSA)
					Set pMsg.Envelope=tEnvelope
					Set tF=tPrefix_$S(""=tSuffix:"",1:"x"_tSuffix)_$S(tPrefix=($C(11)_"D21"_$C(13)):"xxLLP",1:"")
					Quit
				}
			}
			Set tPrev=tPrev_tLine_$S(tTimedOut:"",1:tZB), tLine="" ; re-add CR seg delimiter for blank lines
			Set:tTimedOut||pIOStream.AtEnd tPreJunk=$E(tPreJunk,*-(tMaxReadLen-$L(tPrev)),*)_tPrev, tPrev=""
		} Else {
			Set tSeg1=$E(tLine,seg1pos-3,*) ; take the MSH/FHS/BHS and everything after
			If "f"=tInFraming&&'$L(tPrefix) {
				Set tPre5=$E(tLine,seg1pos-8,seg1pos-4)
				If seg1pos-4>=5 && (tPre5=($C(11)_"D21"_$C(13))) {
					Set (tPreFound,tPrefix)=tPre5, tSuffix=$C(28,13)_"L"
				} ElseIf $L($ZStrip($E(tLine,seg1pos-4),"*E'C")) {
					#; check for 'flexible' prefixes - they must be a control-char
					Set (tPreFound,tPrefix)=$E(tLine,seg1pos-4) ; in flex mode, accept whatever we find
				} Else { Set (tPreFound,tPrefix)="" }
			} Else {
				Set tPreFound=$E(tLine,seg1pos-3-$L(tPrefix),seg1pos-4)
				Set:tPreFound'=tPrefix tPreFound=""
			}
			If tPreFound=tPrefix {
				Set tPreJunk1=$E(tLine,1,seg1pos-4-$L(tPreFound)) ; data is now in tPreJunk and tSeg1
				Set ..%EndBlock=$S(""'=tSuffix:tSuffix
				  , 1:$Case(tPreFound
					,$C($$$HL7DefStartBlockAscii):$C($$$HL7DefEndBlockAscii)
					,$C(1):$C(2)
					,:""))
			} Else { ; no match
				If "f"=tInFraming { Set tPreJunk1=$E(tLine,1,seg1pos-4) }
				Else { Set tSeg1="", tPreJunk1=tLine_tZB } ; reject it - we require the correct StartBlock char (or lack of it)
				Set tPreFound=""
			}
			Set seg1pos=0, tLine=""
			Set:""'=tPreJunk1 tPreJunk=$S(""=tPreJunk:"",1:tPreJunk_"|")_tPreJunk1
		}
		If ""'=tPreJunk {
			$$$LOGWARNING("Discarding received non-HL7 data("_$L(tPreJunk)_") '"_$$$MapCtlLine(tPreJunk)_"'")
			If $IsObject(pIOLogEntry) {
				If '$$$IsdefObject(tDiscard) { Set tDiscard=##class(%GlobalCharacterStream).%New()  $$$ASSERT($IsObject(tDiscard)) }
				Do tDiscard.Write(tPreJunk)
			}
			Set tPreJunk=""
		}
	} While ""=tSeg1&&'pIOStream.AtEnd&&'tTimedOut&&$$$ISOK(tSC)

	Do { ; while 0
		#; Deal with unexpected input before the Message
		If $$$IsdefObject(tDiscard) {
			Set tPreJunk=tDiscard.Read(1000) Do tDiscard.Rewind()
			Set tNote="Unexpected HL7 read data ("_$S(tDiscard.Size>1000:"...",1:"")_tPreJunk_") before Message on "_pIOStream.Name
			Do ..%ServiceInterface.IOLogDiscard(tSC,tNote,tDiscard)
		}
		Quit:$$$ISERR(tSC)
		If '$IsObject(pMsg) { ; not single-byte ACK
			If tTimedOut || ((""=tSeg1)&&(""'=tPreJunk)) {
				Set tText=tPreJunk_tLine Set tText=$$$MapCtlChars($E(tText,*-1000,*))
				If tTimedOut { Set tSC=$$$ERROR($$$EnsErrTCPTerminatedReadTimeoutExpired,tTimedOutTime,"SegTerminatorAscii="_$$$HL7DefSegTerminatorAscii_", on "_pIOStream.Name, tText) }
				Else { Set tSC=$$$ERROR($$$EnsEDIHL7ErrStartBlock,$$$MapCtlChars(tPreFound),$$$MapCtlChars(tPrefix)_", on "_pIOStream.Name,tText) }
				Quit
			}
			#; Read Message from device using ParseIOStream()
			Set ..%LookaheadLine=tSeg1, ..%LookaheadLineTerminator=tZB
			Set pMsg=tMsgClass
			Set tSC=..ParseIOStream(pIOStream,.pMsg,pInbound,1)
			Quit:'$IsObject(pMsg) ; Leave everything else for the next time around
			Set tTimedOut=$$$StatusEquals(tSC,$$$EnsErrTCPTerminatedReadTimeoutExpired)  Set:tTimedOut tSC=$$$OK
			Set tLine=..%LookaheadLine, tZB=..%LookaheadLineTerminator

			#; Make tSuffix match EndBlock if LLP
			If (tPrefix=($C(11)_"D21"_$C(13))) && (10=$L(..%EndBlock)) && ($C(28,13)=$E(..%EndBlock,*-1,*)) {
				Set tSuffix=..%EndBlock ; don't put it in tF
				Set pMsg.Envelope="LLP:"_tPrefix_"<!--HL72MSG-->"_tSuffix
				Set tF=tPrefix_"x"_$C(28,13)_"LxxLLP"
			} ElseIf "f"=tInFraming {
				#; Detect suffix char/block if any
				$$$catTRACE("parse","detected EndBlock '"_$$$MapCtlChars(..%EndBlock)_"' with line '"_$$$MapCtlLineZB(tLine,tZB)_"'")
				Set tStart=$F(..%EndBlock,$C(11))  Set:tStart tLine=$E(..%EndBlock,tStart-1,*)_tLine, ..%EndBlock=$E(..%EndBlock,1,tStart-2), tZB=""
				Set:""=tLine&&(..%EndBlock'=tZB) ..%EndBlock=..%EndBlock_tZB ; add terminator to detected suffix
				Set tSuffix=..%EndBlock
				Set tF=tPrefix_$S(""=tSuffix:"",1:"x"_tSuffix)
			}
			Set ..%LookaheadLine=tLine, ..%LookaheadLineTerminator=tZB
			If ..%EndBlock=tSuffix {
				Set:$$$ISERR(tSC)&&$$$StatusEquals(tSC,$$$EnsErrDocImport) tSC=$$$OK
			} Else {
				#; Quit with error; leave everything else for the next time around
				Set:$$$ISOK(tSC) tSC=$$$ERROR($$$EnsEDIHL7ErrEndBlock,$$$MapCtlChars(..%EndBlock),$$$MapCtlChars(tSuffix)_", on "_pIOStream.Name,$$$MapCtlChars(..%EndBlock_tLine))
				Quit
			}
		} ; '$IsObject(pMsg) ; not single-byte ACK

		If "f"=tInFraming {
			Set:..RememberFlex ..%inFraming=tF
			Set:"xxf"=..%outFraming ..%outFraming=tF
			$$$catTRACE("parse","Detected Framing style '"_$$$MapCtlChars(tF)_"'")
		} Else {
			Set tF=..%inFraming
		}
		If $IsObject(pMsg) {
			Do { ; while 0
				Set tDocPos=pIOStream.Name_$C(13,10)_" Document# "_..%NumChildren_", level 0, @Line "_..%LineCount
				Set tSC1=..%ServiceInterface.OnDocumentEnd(pMsg,tDocPos,tSC)  Quit:$$$ISERR(tSC1) // Fatal Error

				#; Process any trailing stuff in the stream
				#; Read any blank lines to end, just to see if there is another document beginning there
				Set tLine=..%LookaheadLine
				While ""=tLine && 'pIOStream.AtEnd {
					Kill tZB  Set tLine=pIOStream.ReadLine(tMaxReadLen,0,.tSC1,.tZB)  Quit:$$$ISERR(tSC1)
					Quit:""=tLine&&(""=tZB)
					If (tZB=""),(pIOStream.Name["|TCP|") {
						#;This means we got a partial line with Timeout of 0 so try another timed read using item's read timeout.	
						$$$catTRACE("parse","Got partial trailing line '"_$$$MapCtlLine(tLine)_"'")	
						Set tLookAheadTimeout=..ReadTimeout
						Kill tZB  Set tRestOfLine=pIOStream.ReadLine((tMaxReadLen-$L(tLine)),.tLookAheadTimeout,.tSC1,.tZB)
						Quit:$$$ISERR(tSC1)
						Set tLine = tLine_tRestOfLine
						If (tZB="") {
							#; We timed out again using Read timeout setting discard up to now
							$$$LOGWARNING("Discarding received timedout incomplete pre-fetch MSH data("_$L(tLine)_") '"_$$$MapCtlLine(tLine)_"'")
							Set tLine = ""
						} Else {
							$$$catTRACE("parse","Got remainder of trailing framing line '"_$$$MapCtlLineZB(tRestOfLine,tZB)_"'")
							Set ..%LineCount=..%LineCount+1, ..%CharCount=..%CharCount+$L(tLine)+$L(tZB)
							$$$catTRACE("parse","Got trailing framing line '"_$$$MapCtlLineZB(tLine,tZB)_"'")
						}
					} Else {
						Set ..%LineCount=..%LineCount+1, ..%CharCount=..%CharCount+$L(tLine)+$L(tZB)
						$$$catTRACE("parse","Got trailing framing line '"_$$$MapCtlLineZB(tLine,tZB)_"'")
					}
				}
				Quit:$$$ISERR(tSC1)&&($$$StatusText(tSC1)'["<READ>") ; swallow disconnect error- save the data we got
				Set tSC1=..%ServiceInterface.OnPostDocument(pIOStream,.tLine)
				Set:$C(10)=$E(tLine) $E(tLine)=""
				Set ..%LookaheadLine=tLine
				Set ..%LookaheadLineTerminator=$S(""=tLine:"",1:tZB)
			} While 0
			Set:$$$ISERR(tSC1)&&(tSC'=tSC1) tSC=$$$ADDSC(tSC,tSC1)
		}
		If $IsObject(pIOLogEntry) {
			Set pIOLogEntry.InObject=pMsg  Do:$IsObject(pMsg) pMsg.%Save()
			Set pIOLogEntry.Annotation = $S(""=pIOLogEntry.Annotation:"",1:pIOLogEntry.Annotation_" | ")_"Received "_$S($IsObject(pMsg):"message "_pMsg.%Id(),1:"no message")_" with Framing style '"_$$$MapCtlChars(tF)_"'"
			Set:$$$ISERR(tSC) pIOLogEntry.Status=$$$ADDSC(pIOLogEntry.Status,tSC)
		}
	} While 0
Exit
	Quit tSC
Trap
	Set $ZT="",tSC=$$$SystemError
	If $tlevel>0 Trollback
	Kill %topSegIndex  ; clean up
	Goto Exit
}

ClassMethod applyFraming(pFraming As %String, pFlexDefault As %String = "xxf") As %String
{
	Set tFramLC=$ZCVT(pFraming,"L")
	Quit $Case($E(tFramLC,1,5),
		"none":"x",
		"flexi":pFlexDefault,
		"mllp":$C($$$HL7DefStartBlockAscii)_"x"_$C($$$HL7DefEndBlockAscii,$$$HL7DefEndDataCRAscii),
		"llp":$C($$$HL7DefStartBlockAscii)_"D21"_$C($$$HL7DefEndDataCRAscii)_"x"_$C($$$HL7DefEndBlockAscii,$$$HL7DefEndDataCRAscii)_"LxxLLP",
		"msgen":"xx<->", "mllpm":$C($$$HL7DefStartBlockAscii)_"x"_$C($$$HL7DefEndBlockAscii,$$$HL7DefEndDataCRAscii)_"xx<->",
		"ascii":$Case(tFramLC,"asciicr":"x"_$C(13),"asciilf":"x"_$C(10),"asciicrlf":"x"_$C(10),:$$framchars($E(tFramLC,6,*))),
		:$S("mllp"=$E(tFramLC,1,4):$$framchars($E(tFramLC,5,*))_$C($$$HL7DefEndDataCRAscii),
			1:$$framchars(tFramLC)))
framchars(str)
	#; Transform a string of the form nn/mm into $C(nn)_"x"_$C(mm) as before- and after- framing chars
	#; If it is just nn, make it "x"_nn because a lone framing char comes after.
	Set tPiece=$P(str,"/")
	Set tStr="" For i=1:1:$L(tPiece,",") { Set tItem=$P(tPiece,",",i)  Continue:""=tItem
		Set tStr=tStr_$C(+tItem)
	}
	Set tPiece=$P(str,"/",2)
	If ""=tPiece&&("/"'=$E(str,*)) {
		If (tStr=$C(0)) && (0'=$E(str)) { Set tStr=pFlexDefault }
		Else { Set tStr="x"_tStr }
	}
	Else {
		Set tStr=tStr_"x"
		For i=1:1:$L(tPiece,",") { Set tItem=$P(tPiece,",",i)  Continue:""=tItem
			Set tStr=tStr_$C(+tItem)
		}
		Set:"x"=$E(tStr,*) $E(tStr,$L(tStr))=""
	}
	Quit tStr
}

Method %OnNew(initvalue As %RawString) As %Status [ Private, ProcedureBlock = 1 ]
{
	Set ..%ServiceInterface=initvalue
	Do ..Reset()
	Quit $$$OK
}

Method Reset()
{
	Set (..%LookaheadLine,..%LookaheadLineTerminator,..%LookaheadLineIsNew)=""
	Do ..ResetPosition()
	Set ..%Stream =$$$NULLOREF
	Set (..%inFraming,..%outFraming) = "uninitialized"
	Set ..%EndBlock=""
}

Method ResetPosition()
{
	Kill ..%CurrentParents,..%NumChildren
	Set (..%CurrentParents,..%NumChildren,..%SegmentCount,..%LineCount,..%CharCount)=0
	Set:""'=..%LookaheadLine||(""'=..%LookaheadLineTerminator) ..%LineCount=..%LineCount+1, ..%CharCount=..%CharCount+$L(..%LookaheadLine)+$L(..%LookaheadLineTerminator)
	Set ..%CurrentDocument=$$$NULLOREF
	Set ..%ParentIds=""
}

}
