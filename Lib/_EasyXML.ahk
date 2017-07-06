; TODO: This class with use native, AHK, object syntax for XMLS!!
; First pass at design should be through using Coco's XPath library
; I think I should remember to do this project because many people like XML
; This could also lead to further data sets such as, EasyCSV and/or EasyDelim (delim being user defined delimiter, including CSV)

_EasyXML(sFile="", sLoadFromStr="", sDocType="")
{
	return new EasyXML(sFile, sLoadFromStr)
}

class EasyXML
{
	__New(sFile="", sLoadFromStr="", sDocType="")
	{
		static s_sDocType := "msxml2.DOMDocument.6.0"

		; this := this.CreateXMLObj("EasyXML_ReservedFor_m_sFile", sFile)
		this.EasyXML_ReservedFor_m_sFile := sFile

		if (sFile == "" && sLoadFromStr == "")
			return this

		sTmpXMLFile := A_Temp "\EasyXML.xml"
		if (sFile)
			sXML := sFile
		else sXML := sTmpXMLFile

		if (sLoadFromStr)
		{
			; Delete tmp file
			FileDelete, %sXML%
			; Doc def TODO: Pass through class for new XMLs
			FileAppend, % "<?xml version=""1.0"" encoding=""windows-1252""?>", %sXML%
			FileAppend, %sLoadFromStr%, %sXML%
		}

		this.m_vDoc := ComObjCreate(sDocType ? sDocType : s_sDocType)
		this.m_vDoc.async := false
		this.m_vDoc.load(A_WorkingDir "\" sXML)

	if (this.m_vDoc.parseError.errorCode != 0)
	{
		myErr := this.m_vDoc.parseError
		Msgbox % "Error: " myErr.reason
	}

		; Parse XML and convert everything to AHK objects!!!
		s_iELEMENT_NODE := 1
		nodeList := this.m_vDoc.getElementsByTagName("*")
		loop % nodeList.length
		{
			vNode := nodeList.item(A_Index-1)
			if (vNode.NodeType == s_iELEMENT_NODE)
			{
				Msgbox % st_concat("`n", vNode.parentNode.NodeName, vNode.NodeName, vNode.xml)
			}
			else Msgbox % st_concat("`n", "Not a node", vNode.NodeName, vNode.NodeType)
		}

		; How to enumerate through object -- think through smart wrapper for the "for k, v" syntax.
		;objNodeList := this.m_vDoc.GetElementsByTagName("author")
		;Msgbox % st_concat("`n", objNodeList.item(2).text)

		;this._NewEnum := Func("EasyXML_NewEnum")

		this.m_sSelectNode := "*" ; this selects all nodes.
		return this
	}

	; sName is case-sensitive.
	__Get(sName)
	{
		if (this.HasKey(sName))
			return this[sName]

		; Try to retrieve a node. Assume user is interested only in the first match on sName.
		this.m_sSelectNode := sName
		return this._NewEnum()

		; Try to retrieve a node. Assume user is interested only in the first match on sName.
		return this.m_vDoc.getElementsByTagName(sName).item[0].text
	}

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: _NewEnum
			Purpose:
		Parameters
			
	*/
	_NewEnum()
	{
		; this.m_vDoc.childNodes.length ; num child nodes for root node
		this.EasyXML_ReservedFor_m_iIterator := -1
		return this
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function:
			Purpose:
		Parameters
			
	*/
	Next(ByRef k, ByRef v)
	{
		this.EasyXML_ReservedFor_m_iIterator++

		k := this.EasyXML_ReservedFor_m_iIterator

		if (k > this.m_vDoc.getElementsByTagName(this.m_sSelectNode).length)
			return false

		v := this.m_vDoc.getElementsByTagName(this.m_sSelectNode).item[k]

		Msgbox % st_concat("`n", A_ThisFunc "()", k , v)
		return true
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: Node
			Purpose: Select node
		Parameters
			sNode: node
	*/
	Node(sNode)
	{
		this.m_sSelectNode := sNode
		return this.m_vDoc.getElementsByTagName(this.m_sSelectNode)
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
}