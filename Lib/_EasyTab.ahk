_EasyTab(sFile="", sLoadFromStr="", bHasHeader=false)
{
	return new EasyTab(sFile, sLoadFromStr, bHasHeader)
}

class EasyTab
{
	__New(sFile="", sLoadFromStr="", bHasHeader=false) ; Loads ths file into memory.
	{
		this := this.CreateTabObj("EasyTab_ReservedFor_m_sFile", sFile
			, "EasyTab_ReservedFor_m_bHasHeader", bHasHeader)

		if (sFile == A_Blank && sLoadFromStr == A_Blank)
			return this

		; If no file extensions assume ".tab", otherwise leave it alone (see also Save method)
		if (!InStr(SubStr(sFile, StrLen(sFile)-7), "."))
			this.EasyTab_ReservedFor_m_sFile := sFile := (sFile . ".tab")

		sTab := sLoadFromStr
		if (sTab == A_Blank)
			FileRead, sTab, %sFile%
/*
	Current design:
	--------------------------------------------------------------------------------------------------------------------------------------------------
	Standard AHK Tab parsing pretty much completely determines how fields are read in
	Here's an example of how the data will be mapped and how you can manipulate it

	header1, header2
	Field1    ,  Field2
	Field1    ,  Field2

	; TODO: Store by column, then row.
		This is because there *must* be a row for each column,
		 but there doesn't have to be a column for each row.

	for iRow, aRowData in vTab
		for iCol, val in aRowData
			Msgbox Row:`t%iRow%`nCol:`t%iCol%`nVal:`t%val%

	; OR
	iRow := 1
	iCol := 1
	vTab[iRow][iCol] ; = Field1
	vTab[iRow][iCol] := "NewField" ; Changes from Field1 to NewField

	; OR
	vTab.1.1 ; = Field1
	vTab.1.1 := "NewField" ; Changes from Field1 to NewField
	--------------------------------------------------------------------------------------------------------------------------------------------------
*/

		;if (this.GetHasHeader())
			;this[1, this.GetHeaderRow()] := ; This allows us to

		aHeaderMap := []
		Loop, Parse, sTab, `n, `r
		{
			iRow := A_Index
			Loop, Parse, A_LoopField, `t
			{
				if (this.GetHasHeader())
				{
					if (iRow == 1)
					{
						aHeaderMap[A_Index] := A_LoopField
						this[A_LoopField, this.GetHeaderRow()] := A_LoopField
					}
					else this[aHeaderMap[A_Index], iRow] := A_LoopField
				}
				else this[A_Index, iRow] := A_LoopField
			}
		}

		return this
	}

	CreateTabObj(parms*)
	{
		; Define prototype object for Tab arrays:
		static base := {__Set: "EasyTab_Set", _NewEnum: "EasyTab_NewEnum", Remove: "EasyTab_Remove"
			, Insert: "EasyTab_Insert" , InsertBefore: "EasyTab_InsertBefore"
			; Cols
			, AddCol: "EasyTab.AddCol", DeleteCol: "EasyTab.DeleteCol", GetCol: "EasyTab.GetCol", GetNumCols: "EasyTab.GetNumCols"
			; Rows
			, AddRow: "EasyTab.AddRow", DeleteRow: "EasyTab.DeleteRow", GetRow: "EasyTab.GetRow", GetNumRows: "EasyTab.GetNumRows"
			, FindSecs: "EasyTab.FindSecs", FindKeys: "EasyTab.FindKeys", GetVals: "EasyTab.GetVals", FindVals: "EasyTab.FindVals"
			, HasVal: "EasyTab.HasVal", Copy: "EasyTab.Copy", Merge: "EasyTab.Merge", Save: "EasyTab.Save"
			, GetFileName: "EasyTab.GetFileName", GetHasHeader: "EasyTab.GetHasHeader", GetHeaderRow: "EasyTab.GetHeaderRow"}

		; Create and return new object:
		return Object("_keys", Object(), "base", base, parms*)
	}

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: AddCol
			Purpose: To add a column
		Parameters
			sHeader="": Should only be non-blank when EasyTab has been set to have a header.
			rsError
	*/
	AddCol(sHeader="", ByRef rsError="")
	{
		; TODO: Int/Header support (I'm thinking headers are stored at 0, and they may be referenced literally).
		; I think headers should be stored in a separate object, too.

		if (sHeader && !this.GetHasHeader())
		{
			rsError := "Error: trying to set header, """ sHeader """ on a non-header Tab object."
			return false
		}

		this.Insert(EasyTab_CreateBaseObj())
		iCol := this.MaxIndex()

		if (sHeader)
			this[iCol, this.GetHeaderRow()] := sHeader

		return iCol
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: DeleteCol
			Purpose: To delete a column
		Parameters
			iCol: Column to delete
	*/
	DeleteCol(iCol)
	{
		this.Remove(iCol)
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GetCol
			Purpose: Gets data for iCol
		Parameters
			iCol
			sDelim=","
	*/
	GetCol(iCol, sDelim=",")
	{
		for iRow, cell in this[iCol]
			sCol .= (A_Index > 1 ? sDelim : "") . cell

		return sCol
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GetNumCols
			Purpose:
		Parameters
			
	*/
	GetNumCols()
	{
		return this.MaxIndex()
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: AddRow
			Purpose:
		Parameters
			rsError=""
	*/
	AddRow(ByRef rsError)
	{
		;~ for iCol in this
		; Adding one to every col takes a lot of time, and I don't think it is necessary.
		; However, I should verify this -- Verdlin: 5/26/14.
		this.1.Insert("") ; Insert adds new row.

		iRow := this.1.MaxIndex()
		if (iRow == A_Blank)
		{
			rsError := "Error: Thre is no row for column 1.`nThis usually happens when you have not added a column first."
			return
		}
		return iRow
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: DeleteRow
			Purpose: Deletes a iRow from *all* columns, of course.
		Parameters
			iRow
	*/
	DeleteRow(iRow)
	{
		if (!this.1.HasKey(iRow))
			return ; Nothing to delete.

		for iCol, in this
			this[iCol].Remove(iRow)
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GetRow
			Purpose: Gets data for iRow
		Parameters
			iRow
			sDelim=","
	*/
	GetRow(iRow, sDelim="`t")
	{
		for iCol, aRowData in this
			sRow .= (sRow == "" ? "" : sDelim) . aRowData[iRow]
		return sRow
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GetNumRows
			Purpose: Returns total number of rows.
		Parameters
			
	*/
	GetNumRows()
	{
		if (this.GetHasHeader())
		{
			; Grab first key.
			for sec in this
				break
			return this[sec].MaxIndex()
		}
		return this.1.MaxIndex()
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	GetKeys(sec, sDelim="`n")
	{
		for key in this[sec]
			keys .= A_Index == 1 ? key : sDelim key
		return keys
	}

	FindKeys(sec, sExp, iMaxKeys="")
	{
		aKeys := []
		for key in this[sec]
		{
			if (RegExMatch(key, sExp))
			{
				aKeys.Insert(key)
				if (iMaxKeys && aKeys.MaxIndex() == iMaxKeys)
					return aKeys
			}
		}
		return aKeys
	}

	; Non-regex, exact match on key
	; returns key(s) and their assocationed section(s)
	FindExactKeys(key, iMaxKeys="")
	{
		aKeys := {}
		for sec, aData in this
		{
			if (aData.HasKey(key))
			{
				aKeys.Insert(sec, key)
				if (iMaxKeys && aKeys.MaxIndex() == iMaxKeys)
					return aKeys
			}
		}
		return aKeys   
	}

	GetVals(sec, sDelim="`n")
	{
		for key, val in this[sec]
			vals .= A_Index == 1 ? val : sDelim val
		return vals
	}

	FindVals(sec, sExp, iMaxVals="")
	{
		aVals := []
		for key, val in this[sec]
		{
			if (RegExMatch(val, sExp))
			{
				aVals.Insert(val)
				if (iMaxVals && aVals.MaxIndex() == iMaxVals)
					break
			}
		}
		return aVals
	}

	HasVal(sec, FindVal)
	{
		for k, val in this[sec]
			if (FindVal = val)
				return true
		return false
	}

	Copy(vSourceTab, sDestTabFile="")
	{
		this := vSourceTab
		this.EasyTab_ReservedFor_m_sFile := sDestTabFile
		return this
	}

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;; Merge two EasyTab objects. Favors existing EasyTab object, meaning that any key that exists in both objects keeps the original val
	;;;;;;;;;;;;;; UNDER CONSTRUCTION
	Merge(vOtherTab, bRemoveNonMatching = false)
	{
		; TODO: Perhaps just save one Tab, read it back in, and then perform merging? I think this would help with formatting.
		; [Sections]
		for sec, aKeysAndVals in vOtherTab
		{
			if (!this.HasKey(sec))
				if (bRemoveNonMatching)
					this.DeleteRow(sec)
				else this.AddSection(sec)

			; key=val
			for key, val in aKeysAndVals
				if (!this[sec].HasKey(key))
					if (bRemoveNonMatching)
						this.DeleteKey(sec, key)
					else this.AddCol(sec, key, val)
		}
		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GetFileName
			Purpose: Wrapper to return the extremely long named member var, EasyTab_ReservedFor_m_sFile
		Parameters
			None
	*/
	GetFileName()
	{
		return this.EasyTab_ReservedFor_m_sFile
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GetHasHeader
			Purpose: Wrapper to return the extremely long named member var, EasyTab_ReservedFor_m_bHasHeader
		Parameters
			
	*/
	GetHasHeader()
	{
		return this.EasyTab_ReservedFor_m_bHasHeader
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GetHeaderRow
			Purpose: To keep hard-coding for header row in one place.
		Parameters
			
	*/
	GetHeaderRow()
	{
		return 1
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: IsEmpty
			Purpose: To indicate whether or not this Tab has data
		Parameters
			None
	*/
	IsEmpty()
	{
		return (this.GetColumns() == A_Blank) ; No columns.
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: Reload
			Purpose: Reloads object from Tab file. This is necessary when other routines may be modifying the same Tab file.
		Parameters
			None
	*/
	Reload()
	{
		if (FileExist(this.GetFileName()))
			this := _EasyTab(this.GetFileName(), this.GetHasHeader())
		return this ; else nothing to reload.
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; TODO: Option to store load and save times in comment at bottom of Tab?
	Save(sSaveAs="")
	{
		sFile := (sSaveAs == A_Blank ? this.EasyTab_ReservedFor_m_sFile : sSaveAs)

		if (!InStr(SubStr(sFile, StrLen(sFile)-7), "."))
			sFile .= ".tab"

		; Formatting is preserved in Tab class object
		FileDelete, %sFile%
		bIsFirstLine := true
		iRows := this.GetNumRows()

		Loop %iRows%
		{
			iRow := (this.GetHasHeader() ? A_Index - 1 : A_Index)
			sRow := this.GetRow(iRow)

			if (bIsFirstLine)
				FileAppend, %sRow%, %sFile%
			else FileAppend, `n%sRow%, %sFile%

			bIsFirstLine := false
		}

		return
	}
}

; For all of the EasyTab_* functions below, much credit is due to Lexikos and Rbrtryn for their work with ordered arrays
; See http://www.autohotkey.com/board/topic/61792-ahk-l-for-loop-in-order-of-key-value-pair-creation/?p=389662 for Lexikos's initial work with ordered arrays
; See http://www.autohotkey.com/board/topic/94043-ordered-array/#entry592333 for Rbrtryn's OrderedArray lib
EasyTab_CreateBaseObj(parms*)
{
	; Define prototype object for ordered arrays:
	static base := {__Set: "EasyTab_Set", _NewEnum: "EasyTab_NewEnum", Remove: "EasyTab_Remove", Insert: "EasyTab_Insert", InsertBefore: "EasyTab_InsertBefore"}
	; Create and return new base object:
	return Object("_keys", Object(), "base", base, parms*)
}

EasyTab_Set(obj, parms*)
{
	; If this function is called, the key must not already exist.
	; Sub-class array if necessary then add this new key to the key list, if it doesn't begin with "EasyTab_ReservedFor_"
	if parms.maxindex() > 2
		ObjInsert(obj, parms[1], EasyTab_CreateBaseObj())

	; Skip over member variables
	if (SubStr(parms[1], 1, 20) <> "EasyTab_ReservedFor_")
		ObjInsert(obj._keys, parms[1])
	; Since we don't return a value, the default behaviour takes effect.
	; That is, a new key-value pair is created and stored in the object.
}

EasyTab_NewEnum(obj)
{
	; Define prototype object for custom enumerator:
	static base := Object("Next", "EasyTab_EnumNext")
	; Return an enumerator wrapping our _keys array's enumerator:
	return Object("obj", obj, "enum", obj._keys._NewEnum(), "base", base)
}

EasyTab_EnumNext(e, ByRef k, ByRef v="")
{
	; If Enum.Next() returns a "true" value, it has stored a key and
	; value in the provided variables. In this case, "i" receives the
	; current index in the _keys array and "k" receives the value at
	; that index, which is a key in the original object:
	if r := e.enum.Next(i,k)
		; We want it to appear as though the user is simply enumerating
		; the key-value pairs of the original object, so store the value
		; associated with this key in the second output variable:
		v := e.obj[k]
	return r
}

EasyTab_Remove(obj, parms*)
{
	r := ObjRemove(obj, parms*)         ; Remove keys from main object
	Removed := []                     
	for k, v in obj._keys             ; Get each index key pair
		if not ObjHasKey(obj, v)      ; if key is not in main object
			Removed.Insert(k)         ; Store that keys index to be removed later
	for k, v in Removed               ; For each key to be removed
		ObjRemove(obj._keys, v, "")   ; remove that key from key list
	return r
}

EasyTab_Insert(obj, parms*)
{
	r := ObjInsert(obj, parms*)            ; Insert keys into main object
	enum := ObjNewEnum(obj)              ; Can't use for-loop because it would invoke EasyTab_NewEnum
	while enum[k] {                      ; For each key in main object
		for i, kv in obj._keys           ; Search for key in obj._keys
			if (k = "_keys" || k = kv || SubStr(k, 1, 20) = "EasyTab_ReservedFor_" || SubStr(kv, 1, 20) = "EasyTab_ReservedFor_")   ; If found...
				continue 2               ; Get next key in main object
		ObjInsert(obj._keys, k)          ; Else insert key into obj._keys
	}
	return r
}

EasyTab_InsertBefore(obj, key, parms*)
{
	OldKeys := obj._keys                 ; Save key list
	obj._keys := []                      ; Clear key list
	for idx, k in OldKeys {              ; Put the keys before key
		if (k = key)                     ; back into key list
			break
		obj._keys.Insert(k)
	}

	r := ObjInsert(obj, parms*)            ; Insert keys into main object
	enum := ObjNewEnum(obj)              ; Can't use for-loop because it would invoke EasyTab_NewEnum
	while enum[k] {                      ; For each key in main object
		for i, kv in OldKeys             ; Search for key in OldKeys
			if (k = "_keys" || k = kv)   ; If found...
				continue 2               ; Get next key in main object
		ObjInsert(obj._keys, k)          ; Else insert key into obj._keys
	}

	for i, k in OldKeys {                ; Put the keys after key
		if (i < idx)                     ; back into key list
			continue
		obj._keys.Insert(k)
	}
	return r
}