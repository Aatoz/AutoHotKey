class_EasyCSV(sFile="", sLoadFromStr="", bHasHeader=true)
{
	return new EasyCSV(sFile, sLoadFromStr, bHasHeader)
}

class EasyCSV
{
	__New(sFile="", sLoadFromStr="", bHasHeader=true) ; Loads ths file into memory.
	{
		this := this.CreateCSVObj("EasyCSV_ReservedFor_m_sFile", sFile, "EasyCSV_ReservedFor_m_bHasHeader", bHasHeader)

		if (sFile == A_Blank && sLoadFromStr == A_Blank)
			return this

		if (SubStr(sFile, StrLen(sFile)-3, 4) != ".csv")
			sFile .= ".csv"

		sCSV := sLoadFromStr
		if (sCSV == A_Blank)
			FileRead, sCSV, %sFile%
/*
	Current design:
	--------------------------------------------------------------------------------------------------------------------------------------------------
	Standard AHK CSV parsing pretty much completely determines how fields are read in
	Here's an example of how the data will be mapped and how you can manipulate it

	header1, header2
	Field1    ,  Field2
	Field1    ,  Field2

	for iRow, aRowData in vCSV
		for iCol, val in aRowData
			Msgbox Row:`t%iRow%`nCol:`t%iCol%`nVal:`t%val%

	; OR
	iRow := 1
	iCol := 1
	vCSV[iRow][iCol] ; = Field1
	vCSV[iRow][iCol] := "NewField" ; Changes from Field1 to NewField

	; OR
	vCSV.1.1 ; = Field1
	vCSV.1.1 := "NewField" ; Changes from Field1 to NewField
	--------------------------------------------------------------------------------------------------------------------------------------------------
*/

		Loop, Parse, sCSV, `n, `r
		{
			iRow := A_Index
			this[iRow] := EasyCSV_CreateBaseObj()

			Loop, Parse, A_LoopField, CSV
				this[iRow].Insert(A_Index, A_LoopField)
		}

		return this
	}

	CreateCSVObj(parms*)
	{
		; Define prototype object for CSV arrays:
		static base := {__Set: "EasyCSV_Set", _NewEnum: "EasyCSV_NewEnum", Remove: "EasyCSV_Remove", Insert: "EasyCSV_Insert", InsertBefore: "EasyCSV_InsertBefore", AddSection: "EasyCSV.AddSection", RenameSection: "EasyCSV.RenameSection", DeleteSection: "EasyCSV.DeleteSection", GetSections: "EasyCSV.GetSections", FindSecs: "EasyCSV.FindSecs", AddKey: "EasyCSV.AddKey", RenameKey: "EasyCSV.RenameKey", DeleteKey: "EasyCSV.DeleteKey", GetKeys: "EasyCSV.GetKeys", FindKeys: "EasyCSV.FindKeys", GetVals: "EasyCSV.GetVals", FindVals: "EasyCSV.FindVals", HasVal: "EasyCSV.HasVal", Copy: "EasyCSV.Copy", Merge: "EasyCSV.Merge", Save: "EasyCSV.Save"}
		; Create and return new object:
		return Object("_keys", Object(), "base", base, parms*)
	}

	; if row is blank, the column is added to every row.
	AddCol(header, row="", field="", ByRef rsError="")
	{
		if (row != A_Blank && abs(row) == A_Blank) ; is not number doesn't seem to work
		{
			rsError := "Error: Could not add row " row " because that is not a number."
			return false
		}

		if (row == A_Blank)
			for iRow in this
				this[iRow].Insert(field)
		else
		{
			if (this.HasKey(row))
				this[row].Insert(field)
			else
			{
				rsError := "Error: Could not add row " row " because it already exists."
				return false
			}
		}

		return true
	}

	RenameCol(oldCol, newCol, ByRef rsError="")
	{
		if (!this.HasKey(oldCol))
		{
			rsError := "Error: Could not rename section [" oldCol "], because it does not exist."
			return false
		}

		aKeyValsCopy := this[oldCol]
		this.DeleteSection(oldCol)
		this[newCol] := aKeyValsCopy
		return true
	}

	DeleteSection(sec)
	{
		this.Remove(sec)
		return
	}

	GetSections(sDelim="`n")
	{
		for sec in this
			secs .= (A_Index == 1 ? sec : sDelim sec)
		return secs
	}

	FindSecs(sExp, iMaxSecs="")
	{
		aSecs := []
		for sec in this
		{
			if (RegExMatch(sec, sExp))
			{
				aSecs.Insert(sec)
				if (iMaxSecs&& aSecs.MaxIndex() == iMaxSecs)
					return aSecs
			}
		}
		return aSecs
	}

	AddKey(sec, key, val="", ByRef rsError="")
	{
		if (this.HasKey(sec))
		{
			if (this[sec].HasKey(key))
			{
				rsError := "Error: Could not add key because there is an key in the same section:`n`[" sec "]`n" key
				return false
			}
		}
		else
		{
			rsError := "Error: Could not add key`, " key " because Section " sec " does not exist."
			return false
		}
		this[sec, key] := val
		return true
	}

	RenameKey(sec, OldKey, NewKey, ByRef rsError="")
	{
		if (!this[sec].HasKey(OldKey))
		{
			rsError := "Error: The specified key " OldKey " could not be modified because it does not exist."
			return false
		}

		ValCopy := this[sec][OldKey]
		this.DeleteKey(sec, OldKey)
		this.AddKey(sec, NewKey)
		this[sec][NewKey] := ValCopy
		return true
	}

	DeleteKey(sec, key)
	{
		this[sec].Remove(key)
		return
	}

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

	Copy(vSourceCSV, sDestCSVFile="")
	{
		this := vSourceCSV
		this.EasyCSV_ReservedFor_m_sFile := sDestCSVFile
		return this
	}

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;; Merge two EasyCSV objects. Favors existing EasyCSV object, meaning that any key that exists in both objects keeps the original val
	;;;;;;;;;;;;;; UNDER CONSTRUCTION
	Merge(vOtherCSV, bRemoveNonMatching = false)
	{
		; TODO: Perhaps just save one CSV, read it back in, and then perform merging? I think this would help with formatting.
		; [Sections]
		for sec, aKeysAndVals in vOtherCSV
		{
			if (!this.HasKey(sec))
				if (bRemoveNonMatching)
					this.DeleteSection(sec)
				else this.AddSection(sec)

			; key=val
			for key, val in aKeysAndVals
				if (!this[sec].HasKey(key))
					if (bRemoveNonMatching)
						this.DeleteKey(sec, key)
					else this.AddKey(sec, key, val)
		}
		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; TODO: Option to store load and save times in comment at bottom of CSV?
	Save(sSaveAs="")
	{
		sFile := (sSaveAs == A_Blank ? this.EasyCSV_ReservedFor_m_sFile : sSaveAs)

		if (SubStr(sFile, StrLen(sFile)-3, 4) != ".csv")
			sFile .= ".csv"

		; Formatting is preserved in CSV class object
		FileDelete, %sFile%

		for iRow, aRowData in this
		{
			if (A_Index > 1)
				FileAppend, `n, %sFile%

			for iCol, val in aRowData
				FileAppend, % (A_Index > 1 ? "," : "") val, %sFile%
		}

		return
	}
}

; For all of the EasyCSV_* functions below, much credit is due to Lexikos and Rbrtryn for their work with ordered arrays
; See http://www.autohotkey.com/board/topic/61792-ahk-l-for-loop-in-order-of-key-value-pair-creation/?p=389662 for Lexikos's initial work with ordered arrays
; See http://www.autohotkey.com/board/topic/94043-ordered-array/#entry592333 for Rbrtryn's OrderedArray lib
EasyCSV_CreateBaseObj(parms*)
{
	; Define prototype object for ordered arrays:
	static base := {__Set: "EasyCSV_Set", _NewEnum: "EasyCSV_NewEnum", Remove: "EasyCSV_Remove", Insert: "EasyCSV_Insert", InsertBefore: "EasyCSV_InsertBefore"}
	; Create and return new base object:
	return Object("_keys", Object(), "base", base, parms*)
}

EasyCSV_Set(obj, parms*)
{
	; If this function is called, the key must not already exist.
	; Sub-class array if necessary then add this new key to the key list, if it doesn't begin with "EasyCSV_ReservedFor_"
	if parms.maxindex() > 2
		ObjInsert(obj, parms[1], EasyCSV_CreateBaseObj())

	; Skip over member variables
	if (SubStr(parms[1], 1, 20) <> "EasyCSV_ReservedFor_")
		ObjInsert(obj._keys, parms[1])
	; Since we don't return a value, the default behaviour takes effect.
	; That is, a new key-value pair is created and stored in the object.
}

EasyCSV_NewEnum(obj)
{
	; Define prototype object for custom enumerator:
	static base := Object("Next", "EasyCSV_EnumNext")
	; Return an enumerator wrapping our _keys array's enumerator:
	return Object("obj", obj, "enum", obj._keys._NewEnum(), "base", base)
}

EasyCSV_EnumNext(e, ByRef k, ByRef v="")
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

EasyCSV_Remove(obj, parms*)
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

EasyCSV_Insert(obj, parms*)
{
	r := ObjInsert(obj, parms*)            ; Insert keys into main object
	enum := ObjNewEnum(obj)              ; Can't use for-loop because it would invoke EasyCSV_NewEnum
	while enum[k] {                      ; For each key in main object
		for i, kv in obj._keys           ; Search for key in obj._keys
			if (k = "_keys" || k = kv || SubStr(k, 1, 20) = "EasyCSV_ReservedFor_" || SubStr(kv, 1, 20) = "EasyCSV_ReservedFor_")   ; If found...
				continue 2               ; Get next key in main object
		ObjInsert(obj._keys, k)          ; Else insert key into obj._keys
	}
	return r
}

EasyCSV_InsertBefore(obj, key, parms*)
{
	OldKeys := obj._keys                 ; Save key list
	obj._keys := []                      ; Clear key list
	for idx, k in OldKeys {              ; Put the keys before key
		if (k = key)                     ; back into key list
			break
		obj._keys.Insert(k)
	}

	r := ObjInsert(obj, parms*)            ; Insert keys into main object
	enum := ObjNewEnum(obj)              ; Can't use for-loop because it would invoke EasyCSV_NewEnum
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