/* Copyright (c) 2020 by InterSystems Corporation.
   Cambridge, Massachusetts, U.S.A.  All rights reserved.
   Confidential property of InterSystems Corporation. */

Include EnsHL7

IncludeGenerator EnsHL7

/// A class representing all HL7 v2 message documents using the Virtual Document (VDoc) architecture
Class EnsLib.HL7.Message Extends (%Persistent, EnsLib.EDI.BatchDocument, EnsLib.EDI.Segmented, EnsLib.HL7.Util.MsgBodyMethods) [ ClassType = persistent, Inheritance = right, ProcedureBlock, System = 4 ]
{

/// Use our own domain for localization
Parameter DOMAIN = "Ensemble";

Parameter DOCCLASSNAME = "HL7 Message";

Parameter DOCCLASSFULLNAME = "Health Level 7 (HL7) v2. Message";

Parameter DOCSHORTNAME = "HL7";

/// Name of the default SearchTable indexing class used in UI choices and MessageBank submissions 
Parameter DEFSEARCHCLASS = "EnsLib.HL7.SearchTable";

/// Name of the associated schema class and, after a colon, the schema class code that represents a DocType
Parameter SCHEMACLASS = "EnsLib.HL7.Schema:MS";

Parameter EXTENTSIZE = 2000000;

Index Extent [ Extent, Type = bitmap ];

Index ParentId On ParentId;

Index OriginalDocId On OriginalDocId;

/// XML or other 'envelope' For the HL7 message. The HL7 message will be inserted in place of the "&lt;!--HL72MSG--&gt;"
/// string If present, otherwise after the end of the Envelope.
Property Envelope As %String(MAXLEN = "");

/// All 5 Separators as a String
/// Additional characters will be output as the Segment Terminator; may have up to 3 additional chars for output with newlines
Property Separators As %String(MAXLEN = 8, MINLEN = 5) [ Transient ];

/// Field Separator
Property FS As %String [ Calculated, Transient ];

/// Component Separator
Property CS As %String [ Calculated, Transient ];

/// Repetition Separator
Property RS As %String [ Calculated, Transient ];

/// Escape Character
Property ESC As %String [ Calculated, Transient ];

/// Subcomponent Separator
Property SS As %String [ Calculated, Transient ];

/// Segment Terminator character(s)
Property SegmentTerminator As %String [ Calculated, Transient ];

/// Hint value: Schema Category that was combined with the MSH-declared MessageType to identify
/// a schema Message Type that specifies a Message Structure used as the DocType for this Message.
Property MessageTypeCategory As %String [ ReadOnly ];

/// Raw type name of message found at MSH:9
Property Name As %String [ Calculated, ReadOnly, SqlComputeCode = { Set segid=$G($$$vaExtentGbl({ID},"segs",1),"0,0"), data=$S(segid[",":$G($$$vaSegment(segid)),1:$G($$$vaSegmentGbl(segid))), {Name}=$Case($$$vaDataSegName(data),"FHS":"FHS","BHS":"BHS",:##class(EnsLib.HL7.Message).getDataName(data)) }, SqlComputed, Transient ];

/// Raw type version name of message found at MSH:12 in message content
Property TypeVersion As %String [ Calculated, ReadOnly, SqlComputeCode = { Set segid=$G($$$vaExtentGbl({ID},"segs",1),"0,0"), data=$S(segid[",":$G($$$vaSegment(segid)),1:$G($$$vaSegmentGbl(segid))), {TypeVersion}=$Case($$$vaDataSegName(data),"FHS":"Batch","BHS":"Batch",:$$$vaDataTypeVersion(data)) }, SqlComputed, Transient ];

/// Unique document identification string found at MSH:10 / MessageControlId in document content
Property Identifier As %String [ Calculated, ReadOnly, SqlComputeCode = { Set segid=$G($$$vaExtentGbl({ID},"segs",1),"0,0"), data=$S(segid[",":$G($$$vaSegment(segid)),1:$G($$$vaSegmentGbl(segid))), {Identifier}=$Case($$$vaDataSegName(data),"FHS":$$$vaDataBatchIdentifier(data),"BHS":$$$vaDataBatchIdentifier(data),:$$$vaDataDocIdentifier(data)) }, SqlComputed, Transient ];

/// Count of segments composing this message
Property SegCount As %Integer [ Calculated, ReadOnly, SqlComputeCode = { Set {SegCount}=$G($$$vaExtentGbl({ID},"segs"),0) }, SqlComputed, Transient ];

/// Number of Children
Property ChildCount As %Integer [ Calculated, ReadOnly, SqlComputeCode = { Set {ChildCount}=##class({%%CLASSNAME}).getChildCount({ID}) }, SqlComputed, Transient ];

/// A $List of the Ids of all the enclosing parent documents of this nested document, if nested,
/// in order from from immediate to outermost
/// E.g. for Id of enclosing EncounterBatch if we are an Encounter
Property ParentIds As %String [ Calculated, ReadOnly, SqlComputeCode = { Set {ParentIds}=##class({%%CLASSNAME}).getParentIds({ParentId},1) }, SqlComputed, Transient ];

/// The raw text content of the document. Note that this is a truncated version suitable for use in SQL results and visual inspection,
/// but not a complete or definitive representation of the document.
Property RawContent As %String(MAXLEN = 10000) [ Calculated, ReadOnly, SqlComputeCode = { Set {RawContent}=##class({%%CLASSNAME}).getSegsAsString({ID}) }, SqlComputed, Transient ];

/// the category portion of the DocType
Property DocTypeCategory As %String [ ReadOnly, Transient ];

Property DocTypeSecondary As %String [ Calculated, ReadOnly, Transient ];

/// Stored raw document type name ; the secondary type name portion of the DocType
Property DocTypeName As %String [ ReadOnly, Transient ];

/// Size in bytes of the message content.
/// The calculation assumes 1-byte segment terminators and includes any segments that use more than one storage node.
Property FullSize As %Integer [ Calculated, ReadOnly, SqlComputeCode = { Set {FullSize}=##class({%%CLASSNAME}).GetFullSize({ID}) }, SqlComputed, Transient ];

/// A local array of orefs
/// "orefs" - a local map of integer ids to segment objects
/// And either a subscript into ^IRIS.Temp for this object's LVD maps (for notes on LVD implementation see EnsEDI.inc)
/// or local storage for these additional maps:
/// "runtimeIndex" - array for runtime index to segment; will always be defined unless mapRuntimePath is defined
/// "runtimePath" - array for runtime path to segment
/// "bidirectionalLink" - array for runtime path and index linkage
Property %maps [ MultiDimensional, Transient ];

/// Id of original object if we are a mutable clone (also used as a legal subscript that will result in $G(xxx(..%ClonedId))="" instead of a <SUBSCRIPT> error)
Property %ClonedId As %RawString [ InitialExpression = 0, Internal, ReadOnly, Transient ];

Method FSGet() As %String [ CodeMode = expression ]
{
$E(..Separators,1)
}

Method CSGet() As %String [ CodeMode = expression ]
{
$E(..Separators,2)
}

Method RSGet() As %String [ CodeMode = expression ]
{
$E(..Separators,3)
}

Method ESCGet() As %String [ CodeMode = expression ]
{
$E(..Separators,4)
}

Method SSGet() As %String [ CodeMode = expression ]
{
$E(..Separators,5)
}

Method SegmentTerminatorGet() As %String
{
	Set tSegTerminator=$$$SEGTERM(..Separators)
	Set:""=tSegTerminator tSegTerminator=$C($$$HL7DefSegTerminatorAscii)
	Quit tSegTerminator
}

Method NameGet() As %String [ Internal ]
{
	#; Do as much as possible inline to be speedy
	Do:'$D($$$vaM("runtimeIndex")) ..buildRuntimeIndexFromPath()
	Set tId=..%Id()  Set:'tId tId=..%ClonedId
	Set seg=$$$vaSegLookthru(1,tId)
	Quit:""=seg ""
	If $$$vaIsOref(seg) {
		Set tSegObj=..%maps("orefs",1)
		If (tSegObj.ID="")||$D(tSegObj.DataArray) {
			Set tSeps=tSegObj.Separators
			Set tSegName=tSegObj.getAtFromArray(0), tMSH9=tSegObj.getAtFromArray(9)
		} Else {
			Set data=$$$vaSegment(tSegObj.ID), tSeps=$E(data,1,5)
			Set tSegName=$$$vaDataSegName(data), tMSH9=$$$vaDataDocNameRaw(data)
		}
	} Else {
		Set data=$G($$$vaSegment($P(seg,"|"))), tSeps=$E(data,1,5)
		Set tSegName=$$$vaDataSegName(data), tMSH9=$$$vaDataDocNameRaw(data)
	}
	Quit:""=tSegName ""
	Quit:"FHS"=tSegName "FHS"
	Quit:"BHS"=tSegName "BHS"
	If $S($D($$$EnsConfig("HL7NamePropOld"),tNPS)#2:tNPS,1:$G(^Ens.Config("HL7NamePropOld"))) {
		Quit:"_~\&"_$E(tSeps,3,5)=$TR("_~\&"_$E(tSeps,3,5),tMSH9) $TR(tMSH9,tSeps,":_~\&")
		Quit $E(##class(EnsLib.HL7.Segment).replaceSeparators(tSeps_tMSH9,":_~\&"),6,*)
	}
	Quit ..GetMsgType($TR(tMSH9,tSeps,":_~\&"))
}

ClassMethod getDataName(pData As %String) As %String [ Internal ]
{
	Set tSeps=$E(pData,1,5)
	Set tSegName=$$$vaDataSegName(pData), tMSH9=$$$vaDataDocNameRaw(pData)
	Quit:""=tSegName ""
	If $S($D($$$EnsConfig("HL7NamePropOld"),tNPS)#2:tNPS,1:$G(^Ens.Config("HL7NamePropOld"))) {
		Quit:"_~\&"_$E(tSeps,3,5)=$TR("_~\&"_$E(tSeps,3,5),tMSH9) $TR(tMSH9,tSeps,":_~\&")
		Quit $E(##class(EnsLib.HL7.Segment).replaceSeparators(tSeps_tMSH9,":_~\&"),6,*)
	}
	Quit ..GetMsgType($TR(tMSH9,tSeps,":_~\&"))
}

ClassMethod GetMsgType(pName As %String) As %String
{
	Set tPiece3=$P(pName,"_",3,99)
	Quit $S(""'=tPiece3&&((tPiece3["_")||(tPiece3["&")||(tPiece3["\S\")||(tPiece3["\T\")):$P(pName,"_",1,2),1:pName)
}

Method TypeVersionGet() As %String [ CodeMode = expression ]
{
$Case(..GetValueAt("1:0"),"FHS":"Batch", "BHS":"Batch", :$TR(..GetValueAt("1:12"),..Separators,":_~\&"))
}

Method IdentifierGet() As %String [ CodeMode = expression ]
{
$TR($Case(..GetValueAt("1:0"),"FHS":..GetValueAt("1:11"), "BHS":..GetValueAt("1:11"), :..GetValueAt("1:10")),..Separators,":_~\&")
}

Method SegCountGet() As %Integer
{
	If $D($$$vaM("runtimeIndex")) Quit $$$vaM("runtimeIndex")
	Set count=0,path="" For  Set path=$O($$$vaM("runtimePath",path)) Quit:path=""  Set count=count+1
	Quit count
}

Method RawContentGet() As %String
{
	Quit ..OutputToString()
}

Method DocTypeSecondaryGet() As %String [ CodeMode = expression ]
{
..DocTypeName
}

Method FullSizeGet() As %Integer
{
	Do:'$D($$$vaM("runtimeIndex"))&&$D($$$vaM("runtimePath")) ..buildRuntimeIndexFromPath()
	Set tLen=0 For i=1:1:$G($$$vaM("runtimeIndex")) { Set tSeg=..getSegmentByIndex(i)
		If 'tSeg.IsChildHolder(.tRef) { Set tLen=tLen+tSeg.FullSize+1 }
		Do ..commitSegmentByIndex(i)
	}
	Quit tLen
}

ClassMethod GetFullSize(pMsgId) As %Integer
{
	Set tLen=0 For i=1:1:$$$vaExtentGbl(pMsgId,"segs") {
		#; Add segment size: - 5 separators + 1 terminator
		Set segid=$$$vaExtentGbl(pMsgId,"segs",i), tLen = tLen + $S(segid[",":$L($$$vaSegment(segid)),1:$L($$$vaSegmentGbl(segid))) - 4
		#; Get extra from any segs > max seg length
		For j=1:1 { Set segid=$$$vaExtentGbl(pMsgId,"segs",i)  If segid["," { Quit:'$D($$$vaSegmentExt(segid,j),extra) } Else { Quit:'$D($$$vaSegmentGbl(segid,j),extra) }
			Set tLen = tLen + $L(extra)
		}
	}
	Quit tLen
}

Method GetLengthCRC(pLen As %String = 0, ByRef pCRC As %String = 0, pSeparators As %String, pSequenceNumber As %String, pMSHEncoding As %String, pLenLen As %Integer = 5, pCRCLen As %Integer = 3) As %String
{
	Set tLen=pLen
	Set tSeparators=$E($G(pSeparators,..Separators),1,5)
	Do:'$D($$$vaM("runtimeIndex"))&&$D($$$vaM("runtimePath")) ..buildRuntimeIndexFromPath()
	For i=1:1:$G($$$vaM("runtimeIndex")) { Set tSeg=..getSegmentByIndex(i)
		If 'tSeg.IsChildHolder(.tRef) { Set tString=tSeg.OutputToString(tSeparators,.pSequenceNumber,,.pMSHEncoding) Set pCRC=$ZCRC(tString,1,pCRC), tLen=tLen+$L(tString) }
		Else {
			Set tChild=$$$NULLOREF For { Set tChild=..NextChild(tChild,tRef)  Quit:tChild=$$$NULLOREF
				Set tLen=tChild.GetLengthCRC(tLen,.pCRC, tSeparators,.pSequenceNumber,.pMSHEncoding)
			}
		}
	}
	Set pCRC=$$$NUM(pCRC,pCRCLen), tLen=$$$NUM(tLen,pLenLen)
	Quit tLen
}

/// Gets the next index in an array
Method GetNextIndex(pPath As %String, pIndex As %String, ByRef pStatus As %Status = {$$$OK}) As %String
{
	Set f=$F(pPath,"()")  If 'f Set pStatus=$$$ERROR($$$EnsErrGeneral,"Can't iterate on SegmentPath '"_pPath_"'") Quit ""
	Set tSegmentPath=$P(pPath,":",1)
	If f-1>$L(tSegmentPath) { ; '()' was found in PropertyPath not SegmentPath
		Set tPropertyPath=$P(pPath,":",2)
		Set tSegObj=..GetSegmentAt(tSegmentPath,.pStatus) Quit:$$$ISERR(pStatus) ""
		Quit tSegObj.GetNextIndex(tPropertyPath,pIndex,.pStatus)
	} Else {
		Set tHead=$E(pPath,1,f-2), tLen=$L(tHead)
		Quit:"("=tHead $S(+pIndex<..SegCount:pIndex+1,1:"") ; iterate by index if path is just "()"
		Do:'$D($$$vaM("runtimePath")) ..BuildMap(0)
		If '$D($$$vaM("loopIndex",tHead)) {
			#; Build LoopIndex node
			Set path=tHead For { Set path=$O($$$vaM("runtimePath",path))  Quit:path=""
				Quit:$E(path,1,tLen)'=tHead
				Set $$$vaM("loopIndex",tHead,$E(path,tLen+1,$F(path,")",tLen)-2))=""
			}
			If '$D($$$vaM("loopIndex",tHead)) Set $$$vaM("loopIndex",tHead)=0
		}
		Quit $O($$$vaM("loopIndex",tHead,pIndex))
	}
}

/// Gets the next path in a group
Method GetNextGroupPath(pGroup As %String, pPath As %String, ByRef pStatus As %Status = {$$$OK}) As %String
{
	Quit:$$$vaIsIndex(pGroup) ""
	If pGroup[":"||($L(pPath)<$L(pGroup)) Set pStatus=$$$ERROR($$$EnsErrGeneral,"Can't iterate in Group '"_pGroup_"' on Path '"_pPath_"'") Quit ""
	Do:'$D($$$vaM("runtimePath")) ..BuildMap(0)
	Set nextpath=$O($$$vaM("runtimePath",pPath))
	Quit:$E(nextpath,1,$L(pGroup))'=pGroup||$Case($E(nextpath,$L(pGroup)+1),"(":0,".":0,:1) ""
	Quit nextpath
}

Method SetValueAt(pValue As %String, pSegmentPropertyPath As %String, pAction As %String = "set", pKey As %String = "") As %Status
{
	If pSegmentPropertyPath["()" {
		Set tSC=$$$OK
		Set tFind=$F(pSegmentPropertyPath,"()")
		Set tHead=$E(pSegmentPropertyPath,1,tFind-3), tTail=$E(pSegmentPropertyPath,tFind,*)
		Set k=$P(pKey,","), pKey=$P(pKey,",",2,$L(pKey,","))
		If k { Set tSC=..SetValueAt(.pValue,tHead_"("_(k)_")"_tTail,pAction,pKey) Quit:$$$ISERR(tSC) }
		Else {
			Set i="" For { Set i=..GetNextIndex(tHead_"()",i) Quit:i=""
				Set tNewPath=tHead_"("_(i)_")"_tTail
				Set tSC=..SetValueAt(.pValue,tNewPath,pAction,pKey) Quit:$$$ISERR(tSC)
			}
		}
		Quit tSC
	}
	Set tGrpPath=$P(pSegmentPropertyPath,":"), tPropPath=$P(pSegmentPropertyPath,":",2)
	Set tSegPath=..GetNextGroupPath(tGrpPath,tGrpPath)
	If ""'=tSegPath { ; if there are group sub-elements
		For {
			Set tNewPath=tSegPath_$S(""=tPropPath:"",1:":"_tPropPath)
			Set tSC=..SetValueAt(.pValue,tNewPath,pAction,pKey) Quit:$$$ISERR(tSC)
			Set tSegPath=..GetNextGroupPath(tGrpPath,tSegPath,.tSC) Quit:$$$ISERR(tSC)
			Quit:""=tSegPath
		}
		Quit tSC
	} Else {
		Quit:(pAction="remove")&&(""=tPropPath) ..RemoveSegmentAt(tGrpPath)
		Set tSegObj=..GetMutableSegmentAt(tGrpPath,.tSC)  Quit:$$$ISERR(tSC) tSC  $$$ASSERT($IsObject(tSegObj))
		Quit tSegObj.SetValueAt(.pValue,tPropPath,pAction,pKey)
	}
}

Method GetValueAt(pSegmentPropertyPath As %String, pSeparators As %String, Output pStatus As %Status, pTreatEmptyAsNull As %Boolean = 0) As %String
{
	Set pStatus=$$$OK, tSeparators=$G(pSeparators,..Separators)
	Set tSegmentPath=$P(pSegmentPropertyPath,":"), tPropertyPath=$P(pSegmentPropertyPath,":",2)
	If ""=tPropertyPath&&(tSegmentPath["*") {
		Quit:$Case(tSegmentPath,"*":1,"(*)":1,:0) ..SegCount
		Set tLen=$L(tSegmentPath)
		If $E(tSegmentPath,tLen-2,tLen)="(*)" {
			Do:'$D($$$vaM("runtimePath")) ..BuildMap(0)
			Set count=0, (path,path0)=$E(tSegmentPath,1,tLen-2), tLen0=$L(path0), i=0
			For { Set path=$O($$$vaM("runtimePath",path))  Quit:path=""||(path0'=$E(path,1,tLen0))
				Set ti=+$E(path,tLen0+1,*)  Set:ti'=i&&ti count=count+1,i=ti
			}
			Quit count
		}
		If $E(tSegmentPath,tLen-1,tLen)=".*" {
			Set count=0,(path,path0)=$E(tSegmentPath,1,tLen-2),tLen0=$L(path0)
			Do:'$D($$$vaM("runtimePath")) ..BuildMap(0)
			For { Set path=$O($$$vaM("runtimePath",path))  Quit:path=""||(path0'=$E(path,1,tLen0))  Set count=count+1 }
			Quit count
		}
		Quit $$$ERROR($$$EnsErrGeneral,"Invalid segment count value path '"_tSegmentPath_"'")
	}
	Set tSegObj=..GetSegmentAt(tSegmentPath,.pStatus)  Quit:'$IsObject(tSegObj) ""  $$$ASSERT($$$ISOK(pStatus))
	Quit tSegObj.GetValueAt(tPropertyPath,tSeparators,.pStatus,pTreatEmptyAsNull)
}

/// Given a segment index, find the corresponding segment path
Method GetSegmentPath(pIndex As %Integer, Output pStatus As %Status) As %String
{
	If '$D($$$vaM("bidirectionalLink")) {
		If '$D($$$vaM("runtimePath")) { Set pStatus=$$$ERROR($$$EnsErrGeneral,"Document is in index-only mode")  Quit "" }
		Else { Set pStatus=$$$ERROR($$$EnsErrGeneral,"Document is in path-only mode")  Quit "" }
	}
	Set pStatus=$$$OK
	Set tVal=$G($$$vaM("bidirectionalLink",+pIndex))
	Set:""=tVal pStatus=$$$ERROR($$$EnsErrGeneral,"Index "_pIndex_" is out of bounds")
	Quit tVal
}

/// Given a segment path, find the corresponding segment index
Method GetSegmentIndex(pPath As %String, Output pStatus As %Status) As %Integer
{
	If '$D($$$vaM("bidirectionalLink")) {
		If '$D($$$vaM("runtimePath")) { Set pStatus=$$$ERROR($$$EnsErrGeneral,"Document is in index-only mode")  Quit "" }
		Else { Set pStatus=$$$ERROR($$$EnsErrGeneral,"Document is in path-only mode")  Quit "" }
	}
	Set pStatus=$$$OK
	Set tVal=$G($$$vaM("bidirectionalLink",pPath))
	Set:""=tVal||(tVal'=+tVal) pStatus=$$$ERROR($$$EnsErrGeneral,"Path "_pPath_" not found")
	Quit tVal
}

/// Finds all values matching a SegName:PropertyPath string, where the SegName is a simple segment type name
///  (not a full schema-based seg path); PropertyPath describes a field or subfield within the segment.
/// Supports SegName = '*' to match any segment, and SegName(n) to match only the n'th segment of the given type.
Method FindSegmentValuesArray(pSegmentPropertyPath As %String, pSeparators As %String, ByRef pArray As %String, Output pStatus As %Status, pSchemaCategory As %String = "", ByRef pLongArray As %String)
{
	Set pStatus=$$$OK  Kill pArray
	Set tSegName=$P(pSegmentPropertyPath,":"), tPropPath=$P(pSegmentPropertyPath,":",2)
	Set tSegIndex=$P(tSegName,"(",2), tSegName=$P(tSegName,"("), tSegIndex=$ZStrip($P(tSegIndex,")"),"<>W","*")
	Do:$ZStrip(tPropPath,"*A")'=tPropPath&&(""'=..DocType)&&(""=..BuildMapStatus) ..BuildMap(0) ; get seg types if available
	Set tIndex="" For i=1:1 { Set tSegObj=..FindSegment(tSegName,.tIndex,.pStatus)  Quit:""=tIndex
		Continue:(""'=tSegIndex)&&(i'=tSegIndex) ; if they asked for a specific number, forsake all others
		Do tSegObj.FindValuesArray(tPropPath,.pSeparators,.pArray,.pSchemaCategory,.pStatus,.pLongArray)  Quit:$$$ISERR(pStatus)
		Quit:i=tSegIndex ;all done
	}
}

/// Finds all values matching a SegName:PropertyPath string, where the SegName is a simple segment type name
///  (not a full schema-based seg path); PropertyPath describes a field or subfield within the segment. <br>
/// Supports SegName = '*' to match any segment, and SegName(n) to match only the n'th segment of the given type. <br>
/// Final parameter is an output of the list of segment indexes (separated by pValSepString) for the values found.
Method FindSegmentValues(pSegmentPropertyPath As %String, pSeparators As %String, pValSepString As %String = "<>", Output pStatus As %Status, pSchemaCategory As %String = "", Output pIndices As %String) As %String
{
	Set pStatus=$$$OK, pIndices = ""
	Set tSegName=$P(pSegmentPropertyPath,":"), tPropPath=$P(pSegmentPropertyPath,":",2)
	Set tSegIndex=$P(tSegName,"(",2), tSegName=$P(tSegName,"("), tSegIndex=$ZStrip($P(tSegIndex,")"),"<>W","*")
	Do:$ZStrip(tPropPath,"*A")'=tPropPath&&(""'=..DocType)&&(""=..BuildMapStatus) ..BuildMap(0) ; get seg types if available
	Set (tVals,tIndex)="" For i=1:1 { Set tSegObj=..FindSegment(tSegName,.tIndex,.pStatus)  Quit:""=tIndex
		Continue:(""'=tSegIndex)&&(i'=tSegIndex) ; if they asked for a specific number, forsake all others
		Set tVal=tSegObj.FindValues(tPropPath,.pSeparators,pValSepString,.pSchemaCategory,.pStatus)  Quit:$$$ISERR(pStatus)
		If (""'=tVal) {
			Set tVals=$S(""=tVals:"",1:tVals_pValSepString)_tVal
			For tR=1:1:$L(tVal,pValSepString) Set pIndices = $S(""=pIndices:"",1:pIndices_pValSepString)_tIndex
		}
		Quit:i=tSegIndex ;all done
	}
	Quit tVals
}

/// Gets the next segment after index <var>pIndex</var> with name <var>pSegName</var>.
/// Supports <var>pSegName</var> = '*' to match any segment.
Method FindSegment(pSegName As %String, ByRef pIndex As %String = "", Output pStatus As %Status) As EnsLib.HL7.Segment
{
	Set pStatus=$$$OK, tId=..%Id()  Set:'tId tId=..%ClonedId
	Do:'$D($$$vaM("runtimeIndex")) ..buildRuntimeIndexFromPath()
	Set seg=""  For index=+pIndex+1:1:$$$vaM("runtimeIndex") { Set seg=$$$vaSegLookthru(index,tId)  Continue:""=seg
		If $$$vaIsOref(seg) {
			Set tSegObj=..%maps("orefs",index)
			If (pSegName="*")||(tSegObj.Name=pSegName) Set pIndex=index  Quit
		} Else {
			Set segid=$P(seg,"|"), data=$G($$$vaSegment(segid))
			If (pSegName="*")||(pSegName=$$$vaDataSegName(data)) {
				#; Same code as in getSegmentByIndex
				Set pIndex=index
				Set tSegObj=##class(EnsLib.HL7.Segment).%New($LB(segid,(..IsMutable&&(tId=..%ClonedId)),$P(seg,"|",2)))
				Set ..%maps("orefs",pIndex)=tSegObj
				Set $$$vaM("runtimeIndex",pIndex)="@"
				Set path=$G($$$vaM("bidirectionalLink",pIndex)) Set:""'=path $$$vaM("runtimePath",path)="@"_pIndex
				Quit
			}
		}
	}
	If +pIndex<index Set pIndex=""  Quit $$$NULLOREF
	Quit tSegObj
}

Method getSegmentByIndex(pIndex As %Integer, Output pStatus As %Status) As EnsLib.HL7.Segment [ Internal ]
{
	Do:'$D($$$vaM("runtimeIndex")) ..buildRuntimeIndexFromPath()
	Set pStatus=$$$OK, tId=..%Id()  Set:'tId tId=..%ClonedId
	Set seg=$$$vaSegLookthru(pIndex,tId)
	If seg="" Set pStatus=$$$ERROR($$$EnsErrGeneral,"Segment Index "_pIndex_" is out of bounds") Quit $$$NULLOREF
	Quit:$$$vaIsOref(seg) ..%maps("orefs",pIndex)
	Set tSegObj=##class(EnsLib.HL7.Segment).%New($LB($P(seg,"|"),(..IsMutable&&..CacheSegsGotten&&(tId=..%ClonedId)),$P(seg,"|",2)))
	If ..CacheSegsGotten {
		Set ..%maps("orefs",pIndex)=tSegObj
		Set $$$vaM("runtimeIndex",pIndex)="@"
		Set path=$G($$$vaM("bidirectionalLink",pIndex)) Set:""'=path $$$vaM("runtimePath",path)="@"_pIndex
	}
	Quit tSegObj
}

Method getSegmentByPath(pPath As %String, Output pStatus As %Status) As EnsLib.HL7.Segment [ Internal ]
{
	Set pStatus=$$$OK
	Do:'$D($$$vaM("runtimePath")) ..BuildMap(0)
	Set seg=$G($$$vaM("runtimePath",pPath))
	If seg="" Set pStatus=$$$ERROR($$$EnsErrGeneral,"No segment found at path '"_pPath_"'") Quit $$$NULLOREF
	Quit:$$$vaIsOref(seg) ..%maps("orefs",$E(seg,2,*))
	Set tSegObj=##class(EnsLib.HL7.Segment).%New($LB($P(seg,"|"),(..IsMutable&&..CacheSegsGotten&&'..%Id()&&..%ClonedId),$P(seg,"|",2)))
	If ..CacheSegsGotten {
		Set index=$G($$$vaM("bidirectionalLink",pPath))
		If index { Set seg="@"_index, $$$vaM("runtimeIndex",index)="@" }
		Else { Set index=$O(..%maps("orefs",""))-1, seg="@"_index}
		Set ..%maps("orefs",index)=tSegObj
		Set $$$vaM("runtimePath",pPath)=seg
	}
	Quit tSegObj
}

Method getSegmentIdByIndex(pIndex As %Integer, Output pStatus As %Status) As %String
{
	Set pStatus=$$$OK, tId=..%Id()  Set:'tId tId=..%ClonedId
	Do:'$D($$$vaM("runtimeIndex")) ..buildRuntimeIndexFromPath()
	Set seg=$$$vaSegLookthru(pIndex,tId)
	If seg="" Set pStatus=$$$ERROR($$$EnsErrGeneral,"Index "_pIndex_" is out of bounds") Quit ""
	Quit:'$$$vaIsOref(seg) $P(seg,"|")
	Quit ..%maps("orefs",pIndex).ID
}

Method getSegmentIdByPath(pPath As %String, Output pStatus As %Status) As %String
{
	Set pStatus=$$$OK
	Do:'$D($$$vaM("runtimePath")) ..BuildMap(0)
	Set seg=$G($$$vaM("runtimePath",pPath))
	Quit:'$$$vaIsOref(seg) $P(seg,"|")
	Quit ..%maps("orefs",$E(seg,2,*)).ID
}

Method getMutableSegmentByIndex(pIndex As %Integer, Output pStatus As %Status) As EnsLib.HL7.Segment [ Internal ]
{
	Do:'$D($$$vaM("runtimeIndex")) ..buildRuntimeIndexFromPath()
	Set pStatus=$$$OK, i%BuildMapStatus="", tId=..%Id()  Set:'tId tId=..%ClonedId
	Set seg=$$$vaSegLookthru(pIndex,tId)
	If seg="" Set pStatus=$$$ERROR($$$EnsErrGeneral,"Index "_pIndex_" is out of bounds")  Quit $$$NULLOREF
	If $$$vaIsOref(seg) {
		Set tSegObj=..%maps("orefs",pIndex)
		If tSegObj.IsMutable Set tSegObj.Separators=..Separators  Quit tSegObj
		Kill ..%maps("orefs",pIndex)
		Set seg=tSegObj.ID_"|"_tSegObj.DocType
	}
	;Set tSegObj=..NewSegment(pPath)
	Set tSegObj=##class(EnsLib.HL7.Segment).%New($LB($P(seg,"|"),1,$P(seg,"|",2)))
	If '$IsObject(tSegObj)  Set pStatus=%objlasterror  Quit $$$NULLOREF
	Set tSegObj.Separators=..Separators
	Set ..%maps("orefs",pIndex)=tSegObj
	Set $$$vaM("runtimeIndex",pIndex)="@"
	Set path=$G($$$vaM("bidirectionalLink",pIndex)) Set:""'=path $$$vaM("runtimePath",path)="@"_pIndex
	Quit tSegObj
}

Method getMutableSegmentByPath(pPath As %String, Output pStatus As %Status) As EnsLib.HL7.Segment [ Internal ]
{
	If (..DocTypeCategory="")||(..DocTypeName="") Set pStatus=$$$ERROR($$$EnsErrGeneral,"Cannot recognize path before DocType is set")  Quit $$$NULLOREF
	Do:'$D($$$vaM("runtimePath")) ..BuildMap(0)
	Set pStatus=$$$OK, i%BuildMapStatus=""
	Set seg=$G($$$vaM("runtimePath",pPath))
	If $$$vaIsOref(seg) {
		Set index=$E(seg,2,*)
		Set tSegObj=..%maps("orefs",index)
		If tSegObj.IsMutable Set tSegObj.Separators=..Separators  Quit tSegObj
		Kill ..%maps("orefs",index)
		Set seg=$S(""=tSegObj.ID:"", 1:tSegObj.ID_$S(""=tSegObj.DocType:"", 1:"|"_tSegObj.DocType))
	}
	If ""=seg {
		;Set tSegObj=..NewSegment(pPath)
		Set schema=$G($$$vaSchemaGbl(..DocTypeCategory,"MS",..DocTypeName,"map",..convertRuntimePathToSchemaPath(pPath)))
		If schema="" Set pStatus=$$$ERROR($$$EnsErrGeneral,"Path '"_pPath_"' is not mapped in schema for DocType '"_..DocType_"'")  Quit $$$NULLOREF
		Set tSegType=$P(schema,"|",2), tSegName=$P(tSegType,":",2)
		If $ZCVT(tSegName,"U")'=tSegName Set pStatus=$$$ERROR($$$EnsErrGeneral,"Cannot instantiate abstract segment type "_tSegType)  Quit $$$NULLOREF
		Set tSegObj=##class(EnsLib.HL7.Segment).%New($LB("",1,tSegType,$E(..Separators,1,5)_tSegName))
		If '$IsObject(tSegObj) Set pStatus=%objlasterror  Quit $$$NULLOREF
		#;Do tSegObj.SetValueAt(tSegName,0)
		Kill $$$vaM("runtimeIndex"), $$$vaM("bidirectionalLink") ; we are operating only by PathMap now.
		Set index=$O(..%maps("orefs",""))-1, seg="@"_index
	} Else {
		Set tSegObj=##class(EnsLib.HL7.Segment).%New($LB($P(seg,"|"),1,$P(seg,"|",2)))
		If '$IsObject(tSegObj) Set pStatus=%objlasterror  Quit $$$NULLOREF
		Set index=$G($$$vaM("bidirectionalLink",pPath))
		If index { Set seg="@"_index, $$$vaM("runtimeIndex",index)="@" }
		Else { Set index=$O(..%maps("orefs",""))-1, seg="@"_index }
	}
	Set tSegObj.Separators=..Separators
	Set ..%maps("orefs",index)=tSegObj
	Set $$$vaM("runtimePath",pPath)=seg
	If ..AutoBuildMap { Do ..BuildMap(0) }
	Else {
		Set i%BuildMapStatus=""
		#; Add relevant loopIndex node(s) if any
		Set pcs=$L(pPath,"(")-1, tHead=$P(pPath,"(",1,pcs)_"("
		For { Set tHead=$O($$$vaM("loopIndex",tHead_")"),-1), tLen=$L(tHead)  Quit:""=tHead
			If tHead=$E(pPath,1,tLen) { Set $$$vaM("loopIndex",tHead,$E(pPath,tLen+1,$F(pPath,")",tLen)-2))="", pcs=pcs-1, tHead=$P(pPath,"(",1,pcs)_"(" }
			Else {
				Set tPart="" For pcs=1:1 { Set tPrevPart=tPart, tPart=$P(pPath,"(",1,pcs)_"(", tLen=$L(tPart)
					If tPart'=$E(tHead,1,tLen) { Set tHead=tPrevPart  Quit }
				}
			}
			Quit:""=tHead||'pcs
		}
	}
	Quit tSegObj
}

Method setSegmentByIndex(pSegObj As EnsLib.HL7.Segment, pIndex As %Integer, pInsert As %Boolean) As %Status [ Internal ]
{
	Quit:'..IsMutable $$$ERROR($$$EnsErrGeneral,"Object is immutable")
	Quit:'$$$IsdefObject(pSegObj) $$$ERROR($$$EnsErrGeneral,"Cannot set null segment object at index "_pIndex)
	Do:'$D($$$vaM("runtimeIndex")) ..buildRuntimeIndexFromPath()
	Quit:(pIndex\1'=pIndex)||(pIndex<1)||(pIndex>($$$vaM("runtimeIndex")+1)) $$$ERROR($$$EnsErrGeneral,"Index "_pIndex_" is out of bounds")

	If pInsert {
		Set tId=..%Id()  Set:'tId tId=..%ClonedId  For i=$$$vaM("runtimeIndex"):-1:pIndex { ; slide up all segments to make room for inserted one
			Set $$$vaM("runtimeIndex",i+1)=$$$vaSegLookthru(i,tId)
			If $D(..%maps("orefs",i)) Set ..%maps("orefs",i+1)=..%maps("orefs",i)  Kill ..%maps("orefs",i)
		}
		Set path=""
	} Else {
		Set path=$G($$$vaM("bidirectionalLink",pIndex))  Set:""'=path $$$vaM("runtimePath",path)="@"_pIndex
	}
	If pInsert||(pIndex=($$$vaM("runtimeIndex")+1)) Set $$$vaM("runtimeIndex")=$$$vaM("runtimeIndex")+1

	Set $$$vaM("runtimeIndex",pIndex)="@"
	Set pSegObj.DocType="" ; setting by index, the SegType might not match its new position
	Set ..%maps("orefs",pIndex)=pSegObj

	Kill:""=path $$$vaM("runtimePath"), $$$vaM("bidirectionalLink"), $$$vaM("loopIndex") ; we are operating only by IndexMap now.
	If ..AutoBuildMap { Do ..BuildMap(0) } Else { Set i%BuildMapStatus="" }
	Quit $$$OK
}

Method setSegmentByPath(pSegObj As EnsLib.HL7.Segment, pPath As %String) As %Status [ Internal ]
{
	Quit:'..IsMutable $$$ERROR($$$EnsErrGeneral,"Object is immutable")
	Quit:(..DocTypeCategory="")||(""=..DocTypeName) $$$ERROR($$$EnsErrGeneral,"Cannot recognize path before DocType is set")
	Quit:'$$$IsdefObject(pSegObj) $$$ERROR($$$EnsErrGeneral,"Cannot set null segment object at position "_pPath)
	Do:'$D($$$vaM("runtimePath")) ..BuildMap(0)

	Set schema=$G($$$vaSchemaGbl(..DocTypeCategory,"MS",..DocTypeName,"map",..convertRuntimePathToSchemaPath(pPath)))
	Quit:""=schema $$$ERROR($$$EnsErrGeneral,"Path '"_pPath_"' is not mapped in schema for DocType '"_..DocType_"'")
	Set tSegType=$P(schema,"|",2), tSegName=$P(tSegType,":",2)
	Quit:'$Case(tSegName, pSegObj.Name:1, "Zxx":("Z"=$E(pSegObj.Name)), "Hxx":("H"=$E(pSegObj.Name)), "Any":1, :0) $$$ERROR($$$EnsErrGeneral,"Cannot set segment named '"_pSegObj.Name_"' for type '"_tSegName_"' at position "_pPath)
	Set pSegObj.DocType=tSegType ; setting by path, Set the SegType to match its new position

	Set index=$G($$$vaM("bidirectionalLink",pPath))
	If index { Set seg="@"_index, $$$vaM("runtimeIndex",index)="@" }
	Else {
		Set seg=$G($$$vaM("runtimePath",pPath))
		If $$$vaIsOref(seg) { Set index=$E(seg,2,*) }
		Else {
			Set index=$O(..%maps("orefs",""))-1, seg="@"_index
			Kill $$$vaM("runtimeIndex"), $$$vaM("bidirectionalLink") ; we are operating only by PathMap now.
		}
	}
	Set ..%maps("orefs",index)=pSegObj
	Set $$$vaM("runtimePath",pPath)=seg
	If ..AutoBuildMap { Do ..BuildMap(0) }
	Else {
		Set i%BuildMapStatus=""
		#; Add relevant loopIndex node(s) if any
		Set pcs=$L(pPath,"(")-1, tHead=$P(pPath,"(",1,pcs)_"("
		For { Set tHead=$O($$$vaM("loopIndex",tHead_")"),-1), tLen=$L(tHead)  Quit:""=tHead
			If tHead=$E(pPath,1,tLen) { Set $$$vaM("loopIndex",tHead,$E(pPath,tLen+1,$F(pPath,")",tLen)-2))="", pcs=pcs-1, tHead=$P(pPath,"(",1,pcs)_"(" }
			Else {
				Set tPart="" For pcs=1:1 { Set tPrevPart=tPart, tPart=$P(pPath,"(",1,pcs)_"(", tLen=$L(tPart)
					If tPart'=$E(tHead,1,tLen) { Set tHead=tPrevPart  Quit }
				}
			}
			Quit:""=tHead||'pcs
		}
	}
	Quit $$$OK
}

Method setSegmentIdByIndex(pSegId As %String, pIndex As %Integer, pInsert As %Boolean) As %Status [ Internal ]
{
	Quit:'..IsMutable $$$ERROR($$$EnsErrGeneral,"Object is immutable")
	Do:'$D($$$vaM("runtimeIndex")) ..buildRuntimeIndexFromPath()
	Quit:(pIndex\1'=pIndex)||(pIndex<1)||(pIndex>($$$vaM("runtimeIndex")+1)) $$$ERROR($$$EnsErrGeneral,"Index "_pIndex_" is out of bounds")

	If pInsert {
		Set tId=..%Id()  Set:'tId tId=..%ClonedId  For i=$$$vaM("runtimeIndex"):-1:pIndex { ; slide up all segments to make room for inserted one
			Set $$$vaM("runtimeIndex",i+1)=$$$vaSegLookthru(i,tId)
			If $D(..%maps("orefs",i)) Set ..%maps("orefs",i+1)=..%maps("orefs",i)  Kill ..%maps("orefs",i)
		}
		Set path=""
	} Else {
		Set path=$G($$$vaM("bidirectionalLink",pIndex))  Set:""'=path $$$vaM("runtimePath",path)="@"_pIndex
	}
	If pInsert||(pIndex=($$$vaM("runtimeIndex")+1)) Set $$$vaM("runtimeIndex")=$$$vaM("runtimeIndex")+1

	Set $$$vaM("runtimeIndex",pIndex)=pSegId

	Kill:""=path $$$vaM("runtimePath"), $$$vaM("bidirectionalLink"), $$$vaM("loopIndex") ; we are operating only by IndexMap now.
	If ..AutoBuildMap { Do ..BuildMap(0) } Else { Set i%BuildMapStatus="" }
	Quit $$$OK
}

Method setSegmentIdByPath(pSegId As %String, pPath As %String) As %Status [ Internal ]
{
	Quit:'..IsMutable $$$ERROR($$$EnsErrGeneral,"Object is immutable")
	Quit:(..DocTypeCategory="")||(..DocTypeName="") $$$ERROR($$$EnsErrGeneral,"Cannot recognize path unless DocType is set")
	Do:'$D($$$vaM("runtimePath")) ..BuildMap(0)

	Set schema=$G($$$vaSchemaGbl(..DocTypeCategory,"MS",..DocTypeName,"map",..convertRuntimePathToSchemaPath(pPath)))
	Quit:""=schema $$$ERROR($$$EnsErrGeneral,"Path '"_pPath_"' is not mapped in schema for DocType '"_..DocType_"'")
	Set newseg=pSegId_"|"_$P(schema,"|",2)

	Set index=$G($$$vaM("bidirectionalLink",pPath))
	If index { Kill ..%maps("orefs",index)  Set $$$vaM("runtimeIndex",index)=newseg }
	Else {
		Set seg=$G($$$vaM("runtimePath",pPath))
		If $$$vaIsOref(seg) { Kill ..%maps("orefs",$E(seg,2,*)) }
		Else {
			Kill $$$vaM("runtimeIndex"), $$$vaM("bidirectionalLink") ; we are operating only by PathMap now.
		}
	}
	Set $$$vaM("runtimePath",pPath)=newseg
	If ..AutoBuildMap { Do ..BuildMap(0) } Else { Set i%BuildMapStatus="" }
	Quit $$$OK
}

Method removeSegmentByIndex(pIndex As %Integer) As %Status [ Internal ]
{
	Quit:'..IsMutable $$$ERROR($$$EnsErrGeneral,"Object is immutable")
	Do:'$D($$$vaM("runtimeIndex")) ..buildRuntimeIndexFromPath()
	Set tId=..%Id()  Set:'tId tId=..%ClonedId
	Set seg=$$$vaSegLookthru(pIndex,tId)
	Quit:""=seg $$$ERROR($$$EnsErrGeneral,"Index "_pIndex_" is out of bounds")

	For i=pIndex:1:$$$vaM("runtimeIndex")-1 { ; slide all segments down over removed one
		Set $$$vaM("runtimeIndex",i)=$$$vaSegLookthru(i+1,tId)
		If $D(..%maps("orefs",i+1)) Set ..%maps("orefs",i)=..%maps("orefs",i+1)  Kill ..%maps("orefs",i+1)
	}
	Kill $$$vaM("runtimeIndex",$$$vaM("runtimeIndex")), ..%maps("orefs",$$$vaM("runtimeIndex"))
	Set $$$vaM("runtimeIndex")=$$$vaM("runtimeIndex")-1

	Kill $$$vaM("runtimePath"), $$$vaM("bidirectionalLink"), $$$vaM("loopIndex") ; we are operating only by IndexMap now.
	If ..AutoBuildMap { Do ..BuildMap(0) } Else { Set i%BuildMapStatus="" }
	Quit $$$OK
}

Method removeSegmentByPath(pPath As %String) As %Status [ Internal ]
{
	Quit:'..IsMutable $$$ERROR($$$EnsErrGeneral,"Object is immutable")
	Quit:(..DocTypeCategory="")||(..DocTypeName="") $$$ERROR($$$EnsErrGeneral,"Cannot recognize path before DocType is set")
	Do:'$D($$$vaM("runtimePath")) ..BuildMap(0)

	Set seg=$G($$$vaM("runtimePath",pPath))  If seg="" Quit $$$ERROR($$$EnsErrGeneral,"No segment found at path '"_pPath_"'")
	If $$$vaIsOref(seg) { Kill ..%maps("orefs",$E(seg,2,*)) }
	Kill $$$vaM("runtimePath",pPath)

	Kill $$$vaM("runtimeIndex"), $$$vaM("bidirectionalLink") ; we are operating only by PathMap now.
	If ..AutoBuildMap { Do ..BuildMap(0) }
	Else {
		Set i%BuildMapStatus=""
		If pPath["(" {
			#; Invalidate relevant loopIndex sub-arrays if any
			Set tPathHead=$P(pPath,"(",$L(pPath,"(")-1)
			Set tHead=tPathHead For { Set tHead=$O($$$vaM("loopIndex",tHead))  Quit:tPathHead_"("'=$E(tHead,1,$L(tPathHead)+1)
				Kill $$$vaM("loopIndex",tHead)
			}
		}
	}
	Quit $$$OK
}

/// collapse segment object into just ID; Save if necessary
Method commitSegmentByIndex(pIndex As %Integer) As %Status
{
	Do:'$D($$$vaM("runtimeIndex")) ..buildRuntimeIndexFromPath()
	Quit:(pIndex<1)||(pIndex>$$$vaM("runtimeIndex")) $$$ERROR($$$EnsErrGeneral,"Index "_pIndex_" is out of bounds")
	Set seg=$G($$$vaM("runtimeIndex",pIndex))
	Quit:'$$$vaIsOref(seg) $$$OK
	Set tSegObj=..%maps("orefs",pIndex)
	If tSegObj.IsMutable Set tSC=tSegObj.SaveData(..Separators) Quit:$$$ISERR(tSC) tSC
	Set newseg=tSegObj.ID_$S(""=tSegObj.DocType:"", 1:"|"_tSegObj.DocType)
	Set $$$vaM("runtimeIndex",pIndex)=newseg
	Set path=$G($$$vaM("bidirectionalLink",pIndex)) Set:""'=path $$$vaM("runtimePath",path)=newseg
	Kill ..%maps("orefs",pIndex)
	Quit $$$OK
}

/// collapse segment object into just Id; Save if necessary
Method commitSegmentByPath(pPath As %String) As %Status
{
	Do:'$D($$$vaM("runtimePath")) ..BuildMap(0)
	Set seg=$G($$$vaM("runtimePath",pPath))
	If seg="" Quit $$$ERROR($$$EnsErrGeneral,"No segment found at path '"_pPath_"'")
	If '$$$vaIsOref(seg) Quit $$$OK
	Set index=$E(seg,2,*)
	Set tSegObj=..%maps("orefs",index)
	If tSegObj.IsMutable Set tSC=tSegObj.SaveData(..Separators) Quit:$$$ISERR(tSC) tSC
	Set newseg=tSegObj.ID_$S(""=tSegObj.DocType:"", 1:"|"_tSegObj.DocType)
	Set $$$vaM("runtimePath",pPath)=newseg
	Kill ..%maps("orefs",index)
	Set index=$G($$$vaM("bidirectionalLink",pPath)) Set:""'=index $$$vaM("runtimeIndex",index)=newseg
	Quit $$$OK
}

/// collapse segment objects within the collectionPath into just Id; Save if necessary
Method commitCollectionOpenSegments(pCollectionPath As %String) As %Status
{
	If $Get(pCollectionPath)="" Return $$$OK
	#dim tCollectionPath = pCollectionPath_"."
	#dim seg
	#dim lengthCollectionPath = $Length(tCollectionPath)
	#dim tPath = $Order($$$vaM("runtimePath",tCollectionPath),1,seg)
	While ((tPath'="")&&($E(tPath,1,lengthCollectionPath)=tCollectionPath)) {
		#;Path will exist so no need to get return
		If $$$vaIsOref(seg) Do ..commitSegmentByPath(tPath)
		Set tPath = $Order($$$vaM("runtimePath",tPath),1,seg)
	}
	#; Return status so that can be called from DTL set
	Return $$$OK
}

Method convertRuntimePathToSchemaPath(pPath As %String) As %String
{
	Set tOutput=pPath
	Set f=0 For {
		Set f=$F(tOutput,"(",f) Quit:f=0
		Set g=$F(tOutput,")",f) If g=0 Set tOutput="" quit
		Set tOutput=$E(tOutput,1,f-1)_$E(tOutput,g-1,*)
		Set f=g
	}
	Quit tOutput
}

/// Given a runtime path, this method generates the key used for collation
Method getOrderKeyFromRuntimePath(pRuntimePath As %String) As %String [ Internal ]
{
	Set tSchemaPath=pRuntimePath, tRuntimeIndex=0
	Set f=0 For {
		Set f=$F(tSchemaPath,"(",f) Quit:f=0
		Set g=$F(tSchemaPath,")",f) If g=0 Set tSchemaPath="" Quit
		Set tRuntimeIndex($I(tRuntimeIndex))=$E(tSchemaPath,f,g-2)
		Set tSchemaPath=$E(tSchemaPath,1,f-1)_$E(tSchemaPath,g-1,*)
		Set f=g
	}
	Quit:""=tSchemaPath ""
	Set tMapValue=$G($$$vaSchemaGbl(..DocTypeCategory,"MS",..DocTypeName,"map",tSchemaPath))  Quit:""=tMapValue ""
	Set tKey=$P(tMapValue,"|")
	Set f=1 For i=1:1:tRuntimeIndex {
		Set f=$F(tKey,"*",f)  Quit:'f
		Set $E(tKey,f-1)=$$$NUM(tRuntimeIndex(i),8)
	}
	#; If couldn't find a replacement position or there are remaining unfilled replacement positions then key is invalid
	Quit:tKey["*"||'f ""
	Quit tKey
}

Method buildRuntimeIndexFromPath(pClearSegTypes As %Boolean = 0) As %Status [ Internal ]
{
	$$$ASSERT('$D($$$vaM("runtimeIndex"))&&'$D($$$vaM("bidirectionalLink")))
	Set tPath="" For { Set tPath=$O($$$vaM("runtimePath",tPath))  Quit:""=tPath
		Set tOrderKey=..getOrderKeyFromRuntimePath(tPath)  Continue:""=tOrderKey
		Set $$$vaM("OrderKeyToRuntimePath",tOrderKey)=tPath
	}
	#; Re-Order mapOrefs according to new index sequence.
	Set key="",index=0 For { Set key=$O($$$vaM("OrderKeyToRuntimePath",key),1,tPath)  Quit:key=""
		Set seg=$$$vaM("runtimePath",tPath)
		Set index=index+1
		If $$$vaIsOref(seg) {
			Set oldindex=$E(seg,2,*)
			Set tSegObj=..%maps("orefs",oldindex)
			Set:pClearSegTypes tSegObj.DocType=""
			If oldindex'=index {
				Set $$$vaM("runtimePath",tPath)="@"_index  Kill ..%maps("orefs",oldindex)
				#; Migrate ..mapOrefs if needed rather than doing it in place, because re-ordering in Path mode may have occurred after runtimeIndex map was killed
				If $D(..%maps("orefs",index)) { Set tMapOrefs(index)=tSegObj } Else { Set ..%maps("orefs",index)=tSegObj }
			}
			Set $$$vaM("runtimeIndex",index)="@"
		} Else {
			Set:pClearSegTypes seg=$P(seg,"|")
			Set $$$vaM("runtimeIndex",index)=seg
		}
		Set $$$vaM("bidirectionalLink",index)=tPath, $$$vaM("bidirectionalLink",tPath)=index
	}
	Kill $$$vaM("OrderKeyToRuntimePath")
	Merge ..%maps("orefs")=tMapOrefs
	Set $$$vaM("runtimeIndex")=index, $$$vaM("runtimeIndex",0)="" ; set a marker for negative path indices
	Quit $$$OK
}

Method %OnConstructClone(object As %RegisteredObject, deep As %Boolean = 0, ByRef cloned As %String) As %Status [ Private, ProcedureBlock = 1 ]
{
	$$$vaMgetIndex

#ifndef LOCALMAPS
	#; copy runtime maps from old instance
	Merge $$$vaM("runtimePath")=$$$vaMobj(object,"runtimePath")
	Merge $$$vaM("bidirectionalLink")=$$$vaMobj(object,"bidirectionalLink")
	Set tId=object.%Id()  Merge:tId $$$vaM("runtimeIndex")=$$$vaExtentGbl(tId,"segs") ; no lookthru to other guy's Id
	Merge $$$vaM("runtimeIndex")=$$$vaMobj(object,"runtimeIndex")
#endif	
	#; Clone segment objects so the clone can continue to use them without changing the original's data or properties
	Set index="" For { Set index=$O(object.%maps("orefs",index),1,tSegObj)  Quit:""=index
		Set ..%maps("orefs",index)=tSegObj.%ConstructClone()
	}
	Set i%IsMutable=1, ..ParentId="" ; mark it mutable, don't keep parent relationships
	Set i%%ClonedId=object.%ClonedId  Set:'..%ClonedId i%%ClonedId=object.%Id()  Set:'..%ClonedId i%%ClonedId=0
	Quit $$$OK
}

/// create an object based on id=initvalue but editable
Method %OnNew(initvalue As %RawString = "") As %Status [ Private ]
{
	Set tSegmentIds=$LG(initvalue,1), ..Separators=$LG(initvalue,2), i%Source=$LG(initvalue,3), i%ParentId=$LG(initvalue,4)
	Set:""=..Separators ..Separators=$$$HL7DefSeparators
	$$$vaMgetIndex
	If tSegmentIds'="" {
		Set $$$vaM("runtimeIndex")=$LL(tSegmentIds), $$$vaM("runtimeIndex",0)="" ; set a marker for negative path indices
		For i=1:1:$$$vaM("runtimeIndex") { Set $$$vaM("runtimeIndex",i)=$LI(tSegmentIds,i) }
	} Else { ; Automatically construct an MSH because every message should have one
		Set msh=##class(EnsLib.HL7.Segment).%New()
		Set msh.Separators=..Separators
		Do msh.SetValueAt("MSH",0)
		Set $$$vaM("runtimeIndex")=1, $$$vaM("runtimeIndex",1)="@"
		Set ..%maps("orefs",1)=msh
	}
	Quit $$$OK
}

Method %OnOpen() As %Status [ Private ]
{
	Set tId=..%Id()
	$$$vaMgetIndex
	Set oldSegIdList=..IsMutable
	If $E(oldSegIdList)'=oldSegIdList {
		#; open object from old 3.0 storage format
		Set ..IsMutable=0, ..ParentId="", ..Envelope=..Source, ..Source="old storage"
		Set cnt=$LL(oldSegIdList), $$$vaM("runtimeIndex")=cnt, $$$vaM("runtimeIndex",0)=""
		For i=1:1:cnt Set $$$vaM("runtimeIndex",i)=$LG(oldSegIdList,i,0)
		If cnt { Set tSegid=$$$vaM("runtimeIndex",1), ..Separators=$E($$$vaSegment(tSegid),1,5) } Else { Set ..Separators=$$$HL7DefSeparators }
	} Else {
		Set:+..ParentId'=$P(..ParentId,":") ..ParentId=$LG(..ParentId) ; change from 4.0 %parentIds format
		Set cnt=$G($$$vaExtentGbl(tId,"segs")), $$$vaM("runtimeIndex")=cnt, $$$vaM("runtimeIndex",0)="" ; set a marker for negative path indices
		If 'cnt { Set ..Separators=$$$HL7DefSeparators }
		Else {
			If $S($D($$$EnsConfig("HL7Segs-Compat")):$$$EnsConfig("HL7Segs-Compat"),1:$G(^Ens.Config("HL7Segs-Compat"),1)) {
				#; convert segments from old 2008.1 storage if needed
				Lock +$$$vaExtentGbl(tId):2
				If $Test {
					Set tJK=$$$JobKey
					Set:'$D(%topSegIndex) %topSegIndex=$G($$$vaSegmentGbl(tJK)), tNoTop=1
					For iSeg=1:1:cnt {	Set oldsegid=$G($$$vaExtentGbl(tId,"segs",iSeg))
						If oldsegid&&(oldsegid'[",") {
							#; found a segment to convert
							Lock +$$$vaSegment(oldsegid):2
							If $Test {
								TStart
								TRY {
									If $D(convertedSegs(oldsegid), convsegid) {
										#; segments processed on this run
										Set $$$vaExtentGbl(tId,"segs",iSeg)=convsegid
									}
									ElseIf $D($$$vaSegmentGbl(oldsegid),data) && (+data'=data) {
										#; seg has data, still in old form
										If $D($$$vaSegmentGbl(tJK),jkdata) && (+jkdata'=jkdata) {
											#; destination key already has old data - got to move it
											Merge dtree=$$$vaSegmentGbl(tJK)  Kill $$$vaSegmentGbl(tJK)  Set $$$vaSegmentGbl(tJK)=1
											Set segid=tJK_",1"  Merge $$$vaSegment(segid)=dtree  Kill dtree
											#; Update references from any other messages to this segment
											Set id="",did=0  For { Set id=$O($$$vaSegmentRef(segid,id)) Quit:""=id  Continue:id=tId
												Set xsegid="" For s=$G($$$vaExtentGbl(id,"segs"),0):-1:1 {
													Set xsegid=$G($$$vaExtentGbl(id,"segs",s))
													Set:xsegid=tJK $$$vaExtentGbl(id,"segs",s)=segid, did=1
												}
												Kill:'did $$$vaSegmentRef(segid,id) ; if obj has no 
											}
										}
										Set segid=tJK_","_$I(%topSegIndex)
										Merge dtree=$$$vaSegmentGbl(oldsegid)  Kill $$$vaSegmentGbl(oldsegid)  Merge $$$vaSegment(segid)=dtree  Kill dtree
										Set $$$vaExtentGbl(tId,"segs",iSeg)=segid
										#; Update references from any other messages to this segment
										Set id="",did=0  For { Set id=$O($$$vaSegmentRef(segid,id)) Quit:""=id  Continue:id=tId
											Set xsegid="" For s=$G($$$vaExtentGbl(id,"segs"),0):-1:1 {
												Set xsegid=$G($$$vaExtentGbl(id,"segs",s))
												Set:xsegid=oldsegid $$$vaExtentGbl(id,"segs",s)=segid, did=1
											}
											Kill:'did $$$vaSegmentRef(segid,id)
										}
										Set convertedSegs(oldsegid) = segid
									}
									Set $$$vaSegmentGbl(tJK)=%topSegIndex
									TCommit
								} CATCH err {
									TRollback
								}
								Lock -$$$vaSegment(oldsegid)
							}
						}
					}
					Kill:$G(tNoTop) %topSegIndex
					Lock -$$$vaExtentGbl(tId)
				}
			}
			Set ..Separators=$E($$$vaSegment($$$vaExtentGbl(tId,"segs",1)),1,5)
		}
	}
	Set i%DocTypeCategory=$P(..DocType,":",1)
	Set i%DocTypeName=$P(..DocType,":",2)
	#; No automatic BuildMap here - allow cheap instantiation for routing etc; do BuildMap() only when called for
	Quit $$$OK
}

Method %OnAfterSave(insert As %Boolean) As %Status [ Private ]
{
	Set tSC=$$$OK, tId=..%Id()
	Do:'$D($$$vaM("runtimeIndex"))&&$D($$$vaM("runtimePath")) ..buildRuntimeIndexFromPath()
	Set count=+$G($$$vaM("runtimeIndex"))  For index=1:1:count { Set seg=$$$vaSegLookthru(index,..%ClonedId)
		If $$$vaIsOref(seg) {
			Set tSegObj=..%maps("orefs",index)
			Set tSC=tSegObj.SaveData(..Separators)  Quit:$$$ISERR(tSC)
			Set segid=tSegObj.ID
		} Else {
			Set segid=$P(seg,"|")
		}
		If segid {
			Set $$$vaExtentGbl(tId,"segs",index)=segid
			Set $$$vaSegmentRef(segid,tId)=""
			Kill $$$vaOpenSegmentPPG(segid)
		}
	}
	For index=count+1:1:+$G($$$vaExtentGbl(tId,"segs")) { Kill $$$vaExtentGbl(tId,"segs",index) } ; Kill leftovers if we shrank
	Set $$$vaExtentGbl(tId,"segs")=count
	Set i%%ClonedId=0
	Quit tSC
}

Method PokeDocType(pDocType As %String) As %Status [ CodeMode = expression ]
{
..DocTypeSet(pDocType,0)
}

Method PokeTypeCategory(pMessageTypeCategory As %String) As %Status
{
 Set i%MessageTypeCategory=pMessageTypeCategory  Quit $$$OK
}

Method DocTypeSet(pDocType As %String, pBuildMap As %Boolean = 1) As %Status
{
	Quit:pDocType=..DocType&&$D($$$vaM("runtimePath")) $$$OK ; nothing is changed

	#; convert runtimePath to runtimeIndex and then Kill runtimePath
	Do:'$D($$$vaM("runtimeIndex"))&&$D($$$vaM("runtimePath")) ..buildRuntimeIndexFromPath(1) ; 1 = clear types
	Kill $$$vaM("runtimePath"), $$$vaM("bidirectionalLink"), $$$vaM("loopIndex")
	Set i%DocType=pDocType
	Set i%DocTypeCategory=$P(pDocType,":",1)
	Set i%DocTypeName=$P(pDocType,":",2)
	Do:pBuildMap ..BuildMap()
	Quit $$$OK
}

/// pKeepParsingAfterError means keep trying to parse after errors are encountered; returned Status will contain all errors encountered
Method BuildMap(pKeepParsingAfterError As %Boolean = 1) As %Status
{
	If ((""=..DocTypeCategory)||(""=..DocTypeName)) {
		Set i%BuildMapStatus=$S(""=..DocType:"", 1:$$$ERROR($$$EnsEDIErrMapDocType,"HL7",..DocType))
	} Else {
		Quit:$D($$$vaM("runtimePath"))&&(""'=..BuildMapStatus) ..BuildMapStatus ; already done
		Set i%BuildMapStatus=""
	}
	Do:'$D($$$vaM("runtimeIndex")) ..buildRuntimeIndexFromPath(1) ; 1 = clear types
	Kill $$$vaM("runtimePath"), $$$vaM("bidirectionalLink"), $$$vaM("loopIndex")

	Quit:""=..DocType $$$OK
	Quit:""'=..BuildMapStatus ..BuildMapStatus

	Set tSchema=$G($$$vaSchemaGbl(..DocTypeCategory,"MS",..DocTypeName))
	If tSchema="" {
		Set i%BuildMapStatus=$$$ERROR($$$EnsEDIErrMapDocType,"HL7",..DocType)
		Quit ..BuildMapStatus
	}
	Set tId=..%Id()  Set:'tId tId=..%ClonedId
	Set tCurrSeg=1, %seglastmatch=0, %pathlastmatch=""
	Set tSC=..buildRuntimePathFromIndex(tId,"",$Name($$$vaSchemaGbl)_"("""_..DocTypeCategory_""",""MS"","""_..DocTypeName_""",""array"")","top",.tCurrSeg,0,$$$OK,pKeepParsingAfterError)
	$$$ASSERT(%seglastmatch=(tCurrSeg-1))
	#; Map leftover segments
	Set tSegments=$$$vaM("runtimeIndex")
	If tCurrSeg<=tSegments {
		Set tNotZ=0,tNotZName=""
		For i=tCurrSeg:1:tSegments {
			#; Find current Segment's Type Name
			Set seg=$$$vaSegLookthru(i,tId)
			If $$$vaIsOref(seg) {
				Set tSegObj=..%maps("orefs",i)
				Set currsegname=tSegObj.Name
				Set $$$vaM("runtimePath","leftoversegs("_(i+1-tCurrSeg)_")")="@"_i
			} Else {
				Set segid=$P(seg,"|"), data=$G($$$vaSegment(segid))
				Set currsegname=$$$vaDataSegName(data)
				Set $$$vaM("runtimePath","leftoversegs("_(i+1-tCurrSeg)_")")=segid
			}
			If 'tNotZ&&$Case($E(currsegname),"Z":0, "H":0, :1) { Set tNotZ=i, tNotZName=currsegname }
			ElseIf ""=tNotZName { Set tNotZName=currsegname }
		}
		If pKeepParsingAfterError||$$$ISOK(tSC) {
			Set tcurr=$S(tNotZ:tNotZ,1:tCurrSeg) ; use the first non-Z leftover seg to complain about; if all leftovers are Z's then use the first leftover
			Set currname=tcurr_":'"_tNotZName_"'"
			If tCurrSeg=1 { Set lastname="" }
			Else {
				#; Find previous Segment's Type Name
				Set seg=$$$vaSegLookthru(tCurrSeg-1,tId)
				If $$$vaIsOref(seg) {
					Set tSegObj=..%maps("orefs",tCurrSeg-1)
					Set lastname=tSegObj.Name
				} Else {
					Set segid=$P(seg,"|"), data=$G($$$vaSegment(segid))
					Set lastname=$$$vaDataSegName(data)
				}
			}
			Set lastmatch=$S(""'=lastname&&%seglastmatch:%seglastmatch_" ("_%pathlastmatch_")", 1:"0")
			Set tNewSC=$S(tNotZ: $$$ERROR($$$EnsEDIErrMapSegUnrecog,currname,lastmatch)
				,"Z"'=$E(lastname):  $$$ERROR($$$EnsEDIErrMapWildSegUnrecog,currname,lastmatch,"Z")
				,1:                  $$$ERROR($$$EnsEDIErrMapWildSegUnrecogAfterWild,currname,lastmatch,"Z"))
			Set tSC=$$$ADDSC(tSC,tNewSC)
		}
	}
	Kill %seglastmatch, %pathlastmatch
	Set i%BuildMapStatus=tSC
	Quit tSC
}

/// Build a segment map for the current segment index array based on the document schema<br>
/// If <var>pKeepParsingAfterError</var> is false then stop parsing when first error is encountered<br>
Method buildRuntimePathFromIndex(pId As %String, pPath As %String, pContentArray As %String, pType As %String, ByRef pCurrSeg As %Integer, pParentGrpOpt As %Boolean, pSC As %Status, pKeepParsingAfterError As %Boolean) As %Status
{
	Set tSegments=$$$vaM("runtimeIndex"), currsegname=""
	Set type=$P(pType,"(",1,$L(pType,"(")), len=$L(type), tIsUnion="union"=$E(type,len+1-$L("union"),len)
	Set tGrpOpt=(pParentGrpOpt||$G(@pContentArray@("opt"),0)), tFirstReq="", tGrpSeg=pCurrSeg
	For i=1:1:$G(@pContentArray) { ; loop over sub-elements of the root element at this level
		Set pIContents=$Name(@pContentArray@(i))
		Set opt=$G(@pIContents@("opt"),0), tFirstReq=$S(""=tFirstReq&&'opt:1, ""=tFirstReq:"", 1:0)
		Set type=@pIContents@("type")
		Set segtype=$S(type[":":$P(type,":",3),1:"-"_type)
		Set isrep=$P(segtype,"(",2), tMaxReps=$Case(isrep, ")":0, "":1, :+isrep), isrep=(""'=isrep), tRequiredReps='opt
		Set segtype=$P(segtype,"(")
		Set segname=$P(@pIContents@("name"),"(")
		Set subs=$G(@pIContents,0)
		Set tISeg=pCurrSeg
		For rep=1:1 { Quit:rep>tMaxReps&&tMaxReps ; loop for repetitions of the current sub-element
			Set tBaseSeg=pCurrSeg
			Set tIPath=$S(""=pPath:"",1:pPath_".")_segname_$S(isrep:"("_rep_")",1:"")
			#;If isrep&&(rep=1)&&(i=1)&&opt Set pSC=$$$ADDSC(pSC,$$$ERROR($$$EnsEDIErrMapGeneral,"Schema error at "_tIPath_" - the first element in a repeating group must not be optional"))  Quit

			If subs {
				Set pSC=..buildRuntimePathFromIndex(pId,tIPath,pIContents,type,.pCurrSeg,tGrpOpt||(rep>tRequiredReps),pSC,pKeepParsingAfterError)
			} Else {
				#; Find current Segment's Type Name
				If pCurrSeg>tSegments {
					Set currsegname=""
				} Else {
					Set seg=$$$vaSegLookthru(pCurrSeg,pId)
					If $$$vaIsOref(seg) {
						Set tSegObj=..%maps("orefs",pCurrSeg)
						Set currsegname=tSegObj.Name
					} Else {
						Set segid=$P(seg,"|"), data=$G($$$vaSegment(segid))
						Set currsegname=$$$vaDataSegName(data)
					}
				}
				#; Check for segment type match
				If $Case(segtype, currsegname:1, "Zxx":("Z"=$E(currsegname)), "Hxx":("H"=$E(currsegname)), "Any":(""'=currsegname), :0)  {	
					#; Set seg address/schema at path into runtimePath
					Set schema=$P($P(type,":",2,3),"(")
					Set seg=$$$vaSegLookthru(pCurrSeg,pId)
					If $$$vaIsOref(seg) {
						Set $$$vaM("runtimePath",tIPath)="@"_pCurrSeg
						Set ..%maps("orefs",pCurrSeg).DocType=schema
					} Else {
						Set seg=$P(seg,"|")_"|"_schema
						Set $$$vaM("runtimeIndex",pCurrSeg)=seg
						Set $$$vaM("runtimePath",tIPath)=seg
					}
					Set $$$vaM("bidirectionalLink",pCurrSeg)=tIPath, $$$vaM("bidirectionalLink",tIPath)=pCurrSeg

					Set %seglastmatch=pCurrSeg, %pathlastmatch=tIPath
					Set:pCurrSeg<=tSegments pCurrSeg=pCurrSeg+1, currsegname=""
				}
			}
			If tBaseSeg=pCurrSeg { ; found no match in repeat loop
				Set:rep<tRequiredReps&&'tIsUnion&&'tGrpOpt pSC=$$$ADDSC(pSC,$$$ERROR($$$EnsEDIErrMapSegCount,tRequiredReps,tIPath,pCurrSeg_$S(""=$G(currsegname):"",1:" ("_currsegname_")")))
				Quit
			} Else {
				Set tGrpOpt=0
				Quit:pCurrSeg>tSegments
			}
		}
		Quit:$$$ISERR(pSC)&&'pKeepParsingAfterError
		If tISeg=pCurrSeg { ; found no match at element i
			If 'opt&&'tIsUnion {
				Quit:i=1
				Set:'tGrpOpt pSC=$$$ADDSC(pSC,$$$ERROR($$$EnsEDIErrMapRequired,tIPath,pCurrSeg_$S(""=$G(currsegname):"",1:" ("_currsegname_")")))
				Quit:tFirstReq||'pKeepParsingAfterError
			}
		} Else {
			Set tGrpOpt=0
			Quit:tIsUnion
		}
	}
	If tIsUnion {
		If tGrpSeg=pCurrSeg { ; found no match in any union element
			Set:'tGrpOpt pSC=$$$ADDSC(pSC,$$$ERROR($$$EnsEDIErrMapRequiredUnion,pPath,pCurrSeg_$S(""=$G(currsegname):"",1:" ("_currsegname_")")))
		}
	}
	Quit pSC
}

Method DumpMaps() As %Status
{
	Set DocType=..DocType w ! zw DocType
	w !,"DocTypeCategory,DocTypeName="_..DocTypeCategory_","_..DocTypeName
	Set BuildMapStatus=..BuildMapStatus w ! zw BuildMapStatus
	If ""'=..DocTypeCategory&&(""'=..DocTypeName) {
		Merge mapSchemaPath=$$$vaSchemaGbl(..DocTypeCategory,"MS",..DocTypeName,"map") w ! zw mapSchemaPath
		Merge mapContentArray=$$$vaSchemaGbl(..DocTypeCategory,"MS",..DocTypeName,"array") w ! zw mapContentArray
	}
	Merge mapRuntimeIndex=$$$vaM("runtimeIndex") w ! zw mapRuntimeIndex
	Merge mapRuntimePath=$$$vaM("runtimePath") w ! zw mapRuntimePath
	Merge mapBidirectionalLink=$$$vaM("bidirectionalLink") w ! zw mapBidirectionalLink
	Merge mapLoopIndex=$$$vaM("loopIndex") w ! zw mapLoopIndex
 	Merge mapOrefs=..%maps("orefs") w ! zw mapOrefs
	Quit $$$OK
}

ClassMethod GetContentArray(Output pContents, pMode As %String, pDocType As %String, pLevel As %Integer, pIncludeBase As %Boolean) As %Status [ CodeMode = expression ]
{
##class(EnsLib.HL7.Schema).GetContentArray(.pContents,.pMode,.pDocType,.pLevel,.pIncludeBase)
}

/// Returns a list of available DocTypes for this document class. <br/>
/// The DocType is returned as the first column in the result set. <br/>
/// The <var>Category</var> parameter can be used to restrict the list. <br/>
/// If <var>Category</var> is: <br/>
///  0 - return only DocTypes in standard categories <br/>
///  + - return only DocTypes in user-defined categories <br/>
///  empty - return DocTypes from all categories <br/>
///  a category name - return only DocTypes in the named category <br/>
///  a partial name suffixed with '%' - return only DocTypes in categories matching the partial category name <br/>
///  other - return nothing <br/>
/// If <var>IncludeBase</var> is: <br/>
///  0 - return only DocTypes defined in the current schema category itself <br/>
///  1 - return all DocTypes in the current schema category's base category in addition to those defined in the current category itself <br/>
Query EnumerateDocTypes(Category As %String = "", IncludeBase As %Boolean = 0) As %Query(CONTAINID = 0, ROWSPEC = "Type:%String")
{
}

ClassMethod EnumerateDocTypesExecute(ByRef qHandle As %Binary, Category As %String, IncludeBase As %Boolean) As %Status [ CodeMode = expression ]
{
##class(EnsLib.HL7.Schema).MessageStructuresExecute(.qHandle,.Category,.IncludeBase)
}

ClassMethod EnumerateDocTypesFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer) As %Status [ PlaceAfter = EnumerateDocTypesExecute ]
{
	Set tSC=##class(EnsLib.HL7.Schema).MessageStructuresFetch(.qHandle,.Row,.AtEnd)
	Set:""'=$G(Row) Row=$LB($LG(Row))
	Quit tSC
}

ClassMethod EnumerateDocTypesClose(ByRef qHandle As %Binary) As %Status [ CodeMode = expression, PlaceAfter = EnumerateDocTypesExecute ]
{
##class(EnsLib.HL7.Schema).MessageStructuresClose(.qHandle)
}

/// Returns a list of available MessageTypes for this document class. <br/>
/// The MessageTypes is returned as the first column in the result set. <br/>
/// The <var>Category</var> parameter can be used to restrict the list. <br/>
/// If <var>Category</var> is: <br/>
///  0 - return only MessageTypes in standard categories <br/>
///  + - return only MessageTypes in user-defined categories <br/>
///  empty - return MessageTypes from all categories <br/>
///  a category name - return only MessageTypes in the named category <br/>
///  a partial name suffixed with '%' - return only MessageTypes in categories matching the partial category name <br/>
///  other - return nothing <br/>
/// If <var>IncludeBase</var> is: <br/>
///  0 - return only MessageTypes defined in the current schema category itself <br/>
///  1 - return all MessageTypes in the current schema category's base category in addition to those defined in the current category itself <br/>
Query EnumerateMessageTypes(Category As %String = "", IncludeBase As %Boolean = 0) As %Query(CONTAINID = 0, ROWSPEC = "Type:%String")
{
}

ClassMethod EnumerateMessageTypesExecute(ByRef qHandle As %Binary, Category As %String, IncludeBase As %Boolean) As %Status [ CodeMode = expression ]
{
##class(EnsLib.HL7.Schema).MessageTypesExecute(.qHandle,.Category,.IncludeBase)
}

ClassMethod EnumerateMessageTypesFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer) As %Status [ PlaceAfter = EnumerateDocTypesExecute ]
{
	Set tSC=##class(EnsLib.HL7.Schema).MessageTypesFetch(.qHandle,.Row,.AtEnd)
	Set:""'=$G(Row) Row=$LB($LG(Row))
	Quit tSC
}

ClassMethod EnumerateMessageTypesClose(ByRef qHandle As %Binary) As %Status [ CodeMode = expression, PlaceAfter = EnumerateDocTypesExecute ]
{
##class(EnsLib.HL7.Schema).MessageTypesClose(.qHandle)
}

/// Returns a list of document type schema categories for the document class.<br>
/// The <var>Standard</var> parameter can be used to restrict the list.<br>
/// If <var>Standard</var> is:
///  0 - return only standard categories
///  + - return only user-defined categories
///  empty - return all categories
///  a partial category name - return only categories starting with the given category name part<br/>
///  other - return nothing
Query EnumerateTypeCategories(Standard As %String = "") As %Query(CONTAINID = 0, ROWSPEC = "Category:%String,Description:%String,IsStandard:%Boolean,Base:%String")
{
}

ClassMethod EnumerateTypeCategoriesExecute(ByRef qHandle As %Binary, Standard As %String = "") As %Status [ CodeMode = expression ]
{
##class(EnsLib.HL7.Schema).TypeCategoriesExecute(.qHandle, Standard)
}

ClassMethod EnumerateTypeCategoriesFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer) As %Status [ PlaceAfter = EnumerateTypeCategoriesExecute ]
{
	Set tSC=##class(EnsLib.HL7.Schema).TypeCategoriesFetch(.qHandle,.Row,.AtEnd)
	Quit tSC
}

ClassMethod EnumerateTypeCategoriesClose(ByRef qHandle As %Binary) As %Status [ CodeMode = expression, PlaceAfter = EnumerateTypeCategoriesExecute ]
{
##class(EnsLib.HL7.Schema).TypeCategoriesClose(.qHandle)
}

/// Returns a list of schema categories and segment types and segment fields for this document class. <br/>
/// The <var>Category</var> and <var>Level</var> parameters can be used to restrict the list. <br/>
/// If <var>Category</var> is: <br/>
///  0 - return only standard categories <br/>
///  + - return only user-defined categories <br/>
///  empty - return all categories <br/>
///  a category name - return only SegTypes in the named category <br/>
///  a category name:segment type name - return only information about the named SegType <br/>
///  a partial name suffixed with '%' - return only SegTypes in categories matching the partial category name <br/>
///  other - return nothing <br/>
/// If <var>Level</var> is: <br/>
///  0 - return all segment names <br/>
///  n - return the given number of levels of nested field names within each segment <br/>
///  empty - return all levels of nested field names within each segment <br/>
/// If <var>IncludeBase</var> is: <br/>
///  0 - return only segment names defined in the current schema category itself <br/>
///  1 - return all segment names in the current schema category's base category in addition to those defined in the current category itself <br/>
Query EnumerateSegTypes(Category As %String = "", Level As %String = "", IncludeBase As %Boolean = 0) As %Query(CONTAINID = 0, ROWSPEC = "SegType:%String,Field:%String,Description:%String,IsStandard:%Boolean")
{
}

ClassMethod EnumerateSegTypesExecute(ByRef qHandle As %Binary, Category As %String, Level As %String, IncludeBase As %Boolean) As %Status [ CodeMode = expression ]
{
##class(EnsLib.HL7.Schema).SegTypesExecute(.qHandle,.Category,.Level,.IncludeBase)
}

ClassMethod EnumerateSegTypesFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer) As %Status [ PlaceAfter = EnumerateSegTypesExecute ]
{
	Set tSC=##class(EnsLib.HL7.Schema).SegTypesFetch(.qHandle,.Row,.AtEnd)
	Quit tSC
}

ClassMethod EnumerateSegTypesClose(ByRef qHandle As %Binary) As %Status [ CodeMode = expression, PlaceAfter = EnumerateSegTypesExecute ]
{
##class(EnsLib.HL7.Schema).SegTypesClose(.qHandle)
}

/// This method computes the Alias string for a property name, given the property's node in the Content Array.
ClassMethod GetAlias(pContentArrayName As %String, pArrayPos As %String) As %String [ CodeMode = expression ]
{
##class(EnsLib.HL7.Schema).GetAlias(pContentArrayName,pArrayPos)
}

ClassMethod checkDocType(ByRef pDocType As %String) As %Status
{
	Set tSC=$$$OK
	Set category=$P(pDocType,":",1)
	Set secondary=$P(pDocType,":",2)
	If $P(secondary,"_")="ACK" Set secondary="ACK"
	If (""=category)||(""=secondary)||(""=$G($$$vaSchemaGbl(category,"MS",secondary))) {
		Set tSC=$$$ERROR($$$EnsEDIErrMapDocType,"HL7",pDocType)
	}
	Quit tSC
}

/// This method is for use from the RawContent property's SQL Compute invocation
ClassMethod getSegsAsString(pId As %String, pMaxLen As %Integer = 10000, pStartOffset As %Integer = 1) As %String
{
	#; Use delimiters from first segment, translate all subsequent delims to those
	Set str=""  For index=1:1:+$G($$$vaExtentGbl(pId,"segs")) { Set segid=$$$vaExtentGbl(pId,"segs",index), data=$S(segid[",":$G($$$vaSegment(segid)),1:$G($$$vaSegmentGbl(segid)))
		Set:index=1 tSeparators=$E(data,1,5)
		Set:tSeparators'=$E(data,1,5) data=##class(EnsLib.HL7.Segment).replaceSeparators(data, tSeparators)
		If pStartOffset>1 {
			If pStartOffset>($L(data)-5+1) { Set pStartOffset=pStartOffset-($L(data)-5+1) }
			Else { Set pStartOffset=1, data=$E(data,pStartOffset,*) }
		}
		If pMaxLen-$L(str)>=($L(data)-5+1) { Set str=str_$E(data,6,*)_$C($$$HL7DefSegTerminatorAscii) }
		Else { Set str=str_$E(data_$S($L(data)<pMaxLen:$C($$$HL7DefSegTerminatorAscii),1:""),6,5+pMaxLen-$L(str)) }
		Quit:$L(str)>=pMaxLen
	}
	Quit str
}

Method OutputToFile(pFilename As %String, pOverwrite As %Boolean, pSeparators As %String, pSequenceNumber As %String, pIOFormatClassname As %String) As %Status
{
	Set tIOStream=##Class(%IO.FileStream).%New()
	Do tIOStream.Open(pFilename,$S($G(pOverwrite):"NEW",1:"AEW"),5,,.tSC)  Quit:$$$ISERR(tSC) tSC
	Quit ..OutputToIOStream(tIOStream, .pSeparators, .pSequenceNumber, , .pIOFormatClassname)
}

/// Note: order of args is reversed for OutputToDevice() so we can pretend to be a Stream and pass the Sequence number in place of pLen.
Method OutputToDevice(pSequenceNumber As %String, pSeparators As %String, pIOFormatClassname As %String) As %Status
{
	Set tDeviceStream=##class(%IO.DeviceStream).AttachNew(,.tSC)  Quit:$$$ISERR(tSC) tSC
	Quit ..OutputToIOStream(tDeviceStream, .pSeparators, .pSequenceNumber, , .pIOFormatClassname)
}

/// deprecated - use OutputToLibraryStream
Method OutputToOldStream(pOldStream As %Stream.Object, pSeparators As %String, pSequenceNumber As %String) As %Status [ CodeMode = expression ]
{
..OutputToLibraryStream(.pOldStream, .pSeparators, .pSequenceNumber)
}

Method OutputToLibraryStream(pLibStream As %Stream.Object, pSeparators As %String, pSequenceNumber As %String, pIOFormatClassname As %String) As %Status
{
	Set tIOStream=$S(pLibStream.%Extends("%IO.I.CharacterStream"):pLibStream, 1:##Class(%IO.MetaCharacterStream).%New(pLibStream))
	Quit ..OutputToIOStream(tIOStream, .pSeparators, .pSequenceNumber, , .pIOFormatClassname)
}

Method OutputToString(pSeparators As %String, pSequenceNumber As %String, Output pStatus As %Status, pIOFormatClassname As %String) As %String
{
	Set tIOStream=##Class(%IO.StringStream).%New()
	Set pStatus = ..OutputToIOStream(tIOStream, .pSeparators, .pSequenceNumber, , .pIOFormatClassname)
	Do tIOStream.Rewind()
	Quit tIOStream.Read()
}

Method OutputToIOStream(pIOStream As %IO.I.CharacterStream, pSeparators As %String, pSequenceNumber As %String, pFlush As %Boolean = 1, pIOFormatClassname As %String = "") As %Status
{
	Set tSC=$$$OK
	Set tSeparators=$S(""=$G(pSeparators):..Separators, 1:pSeparators)
	If ""=pIOFormatClassname || '$classmethod(pIOFormatClassname,"OutputDocument",$this,.tSC,pIOStream,tSeparators,.pSequenceNumber) {
		Do:'$D($$$vaM("runtimeIndex"))&&$D($$$vaM("runtimePath")) ..buildRuntimeIndexFromPath()
		For i=1:1:$G($$$vaM("runtimeIndex")) { Set tSeg=..getSegmentByIndex(i)
			If 'tSeg.IsChildHolder(.tRef) { Set tSC=tSeg.OutputToIOStream(pIOStream, tSeparators, .pSequenceNumber, i, $G($$$vaM("bidirectionalLink",i),i), $this, pIOFormatClassname) }
			Else {
				Set tChild=$$$NULLOREF For { Set tChild=..NextChild(tChild,tRef)  Quit:tChild=$$$NULLOREF
					Set tSC=tChild.OutputToIOStream(pIOStream, tSeparators, .pSequenceNumber, 0, pIOFormatClassname)  Quit:$$$ISERR(tSC)
				}
			}
			Do ..commitSegmentByIndex(i)
		}
		Do:""'=pIOFormatClassname $classmethod(pIOFormatClassname,"OutputDocumentEnd",$this,.tSC,pIOStream,tSeparators)
	}
	If pFlush Do pIOStream.Flush(.tSC1)  Set:$$$ISOK(tSC) tSC=tSC1
	Quit tSC
}

/// Display Segments as HTML, using DocType info if available
Method OutputHTML() As %Status
{

	If ($System.Security.Check("NotAnonymize", "USE")) {
		quit ..OutputHTMLOriginal()
	} else {
		quit ..OutputHTMLAnonymize()
	}
}

Method OutputHTMLZen() As %Status
{
	If ($System.Security.Check("NotAnonymize", "USE")) {
		quit ..OutputHTMLZenOriginal()
	} else {
		quit ..OutputHTMLZenAnonymize()
	}
}

/// Display Segments as HTML, using DocType info if available
Method OutputHTMLOriginal() As %Status
{
	Set tSC=$$$OK
	Set tSeparators=..Separators  Set:""=tSeparators tSeparators=$$$HL7DefSeparators Set:""=$$$SEGTERM(tSeparators) tSeparators=tSeparators_..SegmentTerminator  Set $$$SEGTERM(tSeparators)=$ZStrip($$$SEGTERM(tSeparators),"*CW")
	Quit ..OutputToDevice(,tSeparators,"EnsLib.HL7.Util.FormatHTMLv2")
}

/// Display Segments as HTML, using DocType info if available
Method OutputHTMLZenOriginal() As %Status
{
	Set tSC=$$$OK
	Set tSeparators=..Separators  Set:""=tSeparators tSeparators=$$$HL7DefSeparators Set:""=$$$SEGTERM(tSeparators) tSeparators=tSeparators_..SegmentTerminator  Set $$$SEGTERM(tSeparators)=$ZStrip($$$SEGTERM(tSeparators),"*CW")
	Quit ..OutputToDevice(,tSeparators,"EnsLib.HL7.Util.FormatHTMLv2Zen")
}

/// Display Segments as HTML, using DocType info if available
Method OutputHTMLAnonymize() As %Status
{
	Set tSC=$$$OK
	Set tSeparators=..Separators  Set:""=tSeparators tSeparators=$$$HL7DefSeparators Set:""=$$$SEGTERM(tSeparators) tSeparators=tSeparators_..SegmentTerminator  Set $$$SEGTERM(tSeparators)=$ZStrip($$$SEGTERM(tSeparators),"*CW")
	Quit ..OutputToDevice(,tSeparators,"EnsLib.HL7.Util.FormatHTMLv2Anonymize")
}

/// Display Segments as HTML, using DocType info if available
Method OutputHTMLZenAnonymize() As %Status
{
	Set tSC=$$$OK
	Set tSeparators=..Separators  Set:""=tSeparators tSeparators=$$$HL7DefSeparators Set:""=$$$SEGTERM(tSeparators) tSeparators=tSeparators_..SegmentTerminator  Set $$$SEGTERM(tSeparators)=$ZStrip($$$SEGTERM(tSeparators),"*CW")
	Quit ..OutputToDevice(,tSeparators,"EnsLib.HL7.Util.FormatHTMLv2ZenAnonymize")
}

ClassMethod ImportFromFile(pFilename As %String, pDocNum As %Integer = 1, Output pStatus As %Status, ByRef pConfigItem As %String, pIOFormatClassname As %String) As EnsLib.HL7.Message
{
	Set tIOStream=##Class(%IO.FileStream).%New()
	Do tIOStream.Open(pFilename,,5,,.pStatus)  Quit:$$$ISERR(pStatus) $$$NULLOREF
	$$$sysTRACE("Opened file '"_pFilename_"'")
	Set tDoc=$$$NULLOREF  For i=1:1:pDocNum {
		If tIOStream.AtEnd Set pStatus=$$$ERROR($$$EnsErrGeneral,"Fewer than "_pDocNum_" messages in file "_pFilename)  Quit
		Set tDoc=..ImportFromIOStream(tIOStream,.pStatus,.pConfigItem,.pIOFormatClassname)  Quit:$$$ISERR(pStatus)
	}
	Quit:$$$ISERR(pStatus) $$$NULLOREF
	Quit tDoc
}

ClassMethod ImportFromDevice(Output pStatus As %Status, ByRef pConfigItem As %String, pIOFormatClassname As %String) As EnsLib.HL7.Message
{
	Set tDeviceStream=##class(%IO.DeviceStream).AttachNew(,.tSC)  Quit:$$$ISERR(tSC) tSC
	Quit ..ImportFromIOStream(tDeviceStream,.pStatus,.pConfigItem,.pIOFormatClassname)
}

/// deprecated - use ImportFromLibraryStream
ClassMethod ImportFromOldStream(pOldStream As %Stream.Object, Output pStatus As %Status, ByRef pConfigItem As %String) As EnsLib.HL7.Message [ CodeMode = expression ]
{
..ImportFromLibraryStream(.pOldStream,.pStatus,.pConfigItem)
}

ClassMethod ImportFromLibraryStream(pLibStream As %Stream.Object, Output pStatus As %Status, ByRef pConfigItem As %String, pIOFormatClassname As %String) As EnsLib.HL7.Message
{
	Set tIOStream=$S(pLibStream.%Extends("%IO.I.CharacterStream"):pLibStream,1:##Class(%IO.MetaCharacterStream).%New(pLibStream))
	Quit ..ImportFromIOStream(tIOStream,.pStatus,.pConfigItem,.pIOFormatClassname)
}

ClassMethod ImportFromString(pString As %String, Output pStatus As %Status, ByRef pConfigItem As %String, pIOFormatClassname As %String) As EnsLib.HL7.Message
{
	Set tIOStream=##Class(%IO.StringStream).%New(pString)
	Quit ..ImportFromIOStream(tIOStream,.pStatus,.pConfigItem,.pIOFormatClassname)
}

ClassMethod ImportFromIOStream(pIOStream As %IO.I.CharacterStream, Output pStatus As %Status = {$$$OK}, ByRef pConfigItem As %String = "", pIOFormatClassname As %String = "") As EnsLib.HL7.Message
{
	Quit:""'=pIOFormatClassname&&$classmethod(pIOFormatClassname,"ImportDocument",.tDoc,.pStatus,pIOStream,pConfigItem) tDoc

	If ""'=pConfigItem {
		If $IsObject(pConfigItem) {
			Set tInst=pConfigItem
		} Else {
			Set tInst=##class(Ens.Host).GetShadowInstance(pConfigItem,.pStatus)  Quit:$$$ISERR(pStatus) $$$NULLOREF
		}
		If 'tInst.%Extends("EnsLib.HL7.Service.Standard") Set pStatus=$$$ERROR($$$EnsErrGeneral,"Config Item class "_$classname(tInst)_" found For "_pConfigItem_" is not not an HL7 Service")  Quit $$$NULLOREF
	} Else {
		Set tInst=##class(Ens.Host).GetShadowInstance("class ||EnsLib.HL7.Service.FileService",.pStatus)  Quit:$$$ISERR(pStatus) $$$NULLOREF
	}
	#; Get a new parser based on a Service; OnInit not called for shadow service instances
	Set tInst.%ForwardBatchWhole=2 ; don't let Service process the document
	If '$IsObject(tInst.%Parser) Set tInst.%Parser=##class(EnsLib.HL7.Parser).%New(tInst)  $$$ASSERT($IsObject(tInst.%Parser))
	Set tInst.%Parser.Framing=tInst.Framing
	Set tInst.%Parser.DefCharEncoding=tInst.DefCharEncoding
	Set:""=tInst.AckMode tInst.AckMode="Immed"

	If tInst'=pConfigItem { ; override some default properties if we created the shadow instance
		Set tInst.SearchTableClass=""
	}
	#; call the parser
	Set tDoc=$$$CurrentClass
	Set pStatus=tInst.%Parser.ParseFramedIOStream(pIOStream,.tDoc,1)
	Set pConfigItem=tInst ; allow repeated calls on the same parser
	Quit tDoc
}

/// Return the DocType of this document.
Method resolveChildDocType() As %String
{
	Set tDocType=..DocType
	Set tParent=..Parent
	If (""=tDocType)&&($IsObject(tParent))&&(""'=tParent.DocTypeCategory) {
		If ("MSH"=..GetValueAt("1:0")) {
			Set tNameFound=..GetValueAt("1:9",":_~\&")
			Set:""=tNameFound tNameFound=..Name
		} Else {
			Set tNameFound=..Name
		}
		#; Match with the DocType specified if any in MessageSchemaCategory for the received Message's type name
		Set tDocType=##class(EnsLib.HL7.Schema).ResolveSchemaTypeToDocType(tParent.DocTypeCategory,tNameFound,.tSC)
		Set:$$$ISERR(tSC) tDocType=""
	}
	Quit tDocType
}

Method CopyValues(pSource As EnsLib.HL7.Message, pSourcePath As %String, pTargetPath As %String, pAction As %String, pKey As %String, pEmptyFieldAsNull As %Boolean = 0, pIgnoreMissingSource As %Boolean = 0) As %Status
{
	Set tSC=$$$OK
	Set tSourceWild=$F(pSourcePath,"()"), tTargetWild=$F(pTargetPath,"()")
	If tSourceWild||tTargetWild {
		Set tSourceHead=$E(pSourcePath,1,tSourceWild-3), tSourceTail=$E(pSourcePath,tSourceWild,*)
		Set tTargetHead=$E(pTargetPath,1,tTargetWild-3), tTargetTail=$E(pTargetPath,tTargetWild,*)
		If tSourceWild {
			If pEmptyFieldAsNull {
				If (tTargetWild)&&(tSourceHead [ ":")&&(tTargetHead [ ":") {
					Quit:(pSource.GetValueAt(tSourceHead)="") $$$OK
				}
			}
			Set i="" For { Set i=pSource.GetNextIndex(tSourceHead_"()",i,.tSC) Quit:i=""
				Set tSourceNewPath=tSourceHead_"("_(i)_")"_tSourceTail
				Set tTargetNewPath=$S(tTargetWild:tTargetHead_"("_(i)_")"_tTargetTail,1:pTargetPath)
				Set tSC2=..CopyValues(pSource,tSourceNewPath,tTargetNewPath,pAction,pKey,pEmptyFieldAsNull,pIgnoreMissingSource)
				If $$$ISERR(tSC2)&&('pIgnoreMissingSource||(($$$StatusText(tSC2)'["No segment found")&&($$$StatusText(tSC2)'["is not an element, instead this node"))) {
					Set tSC=tSC2
					Quit
				}
			}
		} Else {
			Set i="" For { Set i=..GetNextIndex(tTargetHead_"()",i,.tSC) Quit:i=""
				Set tTargetNewPath=tTargetHead_"("_(i)_")"_tTargetTail
				Set tSC=..CopyValues(pSource,pSourcePath,tTargetNewPath,pAction,pKey,pEmptyFieldAsNull,pIgnoreMissingSource) Quit:$$$ISERR(tSC)
			}
		}
	} Else {
		Set tSourceGrpPath=$P(pSourcePath,":"), tSourcePropPath=$P(pSourcePath,":",2)
		Set tTargetGrpPath=$P(pTargetPath,":"), tTargetPropPath=$P(pTargetPath,":",2)
		Set tSrcSegPath=pSource.GetNextGroupPath(tSourceGrpPath,tSourceGrpPath)
		Set tTrgSegPath=..GetNextGroupPath(tTargetGrpPath,tTargetGrpPath)
		If (""'=tSrcSegPath)||(""'=tTrgSegPath) { ; if there are group sub-elements
			If (""'=tSrcSegPath) {
				For {
					Set tSourceNewPath=tSrcSegPath_$S(""=tSourcePropPath:"",1:":"_tSourcePropPath)
					Set tTargetNewPath=tTargetGrpPath_$E(tSrcSegPath,1+$L(tSourceGrpPath),*)_$S(""=tSourcePropPath:"",1:":"_tSourcePropPath)
					Set tSC=..CopyValues(pSource,tSourceNewPath,tTargetNewPath,pAction,pKey,pEmptyFieldAsNull,pIgnoreMissingSource) Quit:$$$ISERR(tSC)
					Set tSrcSegPath=pSource.GetNextGroupPath(tSourceGrpPath,tSrcSegPath,.tSC) Quit:$$$ISERR(tSC)
					Quit:""=tSrcSegPath
				}
			} Else {
				For {
					Set tTargetNewPath=tTrgSegPath_$S(""=tTargetPropPath:"",1:":"_tTargetPropPath)
					Set tSC=..CopyValues(pSource,pSourcePath,tTargetNewPath,pAction,pKey,pEmptyFieldAsNull,pIgnoreMissingSource) Quit:$$$ISERR(tSC)
					Set tTrgSegPath=..GetNextGroupPath(tTargetGrpPath,tTrgSegPath,.tSC) Quit:$$$ISERR(tSC)
					Quit:""=tTrgSegPath
				}
			}
		} Else {
			If ""'=tSourcePropPath||("*"=pSourcePath)||($E(pSourcePath,*-2,*)="(*)") {
				Set tSC=..SetValueAt(pSource.GetValueAt(pSourcePath,,.tSC2,pEmptyFieldAsNull),pTargetPath,pAction,pKey)
				Set:$$$ISERR(tSC2) tSC=$$$ADDSC(tSC,tSC2)
			} Else { ; create clone segment object for id or oref
				Set tId=pSource.GetSegmentIdAt(pSourcePath,.tSC)  Quit:$$$ISERR(tSC) tSC
				If tId'="" {
					Set tSegObj=##class(EnsLib.HL7.Segment).%New($LB(tId,1,"",1))
					Set:$IsObject(tSegObj) tSC=..SetSegmentAt(tSegObj,pTargetPath)
				} Else {
					Set tSegObj=pSource.GetSegmentAt(pSourcePath,.tSC)  Quit:$$$ISERR(tSC) tSC
					Set:$IsObject(tSegObj) tSC=..SetSegmentAt(tSegObj.%ConstructClone(),pTargetPath)
				}
			}
		}
	}
	Quit tSC
}

ClassMethod Purge(Output pDeletedCount As %Integer, pDaysToKeep As %Integer = 7, pDummy As %Boolean = 0) As %Status
{
	If 0=pDaysToKeep Do ..KillGlobals(.pDeletedCount,1,0)  Quit $$$OK

	New %tDoNotDeleteDate,%tID,%tTime  Set %tDoNotDeleteDate = ##class(Ens.Purge).GetDoNotDeleteDate(pDaysToKeep)
	Set SQLCODE=0, pDeletedCount=0
	&sql(Declare C1 Cursor for
		Select ID,TimeCreated Into :%tID,:%tTime From EnsLib_HL7.Message Order By ID)
	&sql(OPEN C1) For { &sql(FETCH C1)  Quit:SQLCODE
		If $$$timeCmp(%tTime,%tDoNotDeleteDate)<0 {
			&sql(Delete From EnsLib_HL7.Message Where ID=:%tID)
			Set pDeletedCount=pDeletedCount+%ROWCOUNT
		}
	} Set tCode=SQLCODE &sql(CLOSE C1) Set:'SQLCODE SQLCODE=tCode
	Quit:SQLCODE&&(SQLCODE'=100) $$$ERROR($$$EnsErrGeneral,"Purge error at ID "_%tID_"; SQLCODE = "_SQLCODE)
	Quit $$$OK
}

ClassMethod %OnDelete(oid As %ObjectIdentity) As %Status [ Private ]
{
	New %tID  Set %tID=$$$oidPrimary(oid)
	Do ##class(Ens.SearchTableBase).RemoveSearchTableEntries($classname(),%tID,1)
	For index=1:1:+$G($$$vaExtentGbl(%tID,"segs")) {
		Set segid=$$$vaExtentGbl(%tID,"segs",index)
		If segid["," {
			Kill $$$vaSegmentRef(segid,%tID)
			If '$D($$$vaSegmentRefs(segid))&&($G($$$vaOpenSegmentPPG(segid),0)<=0) {
				Kill $$$vaSegment(segid)
				Kill $$$vaOpenSegmentPPG(segid)
			} Else {
				Kill $$$vaSegmentGbl(segid,0,%tID)
				If '$D($$$vaSegmentGbl(segid,0))&&($G($$$vaOpenSegmentPPG(segid),0)<=0) {
					Set data=$G($$$vaSegmentGbl(segid))
					Kill:+data'=data $$$vaSegmentGbl(segid)
					Kill $$$vaOpenSegmentPPG(segid)
				}
			}
		}
	}
	If $G($$$EnsConfig("HL7","DeleteNoLock"),1) {
		&sql(Delete %NOLOCK From EnsLib_HL7.Message Where OriginalDocId=:%tID)
		&sql(Delete %NOLOCK From EnsLib_HL7.Message Where ParentId=:%tID Or ParentId %StartsWith :%tID||':')
	} Else {
		&sql(Delete From EnsLib_HL7.Message Where OriginalDocId=:%tID)
		&sql(Delete From EnsLib_HL7.Message Where ParentId=:%tID Or ParentId %StartsWith :%tID||':')
	}
	Quit $$$OK
}

Trigger OnDelete [ Event = DELETE ]
{
	New %tID,index,segid  Set %tID={%%ID}
	Do ##class(Ens.SearchTableBase).RemoveSearchTableEntries($classname(),%tID,1)
	For index=1:1:+$G($$$vaExtentGbl(%tID,"segs")) {
		Set segid=$$$vaExtentGbl(%tID,"segs",index)
		If segid["," {
			Kill $$$vaSegmentRef(segid,%tID)
			If '$D($$$vaSegmentRefs(segid))&&($G($$$vaOpenSegmentPPG(segid),0)<=0) {
				Kill $$$vaSegment(segid)
				Kill $$$vaOpenSegmentPPG(segid)
			}
		} Else {
			Kill $$$vaSegmentGbl(segid,0,%tID)
			If '$D($$$vaSegmentGbl(segid,0))&&($G($$$vaOpenSegmentPPG(segid),0)<=0) {
				Set data=$G($$$vaSegmentGbl(segid))
				Kill:+data'=data $$$vaSegmentGbl(segid)
				Kill $$$vaOpenSegmentPPG(segid)
			}
		}
	}
	If $G($$$EnsConfig("HL7","DeleteNoLock"),1) {
		&sql(Delete %NOLOCK From EnsLib_HL7.Message Where OriginalDocId=:%tID)
		&sql(Delete %NOLOCK From EnsLib_HL7.Message Where ParentId=:%tID Or ParentId %StartsWith :%tID||':')
	} Else {
		&sql(Delete From EnsLib_HL7.Message Where OriginalDocId=:%tID)
		&sql(Delete From EnsLib_HL7.Message Where ParentId=:%tID Or ParentId %StartsWith :%tID||':')
	}
	Quit
}

ClassMethod KillGlobals(Output pDeletedCount, pKeepExtentCount = 0, pDisplayLog = 1)
{
	Set pDeletedCount=..TotalCount()
	Set tExtentCount=$G($$$vaExtentGbl)
	Write:pDisplayLog !,"Killing ",$classname()," extent ("_pDeletedCount_"/"_tExtentCount_")"
	Do ..%KillExtent()
	Set:pKeepExtentCount $$$vaExtentGbl=tExtentCount

	Do ##class(EnsLib.HL7.SearchTable).%KillExtent()

	Set globals($Name($$$vaSegmentGbl))=""

	Set global="" For { Set global=$O(globals(global))  Quit:""=global
		Kill tExtentCount  Set:pKeepExtentCount tExtentCount=$S($D(@global)#2:@global,1:$$topNodesSum(global))
		Write:pDisplayLog !,"Killing ",global,"("_$G(tExtentCount)_")"
		Kill @global
		If $D(tExtentCount) Set @global=tExtentCount
	}
	Quit
topNodesSum(global)
	Set tSum=0,cnt=0,sub="" For { Set sub=$O(@global@(sub),1,cnt) Quit:""=sub  Set tSum=tSum+cnt }
	Quit tSum
}

ClassMethod TotalCount() As %Integer
{
	&sql(SELECT COUNT(*) INTO :tCount From EnsLib_HL7.Message)
	Quit tCount
}

Method %OnClose() As %Status [ Private, ProcedureBlock = 1 ]
{
	#; Kill Segment storage if not %Save'd and segment not used by other Messages
	Set tId=..%Id()
	If ""=tId {
		If $D($$$vaM("runtimeIndex")) {
			For index=1:1:$$$vaM("runtimeIndex") {
				Set seg=$G($$$vaM("runtimeIndex",index))
				If '$$$vaIsOref(seg) {
					Set segid=$P(seg,"|")
				} Else {
					Set tSegObj=..%maps("orefs",index)
					Set segid=tSegObj.ID
				}
				If segid'="" {
					Set $$$vaOpenSegmentPPG(segid)=($G($$$vaOpenSegmentPPG(segid),0)-1)
					If '$D($$$vaSegmentRefs(segid))&&($$$vaOpenSegmentPPG(segid)<=0) {
						Kill $$$vaSegment(segid)
						Kill $$$vaOpenSegmentPPG(segid)
					}
				}
			}
		} Else {
			Set path=""
			For {
				Set path=$O($$$vaM("runtimePath",path),1,seg) Quit:""=path
				If '$$$vaIsOref(seg) {
					Set segid=$P(seg,"|")
				} Else {
					Set tSegObj=..%maps("orefs",$E(seg,2,*))
					Set segid=tSegObj.ID
				}
				If segid'="" {
					Set $$$vaOpenSegmentPPG(segid) = ($G($$$vaOpenSegmentPPG(segid),0) - 1)
					If '$D($$$vaSegmentRefs(segid))&&($$$vaOpenSegmentPPG(segid)<=0) {
						Kill $$$vaSegment(segid)
						Kill $$$vaOpenSegmentPPG(segid)
					}
				}
			}
		}
	}
	If 'tId||$D($$$vaExtentGbl(tId)) $$$vaMkill  ; ..%maps can be undefined when aborting %OpenId() of nonexistent Id
	Quit $$$OK
}

Method NewReplyDocument(pMessageType As %String = {$S(""'=..MessageTypeCategory:..MessageTypeCategory,1:..DocTypeCategory)_":"_..Name}, pLocalFacilityApplication As %String = "", Output pSC As %Status, pForceACK As %Boolean = 1) As EnsLib.HL7.Message
{
	Set pSC=$$$OK
	Do ##class(EnsLib.HL7.Schema).ResolveReplyNameAndDocType(pMessageType,.tReplyDocName,.tReplyDocType,pForceACK)
	Set tReplyMessage=..%New($LB("",..Separators))
	Quit:'$IsObject(tReplyMessage) $$$NULLOREF
	Do tReplyMessage.PokeTypeCategory($P(pMessageType,":"))
	Do tReplyMessage.PokeDocType(tReplyDocType)
	Set tMSH=..GetSegmentAt(1)
	Set tUTCH=$$$timeUTCH, tTime=$$$timeUTCtoUTCH($$$timeUTCtoLocal($$$timeUTCHtoUTC(tUTCH)))
	Set tReplyMSH=tReplyMessage.GetSegmentAt(1)
	#; Support indirection and escaping to allow @ to represent the caller's destination value
	Set tFacil=$P(pLocalFacilityApplication,":",1), tApp=$P(pLocalFacilityApplication,":",2)
	If pLocalFacilityApplication["@" {
		Set pos=1 For { Set pos=$F(tFacil,"\",pos)  Quit:'pos  Set c=$E(tFacil,pos)
			Set tNew=$Case(c, "@":-1, "\":"\", :"\"_c), $E(tFacil,pos-1,pos)=tNew, pos=pos+$L(tNew)-1
		} Set tFacil=$Replace($Replace(tFacil,"@",tMSH.GetValueAt(6)),-1,"@")
		Set pos=1 For { Set pos=$F(tApp,"\",pos)  Quit:'pos  Set c=$E(tApp,pos)
			Set tNew=$Case(c, "@":-1, "\":"\", :"\"_c), $E(tApp,pos-1,pos)=tNew, pos=pos+$L(tNew)-1
		} Set tApp=$Replace($Replace(tApp,"@",tMSH.GetValueAt(5)),-1,"@")
	}
	Do tReplyMSH.SetValueAt(tMSH.GetValueAt(3),5)
	Do tReplyMSH.SetValueAt(tMSH.GetValueAt(4),6)
	Do tReplyMSH.SetValueAt(tApp,3)
	Do tReplyMSH.SetValueAt(tFacil,4)
	Do tReplyMSH.SetValueAt($ZDate(tTime,8)_$TR($ZTime($P(tTime,",",2),2),":"),7)
	Do tReplyMSH.SetValueAt($TR(tReplyDocName,"_",..CS),9)
	Do tReplyMSH.SetValueAt(..NewControlID(tUTCH),10)
	Do tReplyMSH.SetValueAt(tMSH.GetValueAt(11),11)
	Do tReplyMSH.SetValueAt(tMSH.GetValueAt(12),12)
	Set tSeqNum=tMSH.GetValueAt(13)  Do:""'=tSeqNum tReplyMSH.SetValueAt(tSeqNum,13)
	Quit tReplyMessage
}

/// Get an new 20-character control ID, given $ZTS and $ZH timestamps.
/// 2-char base-62 hash(letters or digits) of machine name (mod 31) and job slot(mod 124), 2-digit year,month,day,millisecond UTC time,and microseconds from $ZH
ClassMethod NewControlID(pTimeUTCH As %String = {$ZTS}) As %Integer
{
#define map62(%n) $C($S(%n<0:$A("-"), %n<10:%n+$A(0), %n<36:%n-10+$A("a"), %n<62:%n-36+$A("A"), 1:$A("+")))
 Set tSys=$G($$$EnsRuntime("System",$$$SystemName))  Set:""=tSys tSys=$p($zu(54,13,$zu(54,0)),",",1)_":"_$get(^%SYS("SSPort"),1972)_":"_$znspace
 Set:'$D($$$EnsJobLocal("JobSlot")) $$$EnsJobLocal("JobSlot")=$ZU(67,3,$J)-1, $$$EnsJobLocal("MachineHash")=$ZCRC(tSys,7)#31*2+($$$EnsJobLocal("JobSlot")\62#2)
 Quit $$$map62($$$EnsJobLocal("MachineHash"))_$$$map62($$$EnsJobLocal("JobSlot")#62)_
	$E($ZDate(pTimeUTCH,8),3,8)_
	$TR($ZTime($P(pTimeUTCH,",",2),1,3),":.")_
	$TR($$$PAD($E($P($ZH,".",2),4,6),3)," ","0")
}

/// Delete All Content and reset all properties
Method Clear() As %Status
{
	Quit:'..IsMutable $$$ERROR($$$EnsErrGeneral,"Object is immutable")
	Set tSC=..%OnClose()  Quit:$$$ISERR(tSC) tSC
	Kill $$$vaM("runtimeIndex"), $$$vaM("runtimePath"), $$$vaM("bidirectionalLink"), $$$vaM("loopIndex")
	Set $$$vaM("runtimeIndex")=0
	Set i%BuildMapStatus=""
	Set ..Source=""
	Quit $$$OK
}

/// The same as %Id(), but allocates the Id even if the object hasn't been saved already
Method getId() As %String [ CodeMode = generator ]
{
	$$$GENERATE(" If ..%Id()="""" Do ..%IdSet($increment("_$$$EXTidlocation($$$pEXT,%class)_"))")
	$$$GENERATE(" Quit ..%Id()")
	Quit $$$OK
}

/// Read a field from a segment into a stream.
/// <var>pRemainder</var> is the remainder of the segment after the stream field, including the field's terminating separator
Method GetFieldStreamRaw(ByRef pStream As %Stream.Object, pPropertyPath As %String = "", Output pRemainder As %String, pProc As %String, ByRef pHint) As %Status
{
	Set tSegObj=..GetSegmentAt($P(pPropertyPath,":",1),.tSC)  Quit:$$$ISERR(tSC) tSC
	Quit tSegObj.GetFieldStreamRaw(.pStream,$P(pPropertyPath,":",2),.pRemainder,.pProc,.pHint)
}

/// Read a field from a segment into a stream, decoding from Base64 to plain binary.
/// <var>pRemainder</var> is the remainder of the segment after the stream field, including the field's terminating separator
Method GetFieldStreamBase64(ByRef pStream As %Stream.Object, pPropertyPath As %String = "", Output pRemainder As %String, pUnescapeFirst As %Boolean) As %Status
{
	Set tSegObj=..GetSegmentAt($P(pPropertyPath,":",1),.tSC)  Quit:$$$ISERR(tSC) tSC
	Quit tSegObj.GetFieldStreamBase64(.pStream,$P(pPropertyPath,":",2),.pRemainder,.pUnescapeFirst)
}

/// Read a field from a segment into a stream, unescaping any encoded separators or newlines, to plain text.
/// <var>pRemainder</var> is the remainder of the segment after the stream field, including the field's terminating separator
Method GetFieldStreamUnescaped(ByRef pStream As %Stream.Object, pPropertyPath As %String = "", Output pRemainder As %String = "") As %Status
{
	Set tSegObj=..GetSegmentAt($P(pPropertyPath,":",1),.tSC)  Quit:$$$ISERR(tSC) tSC
	Quit tSegObj.GetFieldStreamUnescaped(.pStream,$P(pPropertyPath,":",2),.pRemainder)
}

/// Store a stream into a segment field. Note that this renders the segment immutable after completing, and therefore works only once per segment.
Method StoreFieldStreamRaw(pStream As %Stream.Object, pPropertyPath As %String = "", pRemainder As %String, pProc As %String, ByRef pHint) As %Status
{
	Set tSegObj=..GetMutableSegmentAt($P(pPropertyPath,":",1),.tSC)  Quit:$$$ISERR(tSC) tSC
	Quit tSegObj.StoreFieldStreamRaw(.pStream,$P(pPropertyPath,":",2),.pRemainder,.pProc,.pHint)
}

/// Store a stream into a segment field, encoding as Base64. Note that this renders the segment immutable after completing, and therefore works only once per segment.
Method StoreFieldStreamBase64(pStream As %Stream.Object, pPropertyPath As %String = "", pRemainder As %String) As %Status
{
	Set tSegObj=..GetMutableSegmentAt($P(pPropertyPath,":",1),.tSC)  Quit:$$$ISERR(tSC) tSC
	Quit tSegObj.StoreFieldStreamBase64(.pStream,$P(pPropertyPath,":",2),.pRemainder)
}

/// Store a stream into a segment field, applying HL7 escaping. Note that this renders the segment immutable after completing, and therefore works only once per segment.
Method StoreFieldStreamEscaped(pStream As %Stream.Object, pPropertyPath As %String = "", pRemainder As %String) As %Status
{
	Set tSegObj=..GetMutableSegmentAt($P(pPropertyPath,":",1),.tSC)  Quit:$$$ISERR(tSC) tSC
	Quit tSegObj.StoreFieldStreamEscaped(.pStream,$P(pPropertyPath,":",2),.pRemainder)
}

/// Returns an array of links to manager pages for this type of VDoc; item 0 is the family description
ClassMethod GetManagerLinks(Output pColumns) As %Boolean
{
	Set iCol=0
	Set pColumns(iCol,"page")="http://www.hl7.org"
	Set pColumns(iCol,"name")=$$$Text("HL7 version 2")
	Set pColumns(iCol,"desc")=$$$Text("Health Level 7 version 2.x Message documents")
	
	Set iCol=iCol+1
	Set pColumns(iCol,"page")=##class(%CSP.Page).Link("HL7/HL7SchemaMain.csp")
	Set pColumns(iCol,"name")=$$$Text("Schema Structures")
	Set pColumns(iCol,"desc")=$$$Text("View schema definitions for various versions/categories of HL7 v2.x message types, structures, segments, fields, components and code tables")

	Set iCol=iCol+1
	Set pColumns(iCol,"page")=##class(%CSP.Page).Link("EDIDocumentView.csp?NAME="_$ZCVT("HL7 Message","O","URL")_"&CLASS=EnsLib.HL7.Message")
	Set pColumns(iCol,"name")=$$$Text("Message Viewer")
	Set pColumns(iCol,"desc")=$$$Text("View HL7 Messages from a variety of sources and test them with various DocType schema definitions and Data Transformations")
	Quit 1
}

/// Returns an array of links to manager pages for this type of VDoc; item 0 is the family description
ClassMethod GetNewManagerLinks(Output pColumns) As %Boolean
{
	Set iCol=0
	Set pColumns(iCol,"page")="http://www.hl7.org"
	Set pColumns(iCol,"name")=$$$Text("HL7 version 2")
	Set pColumns(iCol,"desc")=$$$Text("Health Level 7 version 2.x Message documents")
	
	Set iCol=iCol+1
	Set pColumns(iCol,"page")=##class(%CSP.Page).Link("EnsPortal.HL7.SchemaMain.cls")
	Set pColumns(iCol,"name")=$$$Text("Schema Structures")
	Set pColumns(iCol,"desc")=$$$Text("View schema definitions for various versions/categories of HL7 v2.x message types, structures, segments, fields, components and code tables")

	Set iCol=iCol+1
	Set pColumns(iCol,"page")=##class(%CSP.Page).Link("EDIDocumentView.csp?NAME="_$ZCVT("HL7 Message","O","URL")_"&CLASS=EnsLib.HL7.Message")
	Set pColumns(iCol,"name")=$$$Text("Message Viewer")
	Set pColumns(iCol,"desc")=$$$Text("View HL7 Messages from a variety of sources and test them with various DocType schema definitions and Data Transformations")
	Quit 1
}

/// Validates the HL7 message content against the schema that is referenced in its DocType property.
Method Validate(pValidationSpec As %String) As %Status [ CodeMode = expression ]
{
##class(EnsLib.HL7.Util.Validator).Validate($this,pValidationSpec)
}

/// Deprecated - to be removed
Method toEasyXML(ByRef xml As %GlobalCharacterStream, ByRef schema, pToDevice As %Boolean = 0) As %Status [ Internal ]
{
#define APPEND(%x,%s) If pToDevice { Write %s,! } Else { Do %x.WriteLine(%s) }

	Set xml = $S(pToDevice:$$$NULLOREF,1:##class(%GlobalCharacterStream).%New())

	Set name = $ZCVT(..GetMsgType(..Name),"O","XML")
	Set base = ..DocType
	Set:base'="" base=$G($$$vaSchemaGbl($P(..DocType,":"),"base"))
	Set:base="" base=$P(..DocType,":")
	
	$$$APPEND(xml,"<?xml version=""1.0"" encoding=""UTF-16""?>")
	$$$APPEND(xml,"<"_name_" docType="""_$ZCVT($P(..DocType,":"),"O","XML")_""">")
	For i = 1:1:..SegCount {
		Set segment = ..getSegmentByIndex(i)
		Do segment.toEasyXML(.xml,i,base,.schema,pToDevice)
	}
	$$$APPEND(xml,"</"_name_">")
	Do:'pToDevice xml.Rewind()
	Quit $$$OK
}

Storage Default
{
<Data name="MessageDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>ParentId</Value>
</Value>
<Value name="3">
<Value>DocType</Value>
</Value>
<Value name="4">
<Value>IsMutable</Value>
</Value>
<Value name="5">
<Value>TimeCreated</Value>
</Value>
<Value name="6">
<Value>MessageTypeCategory</Value>
</Value>
<Value name="7">
<Value>Source</Value>
</Value>
<Value name="8">
<Value>Envelope</Value>
</Value>
<Value name="9">
<Value>OriginalDocId</Value>
</Value>
</Data>
<Data name="UserValues">
<Attribute>UserValues</Attribute>
<Structure>subnode</Structure>
<Subscript>"UserValues"</Subscript>
</Data>
<DataLocation>^EnsLib.H.MessageD</DataLocation>
<DefaultData>MessageDefaultData</DefaultData>
<ExtentSize>2000000</ExtentSize>
<IdLocation>^EnsLib.H.MessageD</IdLocation>
<IndexLocation>^EnsLib.H.MessageI</IndexLocation>
<StreamLocation>^EnsLib.H.MessageS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
