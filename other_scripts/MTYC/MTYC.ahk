/*
*************************************************************************************
*************************** MTYC Employee Log Helper ***************************
*************************************************************************************

License: NO LICENSE
	I (Noah Graydon) retain all rights and do not permit distribution, reproduction, or derivative works. I soley grant GitHub the required rights according to their terms of service; namely, GitHub users may view and fork this code.

Credits (See ReadMe.txt)

*/

#SingleInstance Force
SetBatchLines -1 ; Needed for StartHotkeyThread().
SetWinDelay, -1
SendMode, Input
SetWorkingDir, %A_ScriptDir%

if (A_IsCompiled)
	DoFileInstalls()

Menu, TRAY, Icon, images\Logo.ico,, 1

Menu, TRAY, NoStandard
Menu, TRAY, MainWindow ; For compiled scripts

if (A_IsCompiled)
	Menu, TRAY, Add, E&xit, ExitApp
else Menu, TRAY, Add, &Quit, ExitApp ; Just for my own convenience.

; Process command line first.
Loop %0% ; for each parameter
{
	sParm := %A_Index%
	if (sParm = "Admin")
		g_bIsAdmin := true
}

StartSplashProgress()
SetupSplashProgress("Loading spreadsheet", 3)

; Then initialize everything.
Init()

; Administrative run or vanilla employee run?
if (g_bIsAdmin)
	InitAdminGUI()
else AddLogEntry()

EndSplashProgress()

return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: Init
		Purpose: Initialize front-end application.
	Parameters
		
*/
Init()
{
	global g_vExcelApp
	global g_vConfigInfo := class_EasyIni("config.ini")
	UpdateSplashProgress(1) ; 1. Loaded ini

	; Merge config inis
	vDefaultConfigInfo := class_EasyIni("", GetDefaultConfigIni())
	g_vConfigInfo.Merge(vDefaultConfigInfo)

	sPath := g_vConfigInfo.config.path
	if (!FileExist(sPath))
		sPath := ; If a bad path is selected, then prompt for a good path.

	while (!sPath)
	{
		FileSelectFile, sPath,,, Navigate to MTYC spreadsheet...
		if (!sPath)
		{
			if (Msgbox_YesNo("Exit Application", "No spreadsheet selected.`n`nAre you sure you want to exit the application?"))
				gosub ExitApp
		}
	}
	g_vConfigInfo.config.Path := sPath
	g_vConfigInfo.Save() ; Save this change.

	g_vExcelApp := ComObjCreate("Excel.Application")
	g_vExcelApp.Workbooks.Open(sPath)
	g_vExcelApp.Visible := g_vConfigInfo.config.DebugRun
	UpdateSplashProgress(2) ; 2. Opened workbook.

	global g_vMTYC_WB := g_vExcelApp.Workbooks(1)

	; Okay, disallow running this program while the workbook is already open in Excel
	; Why? Because Excel will open THIS instance in Read-Only mode! No good!
	if (g_vMTYC_WB.ReadOnly)
	{
		Msgbox_Error("This workbook is already open in another instance of Excel. "
			. "In order to edit this spreadsheet, you must first exit it in Excel."
			. "`n`nWorksheet:`t" sPath "`n`nThis program will exit after this message is dismissed.", 0)
		gosub ExitApp
	}

	; Create a backup before editing.
	BackupWorkbook(g_vMTYC_WB)
	UpdateSplashProgress(3) ; 3. Backed up workbook.

	MapSheetsToObjects()

	; For ease-of-access, map data entry to data info
	; This helps with setting up the GUI first and then data entry from the GUI second.
	MapDataEntryToDataInfo()
	MapIntKeysToIntVals_InEmployeeTemplate()

	InitLogEntryGUI()

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: InitLogEntryGUI()
		Purpose: Set up the data entry GUI
	Parameters
		
*/
InitLogEntryGUI()
{
	global

	static s_iMSDNStdBtnW := 75
	static s_iMSDNStdBtnH := 23+5 ; icon height is 24
	static s_iMSDNStdBtnSpacing := 6

	; Loop over all columns in this spd, creating data entry controls dynamically.
	; We are going to assume the columns are the same between ALL employee spds.
	; This is a bit yuck, but probably not ever going to be a problem.

; Data entry
	local k
		, iTotalCols := 0
		, vCell :=
		, vDataEntrySpd := g_vIntSheetMap["DataEntry"]
		, vMapSpdDataTypeToGUIDataType := {Date: "DateTime", Time: "DateTime", List: "DDL", Text: "Edit"}
		, aEmployees := []

	GUI, LogEntry_: New, +hwndg_hLogEntry, Log Entry Helper
	; Context-GUI; needed to select employee sheet for contextual editing.
	GUI, Add, Text, xm ym Center vg_vSheetText, % vDataEntrySpd.cells(2, 2).Text ; ID is the first column in data entry spd.
	GUI, Add, DDL, vg_vSheetDDL AltSubmit, % GetListOfEmployees()
	GUIControlGet, g_iSheetDDL_, Pos, g_vSheetDDL ; Apparently if these variables are local then they stay blank...

	; X is determined after we finish looping.
	GUI, Add, Button, % "xm y" g_iSheetDDL_Y+g_iSheetDDL_H+(s_iMSDNStdBtnSpacing*2) " w" s_iMSDNStdBtnW-3 " h" s_iMSDNStdBtnH " Left vg_vSheetEntryOKBtn hwndg_hSheetEntryOKBtn gLogEntry_OnSheetEntry", &Next
	ILButton(g_hSheetEntryOKBtn, "images\Next.ico", 24, 24, 1)
	GUI, Add, Button, % "xp yp wp hp Right vg_vSheetCancelBtn hwndg_hSheetCancelBtn gLogEntry_GUIEscape", &Cancel
	ILButton(g_hSheetCancelBtn, "images\Prev.ico", 24, 24, 0)

	; Paranoia: if somehow ALL the list items really small, then the control will be too narrow for the Prev/OK buttons below it.
	if (g_iSheetDDL_W < 160)
		g_iSheetDDL_W := 160
	local iWidestCtrl := g_iSheetDDL_W, iLogEntry := 0
	; Create a data entry interface for each data entry object.
	SetupSplashProgress("Creating user interface", vDataEntrySpd.UsedRange.Columns)
	for k in vDataEntrySpd.UsedRange.Columns ; go through all used columns on row 1
	{
		IncSplashProgress()
		iCol := A_Index

		; Column 1 is a helper column which is a side-heading to help we who read the spd.
		; Apparently you can't use iCol but you can use A_Index...
		local sDataType := vDataEntrySpd.cells(3, A_Index).Text
		if (iCol == 1 || sDataType = "Formula" || !sDataType)
		{
			iSkipCnt++
			continue
		}

		; Careful. A_Index represents iCol in the spd but iLogEntry represents the GUI entries.
		iLogEntry++

		local sHelperText := vDataEntrySpd.cells(2, A_Index).Text
		GUI, Add, Text, xm ym Center Hidden vg_vText%iLogEntry%, %sHelperText%
		; We need to keep track of the widest text beacuse that determines the width of the GUI
		GUIControlGet, g_iText_, Pos, g_vText%iLogEntry%
		iWidestCtrl := (g_iText_W > iWidestCtrl ? g_iText_W : iWidestCtrl)

		local sDefault :=, sTimeSpinner :=, sWidthOverride :=
		sGUIDataType := vMapSpdDataTypeToGUIDataType[sDataType]
		if (sGUIDataType = "DDL")
		{
			sListID := vDataEntrySpd.cells(1, A_Index).Text
			sDefault := st_glue(GetListFromSheet(sListID), "|")
		}
		if (sDataType = "Time")
		{
			sDefault := "h:mm tt" ; for DateTime, this specifies whether to use Date or Time.
			sTimeSpinner := "1"
		}

		GUI, Add, %sGUIDataType%, Hidden vg_vLogEntry%iLogEntry% %sTimeSpinner%, %sDefault%
		GUIControlGet, iLogEntry%iLogEntry%_, Pos, g_vLogEntry%iLogEntry%

		; X is determined after we've finished looping.
		GUI, Add, Button, % "y" iLogEntry%iLogEntry%_Y+iLogEntry%iLogEntry%_H+(s_iMSDNStdBtnSpacing*2) " w" s_iMSDNStdBtnW " h" s_iMSDNStdBtnH " Hidden Left gLogEntry_OnLogEntry vg_vLogEntryOKBtn" iLogEntry " hwndg_hLogEntryNextBtn" iLogEntry
		, &Next
		ILButton(g_hLogEntryNextBtn%iLogEntry%, "images\Next.ico", 24, 24, 1)
		GUI, Add, Button, % "xp yp wp hp Hidden Right gLogEntry_OnCancelBtn vg_vLogEntryPrevBtn" iLogEntry " hwndg_hLogEntryPrevBtn" iLogEntry, &Previous
		ILButton(g_hLogEntryPrevBtn%iLogEntry%, "images\Prev.ico", 24, 24, 0)

		; This is to keep track of which log entry we are on.
		iCol2 := vDataEntrySpd.cells(1, A_Index).Column
		GUI, Add, Text, x-10 y-10 w0 h0 Hidden Disabled vg_vIntLogEntryCol%iLogEntry%, %iCol2%
	}
	g_iTotalLogEntries := iLogEntry
	g_iCurLogEntryNdx := 1
	g_avRunningLog := []

	; Calc the GUI Width
	g_iLogEntryW := (g_iSheetDDL_X*2)+iWidestCtrl

	; Widen the sheet ctrls to match the GUI width.
	GUIControl, Move, g_vSheetText, w%iWidestCtrl%
	GUIControl, Move, g_vSheetDDL, w%iWidestCtrl%
	GUIControlGet, iSheetOKBtn_, Pos, g_vSheetEntryOKBtn
	GUIControl, Move, g_vSheetCancelBtn, % "x" iSheetOKBtn_X
	GUIControl, Move, g_vSheetEntryOKBtn, % "x" g_iLogEntryW-iSheetOKBtn_W-iSheetOKBtn_X
	GUIControlGet, g_iSheetTextStart_, Pos, g_vSheetText
	GUIControlGet, g_iSheetDDLStart_, Pos, g_vSheetDDL
	GUIControlGet, g_iSheetCancelBtnStart_, Pos, g_vSheetCancelBtn
	GUIControlGet, g_iSheetEntryOKBtnStart_, Pos, g_vSheetEntryOKBtn

	; 1. Move hidden ctrls to just be off the screen (it's important all are in the same place so TurnPage() works properly).
	; 2. Widen hidden ctrls to match the GUI width.
	g_iLogEntryBtnStart_X := g_iLogEntryW+iWidestCtrl-s_iMSDNStdBtnW+1
	loop % g_iTotalLogEntries
	{
		GUIControl, Move, g_vText%A_Index%, x%g_iLogEntryW%
		GUIControl, Move, g_vLogEntry%A_Index%, x%g_iLogEntryW% w%iWidestCtrl%
		GUIControl, Move, g_vLogEntryPrevBtn%A_Index%, % "x" g_iLogEntryW-1 ; This isn't technically correct but looks better to me.
		GUIControl, Move, g_vLogEntryOKBtn%A_Index%, % "x" g_iLogEntryBtnStart_X
	}

	return


	LogEntry_OnSheetEntry:
	{
		GUI, LogEntry_: Default
		GUIControlGet, g_vSheetDDL,, g_vSheetDDL, Text

		if (!g_vSheetDDL)
		{
			Msgbox_Error("You must select a sheet.")
			GUIControl, Focus, g_vSheetDDL
			return
		}

		GUIControlGet, iSheetSel,, g_vSheetDDL
		g_vEmployeeSpd := g_avEmployeeSpds[iSheetSel]
		sName := g_vEmployeeSpd.Name
		; Copy/Paste fails if this isn't the active worksheet.
		; This is also just a good principle.
		g_vEmployeeSpd.Activate

		; Map internal keys to vals in this employee spd
		g_IntKeysToIntVals_InEmployeeSpd := MapIntKeysToIntVals_InSpd(g_vEmployeeSpd)

		; Insert row in the spd now because we can undo any changes, even deleting the row entirely, if necessary.
		; Doing copy/paste proc in order to bring over formatting and formulas.
		g_iLogEntryInsertRow := g_IntKeysToIntVals_InEmployeeSpd.InsertRow
		g_iLogEntryStartingRow := g_iLogEntryInsertRow-1
		g_iCurLogEntryNdx := 1
		g_avRunningLog := []

		; Help tagging suspicious data input.
		g_iDataFlagCol := GetDataFlagCol(g_vEmployeeSpd)
		; Insert the row, copying formatting and formulas.
		g_iLogEntryRow := InsertRowProc(g_vEmployeeSpd, g_iLogEntryInsertRow, g_iDataFlagCol)

		TurnPage(true
			, ["g_vSheetText", "g_vSheetDDL", "g_vSheetEntryOKBtn", "g_vSheetCancelBtn"]
			, ["g_vText" g_iCurLogEntryNdx
			, "g_vLogEntry" g_iCurLogEntryNdx
			, "g_vLogEntryOKBtn" g_iCurLogEntryNdx
			, "g_vLogEntryPrevBtn" g_iCurLogEntryNdx])

		; Needed to reset GUI.
		GUIControlGet, g_iLogEntryOKBtnStart_, Pos, g_vLogEntryOKBtn%g_iCurLogEntryNdx%
		; Focus entry
		GUIControl, Focus, g_vLogEntry%g_iCurLogEntryNdx%
		return
	}

	LogEntry_OnLogEntry:
	{
		GUI, LogEntry_: Default

		; Get current log entry
		GUIControlGet, sLogEntry,, g_vLogEntry%g_iCurLogEntryNdx%
		iLogEntryCol := GetLogEntryCol(g_iCurLogEntryNdx)
		sEntryType := g_avMapDataEntryToDataInfo[iLogEntryCol].Entry

		; Data validation.
		if (!ValidateLogEntry(sLogEntry, g_iCurLogEntryNdx, sEntryType))
			return

	; Passed validation; populate this cell.
	AddLogEntryToSheet(sLogEntry, iLogEntryCol)

	if (g_iCurLogEntryNdx == g_iTotalLogEntries)
	{
		; Provide summary of running log, prompt to correct or confirm, save to excel, then exit.
		if (GetLogSummary())
		{
			gosub LogEntry_GUISubmit
			return
		}
		else ; We have now provided a "Previous" button, so the user should use that to go back.
		{
			GUIControl, Focus, g_vLogEntry%g_iCurLogEntryNdx%
			return
		}
	}

		TurnPage(true
			, ["g_vText" g_iCurLogEntryNdx
			, "g_vLogEntry" g_iCurLogEntryNdx
			, "g_vLogEntryOKBtn" g_iCurLogEntryNdx
			, "g_vLogEntryPrevBtn" g_iCurLogEntryNdx]
			, ["g_vText" g_iCurLogEntryNdx+1
			, "g_vLogEntry" g_iCurLogEntryNdx+1
			, "g_vLogEntryOKBtn" g_iCurLogEntryNdx+1
			, "g_vLogEntryPrevBtn" g_iCurLogEntryNdx+1])

		g_iCurLogEntryNdx++
		; Focus new entry
		GUIControl, Focus, g_vLogEntry%g_iCurLogEntryNdx%

		return
	}

	LogEntry_OnCancelBtn:
	{
		GUI, LogEntry_: Default

		if (g_iCurLogEntryNdx = 1)
		{
			TurnPage(false
				, ["g_vText" g_iCurLogEntryNdx
				, "g_vLogEntry" g_iCurLogEntryNdx
				, "g_vLogEntryOKBtn" g_iCurLogEntryNdx
				, "g_vLogEntryPrevBtn" g_iCurLogEntryNdx]
				, ["g_vSheetText", "g_vSheetDDL", "g_vSheetEntryOKBtn", "g_vSheetCancelBtn"])

			UndoRowProc()
		}
		else
		{
			TurnPage(false
				, ["g_vText" g_iCurLogEntryNdx
				, "g_vLogEntry" g_iCurLogEntryNdx
				, "g_vLogEntryOKBtn" g_iCurLogEntryNdx
				, "g_vLogEntryPrevBtn" g_iCurLogEntryNdx]
				, ["g_vText" g_iCurLogEntryNdx-1
				, "g_vLogEntry" g_iCurLogEntryNdx-1
				, "g_vLogEntryOKBtn" g_iCurLogEntryNdx-1
				, "g_vLogEntryPrevBtn" g_iCurLogEntryNdx-1])

			; Undo log entry
			; Note: we remove the log entry we were on before we decrement,
			; which means we have to specifically handle the final log entry.
			if (g_iCurLogEntryNdx == g_iTotalLogEntries)
			{
				iLogEntryCol := GetLogEntryCol(g_iCurLogEntryNdx)
				RemoveLogEntryFromSheet(iLogEntryCol)
			}

			g_iCurLogEntryNdx--
			iLogEntryCol := GetLogEntryCol(g_iCurLogEntryNdx)
			RemoveLogEntryFromSheet(iLogEntryCol)
		}

		return
	}

	LogEntry_GUIReset:
	{
		; Move dynamically created log entry ctrls out of view again.
		Loop % g_iTotalLogEntries
		{
			GUIControl, Move, g_vText%A_Index%, x%g_iLogEntryW%
			GUIControl, Hide, g_vText%A_Index%
			GUIControl, Move, g_vLogEntry%A_Index%, x%g_iLogEntryW%
			GUIControl, Hide, g_vLogEntry%A_Index%
			GUIControl, Move, g_vLogEntryPrevBtn%A_Index%, % "x" g_iLogEntryW-1 ; This isn't technically correct but looks better to me.
			GUIControl, Hide, g_vLogEntryPrevBtn%A_Index%
			GUIControl, Move, g_vLogEntryOKBtn%A_Index%, % "x" g_iLogEntryBtnStart_X
			GUIControl, Hide, g_vLogEntryOKBtn%A_Index%
			GUIControl, Show, g_vLogEntryOKBtn%A_Index%
		}
		; Move sheet entry ctrls back into view.
		GUIControl, Move, g_vSheetText, x%g_iSheetTextStart_X%
		GUIControl, Enable, g_vSheetText
		GUIControl, Show, g_vSheetText
		GUIControl, Move, g_vSheetDDL, x%g_iSheetDDLStart_X%
		GUIControl, Enable, g_vSheetDDL
		GUIControl, Show, g_vSheetDDL
		GUIControl, Move, g_vSheetCancelBtn, x%g_iSheetCancelBtnStart_X%
		GUIControl, Enable, g_vSheetCancelBtn
		GUIControl, Show, g_vSheetCancelBtn
		GUIControl, Move, g_vSheetEntryOKBtn, x%g_iSheetEntryOKBtnStart_X%
		GUIControl, Enable, g_vSheetEntryOKBtn
		GUIControl, Show, g_vSheetEntryOKBtn

		return
	}

	LogEntry_GUISubmit:
	{
		SaveAll()
		; fall through
	}
	LogEntry_GUIEscape:
	LogEntry_GUIClose:
	{
		; If we haven't saved, prompt to save.
		; This issue was tricky because we only save from the label above.
		; If changes ARE saved and we're trying to exit, then you can't check g_vMTYC_WB.Saved.
		if (A_ThisLabel != "LogEntry_GUISubmit")
		{
			if (g_vMTYC_WB.Saved && !g_hParent)
				gosub ExitApp ; There is no parent; this is the main app and we should shut down now.
			if (Msgbox_YesNo("Exit Application", "Exiting now will cause you to lose all your changes.`n`nAre you sure you want to exit?"))
			{
				; If there is no parent, this is the main app and we should shut down now.
				if (!g_hParent)
					gosub ExitApp
			}
			else return
		}

		if (g_hParent)
		{
			GUI, LogEntry_: Hide
			WinSet, Enable,, ahk_id %g_hParent%
			WinActivate, ahk_id %g_hParent%
			g_hParent :=
		}

		gosub LogEntry_GUIReset
	}

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: AddLogEntry()
		Purpose: To show Log Entry GUI to the user can add a log entry.
	Parameters
		hParent: Parent window
*/
AddLogEntry(hParent="")
{
	global g_iLogEntryW, g_hParent
		, g_vMTYC_WB, g_avEmployeeSpds, g_vIntSheetMap

	GUI, LogEntry_:Default

	; Update employee sheet DDL because an employee could have been added through AddEmployee().
	GUIControl,, g_vSheetDDL, % "|" GetListOfEmployees()

	GUIControl, Focus, g_vSheetDDL
	GUI, Show, w%g_iLogEntryW%

	g_hParent := hParent
	GUI, +Owner%g_hParent%
	WinSet, Disable,, ahk_id %g_hParent%

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: InsertRowProc
		Purpose: To encapsulate logic for inserting a row.
			This function uses a process a spent a lot of time speeding up (there are many ways to accomplish it)
			copying down the formulas and formatting from the row above into the inserted row below.
	Parameters
		vSpd: Employee spd
		iInsertRow: Insert at
		iDataFlagCol: Index of data flag column
*/
InsertRowProc(vSpd, iInsertRow, iDataFlagCol)
{
	global g_vIntSheetMap, g_avMapDataEntryToDataInfo, g_IntKeysToIntVals_InEmployeeSpd

	iStartingRow := g_IntKeysToIntVals_InEmployeeSpd.StartingRow
	if (iInsertRow-1 == iStartingRow)
	{
		; The first row won't have data filled in if this is the first entry ever.
		; Check the row above and see if it's a column header.
		; If it is, then we know we're on the first entry and should return without inserting a row.

		; Data entry has row headings, so the first column is B. I think it's fine to hardcode this.
		sFirstColHeader := g_vIntSheetMap["DataEntry"].cells(1, "B").Text
		sTestCellHeader := vSpd.Range("B" iStartingRow-1).Text
		sTestCellEntry := vSpd.Range("C" iStartingRow).Text

		if (sTestCellHeader = sFirstColHeader && !sTestCellEntry)
			return iInsertRow-1 ; The first rirst row doesn't have any data filled in yet.
	}

	; Insert a new row.
	vSpd.Range("A" iInsertRow).EntireRow.Insert
	; Get cell address of row above to copy to row below.
	iTotalCols := vSpd.UsedRange.Columns.Count
	vLastCellInRow := vSpd.cells(iInsertRow-1, iTotalCols)
	sLastCellInRow := vLastCellInRow.Address(true, false)
	; It'll be like 0$8, so split the char and row number.
	StringSplit, aSplitAddress, sLastCellInRow, $
	; Copy everything below quikcly (copy/paste methods are slow).
	vSpd.Range("A" iInsertRow-1 ":" aSplitAddress1 . iInsertRow).FillDown
	; Clear everything out.
	vSpd.Range("A" iInsertRow ":" aSplitAddress1 . iInsertRow).ClearContents
	; Now restore formulas.
	for iDataEntryCol, vDataInfo in g_avMapDataEntryToDataInfo
	{
		vCell := vSpd.cells(iInsertRow, iDataEntryCol)
		vCellAbove := vSpd.cells(iInsertRow-1, iDataEntryCol)

		bUseFormula := (vDataInfo.DataType = "Formula")
		if (bUseFormula)
		{
			sRange := vCellAbove.Address(false, false) ":" vCell.Address(false, false)
			vSpd.Range(sRange).FillDown
		}

		; If the cell above was flagged, don't carry over the flag.
		if (vCellAbove.Text != "")
			ClearFlaggedCell(vCell, vSpd.cells(iInsertRow, iDataFlagCol))
	}

	return iInsertRow
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: UndoRowProc
		Purpose: To remove the inserted row, if it hasn't already been removed.
	Parameters
		
*/
UndoRowProc()
{
	global g_vEmployeeSpd
		, g_iLogEntryRow, g_iLogEntryStartingRow, g_iCurLogEntryNdx
		, g_avRunningLog := []

	if (g_iLogEntryRow == g_iLogEntryStartingRow)
	{
		; No row to delete, but be sure to clear all the data (except for ID) on this row.
		Loop % g_iCurLogEntryNdx
		{
			iLogEntryCol := GetLogEntryCol(A_Index)
			RemoveLogEntryFromSheet(iLogEntryCol)
		}
	}
	else
	{
		g_vEmployeeSpd.Rows(g_iLogEntryRow).Delete
		g_iLogEntryRow--
	}

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function ClearFlagCell
		Purpose: Encapsulate the logic for clearing a flagged cell.
	Parameters
		vActualCell: This is the flagged cell
		vHelperCell: This is the helper cell in a hidden column this makes coding easier
*/
ClearFlaggedCell(vFlaggedCell, vHelperCell)
{
	vFlaggedCell.ClearComments()
	vFlaggedCell.Interior.ColorIndex := 0 ; Reset background color, too. 2=NoFill
	vHelperCell.Value := ""
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: TurnPage()
		Purpose: Turn page backwards or forward, moving GUIControls left or right
	Parameters
		bFwd: Turn page backwards or forward
		aControlsToRemove: String array of GUIControl IDs to move out of view
		aControlsToFocus: String array of GUIControl IDs to move into view
*/
TurnPage(bFwd, aControlsToRemove, aControlsToFocus)
{
	GUI, LogEntry_: Default

	Loop % aControlsToRemove.MaxIndex()
	{
		sControlID := aControlsToRemove[A_Index]
		GUIControlGet, iControl%A_Index%_, Pos, %sControlID%
		if (iWidestCtrl < iControl%A_Index%_W)
			iWidestCtrl := iControl%A_Index%_W
		GUIControl, Disable, %sControlID%
	}
	Loop % aControlsToFocus.MaxIndex()
	{
		sControlID := aControlsToFocus[A_Index]
		GUIControlGet, iFocusControl%A_Index%_, Pos, %sControlID%
		GUIControl, Show, %sControlID%
		GUIControl, Disable, %sControlID%
	}

	iLoop := 100
	iFactor := (iWidestCtrl+iControl1_X)/iLoop
	if (bFwd)
		iFactor *= -1

	; This code is tricky, so I'm adding safeguards.
	iTargetX := iControl1_X

	Loop %iLoop%
	{
		iLoopNdx := A_Index
		Loop % aControlsToRemove.MaxIndex()
		{
			; Move controls out of view.
			sControlID := aControlsToRemove[A_Index]
			iCtrlX := iControl%A_Index%_X
			GUIControl, Move, %sControlID%, % "X" iCtrlX +(iFactor*iLoopNdx)

			; Move control into view.
			sControlID := aControlsToFocus[A_Index]
			iCtrlX := iFocusControl%A_Index%_X

			; Safeguard against going off screen.
			iNewX := iCtrlX +(iFactor*iLoopNdx)
			if (bFwd && iNewX < iTargetX)
				iNewX := iTargetX
			GUIControl, Move, %sControlID%, % "X" iNewX
		}
	}

	for iCtrl, sCtrl in aControlsToRemove
		GUIControl, Hide, %sCtrl%

	for iCtrl, sCtrl in aControlsToFocus
		GUIControl, Enable, %sCtrl%

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: GetListFromSheet
		Purpose: Load list elements for sListID and return as simple array
	Parameters
		sListID: List ID
*/
GetListFromSheet(sListID)
{
	global g_vIntSheetMap

	; Retrieve appropriate list from lists spd
	aDDLOptions := []
	vListsSpd := g_vIntSheetMap["Lists"]
	for vListsRange in vListsSpd.UsedRange.Columns ; go through all used columns on row 1
	{
		sCurListName := vListsSpd.cells(1, A_Index).Text
		if (sCurListName = sListID)
		{	; Matched our lists!
			; Loop over lists in column
			for vCell in vListsRange.Rows ; will go through all cells in row
			{
				if (A_Index == 1)
					continue ; Header

				if (vCell.Text)
					aDDLOptions.Insert(vCell.Text)
				else break
			}

			break
		}
	}

	return aDDLOptions
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: CopySheet
		Purpose: To copy a sheet template; returns the copied sheet object.
	Parameters
		vSheet: Excel sheet COM object
		sName: New sheet name
*/
CopySheet(vSheet, sName)
{
	global g_vMTYC_WB

	; Not sure why I need the second parm, but I think this is harmless.
	vSheet.Copy(ComObjMissing(), g_vMTYC_WB.Sheets("EmployeeTemplate"))
	vCopiedSheet := g_vMTYC_WB.Worksheets(vSheet.Name " (2)")
	vCopiedSheet.Name := sName

	return vCopiedSheet
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: AddEmployee
		Purpose: For admins to be able to interactively add a sheet for an employee
	Parameters
		
*/
AddEmployee(hParent="")
{
	global

	static s_iMSDNStdBtnW := 75
	static s_iMSDNStdBtnH := 23
	static s_iMSDNStdBtnSpacing := 6

	/*
		Add an employee GUI. Items to prompt for:
			1. Employee Name
			2. Starting Date
			3. Title
	*/

	GUI, NewEmployee_: New, +hwndg_hNewEmployee, Add a New Employee

	GUI, Add, Text, xm ym w110, Employee name`n(i.e. Steve Jobs):
	GUI, Add, Text, xp yp+40 wp, Starting date:
	GUI, Add, Text, xp yp+40 wp h20 , Title:
	GUI, Add, Edit, xp+90 ym wp r1 vg_vNewEmployee_Name
	GUI, Add, DateTime, xp yp+40 wp h20 vg_vNewEmployee_StartDt
	GUI, Add, Edit, xp yp+40 wp r1 vg_vNewEmployee_Title

	; Apparently declaring iGUI_X, iGUI_Y, etc. local screws up retrieval of x (it keeps coming back blank)
	GUIControlGet, iGUI_, Pos, g_vNewEmployee_StartDt

	local iBtnEdge := s_iMSDNStdBtnW-1
	local iCancelX := (iGUI_X+iGUI_W)-iBtnEdge
	local iOKX := iCancelX-(s_iMSDNStdBtnW+s_iMSDNStdBtnSpacing)
	GUI, Add, Button, % "x" iOKX " yp+" iGUI_H+(s_iMSDNStdBtnSpacing*2) " w" s_iMSDNStdBtnW " h" s_iMSDNStdBtnH " gNewEmployee_GUISubmit", &OK
	GUI, Add, Button, x%iCancelX% yp wp hp gNewEmployee_GUIClose, &Cancel

	g_hParent := hParent
	GUI, % "+Owner" g_hParent
	WinSet, Disable,, ahk_id %g_hParent%

	GUI, Show
	return

	NewEmployee_GUISubmit:
	{
		GUI, NewEmployee_: Default

		GUIControlGet, g_vNewEmployee_Name,, g_vNewEmployee_Name
		GUIControlGet, g_vNewEmployee_StartDt,, g_vNewEmployee_StartDt
		GUIControlGet, g_vNewEmployee_Title,, g_vNewEmployee_Title

		; Ensure first and last names are specified so that we can actually create an employee ID...
		StringSplit, aFullName, g_vNewEmployee_Name, %A_Space%

		if (aFullName0 < 2)
		{
			Msgbox_Error("You must specify a first and last name.`n`n" aFullName1 " " aFullName2, 0)
			return
		}

		Loop %aFullName0%
		{
			; Remove periods and commas.
			StringReplace, aFullName%A_Index%, aFullName%A_Index%, `.,, All
			StringReplace, aFullName%A_Index%, aFullName%A_Index%, `,,, All
		}

		; Now create employee ID.
		sStrID := SubStr(aFullName1, 1, 1) . SubStr(aFullName2, 1, 1) "-"
		SetFormat, float, 03.0 ; or 02 will do also
		sEmployeeID := sStrID . 000

		; See if this employee ID exists, if it does, increment the ID until it doesn't exist.
		bContinue := true
		while (bContinue)
		{
			; Crappy pad proc.
			if (A_Index < 10)
				sEmployeeID := sStrID . 00 . A_Index
			else if (A_Index < 100)
				sEmployeeID := sStrID . 0 . A_Index
			else if (A_Index < 1000)
				sEmployeeID := sStrID . A_Index

			try
			{
				IsObject(g_vMTYC_WB.Sheets(sEmployeeID))
				; Found a sheet with this name; keep looping.
			}
			catch
			{
				; No sheet by this name; use this sheet name.
				bContinue := false
			}
		}

		local vEmployeeSheet := CopySheet(g_vIntSheetMap["EmployeeTemplate"], sEmployeeID)
		; Now automatically fills in employee info using the internal key-val map provided in the template.
		for sKey, sVal in g_IntKeysToIntVals_InEmployeeTemplate
		{
			; Cell address is in sVal
			if (sKey = "InsertName")
				vEmployeeSheet.Range(sVal).Value := g_vNewEmployee_Name
			else if (sKey = "InsertID")
				vEmployeeSheet.Range(sVal).Value := sEmployeeID
			else if (sKey = "InsertStartDt") ; Appended
			{
				FormatTime, sStartDt, %g_vNewEmployee_StartDt%, ShortDate
				vEmployeeSheet.Range(sVal).Value .= sStartDt
			}
			else if (sKey = "InsertPos") ; Appended
				vEmployeeSheet.Range(sVal).Value .= g_vNewEmployee_Title
			else if (sKey = "InsertYear") ; Appended
				vEmployeeSheet.Range(sVal).Value .= A_YYYY
		}

		SetFormat, Integer, d

		MapSheetsToObjects()

		; fall through
	}

	NewEmployee_GUIEscape:
	NewEmployee_GUIClose:
	{
		WinSet, Enable,, ahk_id %g_hParent%
		WinActivate, ahk_id %g_hParent%
		GUI, NewEmployee_: Destroy
		return
	}
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: GetLogEntryCol
		Purpose: Localize logic, specifically forcing the col to a number.
	Parameters
		iLogEntry: Which log entry to retrieve the column for
*/
GetLogEntryCol(iLogEntry)
{
	GUIControlGet, iLogEntryCol,, g_vIntLogEntryCol%iLogEntry%
	return iLogEntryCol+0 ; Forces to a number which is a MUST for calls to COM methods.
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: ShowLogSummary()
		Purpose: To show a summary of what is going to be placed in the Excel spreadsheet.
	Parameters
		
*/
GetLogSummary()
{
	global g_avRunningLog
	, g_vIntSheetMap, g_avMapDataEntryToDataInfo
	, g_vEmployeeSpd

	aSummary := ["All of the following data will be added to the employee sheet named, " """" g_vEmployeeSpd.Name """`n"]
	for iLogEntry, vLogInfo in g_avRunningLog
		aSummary.Insert("Enter """ vLogInfo.Text """ for entry """ vLogInfo.Entry """")

	return Msgbox_YesNo("Confirm Log Entry", st_glue(aSummary, "`n") "`n`nDoes this information look correct?")
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: ValidateLogEntry
		Purpose:
	Parameters
		
*/
ValidateLogEntry(sLogEntry, iCurLogEntryNdx, sEntryType)
{
	global g_vEmployeeSpd, g_iLogEntryRow, g_iDataFlagCol

	if (!sLogEntry && sEntryType != "Notes") ; Notes may be left blank.
	{
		Msgbox_Error("You must select something.")
		GUIControl, Focus, g_vLogEntry%iCurLogEntryNdx%
		return false
	}
	; Warn if the date is not today's date
	else if (sEntryType = "Date")
	{
		FormatTime, sToday, %A_Now%, ShortDate
		FormatTime, sEntryDate, %sLogEntry%, ShortDate
		if (sToday <> sEntryDate)
		{
			bGoBack := !Msgbox_YesNo("Confirm Date Entry"
			, "You are entering a date other than today's date. "
				. "Are you certain this is correct?`n`n"
				. "Today's date:`t" sToday "`n"
				. "Entry date:`t" sEntryDate)

			if (bGoBack)
			{
				GUIControl, Focus, g_vLogEntry%iCurLogEntryNdx%
				return false
			}
			else ; Flag this row since today's date was not used.
			{
				vCell := g_vEmployeeSpd.cells(g_iLogEntryRow, g_iDataFlagCol)
				vCell.Value := "Date other than today's date used."

				; Set actual cell background color to red to flag it, then add a comment to the cell explaining the flag.
				iLogEntryCol := GetLogEntryCol(iCurLogEntryNdx)
				vDataCell := g_vEmployeeSpd.cells(g_iLogEntryRow, iLogEntryCol)
				vDataCell.Interior.ColorIndex := 3 ; 3=red, 4=green, and 6 = yellow.
				vDataCell.AddComment("Date other than today's date used.")

				; Flag this column because we want to access it quickly and eficiently later.
				vFlagCell := g_vEmployeeSpd.cells(g_iLogEntryRow, g_iDataFlagCol)
				vFlagCell.Value := vDataCell.Address(true, false) ; now we can clear out the comments so easily -- hooray!
			}
		}
	}
	; Validate that start time is before end time.
	else if (sEntryType = "End Time")
	{
		; Get start time from GUI
		iStartTimeNdx := iCurLogEntryNdx-1
		GUIControlGet, sStartTime,, g_vLogEntry%iStartTimeNdx%
		if (sStartTime >= sLogEntry)
		{
			; Format start and end time for friendly display
			FormatTime, sFmtStartTime, %sStartTime%, h:mm tt
			FormatTime, sFmtEndTime, %sLogEntry%, h:mm tt

			Msgbox_Info("The start time must be before the end time.`n`nStart Time:`t" sFmtStartTime "`nEnd Time:`t`t" sFmtEndTime, 2)
			GUIControl, Focus, g_vLogEntry%iCurLogEntryNdx%
			return false
		}
	}

	return true
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: AddLogEntryToSheet()
		Purpose: To fill in with appropriate cell with sLogEntry
	Parameters
		sLogEntry: What to enter
		iLogEntryCol: Which column to enter it in
*/
AddLogEntryToSheet(sLogEntry, iLogEntryCol)
{
	global g_avMapDataEntryToDataInfo, g_avRunningLog
	, g_vEmployeeSpd, g_iLogEntryRow

	vCell := g_vEmployeeSpd.cells(g_iLogEntryRow, iLogEntryCol)

	; Format Start Time and End Time cells
	sDataType := g_avMapDataEntryToDataInfo[iLogEntryCol].DataType

	; Formatting.
	if (sDataType = "Date") 
	{
		FormatTime, sLogEntry, %sLogEntry%, ShortDate
		vCell.Value := sLogEntry
	}
	else if (sDataType = "Time") 
	{
		FormatTime, sLogEntry, %sLogEntry%, h:mm tt
		vCell.NumberFormat := "hh:mm"
		vCell.Value := sLogEntry
	}
	else vCell.Value := sLogEntry

	; Add to log.
	g_avRunningLog.Insert(Object("Entry", g_avMapDataEntryToDataInfo[vCell.Column].Entry
		, "Text", sLogEntry
		, "Type", sDataType))

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: RemoveLogEntryFromSheet()
		Purpose: To blank out appropriate cell for the current log entry
	Parameters
		iLogEntryCol: Which column to remove the entry from
*/
RemoveLogEntryFromSheet(iLogEntryCol)
{
	global g_vEmployeeSpd, g_iLogEntryRow, g_avRunningLog
		, g_avMapDataEntryToDataInfo, g_iDataFlagCol

	; Force to number
	iLogEntryCol += 0.0
	vCell := g_vEmployeeSpd.cells(g_iLogEntryRow, iLogEntryCol)

	; Remove from log.
	g_avRunningLog.Remove()

	; Blank out value
	vCell.Value := A_Blank

	; This is a bit hacky, but oh well. If this was today's entry and was flagged, clear that flag out.
	sEntryType := g_avMapDataEntryToDataInfo[vCell.Column].Entry
	if (sEntryType = "Date")
	{
		vCell := g_vEmployeeSpd.cells(g_iLogEntryRow, g_iDataFlagCol)
		vCell.Value := A_Blank
	}

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: GetListOfEmployees
		Purpose: Returns a pipe-delimited list of employee names for output in the Log Entry GUI DDL
	Parameters
		
*/
GetListOfEmployees()
{
	global g_vMTYC_WB, g_avEmployeeSpds, g_vIntSheetMap, g_IntKeysToIntVals_InEmployeeTemplate

	aEmployees := []
	Loop % g_vMTYC_WB.Worksheets.Count
	{
		vSheet := g_vMTYC_WB.Worksheets(A_Index)

		if (StrLen(vSheet.Name) == 6 && SubStr(vSheet.Name, 3, 1) == "-")
		{
			sNameAndIDAddr := g_IntKeysToIntVals_InEmployeeTemplate.NameAndID
			sFullName := vSheet.Range(sNameAndIDAddr).Text
			; Trim out employee ID suffix.
			StringLeft, sFullName, sFullName, InStr(sFullName, " -")
			; Because of Excel formatting, leading spaces can happen. Trim those, just in case.
			aEmployees.Insert(Trim(sFullName))
		}
	}

	return st_glue(aEmployees, "|")
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: GetDataEntryCols()
		Purpose: To return a pipe list of data entry columns (for use in ListView, currently)
	Parameters
*/
GetDataEntryCols()
{
	global g_avMapDataEntryToDataInfo

	aTmp := []
	for iDataEntry, vDataInfo in g_avMapDataEntryToDataInfo
		aTmp.Insert(vDataInfo.Entry)

	return st_glue(aTmp, "|")
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: MapSheetsToObjects
		Purpose: Enumerate all sheets, separating employee sheets from all other (internal) sheets
	Parameters
		
*/
MapSheetsToObjects()
{
	global g_vMTYC_WB, g_avEmployeeSpds := {}, g_vIntSheetMap := {}

	SetupSplashProgress("Enumerating sheets", g_vMTYC_WB.Worksheets.Count)
	Loop % g_vMTYC_WB.Worksheets.Count
	{
		vSheet := g_vMTYC_WB.Worksheets(A_Index)

		if (StrLen(vSheet.Name) == 6 && SubStr(vSheet.Name, 3, 1) == "-")
			g_avEmployeeSpds.Insert(vSheet) ; Employee sheets.
		else g_vIntSheetMap[vSheet.Name] := vSheet ; Internal sheets.

		IncSplashProgress()
	}

	;~ EndSplashProgress()
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: MapDataEntryToDataInfo
		Purpose: For ease-of-access, map literal data entry column header texts to their data info as defined in the "DataEntry" spd.
	Parameters
		
*/
MapDataEntryToDataInfo()
{
	global g_vIntSheetMap, g_avMapDataEntryToDataInfo := {}

	asRowHeadings := []
	vDataEntrySpd := g_vIntSheetMap["DataEntry"]
	SetupSplashProgress("Setting up data entry database"
		, vDataEntrySpd.UsedRange.Columns.Count * vDataEntrySpd.UsedRange.Rows.Count)
	for vRange in vDataEntrySpd.UsedRange.Columns
	{
		IncSplashProgress()
		iCol := A_Index + 0 ; This forces iCol to number, which is important for any call to cells()

		vDataInfo := {}
		for vRange2 in vDataEntrySpd.UsedRange.Rows
		{
			IncSplashProgress()
			vCell := vDataEntrySpd.cells(A_Index, iCol)

			; Row headings...
			if (iCol == 1)
			{
				asRowHeadings.Insert(vDataEntrySpd.cells(A_Index, 1).text)
				continue
			}

			sRowHeading := asRowHeadings[A_Index]
			vDataInfo[sRowHeading] := vCell.text
		}

		g_avMapDataEntryToDataInfo[vCell.Column] := vDataInfo
	}

	;~ EndSplashProgress()
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: MapIntKeysToIntVals_InEmployeeTemplate
		Purpose: There an internal key/val mapping in the EmployeeTemplate spd that helps us set it up
			This function maps those keys to vals for ease-of-access
	Parameters
		
*/
MapIntKeysToIntVals_InEmployeeTemplate()
{
	global g_vIntSheetMap, g_IntKeysToIntVals_InEmployeeTemplate := {}

	asRowHeadings := []
	vSpd := g_vIntSheetMap["EmployeeTemplate"]
	SetupSplashProgress("Setting up internal database map"
	, vSpd.UsedRange.Columns.Count * vSpd.UsedRange.Rows.Count)
	for vRange in vSpd.UsedRange.Columns
	{
		IncSplashProgress()
		iCol := A_Index + 0  ; This forces iCol to number, which is important for any call to cells()

		; Skip until we find "Internal_Key" col
		vTestCell := vSpd.cells(1, iCol)

		if (vTestCell.Text != "Internal_Key")
			continue

		for vRange2 in vRange.Rows
		{
			; Okay, so if you don't use A_Index then the calls to cells() fails. That's why we crazy with iCol.
			vKeyCell := vSpd.cells(A_Index, iCol)
			vValCell := vSpd.cells(A_Index, iCol+1)

			; Row headings...
			if (A_Index == 1 || vKeyCell.Text = "") ; a blank key means no data in the row, but there could be data in a row further down.
				continue

			g_IntKeysToIntVals_InEmployeeTemplate[vKeyCell.Text] := vValCell.Text
		}
	}

	;~ EndSplashProgress()
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: MapIntKeysToIntVals_InSpd
		Purpose: There an internal key/val mapping in the EmployeeTemplate spd that helps us set it up
			This function maps those keys to vals for ease-of-access
	Parameters
		vSpd: Spd to map.
*/
MapIntKeysToIntVals_InSpd(vSpd)
{
	vMapping := {}
	SetupSplashProgress("Setting up internal database map"
		, vSpd.UsedRange.Columns.Count * vSpd.UsedRange.Rows.Count)
	for vRange in vSpd.UsedRange.Columns
	{
		IncSplashProgress()
		iCol := A_Index + 0  ; This forces iCol to number, which is important for any call to cells()

		; Skip until we find "Internal_Key" col
		vTestCell := vSpd.cells(1, iCol)

		if (vTestCell.Text != "Internal_Key")
			continue

		for vRange2 in vRange.Rows
		{
			IncSplashProgress()

			vKeyCell := vSpd.cells(A_Index, iCol)
			vValCell := vSpd.cells(A_Index, iCol+1)

			; Row headings...
			if (A_Index == 1 || vKeyCell.Text = "") ; a blank key means no data in the row, but there could be data in a row further down.
				continue

			vMapping[vKeyCell.Text] := vValCell.Text
		}
	}

	;~ EndSplashProgress()
	return vMapping
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: MapDataEntryColHeaderToCellAddr
		Purpose: For ease-of-access, map literal column header texts to their Excel alphabetical column IDs.
			WARNING: This is a SLOW function
		This is a 2-step process:
			1. First, find the first column for data entry
			2. Then create the map
	Parameters
		
*/
MapDataEntryColHeaderToCellAddr()
{
	global g_vIntSheetMap, g_vEmployeeSpd
		, g_IntKeysToIntVals_InEmployeeTemplate
	global g_vMapDataEntryColHeaderToCellAddr := {}

	; #1. Find the first column for data entry
	; Find cell which represents first column header for data entry.
	sFirstColHeader := g_vIntSheetMap["DataEntry"].cells(1, "B").text
	; Force to number
	iLastCol := g_IntKeysToIntVals_InEmployeeTemplate.LastDataEntryCol + 0.0
	sLastColHeader := g_vIntSheetMap["DataEntry"].cells(1, iLastCol).text

	sStartCellAddr := ""
	sEndCellAddr := ""
	for vRange in g_vEmployeeSpd.UsedRange.Columns ; go through all used columns on row 1
	{
		iCol := A_Index + 0 ; This forces iCol to number, which is important for any call to cells()
		for vRange2 in g_vEmployeeSpd.UsedRange.Rows
		{
			vCell := g_vEmployeeSpd.cells(A_Index, iCol)

			if (vCell.Text = sFirstColHeader)
			{
				sStartCellAddr := vCell.Address(true, false)
				break
			}
			if (vCell.Text = sLastColHeader)
			{
				sEndCellAddr := vCell.Address(true, false)
				break
			}
		}
		if (sStartCellAddr && sEndCellAddr)
			break
	}

	; #2. Create the map
	StringSplit, sPart, sStartCellAddr, $
	sStartCol := sPart1
	sDataEntryRow := sPart2
	StringSplit, sPart, sEndCellAddr, $
	sLastCol := sPart1

	sRange := sStartCol . sDataEntryRow ":"
	sRange .= sLastCol . sDataEntryRow
	for vCell in g_vEmployeeSpd.Range(sRange)
		g_vMapDataEntryColHeaderToCellAddr[vCell.Text] := vCell.Address(true, false)

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: GetDataFlagCol
		Purpose: To find the data flag col in the Employee sheet and set it to g_iDataFlagCol
			Needed for flagging suspicious data input in LogEntry_OnLogEntry
	Parameters
		vSpd: Spd to find the data flag col in
*/
GetDataFlagCol(vSpd)
{
	iDataFlagCol :=

	for vColRange, vRange in vSpd.Columns
	{
		vCell := vSpd.cells(1, A_Index)
		if (vCell.Text = "Flag")
		{
			iDataFlagCol := vCell.Column
			break
		}

		if (A_Index > 200)
			break ; avoid infinite recursion.
	}

	if (iDataFlagCol == 0)
		Msgbox_Error("Unable to find data flag column in sheet:`t" vSpd.Name)

	return iDataFlagCol + 0.0 ; force to number
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: BackupWorkbook
		Purpose: To backup the main excel spreadsheet
	Parameters
		vWorkbook: The main excel spd. Not simply using the global in global context to be extra safe.
			The reason is I'm not going to pass in an uninitialized g_vMTYC_WB, but using the global itself
			could lead to my mistakenly calling BackupWorkbook before we've loaded g_vMTYC_WB.
*/
BackupWorkbook(vWorkbook)
{
	if (!FileExist("backup"))
		FileCreateDir, backup

	; Backup once per day.
	sBackupPrefix := A_YYYY . A_MM . A_DD

	sBackupFile .= sBackupPrefix "_" vWorkbook.Name
	; The timestamp doesn't account for HHMM, so if the app is launched more than once on the same day,
	; we could overwrite the backup. Don't do that beacuse we want the earliest copy of the spd for the day.
	FileCopy, % vWorkbook.Name, % A_WorkingDir "\backup\" sBackupFile, 0 ; no overwrite

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: SaveAll()
		Purpose: To save everything
	Parameters
		
*/
SaveAll()
{
	global g_vMTYC_WB

	; So there isn't a way to tell if this was sucessful or not, and that's not great.
	; However, as long as there isn't another instance of the same WB open,
	; this should work fine.
	try
		g_vMTYC_WB.Save
	catch
		Msgbox_Error("Unable to save. Your changes will not be saved. Sars :\")

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: ScanAllEmployeeSpdsForFlags
		Purpose: To find all the Flags (this is a column in each employee spd)output them to the user,
			and provide an option to clear or keep each flag.
	Parameters
		
*/
ScanAllEmployeeSpdsForFlags()
{
	global
	static s_iMSDNStdBtnW := 75, s_iMSDNStdBtnH := 23, s_iMSDNStdBtnSpacing := 6

	GUI SSS: New, hwndg_hSSS, Employee Flag Scan Summary
	GUI, Add, ListView, xm y5 w800 r10 AltSubmit Grid NoSort NoSortHdr -ReadOnly -Multi hwndg_hSSS_LV vg_vSSSLV gSSS_LVProc, % GetDataEntryCols()
	g_aMapForHiddenLB := []
	g_vSSS_InEditLV := new LV_InCellEdit(g_hSSS_LV)
	g_vSSS_InEditLV.Critical := 100

	LV_Colors() ; Loads up user lib.
	LV_Colors.OnMessage()
	LV_Colors.Attach(g_hSSS_LV)

	GUIControlGet, g_iLV_, Pos, g_vSSSLV

	; Add (hopefully) helpful text.
	iSpacingBetweenClearAndOK := g_iLV_W-(s_iMSDNStdBtnW*2)-s_iMSDNStdBtnSpacing
	iTextW := iSpacingBetweenClearAndOK-(s_iMSDNStdBtnW+(s_iMSDNStdBtnSpacing))
	GUI, Font, wBold
	GUI, Add, Text, % "xm+" s_iMSDNStdBtnW+(s_iMSDNStdBtnSpacing) " yp+" g_iLV_H+s_iMSDNStdBtnSpacing+5 " w" iTextW-4 " h" s_iMSDNStdBtnH " Center c0xDF7000", To edit a date, select a row and press F2; you can also double-click a cell under the Date column.
	GUI, Font, wnorm
	; Add buttons
	GUI, Add, Button, % "xm yp-5 w" s_iMSDNStdBtnW " hp gSSSGUIClearFlagBtn", C&lear Flag
	GUI, Add, Button, % "xp+" iSpacingBetweenClearAndOK " yp wp hp gSSSGUISubmit", &OK
	GUI, Add, Button, % "xp+" s_iMSDNStdBtnW+s_iMSDNStdBtnSpacing " yp wp hp gSSSGUIClose", &Cancel

	local vSpd := "", iSpd := ""
	for iSpd, vSpd in g_avEmployeeSpds
	{
		; This is a lengthy process, so use the splash progress.
		if (iSpd == 1)
		{
			; Number of spds * rows in data flag col is a good estimate.
			; Currently data flag is 16, but that's bound to change.
			; But this is just an estimate, so big deal.
			StartSplashProgress()
			SetupSplashProgress("Scanning"
				, g_avEmployeeSpds.MaxIndex() * vSpd.UsedRange.Columns(16).Rows.Count)
		}
		IncSplashProgress()

		local vSheetMap := MapIntKeysToIntVals_InSpd(vSpd)
		local sStartAddr := vSheetMap.FirstDataEntryAddr
		StringSplit, aStartAddr, sStartAddr, `$
		local sEndAddr := vSheetMap.LastDataEntryAddr
		StringSplit, aEndAddr, sEndAddr, `$
		sStartAddr := aStartAddr2
		sEndAddr := aEndAddr2

		; Find all comment in the log entry range
		; Unfortunately we can't simply enumare off vSpd.Comments because this doesn't provide cell addresses.
		; We need the addresses to give context to this comment.
		local iFirstRow := vSheetMap.StartingRow
		local iLastRow := vSheetMap.InsertRow-1

		local sTestRange := sStartAddr . iFirstRow ":" sEndAddr . iLastRow
		local vFlagCell
		for vFlagCell in vSpd.Range(sTestRange)
		{
			IncSplashProgress()

			if (vFlagCell.Comment.Text = "")
				continue ; no flag to catch.

			; Output the entire row
			local sStartColAddr := vFlagCell.Address(true, false)
			local sRowRange := sStartColAddr ":" sEndAddr . vFlagCell.Row
			local aRowData := [vSpd.Name] ; First column is ID
			local vCell
			for vCell in vSpd.Range(sRowRange)
				aRowData.Insert(vCell.Text)

			; Add the row of data.
			LV_SetDefault("SSS", "g_vSSSLV")
			local iRow := LV_Add("", aRowData*)
			; Color the flag cell red.
			local sRed := "0xFF0000"
			g_iLVFlagCol := vFlagCell.Column-1
			LV_Colors.Cell(g_hSSS_LV, iRow, g_iLVFlagCol, sRed)
			; Only make the flag cell column editable
			g_vSSS_InEditLV.SetColumns(g_iLVFlagCol)
			; Mapping rows to spd and cells so that we can properly overwrite them.
			g_aMapForHiddenLB.InsertAt(iRow, vFlagCell.Address)
		}
	}

	LV_SetDefault("SSS", "g_vSSSLV")
	LV_ModifyCol()

	GUI, SSS:Show

	EndSplashProgress()
	return

	SSS_LVProc:
	{
		LV_SetDefault("SSS", "g_vSSSLV")

	if (A_GUIEvent == "F" && g_vSSS_InEditLV.Changed)
	{
		iRow := LV_GetSel()
		for iChg, vChangeInfo in g_vSSS_InEditLV.Changed
		{
			if (vChangeInfo.Row = iRow)
				break
		}
		if (vChangeInfo.Row != iRow)
			return ; We don't want to change a row we couldn't find a match for because that would just change a random row.

		sSpdName := LV_GetAsText(vChangeInfo.Row, 1)
		sCellAddr := g_aMapForHiddenLB[iRow]

		try
			vSpd := g_vMTYC_WB.Sheets(sSpdName)
		catch
		{
			; Silently continue; if something is broken, we'll catch this on exit.
			return
		}

		; Only reset color if changed.
		vFlagCell := vSpd.Range(sCellAddr)
		if (vChangeInfo.Txt != vFlagCell.Text)
			LV_Colors.Cell(g_hSSS_LV, iRow, g_iLVFlagCol, "")
	}

	if (A_EventInfo == 113) ; 113 = F2
		g_vSSS_InEditLV.EditCell(LV_GetSel(), g_iLVFlagCol) ; This will get tracked in the Changed array -- nice!

		return
	}

	SSSGUIClearFlagBtn:
	{
		LV_SetDefault("SSS", "g_vSSSLV")

		g_vSSS_InEditLV.Changed[LV_GetSel()] := Object("Row", LV_GetSel()
			, "Col", g_iLVFlagCol
			, "Txt", LV_GetSelText(g_iLVFlagCol))
		LV_Colors.Cell(g_hSSS_LV, LV_GetSel(), g_iLVFlagCol, "") ; Reset cell color.

		GUIControl, Focus, g_vSSSLV
		return
	}

	SSSGUISubmit:
	{
		; Changes are conveniently audited in g_vSSS_InEditLV.Changed
		for iChg, vCell in g_vSSS_InEditLV.Changed
		{
			sSpdName := LV_GetAsText(vCell.Row, 1)
			sCellAddr := g_aMapForHiddenLB[vCell.Row]

			try
				vSpd := g_vMTYC_WB.Sheets(sSpdName)
			catch
			{
				; Error and continue.
				Msgbox_Error("The mapping of ID to Employee Spds has broken. Your changes to the following sheet will not be saved: " sSpdName)
				continue
			}

			; Update the cell value.
			vFlaggedCell := vSpd.Range(sCellAddr)
			vFlaggedCell.Value := vCell.Txt
			vHelperCell := vSpd.cells(vFlaggedCell.Row, GetDataFlagCol(vSpd))
			ClearFlaggedCell(vFlaggedCell, vHelperCell)
		}

		SaveAll()
		; fall through
	}

	SSSGUIEscape:
	SSSGUIClose:
	{
		; If we haven't saved, prompt to save.
		if (!g_vMTYC_WB.Saved
			&& !Msgbox_YesNo("Exit Application", "Exiting now will cause you to lose all your changes.`n`nAre you sure you want to exit?"))
		{
			return ; Go back.
		}

		GUI, SSS:Destroy
		WinSet, Enable,, ahk_id %g_hAdminCmdCenter%
		WinActivate, ahk_id %g_hAdminCmdCenter%

		return
	}
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: InitAdminGUI
		Purpose: Initialize the administrator's GUI
	Parameters
		
*/
InitAdminGUI()
{
	global

	static s_iMSDNStdBtnW := 75, s_iMSDNStdBtnH := 23, s_iMSDNStdBtnSpacing := 6
	static s_iCoolBtnW := 126, s_iCoolBtnH := 36, s_iCoolBtnSpacingX := 14, s_iCoolBtnSpacingY := 46

	GUI, AdminCmdCenter_: New, +hwndg_hAdminCmdCenter, Administrative Command Center®

	sDefaultSheet := g_vConfigInfo.config.path
	GUI, Color, 202020
	GUI, Font, c5C5CF0 wbold s12, Arial
	GUI, Add, Text, xm ym Center vg_vWelcomeText, Administrative Command Center®
	GUIControlGet, iWelcomeText_, Pos, g_vWelcomeText
	GUI, Font, cRed wbold s8, Arial
	g_sSheetPathTextPrefix := "`tThe default sheet for log entry is:`n"
	GUI, Add, Text, % "xm yp+" iWelcomeText_H*2 " r4 Left vg_vSheetPathText", %g_sSheetPathTextPrefix%%sDefaultSheet%
	GUIControlGet, iText_, Pos, g_vSheetPathText
	GUI, Font, c5C5CF0 norm

	local iFirstBtnOffsetY := iText_H+(s_iCoolBtnSpacingY/2)
	GUI, Add, Button, % "xm+14 yp+" iFirstBtnOffsetY " w" s_iCoolBtnW " h" s_iCoolBtnH " vg_vFirstBtn hwndg_hSetDefaultSheetBtn gAdminCmdCenter_SetDefaultSheetBtn",`tSet &Default Sheet
	ILButton(g_hSetDefaultSheetBtn, "images\Default.ico", 24, 24, 0)
	GUI, Add, Button, % "xp+" s_iCoolBtnW+ s_iCoolBtnSpacingX " yp w126 h36 vg_vFarRightBtn hwndg_hAddEmployeeBtn gAdminCmdCenter_AddEmployeeBtn",`tAdd an &Employee
	ILButton(g_hAddEmployeeBtn, "images\Employee.ico", 24, 24, 0)
	GUI, Add, Button, % "xm+14 yp+" s_iCoolBtnSpacingY " wp hp hwndg_hScanBtn gAdminCmdCenter_ScanBtn",`t&Scan for Discrepancies
	ILButton(g_hScanBtn, "images\Scan.ico", 24, 24, 0)
	GUI, Add, Button, % "xp+" s_iCoolBtnW+ s_iCoolBtnSpacingX " yp wp hp hwndg_hLogEntryBtn gAdminCmdCenter_LogEntryBtn",`tAdd &Log Entry
	ILButton(g_hLogEntryBtn, "images\LogEntry.ico", 24, 24, 0)
	GUI, Add, Button, % "xm+14 yp+" s_iCoolBtnSpacingY " wp hp vg_vBottomBtn hwndg_hGraphBtn gAdminCmdCenter_GraphBtn",`t&Graph`n(Coming Soon)
	ILButton(g_hGraphBtn, "images\Graph.ico", 24, 24, 0)

	GUIControlGet, iFirstBtn_, Pos, g_vFirstBtn
	GUIControlGet, iFarRightBtn_, Pos, g_vFarRightBtn
	GUIControlGet, iBottomBtn_, Pos, g_vBottomBtn

	local iMSDNBtnOffset := s_iMSDNStdBtnW+s_iMSDNStdBtnSpacing
	local iGroupBoxW := iFarRightBtn_X+iFarRightBtn_W
	GUI, Add, Button, % "xm+" iGroupBoxW-s_iMSDNStdBtnW " yp+" s_iCoolBtnSpacingY+s_iMSDNStdBtnSpacing " w" s_iMSDNStdBtnW " h" s_iMSDNStdBtnH " gAdminCmdCenter_GUIEscape", &OK

	; Draw GroupBox around buttons
	local iGroupBoxY := (iFirstBtn_Y-s_iCoolBtnSpacingY+s_iCoolBtnH)-(s_iMSDNStdBtnSpacing*2)
	GUI, Add, Groupbox, % "xm y" iGroupBoxY " w" iGroupBoxW " h" (iBottomBtn_Y-iGroupBoxY)+iBottomBtn_H+(s_iMSDNStdBtnSpacing*2), Actions

	; Align text with groupbox
	GUIControl, Move, g_vWelcomeText, w%iGroupBoxW%
	GUIControl, Move, g_vHelperText, w%iGroupBoxW%

	GUI, Show

	return

	AdminCmdCenter_SetDefaultSheetBtn:
	{
		GUI, AdminCmdCenter_: Default

		FileSelectFile, sSheetPath,,, Navigate to MTYC spreadsheet...
		if (!sSheetPath || sSheetPath = g_vConfigInfo.config.path)
			return ; No sheet selected or the sheets are the same; nothing to reload.

		GUIControl,, g_vSheetPathText, %g_sSheetPathTextPrefix%%sSheetPath%
		g_vConfigInfo.config.path := sSheetPath
		g_vConfigInfo.Save()
		; Kill current spd
		g_vExcelApp.DisplayAlerts := false
		g_vExcelApp.Quit
		ObjRelease(g_vExcelApp)
		g_vExcelApp := ""
		; Reinit
		Init()

		return
	}

	AdminCmdCenter_AddEmployeeBtn:
	{
		GUI, AdminCmdCenter_: Default
		AddEmployee(g_hAdminCmdCenter)
		return
	}

	AdminCmdCenter_ScanBtn:
	{
		GUI, AdminCmdCenter_: Default
		ScanAllEmployeeSpdsForFlags()
		return
	}

	AdminCmdCenter_LogEntryBtn:
	{
		GUI, AdminCmdCenter_: Default
		AddLogEntry(g_hAdminCmdCenter)
		return
	}

	AdminCmdCenter_GraphBtn:
	{
		GUI, AdminCmdCenter_: Default
		Msgbox Coming soon!
		return
	}

	AdminCmdCenter_GUIEscape:
	AdminCmdCenter_GUIClose:
	{
		GUI, AdminCmdCenter_: Destroy
		gosub ExitApp
		return
	}
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: StartSplashProgress
		Purpose: Output progress for loading application
	Parameters
		
*/
StartSplashProgress()
{
	global

	GUI, SplashProgess_: New, -Caption +Border
	GUI, Margin, 0,0
	GUI, Font, s14 wBold, Bell MT ; Leelawadee
	GUI, Add, Text, x0 y0 w200 r1 Center c71D4F5 BackgroundTrans vg_vSP_Output
	GUI, Font, norm
	GUIControlGet, g_iOutput_, Pos, g_vSP_Output
	GUI, Add, Picture, % "x0 y" g_iOutput_Y+g_iOutput_H+1 " vg_vSP_BkgdPic", images\Splash.png
	GUIControlGet, g_iPic_, Pos, g_vSP_BkgdPic
	GUI, Add, Progress, % "x0 y" g_iPic_Y+g_iPic_H+1 " w" g_iPic_W " h20 c2BB70B BackGround333333 +Border vg_vSP_Progress"
	; Resize text to span GUI
	GUIControl, Move, g_vSP_Output, w%g_iPic_W%
	GUI, Show

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function:
		Purpose: Kill the progress GUI
	Parameters
		
*/
EndSplashProgress()
{
	GUI, SplashProgess_: Destroy
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function:
		Purpose:
	Parameters
		
*/
SetupSplashProgress(sHeader, iRange)
{
	global

	GUIControl,, g_vSP_Output, %sHeader%...
	GUIControl, % "+Range0-" iRange, g_vSP_Progress

	return
}

UpdateSplashProgress(iNdx)
{
	GUIControl,, g_vSP_Progress, % iNdx
	return
}

IncSplashProgress()
{
	GUIControl,, g_vSP_Progress, +1
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: Msgbox_YesNo
		Purpose:
	Parameters
		sHeader: Dialog header (should be a question)
		sMsg: Actual prompt (should be a question)
*/
Msgbox_YesNo(sHeader, sMsg)
{
	MsgBox, 8228, %sHeader%, %sMsg%

	IfMsgBox Yes
		return true
	return false
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: Msgbox_Error
		Purpose:
	Parameters
		
*/
Msgbox_Error(sMsg, iErrorMsg=1)
{
	static aStdMsg := ["", "An internal error occured:`n`n"]

	if (iErrorMsg > 1)
		Msgbox 8208,, % aStdMsg[iErrorMsg] sMsg
	else Msgbox 8256,, %sMsg%

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: Msgbox_Info
		Purpose: To provide information in a MsgBox that is System Modal
	Parameters
		sMsg
		sTitle=""
*/
Msgbox_Info(sMsg, sTitle="")
{
	MsgBox, 4160, %sTitle%, %sMsg%
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Label: ExitApp
		Purpose:
*/
ExitApp:
{
	g_vExcelApp.DisplayAlerts := false
	g_vExcelApp.Quit
	ObjRelease(g_vExcelApp)
	g_vExcelApp := ""
	ExitApp
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Label: Reload
		Purpose:
*/
Reload:
{
	g_vExcelApp.DisplayAlerts := false
	g_vExcelApp.Quit
	ObjRelease(g_vExcelApp)
	g_vExcelApp := ""
	Reload
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: DoFileInstalls()
		Purpose: Encapsulate FileInstall prerequisites
	Parameters
		
*/
DoFileInstalls()
{
	if (!FileExist("images"))
		FileCreateDir, images

	FileInstall, images\Splash.png, images\Splash.png, 1
	FileInstall, images\Logo.ico, images\Logo.ico, 1
	FileInstall, images\Default.ico, images\Default.ico, 1
	FileInstall, images\Employee.ico, images\Employee.ico, 1
	FileInstall, images\Graph.ico, images\Graph.ico, 1
	FileInstall, images\LogEntry.ico, images\LogEntry.ico, 1
	FileInstall, images\Next.ico, images\Next.ico, 1
	FileInstall, images\Prev.ico, images\Prev.ico, 1
	FileInstall, images\Scan.ico, images\Scan.ico, 1
	; License and other help files.
	FileInstall, License.txt, License.txt, 1
	FileInstall, ReadMe.txt, ReadMe.txt, 1
	; Dependencies
	FileInstall, msvcr100.dll, msvcr100.dll, 1

	FileCreateShortcut, % A_AhkExe(), %A_WorkingDir%\MTYC Admin Center.lnk, %A_WorkingDir%, Admin
	FileCreateShortcut, % A_AhkExe(), %A_WorkingDir%\MTYC Employee Log Entry.lnk, %A_WorkingDir%

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: GetDefaultConfigIni
		Purpose: Set up default config ini on install
	Parameters
		
*/
	GetDefaultConfigIni()
	{
		return "
			(LTrim
				[config]
				Path=
				DebugRun=false
			)"
	}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#Include %A_ScriptDir%\Class_LV_InCellEdit.ahk