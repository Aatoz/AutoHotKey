#SingleInstance Force

SetBatchLines -1
SetWinDelay, -1
SetWorkingDir, %A_ScriptDir%
StringCaseSense, Off
Thread, interrupt, 1000

#Include %A_ScriptDir%\CFlyout_TLB.ahk

Hotkey, IfWinExist
	Hotkey, !+E, QL_Show

InitEverything()

OnMessage(WM_DISPLAYCHANGE:=126, "InitEverything")

^+Q::Reload

return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
InitEverything()
{
	InitializeQuickLauncher()
	InitGlobals()

	; Create CFlyout but start with it hidden (last parameter hides it for us).
	global g_vGUIFlyout := new CFlyout(g_hQL, 0, false, false, "", "", "", 10, A_ScreenHeight - g_iQLY - g_iTaskBarH, false, 0, 0, 0, "", "", false)
	g_vGUIFlyout.OnMessage("513,515", "QL_OnCFlyoutClick") ; WM_LBUTTONDOWN:= 513 WM_LBUTTONDBLCLK:=515

	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
InitGlobals()
{
	global g_sOfficialSourceDir := "Z:\Source", g_sLocationOfInvest := "C:\Invtools\Databases\PFO"

	; http://msdn.microsoft.com/en-us/library/windows/desktop/aa511453.aspx#sizing
	global g_iMSDNStdBtnW := 75
	global g_iMSDNStdBtnH := 23
	global g_iMSDNStdBtnSpacing := 6

	SysGet, iPrimary, MonitorPrimary
	SysGet, iPrimaryMon, Monitor, %iPrimary%
	SysGet, iPrimaryMonWorkArea, MonitorWorkArea, %iPrimary%
	WinGetPos,,,, iH, ahk_class Shell_TrayWnd
	bTaskBarAffectsHeight := PrimaryMonTop != iPrimaryMonWorkAreaTop && iPrimaryMonBottom != iPrimaryMonWorkAreaBottom
	global g_iTaskBarH := bTaskBarAffectsHeight ? iH : 0
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Create GUI
InitializeQuickLauncher()
{
	global

	vTmpIni := class_EasyIni(A_WorkingDir "\Flyout_config.ini")
	g_ConfigIni := class_EasyIni(A_WorkingDir "\config.ini")
	g_ConfigIni.Merge(vTmpIni)

	for key, val in g_ConfigIni.QLauncher
	{
		if (InStr(val, "Expr:"))
			NewVal := Trim(DynaExpr_EvalToVar(SubStr(val, InStr(val, "Expr:") + 5)), A_Space)
		else NewVal := val
		if (key = "Background" || key = "Font")
			s%key% := NewVal
		if (key = "SubmitSelectedIfNoMatchFound")
			g_bQL%key% := NewVal = "true" || NewVal = "1" ? true : false
		g_iQL%key% := NewVal
	}

	;~ if (!FileExist(sBackground))
		;~ sBackground := "" ; TODO: Standard pic?

	GUI, QuickLauncher:New, +Hwndg_hQL, Quick Launcher
	GUI, Add, Picture, AltSubmit x36 y0 W%g_iQLW% H%g_iQLH%, %sBackground%

	GUI, Font, s55 c0x48A4FF, %sFont% ; c83B2F7 ; c000080 ; c83B2F7 ; q
	GUI, Add, Text, hwndg_hQLText vQLText xp y0 W%g_iQLW% H%g_iQLH% Center BackgroundTrans +0x80, |
	;~ GUI, Add, GroupBox, x0 y0 W%g_iQLW% H%g_iQLH%

	GUI, Add, Edit, HwndQLEditHwnd BackgroundTrans vQLEdit gQLEditProc ; Can't use hidden because keystrokes are actually sent to this edit.
	g_hQLEdit := QLEditHwnd

	GUI, Add, Button, x0 y0 h32 w36 hwndg_hQLSettings gLaunchQuickLauncherEditor, `n&s
	ILButton(g_hQLSettings, "..\..\res\icons\Settings5.ico", 32, 32, 4)

	GUI, Color, Black
	GUI, +LastFound -Caption
	;~ WinSet, Transparent, 0
	;~ GUI, Show, X-32768 Y-32768 W%g_iQLW% h%g_iQLH%aua

	;~ WAnim_SlideViewInOutFrom(true, "Bottom", g_iQLX, g_iQLY, g_hQL, "QuickLauncher")
	;~ WAnim_FadeViewInOut(g_hQL, 20, true, "QuickLauncher")

	; Hotkeys
	Hotkey, IfWinActive, ahk_id %g_hQL%
	{
		; Hotkey to launch Flyout.
		Hotkey, Down, Flyout_MoveDown
		Hotkey, WheelDown, Flyout_MoveDown
		Hotkey, Up, Flyout_MoveUp
		Hotkey, WheelUp, Flyout_MoveUp

		; Delete keys
		Hotkey, +Delete, RemoveSelItem

		; Submit keys.
		Hotkey, Enter, QLEnterProc
		Hotkey, NumpadEnter, QLEnterProc
		Hotkey, MButton, QLEnterProc
		Hotkey, ^Enter, Submit_Selected_From_Flyout
		Hotkey, ^NumpadEnter, Submit_Selected_From_Flyout
		Hotkey, ^MButton, Submit_Selected_From_Flyout

		; Navigation keys.
		Hotkey, Home, QLCaretProc
		Hotkey, ^Home, QLCaretProc
		Hotkey, +Home, QLCaretProc
		Hotkey, End, QLCaretProc
		Hotkey, ^End, QLCaretProc
		Hotkey, +End, QLCaretProc
		Hotkey, Left, QLCaretProc
		Hotkey, Right, QLCaretProc
		Hotkey, +Left, QLCaretProc
		Hotkey, +Right, QLCaretProc
		Hotkey, +Up, QLCaretProc
		Hotkey, +Down, QLCaretProc
		Hotkey, ^Left, QLCaretProc
		Hotkey, ^Right, QLCaretProc
		Hotkey, ^Up, QLCaretProc
		Hotkey, ^Down, QLCaretProc
		Hotkey, ^+Left, QLCaretProc
		Hotkey, ^+Right, QLCaretProc
		Hotkey, ^+Up, QLCaretProc
		Hotkey, ^+Down, QLCaretProc
	}

	; For Flyout
	; Load the arrays even if we don't use a flyout, because, most of the time, we will.
	; Also I think this may be faster than loading the arrays upon creation.
	LoadFromQLRecentCmdsDB()

	g_iMaxElements := 33 ; This seems like plenty.

	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Flyout helper
Flyout_MoveDown:
{
	If (WinExist("ahk_id" g_hQL) && g_vGUIFlyout.m_hFlyout)
		g_vGUIFlyout.Move(false) ; false = Down

	return
}

Flyout_MoveUp:
{
	If (WinExist("ahk_id" g_hQL) && g_vGUIFlyout.m_hFlyout)
		g_vGUIFlyout.Move(true) ; true = Up

	return
}

Submit_Selected_From_Flyout:
{
	sCurSel := g_vGUIFlyout.GetCurSel()
	QuickLaunch(true) ; true = don't launch, but dismiss GUIs;
		; When this happens, we have to store g_vGUIFlyout.GetCurSel() because the selection is reset to 1 once the flyout is hidden.
	DoLaunch(sCurSel, true, false)
	s :=
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Show Quick Launcher
QL_Show:
{
	; Before showing the quick launcher, store the currently active
	; window in a variable so that we can, potentially, call functions
	; that would make changes to that window.
	global g_hActiveWndBeforeQLInit :=
	WinGet, g_hActiveWndBeforeQLInit, ID, A

	IfWinExist, ahk_id %g_hQL%
		WinActivate, ahk_id %g_hQL%
	else
	{
		g_vGUIFlyout.UpdateFlyout("") ; Clears the list and shows the flyout

		GUI, QuickLauncher:Default
		GUIControl, Enable, QLEdit ; See QuickLaunch().
		GUIControl, Focus, QLEdit
		GUI, Show, X%g_iQLX% Y%g_iQLY% W%g_iQLW% h%g_iQLH%
	}
	WinSet, Trans, Off, ahk_id %g_hQL%

	return
}

QL_OnCFlyoutClick(vFlyout, msg)
{
	global g_hQL
	static WM_LBUTTONDOWN:=513, WM_LBUTTONDBLCLK := 515
	Critical

	if (msg == WM_LBUTTONDBLCLK && vFlyout.GetCurSel() != A_Blank)
		QuickLaunch(false, true)

	WinActivate, ahk_id %g_hQL%
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Label made wrapper to function so as to
;;;;;;;;;;;;;; keep variables local.
QLCaretProc:
{
	QLCaretProc()
	return
}

QLCaretProc()
{
	if (InStr(A_ThisHotkey, "^"))
	{
		iHasCtrl := InStr(A_ThisHotkey, "^")
		SendStr := SubStr(A_ThisHotkey, InStr(A_ThisHotkey, "^"), 1)
	}
	if (InStr(A_ThisHotkey, "+"))
	{
		iHasShift := InStr(A_ThisHotkey, "+")
		SendStr := SendStr SubStr(A_ThisHotkey, InStr(A_ThisHotkey, "+"), 1)
	}
	iTextPos := iHasShift
	if (iHasCtrl > iTextPos)
		iTextPos := iHasCtrl
	iTextPos++

	SendStrText := SubStr(A_ThisHotkey, iTextPos)

	SendInput %SendStr%{%SendStrText%}
	gosub QLEditProc
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
QLEditProc:
{
	GUI, QuickLauncher:Default
	sCaret := "|" ; With regular fonts, this actually looks better. The Chr(5) caret leaves a large spacing between letters.

	sTxtFromEdit := GUIControlGet("", "QLEdit")
	sTxtFromEditWithCaret := sTxtFromEdit sCaret

	ControlGet, CaretPos, CurrentCol, ,, ahk_id %g_hQLEdit%

	if (CaretPos != StrLen(sTxtFromEdit) + 1) ; if the caret is no longer at the end of the text.
	{
		LeftStr := SubStr(sTxtFromEdit, 1, CaretPos - 1)
		RightStr := SubStr(sTxtFromEdit, StrLen(LeftStr) + 1)
		sTxtFromEditWithCaret := LeftStr sCaret RightStr
		;~ Tooltip %sTxtFromEdit%`n`n%sTxtFromEditWithCaret%
	}

	GUIControl,, QLText, %sTxtFromEditWithCaret%

	if (sTxtFromEdit == A_Blank || sTxtFromEdit == g_sLastTxtFromEdit)
		return

	asShortcuts := GetMatchingSecs(sTxtFromEdit)
	if (asShortcuts[1] != A_Blank)
	{
		g_vGUIFlyout.UpdateFlyout(asShortcuts)
		g_vGUIFlyout.MoveTo(1)
	}

	g_sLastTxtFromEdit := sTxtFromEdit
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Blank parameter means all
GetMatchingSecs(sSecToMatch="")
{
	global g_iMaxElements, g_CommandsIni

	; Escape [
	if (SubStr(sSecToMatch, 1, 1) == "[")
		sSecToMatch := "|OpenBracket|" SubStr(sSecToMatch, 2)

	StringReplace, sSecToMatch, sSecToMatch, \, \\, All
	StringReplace, sSecToMatch, sSecToMatch, ., \., All
	StringReplace, sSecToMatch, sSecToMatch, *, \*, All
	StringReplace, sSecToMatch, sSecToMatch, ?, \?, All
	StringReplace, sSecToMatch, sSecToMatch, +, \+, All
	StringReplace, sSecToMatch, sSecToMatch, [, \[, All
	StringReplace, sSecToMatch, sSecToMatch, `{, \`}, All
	StringReplace, sSecToMatch, sSecToMatch, |, \|, All
	StringReplace, sSecToMatch, sSecToMatch, `(, \`(, All
	StringReplace, sSecToMatch, sSecToMatch, `), \`), All
	StringReplace, sSecToMatch, sSecToMatch, ^, \^, All
	StringReplace, sSecToMatch, sSecToMatch, $, \$, All

	;~ if (sSecToMatch == A_Blank)
		;~ aTmpSecs := g_CommandsIni.Commands
	aTmpSecs := g_CommandsIni.FindSecs("i)" sSecToMatch ".*", g_iMaxElements)

	aSecs := []
	for k, v in aTmpSecs
	{
		; Unescape [
		StringReplace, v, v, |OpenBracket|, `[, All
		StringReplace, v, v, &, &&, All ; Escape ampersands so they aren't underlined.
		aSecs.Insert(v)
	}

	return aSecs
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Hotkeys for Quick Launcher
QLEnterProc:
{
	Quicklaunch(false)
	return
}

QuickLauncherGUIClose:
QuickLauncherGUIEscape:
{
	Quicklaunch(true)
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
QuickLaunch(bShouldExitWithoutLaunch, bFromClick=false)
{
	global

	GUI, QuickLauncher:Default
	Tooltip ; Turn off any tooltips from exterior tooltips.

	local sInput := Trim(GUIControlGet("", "QLEdit"))
	g_sLastSel := g_vGUIFlyout.GetCurSel()

	; Unescape ampersands so the input is true (as displayed).
	StringReplace, sInput, sInput, &&, &, All
	StringReplace, g_sLastSel, g_sLastSel, &&, &, All

	; Empty controls
	GUIControl,, QLEdit
	GUIControl,, QLText

	if (!g_vGUIFlyout.m_bIsHidden)
	{
		;~ WAnim_SlideOut("Top", g_vGUIFlyout.m_hFlyout, "GUI_Flyout1", 60, false)
		;~ g_vGUIFlyout.m_bIsHidden := true
		g_vGUIFlyout.Hide()
	}

	; Note: we have to disable/enable the edit when exiting;
	; otherwise, you can type while we are sliding out, which reactives the flyout.
	GUI, QuickLauncher:Default
	GUIControl, Disable, QLEdit
	WAnim_SlideOut("Bottom", g_hQL, "QuickLauncher", 20, false)
	; Don't enable yet because WAnim returns immediately after setting a timer.
	; Reactivate in QL_Show.

	g_sLastTxtFromEdit :=
	if (bShouldExitWithoutLaunch)
		return

	; Tmp
	if (sInput = "RestartComputer" || GetMatchingSecs(sInput)[1] = "RestartComputer")
	{
		Tmp_Restart()
		return true
	}
	if (sInput = "ReloadProgram" || GetMatchingSecs(sInput)[1] = "ReloadProgram")
	{
		Tmp_Reload()
		return true
	}
	else if (sInput = "EditFlyout" || GetMatchingSecs(sInput)[1] = "EditFlyout")
	{
		Suspend ; the below function will reload on exit
		g_vGUIFlyout.GUIEditSettings(0, "", true)
		return
	}
	else if (sInput = "LaunchEditor" || GetMatchingSecs(sInput)[1] = "LaunchEditor")
	{
		gosub, LaunchQuickLauncherEditor
		return
	}
	else if (sInput = "Quit" || GetMatchingSecs(sInput)[1] = "Quit")
		ExitApp

	if (g_sSelectedCmdToSubmit == A_Blank && sInput == A_Blank)
	{
		if (g_bQLSubmitSelectedIfNoMatchFound && (bFromClick || A_ThisHotkey = "Enter" || A_ThisHotkey = "NumpadEnter" || A_ThisHotkey = "MButton"))
			sInput := g_sLastSel
		else return
	}
	else if (g_sSelectedCmdToSubmit != A_Blank)
		sInput := g_sSelectedCmdToSubmit ; sInput can be a Shortcut or a Cmd.

	if (bFromClick)
		sInput := g_sLastSel

	DoLaunch(sInput)

	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; All commands are funtion-driven
;;;;;;;;;;;;;; if a function is determined to be nonexistent, this will return false
;;;;;;;;;;;;;; bAvoidRecursion is a fail-safe to avoid nasty recursion bug in the routine
;;;;;;;;;;;;;; it specifically handels when g_bQLSubmitSelectedIfNoMatchFound is true
DoLaunch(sInput, bAvoidRecursion=false, bSave=true)
{
	global g_CommandsIni, g_vGUIFlyout, g_sLastSel, g_bQLSubmitSelectedIfNoMatchFound

	; If we have typed in a shortcut
	; then retrieve the appropriate command.

	NEWFLIPPINGParseSpecial(sInput, rsCmd)
	; Temp workaround
	return

	sSavedCmd := g_CommandsIni.Commands[sInput]
	;~ if (sSavedCmd != A_Blank)
	;~ {
		;~ ParseSpecial(sSavedCmd, sParsedCmd)
		;~ if (!DynaExpr_FuncCall(sSavedCmd))
			;~ Run(sSavedCmd, "", "UseErrorLevel")
		;~ return ; Everything is already saved, so we can return
	;~ }

	sInputCmd := sInput
	if (sSavedCmd)
		sInputCmd := sSavedCmd

	if (ParseSpecial(sInputCmd, sCmd))
	{
		if (DynaExpr_FuncCall(sCmd, bRetValIfFunc)) ; Do not set bSuccess to DynaExpr_FuncCall(sCmd) because the function returns false if the cmd is not a function
			bSuccess := bRetValIfFunc
		else
		{
			bSuccess := Run(sCmd, "", "UseErrorLevel")
			; Set bSuccess to true regardless of what Run() returns if g_bQLSubmitSelectedIfNoMatchFound is true
			; because Run may run something, where intentional or unintentional, and we don't want to launch two
			; different items
			if (g_bQLSubmitSelectedIfNoMatchFound)
				bSuccess := true
		}
	}
	else if (DynaExpr_FuncCall(sCmd), bRetValIfFunc) ; So the command may have not parsed, but it still could be a function call
		bSuccess := bRetValIfFunc

	; If the launch was unsuccessful, and g_bQLSubmitSelectedIfNoMatchFound is true
	; redo routine using selected from flyout
	if (g_bQLSubmitSelectedIfNoMatchFound && sSavedCmd == A_Blank
		&& !bAvoidRecursion && !bSuccess && sInput != g_sLastSel
		&& g_sLastSel != A_Blank)
	{
		DoLaunch(g_sLastSel, true)
	}

	if (sSavedCmd == A_Blank && bSuccess && bSave) ; Do we need to save the sInput in the Recent Quick Launcher Commands database?
		SaveToDB(sInput == A_Blank ? sCmd : sInput, sCmd, "Recent")

	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Saves to Master Commands or Recent Quick Launcher Commands ini
SaveToDB(sInput, sCmd, sIni)
{
	global g_MasterIni, g_RecentIni

	if (SubStr(sInput, 1, 1) = "[")
		sInput := "|OpenBracket|" SubStr(sInput, 2)

	if (sIni = "Master")
	{
		if (g_MasterIni.AddKey("Commands", sInput, sCmd, sError))
			g_MasterIni.Save()
		else Msgbox 8192,, %sError%
	}
	else
	{
		if (g_RecentIni.AddKey("Commands", sInput, sCmd, sError))
			g_RecentIni.Save()
		else Msgbox 8192,, %sError%
	}

	LoadFromQLRecentCmdsDB()
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Remove selected item from flyout and DB
RemoveSelItem:
{
	Critical

	sToRemove := g_vGUIFlyout.GetCurSel()
	g_CommandsIni.Remove(sToRemove)
	if (g_MasterIni.HasKey(sToRemove))
		g_MasterIni.Remove(sToRemove)
	else g_RecentIni.Remove(sToRemove)

	g_MasterIni.Save()
	g_RecentIni.Save()

	; Update flyout
	LoadFromQLRecentCmdsDB()
	g_iStartAt := g_vGUIFlyout.GetCurSelNdx()
	GUI, QuickLauncher:Default
	g_vGUIFlyout.UpdateFlyout(GetMatchingSecs(GUIControlGet("", "QLEdit")))
	g_vGUIFlyout.MoveTo(1)

	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Main edit GUI
LaunchQuickLauncherEditor:
{
	GUI, QL_Editor_:New, hwndg_hQLEditorDlg +Owner%g_hQL% +Resize MinSize, Commands Browser
	GUI, QuickLauncher:+Disabled

	GUI, Add, ListView, hwndg_hEditorLV vg_vEditorLV gQL_Editor_LVProc w524 r20 AltSubmit, Shortcut|Action
	Attach(g_hEditorLV, "w1 h1")

	for sec, aData in g_CommandsIni
	{
		StringReplace, sec, sec, |OpenBracket|, `[, All
		LV_Add("", sec, aData.Action)
	}
	LV_ModifyCol(1, 245)
	LV_ModifyCol(2, 245)
	LV_ModifyCol(1, "Sort")

	GUI, Add, Button, x544 y148 w75 h23 hwndhLVAddProc gQL_Editor_LVAddProc, &Add
	Attach(hLVAddProc, "x1 y1/2")
	GUI, Add, Button, xp y176 w75 h23 hwndhLVEditProc gQL_Editor_LVEditProc, &Edit
	Attach(hLVEditProc, "x1 y1/2")
	GUI, Add, Button, xp y204 w75 h23 hwndhLVDeleteProc gQL_Editor_LVDeleteProc, &Delete
	Attach(hLVDeleteProc, "x1 y1/2")

	GUI, Add, Button, x460 w75 h23 hwndhOKNext vg_vOkNext gQL_Editor_GUIOk, &OK
	Attach(hOKNext, "x1 y1")
	GUI, Add, Button, x544 yp w75 h23 hwndhCancel gQL_Editor_GUIClose, &Cancel
	Attach(hCancel, "x1 y1")

	GUI, Show, AutoSize
	return
}

QL_Editor_LVProc:
{
	if (A_GUIEvent = "DoubleClick" || (A_GUIEvent = "K" &&A_EventInfo == 113)) ; 113 = F2
		gosub QL_Editor_LVEditProc
	return
}

QL_Editor_LVAddProc:
{
	QuickLauncherGUIDropFiles(true, g_hQLEditorDlg)
	return
}

QL_Editor_LVEditProc:
{
	QuickLauncherGUIDropFiles(true, g_hQLEditorDlg, LV_GetSelText(), LV_GetSelText(2))
	return
}

QL_Editor_LVDeleteProc:
{
	iRow := 0
	Loop
	{
		iRow := LV_GetNext(RowNumberiRow)  ; Resume the search at the row after that found by the previous iteration.
		if (!iRow)
			break
		LV_GetText(sRow, iRow)
		StringReplace, sRow, sRow, `r, , All ; Sometimes, characters are retrieved with a carriage-return.

		if (SubStr(sRow, 1, 1) = "[")
			sRow := "|OpenBracket|" SubStr(sRow, 2)

		g_CommandsIni.Commands.Remove(sRow)
		; Remove from Recent or Master ini
		if (g_MasterIni.Commands.HasKey(sRow))
			g_MasterIni.Commands.Remove(sRow)
		else g_RecentIni.Commands.Remove(sRow)

		LV_Delete(iRow)
	}
	return
}

QL_Editor_GUISize:
{
	; The shortcut column's contents will almost always be shorter than the contents in the action column, so resize the shortcut column by only 1/4 the LV width
	GUIControlGet, iLV, Pos, g_vEditorLV
	iResize := iLVW / 4
	LV_ModifyCol(1, iResize)
	LV_ModifyCol(2, iLVW - iResize - 71) ; give 50px space for user to click-n-drag over multiple rows
	return
}

QL_Editor_GUIOk:
{
	g_MasterIni.Save()
	g_RecentIni.Save()
	gosub QL_Editor_GUIClose
	return
}

QL_Editor_GUIEscape:
QL_Editor_GUIClose:
{
	GUI, QL_Editor_:Destroy
	GUI, QuickLauncher:Default
	GUI, -Disabled
	GUIControl, Focus, QLEdit
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; QuickLauncher Edit Dlg
QuickLauncherGUIDropFiles:
{
	QuickLauncherGUIDropFiles(false, g_hQL)
	return
}

QL_Editor_GUIDropFiles:
{
	; TODO:
	return
}

QL_EditDlg_GUIDropFiles:
{
	if (InStr(A_GuiEvent, "`n"))
		GUIControl,, g_vOkNext, &Next
	else GUIControl,, g_vOkNext, &Ok

	GUIControl, Choose, g_vDDL, 1
	GUIControl, Show, g_vActionBuilderOpenFileBtn
	gosub QL_Editor_GUIDropFiles_InitFromList
	return
}

QL_Editor_GUIDropFiles_InitFromList:
{
	g_sFiles := A_GuiEvent
	if (InStr(g_sFiles, "`n"))
		sFile := SubStr(g_sFiles, 1, InStr(g_sFiles, "`n") - 1)
	else sFile := g_sFiles
	GUIControl,, g_vAction, %sFile%
	return
}

QuickLauncherGUIDropFiles(bFromEditor, hOwner, sExistingShortcut="", sExistingAction="")
{
	global
	g_sFiles := g_hQLEditor := g_vTmpFlyout := g_vAction := g_hShortcutCtrl := g_vShortcut := g_vDDL := g_vActionBuilderEdit := g_vActionBuilderHelperText := g_vActionBuilderOpenFileBtn := g_vActionBuilderParmsText := g_vActionBuilderParmsEdit := g_vActionBuilderText, g_vOkNext :=

	g_bFromEditor := bFromEditor
	g_hOwner := hOwner
	g_sExistingShortcut := sExistingShortcut
	g_sExistingAction := sExistingAction

	iGUIWidth := 406
	iGUIHeight := 165

	GUI, QL_EditDlg_: New, hwndg_hQLEditor +Owner%g_hOwner% MinSize, Command Editor
	WinSet, Disable,, ahk_id %g_hOwner%

	GUI, Color, Black
	GUI, Font, c0x5AAC7

	GUI, Add, Picture, x0 y0, % g_ConfigIni.QLauncher.background
	GUI, Add, GroupBox, % "x0 y-6 w" iGUIWidth-1 " h" iGUIHeight+2

	if (g_bFromEditor) 
	{
		iChoose := 1
		if (g_sExistingAction)
		{
			if (SubStr(g_sExistingAction, 1, 4) = "run:" && InStr(g_sExistingAction, "."))
				iChoose := 1
			else if (SubStr(g_sExistingAction, 1, 4) = "run:")
				iChoose := 2
			else if (SubStr(g_sExistingAction, 1, 9) = "RDLaunch:")
				iChoose := 3
			else if (SubStr(g_sExistingAction, 1, 3) = "WS:")
				iChoose := 4
			else if (SubStr(g_sExistingAction, 1, 4) = "WWW:")
				iChoose := 5
			else if (SubStr(g_sExistingAction, 1, 7) = "custom:")
				iChoose := 6
			else iChoose := 6
		}

		sShowHide := iChoose > 1 ? "Hidden" : ""
		GUI, Add, DropDownList, x5 y5 w130 Choose%iChoose% r20 vg_vDDL gQL_EditDlg_ActionBuilderDDL, Open a File|Open a Folder|Remote Desktop|Search Google for|Open a Website|Custom
		GUI, Add, Text, x138 yp+4 w40 vg_vActionBuilderHelperText BackgroundTrans %sShowHide%
		GUI, Add, Button, x175 yp-4 w20 h21 vg_vActionBuilderOpenFileBtn gQL_EditDlg_ActionBuilderEditBtnProc %sShowHide%, ...
		GUI, Add, Edit, x195 yp w205 r1 vg_vActionBuilderEdit gQL_EditDlg_ActionBuilderEditProc hwndg_hActionBuilderEdit
		GUI, Add, Text, x138 y40 w34 vg_vActionBuilderParmsText BackgroundTrans %sShowHide%, Parameters:
		GUI, Add, Edit, x195 yp-4 w205 r1 gQL_EditDlg_ActionBuilderParmsEditProc vg_vActionBuilderParmsEdit %sShowHide%
	}
	gosub QL_EditDlg_ActionBuilderDDL

	GUI, Add, Text, x5 y70 Center BackgroundTrans, Action:
	GUI, Add, Edit, x50 y67 w350 r1 vg_vAction ReadOnly -TabStop, %sExistingAction%

	if (!g_bFromEditor)
		gosub QL_Editor_GUIDropFiles_InitFromList

	GUI, Add, Text, x5 y101 BackgroundTrans, &Shortcut:
	GUI, Add, Edit, % "x50 y98 w350 r1 hwndg_hShortcutCtrl vg_vShortcut gQL_EditDlg_ShortcutEditProc", %sExistingShortcut%

	if (g_bFromEditor)
		GUI, Add, Button, x5 y134 w75 h23 gQL_EditDlg_TestActionProc, &Test Action

	GUI, Add, Button, % "x" IGUIWidth-160 " y134 w75 h23 gQL_EditDlg_GUIClose", &Cancel
	GUI, Add, Button, xp+80 yp wp hp vg_vOkNext gQL_EditDlg_OnOkNext, % (g_bFromEditor ? "&OK" : (InStr(g_sFiles, "`n") ? "&Next" : "&OK"))

	if (g_bFromEditor)
	{
		GUIControl,, g_vActionBuilderEdit, %sExistingAction%
		GUIControl, Focus, g_vActionBuilderEdit
		SendMessage, EM_SETSEL:=177, 0, -1,, ahk_id %g_hActionBuilderEdit%
	}
	else GUIControl, Focus, g_vShortcut

	GUI, Show, % "W" iGUIWidth " H" iGUIHeight-4

	vTmpIni := class_EasyIni("Flyout_config.ini")
	g_vTmpFlyout := new CFlyout(g_hQLEditor, "", false, false, (A_ScreenWidth / 2) - (iGUIWidth / 2) + 50, 0, 350, 10, (A_ScreenHeight / 2) + (iGUIHeight / 2) - 130, true, 0, vTmpIni.Flyout.Font, "s16 c" vTmpIni.Flyout.FontColor)

	Hotkey, IfWinActive, ahk_id %g_hQLEditor%
		Hotkey, Down, QL_EditDlg_Flyout_SelectNext
		Hotkey, Up, QL_EditDlg_Flyout_SelectPrevious

	if (!g_bFromEditor)
	{
		Hotkey, IfWinActive, ahk_id %g_hQLEditor%
			Hotkey, Enter, QL_EditDlg_OnOkNext
	}

	SetTimer, QL_EditDlg_DismissFlyoutOnAction

	return
}

QL_EditDlg_ActionBuilderEditProc:
{
	sCurSelDDL := GUIControlGet("", "g_vDDL")
	sActionBuilderEdit := GUIControlGet("", "g_vActionBuilderEdit")

	if (sCurSel = "Open a File" || sCurSel = "Open a Folder")
	{
		GUIControl,, g_vAction, Run:%sActionBuilderEdit%
	}
	else if (sCurSelDDL = "Remote Desktop")
	{
		sActionBuilderParmsEdit := GUIControlGet("", "g_vActionBuilderParmsEdit")
		StringSplit, aParms, sActionBuilderParmsEdit, %A_Space%
		Loop %aParms0%
		{
			if (InStr(aParms%A_Index%, "w"))
				sWidth := Trim(SubStr(aParms%A_Index%, 2), A_Space)
			if (InStr(aParms%A_Index%, "h"))
				sHeight := Trim(SubStr(aParms%A_Index%, 2), A_Space)
		}
		GUIControl,, g_vAction, rd: v:%sActionBuilderEdit% w:%sWidth% h:%sHeight%
	}
	else if (sCurSelDDL = "Open a Website")
	{
		GUIControl,, g_vAction, WWW:%sActionBuilderEdit%
	}
	else if (sCurSelDDL = "Search Google for")
	{
		GUIControl,, g_vAction, WS:%sActionBuilderEdit%
	}
	else if (sCurSelDDL = "Custom")
	{
		GUIControl,, g_vAction, %sActionBuilderEdit%
	}
	return
}

QL_EditDlg_ActionBuilderDDL:
{
	GUIControl,, g_vActionBuilderEdit,

	sCurSel := GUIControlGet("", "g_vDDL")
	if (sCurSel = "Open a File" || sCurSel = "Open a Folder")
	{
		QL_EditDlg_ShowHideActionBuilderParms("Show")
		GUIControl, Show, g_vActionBuilderOpenFileBtn
		GUIControl, Show, g_vActionBuilderHelperText
		GUIControl,, g_vActionBuilderHelperText, Click...
		GUIControl,, g_vActionBuilderParmsText, Parameters:
		GUIControl,, g_vActionBuilderParmsEdit
	}
	else if (sCurSel = "Remote Desktop")
	{
		QL_EditDlg_ShowHideActionBuilderParms("Show")
		GUIControl, Hide, g_vActionBuilderOpenFileBtn
		GUIControl, Show, g_vActionBuilderHelperText
		GUIControl,, g_vActionBuilderHelperText, Address:
		GUIControl,, g_vActionBuilderParmsText, wN hN
		GUIControl,, g_vActionBuilderParmsEdit, w1680 h1050
	}
	else if (sCurSel = "Open a Website")
	{
		QL_EditDlg_ShowHideActionBuilderParms("Hide")
		GUIControl, Hide, g_vActionBuilderOpenFileBtn
		GUIControl, Show, g_vActionBuilderHelperText
		GUIControl,, g_vActionBuilderHelperText, Address:
	}
	else if (sCurSel = "Search Google for")
	{
		QL_EditDlg_ShowHideActionBuilderParms("Hide")
		GUIControl, Hide, g_vActionBuilderOpenFileBtn
		GUIControl, Show, g_vActionBuilderHelperText
		GUIControl,, g_vActionBuilderHelperText, Text:
	}
	else if (sCurSel = "Custom")
	{
		QL_EditDlg_ShowHideActionBuilderParms("Hide")
		GUIControl, Hide, g_vActionBuilderOpenFileBtn
		GUIControl, Show, g_vActionBuilderHelperText
		GUIControl,, g_vActionBuilderHelperText, Custom:
	}
	return
}

QL_EditDlg_ShowHideActionBuilderParms(sShowHide)
{
	GUIControl, %sShowHide%, g_vActionBuilderParmsEdit
	GUIControl, %sShowHide%, g_vActionBuilderParmsText
	return
}

QL_EditDlg_ActionBuilderEditBtnProc:
{
	GUI +OwnDialogs
	sCurSelDDL := GUIControlGet("", "g_vDDL")

	if (sCurSelDDL = "Open a File")
	{
		GUIControl,, g_vActionBuilderText, file:

		FileSelectFile, sFile,,, Chose a file
		if (sFile)
			GUIControl, , g_vActionBuilderEdit, %sFile%
	}
	else if (sCurSelDDL = "Open a Folder")
	{
		GUIControl,, g_vActionBuilderText, folder:

		FileSelectFolder, sFolder,,, Choose a folder
		if (sFolder)
			GUIControl, , g_vActionBuilderEdit, %sFolder%
	}
	else if (!A_IsCompiled)
		Msgbox 8208,, ASSERT: Edit button was activated on an unsupported control.

	return
}

QL_EditDlg_ActionBuilderParmsEditProc:
{
	sCurSelDDL := GUIControlGet("", "g_vDDL")
	sActionBuilderEdit := GUIControlGet("", "g_vActionBuilderEdit")
	sActionBuilderParmsEdit := GUIControlGet("", "g_vActionBuilderParmsEdit")

	if (sCurSelDDL = "Open a File" || sCurSelDDL = "Open a Folder")
	{
		sParms := (sActionBuilderParmsEdit ? "" sActionBuilderParmsEdit "" : "")
		GUIControl,, g_vAction, Run:%sActionBuilderEdit% %sParms%
	}
	else if (sCurSelDDL = "Remote Desktop")
	{
		StringSplit, aParms, sActionBuilderParmsEdit, %A_Space%
		Loop %aParms0%
		{
			if (InStr(aParms%A_Index%, "w"))
				sWidth := Trim(SubStr(aParms%A_Index%, 2), A_Space)
			if (InStr(aParms%A_Index%, "h"))
				sHeight := Trim(SubStr(aParms%A_Index%, 2), A_Space)
		}
		GUIControl,, g_vAction, rd: v:%sActionBuilderEdit% w:%sWidth% h:%sHeight%
	}

	return
}

QL_EditDlg_ShortcutEditProc:
{
	g_sInput := GUIControlGet("", "g_vShortcut")
	g_asShortcuts := GetMatchingSecs(g_sInput)

	if (g_vTmpFlyout.m_bIsHidden)
	{
		g_vTmpFlyout.Show()
		WinActivate, ahk_id %g_hQLEditor%
	}

	if (g_asShortcuts[1] != A_Blank)
	{
		if (g_sInput = g_asShortcuts[1])
			g_asShortcuts[1] := """" g_sInput """ is used!"
		else g_asShortcuts.Insert(1, """" g_sInput """ is unused!")

		g_vTmpFlyout.UpdateFlyout(g_asShortcuts)
	}
	else g_vTmpFlyout.UpdateFlyout(["""" g_sInput """ is unused!"])
	return
}

QL_EditDlg_DismissFlyoutOnAction:
{
	if (WinActive("ahk_id" g_hQLEditor) || WinActive("ahk_id" g_vTmpFlyout.m_hFlyout))
	{
		GUI, QL_EditDlg_:Default
		g_sInput := GUIControlGet("", "g_vShortcut")

		ControlGetFocus, sCtrlClassName, ahk_id %g_hQLEditor%
		ControlGet, hActiveCtrl, Hwnd,, %sCtrlClassName%, ahk_id %g_hQLEditor%

		if (g_hShortcutCtrl == hActiveCtrl && g_vTmpFlyout.m_bIsHidden)
		{
			if (g_bUpdateShortcutEdit)
				gosub QL_EditDlg_ShortcutEditProc
			return
		}
		if (!(g_hShortcutCtrl == hActiveCtrl || g_vTmpFlyout.m_bIsHidden || WinActive("ahk_id" g_vTmpFlyout.m_hFlyout)))
			g_vTmpFlyout.Hide()

		g_sPrevInput := g_sInput
		return
	}

	if (!g_vTmpFlyout.m_bIsHidden)
	{
		hActive := WinExist("A")
		g_vTmpFlyout.Hide()
		WinActivate, ahk_id %hActive%
	}

	return
}

QL_EditDlg_Flyout_SelectNext:
{
	GUI, QL_EditDlg_:Default

	ControlGetFocus, sCtrlClassName, ahk_id %g_hQLEditor%
	ControlGet, hActiveCtrl, Hwnd,, %sCtrlClassName%, ahk_id %g_hQLEditor%
	if (g_hShortcutCtrl == hActiveCtrl)
	{
		g_vTmpFlyout.Move(false)
		g_vTmpFlyout.Move(false)
		GUI, QL_EditDlg_:Default
		GUIControl,, g_vShortcut, % g_vTmpFlyout.GetCurSel()

		g_bUpdateShortcutEdit := false
		Send, ^{End}
	}
	else Send {Down}
	return
}
QL_EditDlg_Flyout_SelectPrevious:
{
	GUI, QL_EditDlg_:Default

	ControlGetFocus, sCtrlClassName, ahk_id %g_hQLEditor%
	ControlGet, hActiveCtrl, Hwnd,, %sCtrlClassName%, ahk_id %g_hQLEditor%

	if (g_hShortcutCtrl == hActiveCtrl)
	{
		g_vTmpFlyout.Move(true)
		g_vTmpFlyout.Move(true)
		GUI, QL_EditDlg_:Default
		GUIControl,, g_vShortcut, % g_vTmpFlyout.GetCurSel()

		g_bUpdateShortcutEdit := false
		Send, ^{End}
	}
	else Send {Up}
	return
}

QL_EditDlg_TestActionProc:
{
	DoLaunch(GUIControlGet("", "g_vAction"), true, false)
	return
}

QL_EditDlg_OnOkNext:
{
	GUI, QL_EditDlg_:Default
	GUI +OwnDialogs
	sShortcut := GUIControlGet("", "g_vShortcut")
	sFile := GUIControlGet("", "g_vAction")
	bLastFile := GUIControlGet("", "g_vOkNext") = "&Ok"
	bSave := true

	if (sShortcut == A_Blank)
	{
		if (sFile == A_Blank)
		{
			gosub QL_EditDlg_GUIClose
			return
		}

		MsgBox, 8196, , No shortcut was entered.`nDo you want to discard this change?
		IfMsgBox No
			return
		else
		{
			if (bLastFile)
				gosub QL_EditDlg_GUIClose

			bSave := false
		}
	}

	if (bSave && g_CommandsIni.Commands.HasKey(sShortcut))
	{
		Msgbox 8192,, % "The specified shortcut, """ sShortcut """ is already used to execute`n" g_CommandsIni.GetVal(sShortcut) "`n`nPlease use another shortcut"
		return
	}

	; Trim last shortcut from g_sFiles
	g_sFiles := SubStr(g_sFiles, InStr(g_sFiles, "`n") + 1)
	; Check to see if there is another file in the list
	g_sNext := SubStr(g_sFiles, InStr(g_sFiles, "`n") + 1)

	if (bLastFile)
		gosub QL_EditDlg_GUIClose

	if (g_sNext == g_sFiles)
	{
		GUIControl,, g_vShortcut,
		GUIControl, Focus, g_vShortcut
		GUIControl,, g_vOkNext, &Ok
		GUIControl,, g_vAction, %g_sFiles%
	}
	else
	{
		GUIControl,, g_vShortcut,
		GUIControl, Focus, g_vShortcut
		GUIControl,, g_vAction, % SubStr(g_sFiles, 1, InStr(g_sFiles, "`n") - 1)
	}

	if (bSave)
	{
		SaveToDB(sShortcut, sFile, "Master")
		LoadFromQLRecentCmdsDB()

		if (g_bFromEditor)
		{
			GUI, QL_EditDlg_: Default
			GUIControlGet, sAction,, g_vAction

			GUI, QL_Editor_: Default

			if (!(g_sShortcut == A_Blank && g_sFile == A_Blank))
			{
				iCurSel := LV_GetSel()
				LV_Modify(iCurSel, "", sShortcut, sAction)
			}
			else LV_Add("", sShortcut, sAction)
		}
	}

	return
}

QL_EditDlg_GUIEscape:
QL_EditDlg_GUIClose:
{
	GUI, QL_EditDlg_: Hide
	g_vTmpFlyout:=

	WinSet, Enable, , ahk_id %g_hOwner%
	WinActivate, ahk_id %g_hOwner%
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

NEWFLIPPINGParseSpecial(sShortcut, ByRef rsCmd)
{
	global g_CommandsIni, g_RecentIni, g_bQLSubmitSelectedIfNoMatchFound, g_sLastSel
	static s_bAvoidRecursion := false

	StringSplit, aSplit, sShortcut, `:
	sAlias := aSplit1
	sCmd := aSplit2

	rsCmd := g_CommandsIni[sShortcut].Action

	sFunc :=g_CommandsIni[sShortcut].Func
	sFunc := SubStr(sFunc, 1, StrLen(sFunc)-2)

	if (g_CommandsIni.HasKey(sShortcut))
	{
		; Temp workaround
		bSuccess := DynaExpr_FuncCall(sFunc "(" rsCmd ")", bRetValIfFunc) || Func(sFunc).(rsCmd)
	}
	else
	{
		; If the launch was unsuccessful, and g_bQLSubmitSelectedIfNoMatchFound is true
		; redo routine using selected from flyout
		if (g_bQLSubmitSelectedIfNoMatchFound && !s_bAvoidRecursion
			&& sShortcut != g_sLastSel && g_sLastSel != A_Blank)
		{
			DoLaunch(g_sLastSel, true)
			return
		}
	}

	if (bSuccess)
		return

	if (!ParseSpecial(sShortcut, sNewCmd))
		return

	if (InStr(sNewCmd, "RDLaunch"))
	{
		sFunc := "RDLaunch()"
		StringReplace, sNewCmd, sNewCmd, RDLaunch`(
		sNewCmd := SubStr(sNewCmd, 1, StrLen(sNewCmd)-1)
	}
	else if (InStr(sNewCmd, "PCLookup"))
	{
		sFunc := "PCLookup()"
		StringReplace, sNewCmd, sNewCmd, PCLookup`(
		sNewCmd := SubStr(sNewCmd, 1, StrLen(sNewCmd)-1)
	}
	else if (InStr(sNewCmd, "LaunchCatalog"))
	{
		sFunc := "LaunchCatalog()"
		StringReplace, sNewCmd, sNewCmd, LaunchCatalog`(
		sNewCmd := SubStr(sNewCmd, 1, StrLen(sNewCmd)-1)
	}
	else if (InStr(sNewCmd, "InvLaunch"))
	{
		sFunc := "InvLaunch()"
		StringReplace, sNewCmd, sNewCmd, InvLaunch`(
		sNewCmd := SubStr(sNewCmd, 1, StrLen(sNewCmd)-1)
	}
	else if (InStr(sNewCmd, "msdn"))
	{
		sFunc := "msdn()"
		StringReplace, sNewCmd, sNewCmd, msdn`(
		sNewCmd := SubStr(sNewCmd, 1, StrLen(sNewCmd)-1)
	}
	else
	{
		if (InStr(sNewCmd, "Run"))
		{
			StringReplace, sNewCmd, sNewCmd, Run`(
			sNewCmd := SubStr(sNewCmd, 1, StrLen(sNewCmd)-1)
		}
		sFunc := "Run()"
	}

		; Temp workaround
		sTmpFunc := SubStr(sFunc, 1, StrLen(sFunc)-2)
		DynaExpr_FuncCall(sTmpFunc "(" sNewCmd ")", bRetValIfFunc)

		if (!bRetValIfFunc)
			Func(sFunc).(sNewCmd)

	if (g_RecentIni.AddSection(sShortcut, "Action", sNewCmd, sError)
		&& g_RecentIni.AddKey(sShortcut, "Func", sFunc, sError))
	{
		g_RecentIni.Save()
		LoadFromQLRecentCmdsDB()
	}
	else Msgbox 8192,, %sError%

	return
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Parse special syntax
ParseSpecial(sShortcut, ByRef sCmd)
{
	; rd:v:192.168.0.1 w:1920 h:1080
	; sCmd == v:192.168.0.1 w:1920 h:1080
	sCmd := SubStr(sShortcut, 1, InStr(sShortcut, ":"))
	sParmsList := SubStr(sShortcut, InStr(sShortcut, ":") +1)

	if (IsSpecialCmd(sCmd == A_Blank ? sShortcut : sCmd))
	{
		; v:192.168.0.1 w:1920 h:1080
		; v:192.168.0.1
		; w:1920
		; h:1080
		StringSplit, aParms, sParmsList, %A_Space%
		Loop %aParms0%
		{
			if (aParms%A_Index% = A_Space)
				continue ; ignore double or more spaces
			sParms .= A_Index == 1 ? aParms%A_Index% : ", " aParms%A_Index%
		}
		sParms := Trim(sParms, ",")

		;;; Needed variables
		bJobLookup := InStr(sShortcut, "[[") ; [[CCNNNNNN]]
		bPCLookup := InStr(sShortcut, "PC:") ; Product Changes Scan
		bQDLookup := InStr(sShortcut, "QD:") ; Queued Product Changes

		if (SubStr(sShortcut, 1, 3) = "Ex:")
		{
			StringReplace, sParmsList, sParmsList, `,, ``,,, All
			sCmd := "DynaExpr_Eval(" sParmsList ")"
			return true
		}
		if (SubStr(sShortcut, 1, 2) = "i:")
		{
			sCmd := "InvLaunch(" SubStr(sShortcut, 3) ")"
			return true
		}
		;;; PC Lookup
		if (bJobLookup || bPCLookup || bQDLookup)
		{
			sCmd := "PCLookup(" sShortcut ")"
			return true
		}
		;;; Catalogs
		if (SubStr(sShortcut, 1, 3) = "ca:")
		{
			sCmd := "LaunchCatalog(" SubStr(sShortcut, 4) ")"
			return true
		}
		bOpenFile := InStr(SubStr(sShortcut, StrLen(sShortcut) - 3), ".")
		if (SubStr(sShortcut, 1, 4) = "run:" || bOpenFile)
		{
			if (!bOpenFile)
				sCmd := Trim(SubStr(sShortcut, 3), A_Space)
			sCmd := "explorer.exe " Trim(sParmsList, A_Space)
			return true
		}
	}
	; Backwards compatibility: old explorer syntax.
	else if (InStr(sShortcut, "\") || InStr(SubStr(sShortcut, StrLen(sShortcut) - 3), "."))
	{
		iPosOfExe := InStr(sShortcut, ".exe") + 4
		sExe := SubStr(sShortcut, 1, iPosOfExe)
		sParmsList := SubStr(sShortcut, iPosOfExe)
		if (iPosOfExe > 4)
			sCmd := sExe " " sParmsList ; File
		else sCmd := "Run(" sShortcut ")" ; Folder
		return true
	}
	; Backwards compatibility: old web syntax.
	else if (SubStr(sShortcut, 1, 3) = "www" || SubStr(sShortcut, 1, 4) = "http")
	{
		sCmd := "WWW(" sShortcut ")"
		return true
	}
	; else this should be a function
	if (IsFunc(SubStr(sShortcut, 1, InStr(sShortcut, "(")-1)))
	{
		sCmd := sShortcut
		return true
	}
	return false
}

IsSpecialCmd(sCmd)
{
	g_aSpecialCmds := ["run:", "rd", "i:", "ca:", "ex", "[[", "PC:", "QD:"] ; TODO: Static
	Loop % g_aSpecialCmds.MaxIndex()
	{
		if (sCmd = g_aSpecialCmds[A_Index])
			return true
		else if (SubStr(sCmd, 1, 2) = g_aSpecialCmds[A_Index]) ; support for [[ and maybe future 2-character cmds
			return true
	}

	return false
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
LoadFromQLRecentCmdsDB()
{
	global g_MasterIni := class_EasyIni("Master.ini")
	global g_RecentIni := class_EasyIni("Recent.ini")
	global g_CommandsIni := class_EasyIni("Master.ini") ; ObjCopy is actually not copying properly, so, at least for now, just init to Master.ini

	if (!g_RecentIni.HasKey("Commands"))
		g_RecentIni.AddSection("Commands")

	vTestIni := class_EasyIni("", GetDefaultIni())
	g_CommandsIni.Merge(g_RecentIni)
	g_CommandsIni.Merge(vTestIni)
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; TODO: Default ini
GetDefaultIni()
{
	return "
	(LTrim
		[Commands]
		; Working commands
		My Computer=::{20d04fe0-3aea-1069-a2d8-08002b30309d}
		My Documents=::{450d8fba-ad25-11d0-98a8-0800361b1103}
		My Network Places=::{208d2c60-3aea-1069-a2d7-08002b30309d}
		Network Computers=::{1f4de370-d627-11d1-ba4f-00a0c91eedba}
		Network Connections=::{7007acc7-3202-11d1-aad2-00805fc1270e}
		Printers and Faxes=::{2227a280-3aea-1069-a2de-08002b30309d}
		Recycle Bin=::{645ff040-5081-101b-9f08-00aa002f954e}
		Scheduled Tasks=::{d6277990-4c6a-11cf-8d87-00aa0060f5bf}

		; TODO: Parse
		AdminTools=::{724EF170-A42D-4FEF-9F26-B60E846FBA4F}
		CDBurning=::{9E52AB10-F80D-49DF-ACB8-4330F5687855}
		CommonAdminTools=::{D0384E7D-BAC3-4797-8F14-CBA229B392B5}
		CommonOEMLinks=::{C1BAE2D0-10DF-4334-BEDD-7AA20B227A9D}
		CommonPrograms=::{0139D44E-6AFE-49F2-8690-3DAFCAE6FFB8}
		CommonStartMenu=::{A4115719-D62E-491D-AA7C-E74B8BE3B067}
		CommonStartup=::{82A5EA35-D9CD-47C5-9629-E15D2F714E6E}
		CommonTemplates=::{B94237E7-57AC-4347-9151-B08C6C32D1F7}
		Contacts=::{56784854-C6CB-462b-8169-88E350ACB882}
		Cookies=::{2B0F765D-C0E9-4171-908E-08A611B84FF6}
		Desktop=::{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}
		DeviceMetadataStore=::{5CE4A5E9-E4EB-479D-B89F-130C02886155}
		DocumentsLibrary=::{7B0DB17D-9CD2-4A93-9733-46CC89022E7C}
		Downloads=::{374DE290-123F-4565-9164-39C4925E467B}
		Favorites=::{1777F761-68AD-4D8A-87BD-30B759FA33DD}
		Fonts=::{FD228CB7-AE11-4AE3-864C-16F3910AB8FE}
		GameTasks=::{054FAE61-4DD8-4787-80B6-090220C4B700}
		History=::{D9DC8A3B-B784-432E-A781-5A1130A75963}
		ImplicitAppShortcuts=::{BCB5256F-79F6-4CEE-B725-DC34E402FD46}
		InternetCache=::{352481E8-33BE-4251-BA85-6007CAEDCF9D}
		Libraries=::{1B3EA5DC-B587-4786-B4EF-BD1DC332AEAE}
		Links=::{bfb9d5e0-c6a9-404c-b2b2-ae6db6af4968}
		LocalAppData=::{F1B32785-6FBA-4FCF-9D55-7B8E7F157091}
		LocalAppDataLow=::{A520A1A4-1780-4FF6-BD18-167343C5AF16}
		LocalizedResourcesDir=::{2A00375E-224C-49DE-B8D1-440DF7EF3DDC}
		Music=::{4BD8D571-6D19-48D3-BE97-422220080E43}
		MusicLibrary=::{2112AB0A-C86A-4FFE-A368-0DE96E47012E}
		NetHood=::{C5ABBF53-E17F-4121-8900-86626FC2C973}
		OriginalImages=::{2C36C0AA-5812-4b87-BFD0-4CD0DFB19B39}
		PhotoAlbums=::{69D2CF90-FC33-4FB7-9A0C-EBB0F0FCB43C}
		Pictures=::{33E28130-4E1E-4676-835A-98395C3BC3BB}
		PicturesLibrary=::{A990AE9F-A03B-4E80-94BC-9912D7504104}
		Playlists=::{DE92C1C7-837F-4F69-A3BB-86E631204A23}
		PrintHood=::{9274BD8D-CFD1-41C3-B35E-B13F55A758F4}
		Profile=::{5E6C858F-0E22-4760-9AFE-EA3317B67173}
		ProgramData=::{62AB5D82-FDC1-4DC3-A9DD-070D1D495D97}
		ProgramFiles=::{905e63b6-c1bf-494e-b29c-65b732d3d21a}
		ProgramFilesCommon=::{F7F1ED05-9F6D-47A2-AAAE-29D317C6F066}
		ProgramFilesCommonX64=::{6365D5A7-0F0D-45E5-87F6-0DA56B6A4F7D}
		ProgramFilesCommonX86=::{DE974D24-D9C6-4D3E-BF91-F4455120B917}
		ProgramFilesX64=::{6D809377-6AF0-444b-8957-A3773F02200E}
		ProgramFilesX86=::{7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E}
		Programs=::{A77F5D77-2E2B-44C3-A6A2-ABA601054A51}
		Public=::{DFDF76A2-C82A-4D63-906A-5644AC457385}
		PublicDesktop=::{C4AA340D-F20F-4863-AFEF-F87EF2E6BA25}
		PublicDocuments=::{ED4824AF-DCE4-45A8-81E2-FC7965083634}
		PublicDownloads=::{3D644C9B-1FB8-4f30-9B45-F670235F79C0}
		PublicGameTasks=::{DEBF2536-E1A8-4c59-B6A2-414586476AEA}
		PublicLibraries=::{48DAF80B-E6CF-4F4E-B800-0E69D84EE384}
		PublicMusic=::{3214FAB5-9757-4298-BB61-92A9DEAA44FF}
		PublicPictures=::{B6EBFB86-6907-413C-9AF7-4FC2ABF07CC5}
		PublicRingtones=::{E555AB60-153B-4D17-9F04-A5FE99FC15EC}
		PublicVideos=::{2400183A-6185-49FB-A2D8-4A392A602BA3}
		QuickLaunch=::{52a4f021-7b75-48a9-9f6b-4b87a210bc8f}
		Recent=::{AE50C081-EBD2-438A-8655-8A092E34987A}
		RecordedTVLibrary=::{1A6FDBA2-F42D-4358-A798-B74D745926C5}
		ResourceDir=::{8AD10C31-2ADB-4296-A8F7-E4701232C972}
		Ringtones=::{C870044B-F49E-4126-A9C3-B52A1FF411E8}
		RoamingAppData=::{3EB685DB-65F9-4CF6-A03A-E3EF65729F3D}
		SampleMusic=::{B250C668-F57D-4EE1-A63C-290EE7D1AA1F}
		SamplePictures=::{C4900540-2379-4C75-844B-64E6FAF8716B}
		SamplePlaylists=::{15CA69B3-30EE-49C1-ACE1-6B5EC372AFB5}
		SampleVideos=::{859EAD94-2E85-48AD-A71A-0969CB56A6CD}
		SavedGames=::{4C5C32FF-BB9D-43b0-B5B4-2D72E54EAAA4}
		SavedSearches=::{7d1d3a04-debb-4115-95cf-2f29da2920da}
		SendTo=::{8983036C-27C0-404B-8F08-102D10DCFD74}
		SidebarDefaultParts=::{7B396E54-9EC5-4300-BE0A-2482EBAE1A26}
		SidebarParts=::{A75D362E-50FC-4fb7-AC2C-A8BEAA314493}
		StartMenu=::{625B53C3-AB48-4EC1-BA1F-A1EF4146FC19}
		Startup=::{B97D20BB-F46A-4C97-BA10-5E3608430854}
		System=::{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}
		SystemX86=::{D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27}
		Templates=::{A63293E8-664E-48DB-A079-DF759E0509F7}
		UserPinned=::{9E3995AB-1F9C-4F13-B827-48B24B6C7174}
		UserProfiles=::{0762D272-C50A-4BB0-A382-697DCD729B80}
		UserProgramFiles=::{5CD7AEE2-2219-4A67-B85D-6C9CE15660CB}
		UserProgramFilesCommon=::{BCBD3057-CA5C-4622-B42D-BC56DB0AE516}
		Videos=::{18989B1D-99B5-455B-841C-AB7C74E4DDFC}
		VideosLibrary=::{491E922F-5643-4AF4-A7EB-4E7A138D8174}
		Windows=::{F38BF404-1D43-42F2-9305-67DE0B28FC23}
	)"
	;~ return ";structure is Name,GUID,CSIDL
	;~ (LTrim
		;~ AdminTools,{724EF170-A42D-4FEF-9F26-B60E846FBA4F},48
		;~ CDBurning,{9E52AB10-F80D-49DF-ACB8-4330F5687855},59
		;~ CommonAdminTools,{D0384E7D-BAC3-4797-8F14-CBA229B392B5},47
		;~ CommonOEMLinks,{C1BAE2D0-10DF-4334-BEDD-7AA20B227A9D},58
		;~ CommonPrograms,{0139D44E-6AFE-49F2-8690-3DAFCAE6FFB8},23
		;~ CommonStartMenu,{A4115719-D62E-491D-AA7C-E74B8BE3B067},22
		;~ CommonStartup,{82A5EA35-D9CD-47C5-9629-E15D2F714E6E},24
		;~ CommonTemplates,{B94237E7-57AC-4347-9151-B08C6C32D1F7},45
		;~ Contacts,{56784854-C6CB-462b-8169-88E350ACB882},
		;~ Cookies,{2B0F765D-C0E9-4171-908E-08A611B84FF6},33
		;~ Desktop,{B4BFCC3A-DB2C-424C-B029-7FE99A87C641},0
		;~ DeviceMetadataStore,{5CE4A5E9-E4EB-479D-B89F-130C02886155},
		;~ DocumentsLibrary,{7B0DB17D-9CD2-4A93-9733-46CC89022E7C},
		;~ Downloads,{374DE290-123F-4565-9164-39C4925E467B},
		;~ Favorites,{1777F761-68AD-4D8A-87BD-30B759FA33DD},6
		;~ Fonts,{FD228CB7-AE11-4AE3-864C-16F3910AB8FE},20
		;~ GameTasks,{054FAE61-4DD8-4787-80B6-090220C4B700},
		;~ History,{D9DC8A3B-B784-432E-A781-5A1130A75963},34
		;~ ImplicitAppShortcuts,{BCB5256F-79F6-4CEE-B725-DC34E402FD46},
		;~ InternetCache,{352481E8-33BE-4251-BA85-6007CAEDCF9D},32
		;~ Libraries,{1B3EA5DC-B587-4786-B4EF-BD1DC332AEAE},
		;~ Links,{bfb9d5e0-c6a9-404c-b2b2-ae6db6af4968},
		;~ LocalAppData,{F1B32785-6FBA-4FCF-9D55-7B8E7F157091},28
		;~ LocalAppDataLow,{A520A1A4-1780-4FF6-BD18-167343C5AF16},
		;~ LocalizedResourcesDir,{2A00375E-224C-49DE-B8D1-440DF7EF3DDC},57
		;~ Music,{4BD8D571-6D19-48D3-BE97-422220080E43},
		;~ MusicLibrary,{2112AB0A-C86A-4FFE-A368-0DE96E47012E},
		;~ NetHood,{C5ABBF53-E17F-4121-8900-86626FC2C973},19
		;~ OriginalImages,{2C36C0AA-5812-4b87-BFD0-4CD0DFB19B39},
		;~ PhotoAlbums,{69D2CF90-FC33-4FB7-9A0C-EBB0F0FCB43C},
		;~ Pictures,{33E28130-4E1E-4676-835A-98395C3BC3BB},39
		;~ PicturesLibrary,{A990AE9F-A03B-4E80-94BC-9912D7504104},
		;~ Playlists,{DE92C1C7-837F-4F69-A3BB-86E631204A23},
		;~ PrintHood,{9274BD8D-CFD1-41C3-B35E-B13F55A758F4},27
		;~ Profile,{5E6C858F-0E22-4760-9AFE-EA3317B67173},40
		;~ ProgramData,{62AB5D82-FDC1-4DC3-A9DD-070D1D495D97},35
		;~ ProgramFiles,{905e63b6-c1bf-494e-b29c-65b732d3d21a},38
		;~ ProgramFilesCommon,{F7F1ED05-9F6D-47A2-AAAE-29D317C6F066},43
		;~ ProgramFilesCommonX64,{6365D5A7-0F0D-45E5-87F6-0DA56B6A4F7D},
		;~ ProgramFilesCommonX86,{DE974D24-D9C6-4D3E-BF91-F4455120B917},44
		;~ ProgramFilesX64,{6D809377-6AF0-444b-8957-A3773F02200E},
		;~ ProgramFilesX86,{7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E},42
		;~ Programs,{A77F5D77-2E2B-44C3-A6A2-ABA601054A51},2
		;~ Public,{DFDF76A2-C82A-4D63-906A-5644AC457385},
		;~ PublicDesktop,{C4AA340D-F20F-4863-AFEF-F87EF2E6BA25},25
		;~ PublicDocuments,{ED4824AF-DCE4-45A8-81E2-FC7965083634},46
		;~ PublicDownloads,{3D644C9B-1FB8-4f30-9B45-F670235F79C0},
		;~ PublicGameTasks,{DEBF2536-E1A8-4c59-B6A2-414586476AEA},
		;~ PublicLibraries,{48DAF80B-E6CF-4F4E-B800-0E69D84EE384},
		;~ PublicMusic,{3214FAB5-9757-4298-BB61-92A9DEAA44FF},53
		;~ PublicPictures,{B6EBFB86-6907-413C-9AF7-4FC2ABF07CC5},54
		;~ PublicRingtones,{E555AB60-153B-4D17-9F04-A5FE99FC15EC},
		;~ PublicVideos,{2400183A-6185-49FB-A2D8-4A392A602BA3},55
		;~ QuickLaunch,{52a4f021-7b75-48a9-9f6b-4b87a210bc8f},
		;~ Recent,{AE50C081-EBD2-438A-8655-8A092E34987A},8
		;~ RecordedTVLibrary,{1A6FDBA2-F42D-4358-A798-B74D745926C5},
		;~ ResourceDir,{8AD10C31-2ADB-4296-A8F7-E4701232C972},56
		;~ Ringtones,{C870044B-F49E-4126-A9C3-B52A1FF411E8},
		;~ RoamingAppData,{3EB685DB-65F9-4CF6-A03A-E3EF65729F3D},26
		;~ SampleMusic,{B250C668-F57D-4EE1-A63C-290EE7D1AA1F},
		;~ SamplePictures,{C4900540-2379-4C75-844B-64E6FAF8716B},
		;~ SamplePlaylists,{15CA69B3-30EE-49C1-ACE1-6B5EC372AFB5},
		;~ SampleVideos,{859EAD94-2E85-48AD-A71A-0969CB56A6CD},
		;~ SavedGames,{4C5C32FF-BB9D-43b0-B5B4-2D72E54EAAA4},
		;~ SavedSearches,{7d1d3a04-debb-4115-95cf-2f29da2920da},
		;~ SendTo,{8983036C-27C0-404B-8F08-102D10DCFD74},9
		;~ SidebarDefaultParts,{7B396E54-9EC5-4300-BE0A-2482EBAE1A26},
		;~ SidebarParts,{A75D362E-50FC-4fb7-AC2C-A8BEAA314493},
		;~ StartMenu,{625B53C3-AB48-4EC1-BA1F-A1EF4146FC19},11
		;~ Startup,{B97D20BB-F46A-4C97-BA10-5E3608430854},7
		;~ System,{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7},37
		;~ SystemX86,{D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27},41
		;~ Templates,{A63293E8-664E-48DB-A079-DF759E0509F7},21
		;~ UserPinned,{9E3995AB-1F9C-4F13-B827-48B24B6C7174},
		;~ UserProfiles,{0762D272-C50A-4BB0-A382-697DCD729B80},
		;~ UserProgramFiles,{5CD7AEE2-2219-4A67-B85D-6C9CE15660CB},
		;~ UserProgramFilesCommon,{BCBD3057-CA5C-4622-B42D-BC56DB0AE516},
		;~ Videos,{18989B1D-99B5-455B-841C-AB7C74E4DDFC},
		;~ VideosLibrary,{491E922F-5643-4AF4-A7EB-4E7A138D8174},
		;~ Windows,{F38BF404-1D43-42F2-9305-67DE0B28FC23},36
		;~ ALTSTARTUP,,29
		;~ COMMON_ALTSTARTUP,,30
		;~ COMMON_FAVORITES,,31
		;~ COMPUTERSNEARME,,61
		;~ DESKTOPDIRECTORY,,16
		;~ PERSONAL,,5
	;~ )"
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
GetKnownFolder(FolderName) { ;http://www.autohotkey.com/forum/viewtopic.php?t=68194
If !RegExMatch(folderdata(),"im`a)^" . foldername . ".+$",line)
   return 0, ErrorLevel := -2 ;FolderName not found
StringSplit,data,line,`,
VarSetCapacity(mypath,(A_IsUnicode ? 2 : 1)*260)

If A_OSVersion in WIN_VISTA,WIN_7
   {
   if !data2
      return 0, ErrorLevel := -1  ;No corresponding FOLDERID value
   SetGUID(rfid, data2)
   r := DllCall("Shell32\SHGetKnownFolderPath", "UInt", &rfid, "UInt", 0, "UInt", 0, "UIntP", mypath)
      return (r or ErrorLevel) ? 0 : StrGet(mypath)
   }
Else
   {
   if !data3
      return 0, ErrorLevel := -1  ;No corresponding CSILD value
   r := DllCall("Shell32\SHGetFolderPath", "int", 0 , "uint", data3 , "int", 0 , "uint", 0 , "str" , mypath)
      return (r or ErrorLevel) ? 0 : mypath
   }
}


SetGUID(ByRef GUID, String) {
VarSetCapacity(GUID, 16, 0)
StringReplace,String,String,-,,All
NumPut("0x" . SubStr(String, 2,  8), GUID, 0,  "UInt")   ; DWORD Data1
NumPut("0x" . SubStr(String, 10, 4), GUID, 4,  "UShort") ; WORD  Data2
NumPut("0x" . SubStr(String, 14, 4), GUID, 6,  "UShort") ; WORD  Data3
Loop, 8
   NumPut("0x" . SubStr(String, 16+(A_Index*2), 2), GUID, 7+A_Index,  "UChar")  ; BYTE  Data4[A_Index]
}

folderdata()
{
	folderdata =  ;structure is Name,GUID,CSIDL
	(LTrim
		AdminTools,{724EF170-A42D-4FEF-9F26-B60E846FBA4F},48
		CDBurning,{9E52AB10-F80D-49DF-ACB8-4330F5687855},59
		CommonAdminTools,{D0384E7D-BAC3-4797-8F14-CBA229B392B5},47
		CommonOEMLinks,{C1BAE2D0-10DF-4334-BEDD-7AA20B227A9D},58
		CommonPrograms,{0139D44E-6AFE-49F2-8690-3DAFCAE6FFB8},23
		CommonStartMenu,{A4115719-D62E-491D-AA7C-E74B8BE3B067},22
		CommonStartup,{82A5EA35-D9CD-47C5-9629-E15D2F714E6E},24
		CommonTemplates,{B94237E7-57AC-4347-9151-B08C6C32D1F7},45
		Contacts,{56784854-C6CB-462b-8169-88E350ACB882},
		Cookies,{2B0F765D-C0E9-4171-908E-08A611B84FF6},33
		Desktop,{B4BFCC3A-DB2C-424C-B029-7FE99A87C641},0
		DeviceMetadataStore,{5CE4A5E9-E4EB-479D-B89F-130C02886155},
		DocumentsLibrary,{7B0DB17D-9CD2-4A93-9733-46CC89022E7C},
		Downloads,{374DE290-123F-4565-9164-39C4925E467B},
		Favorites,{1777F761-68AD-4D8A-87BD-30B759FA33DD},6
		Fonts,{FD228CB7-AE11-4AE3-864C-16F3910AB8FE},20
		GameTasks,{054FAE61-4DD8-4787-80B6-090220C4B700},
		History,{D9DC8A3B-B784-432E-A781-5A1130A75963},34
		ImplicitAppShortcuts,{BCB5256F-79F6-4CEE-B725-DC34E402FD46},
		InternetCache,{352481E8-33BE-4251-BA85-6007CAEDCF9D},32
		Libraries,{1B3EA5DC-B587-4786-B4EF-BD1DC332AEAE},
		Links,{bfb9d5e0-c6a9-404c-b2b2-ae6db6af4968},
		LocalAppData,{F1B32785-6FBA-4FCF-9D55-7B8E7F157091},28
		LocalAppDataLow,{A520A1A4-1780-4FF6-BD18-167343C5AF16},
		LocalizedResourcesDir,{2A00375E-224C-49DE-B8D1-440DF7EF3DDC},57
		Music,{4BD8D571-6D19-48D3-BE97-422220080E43},
		MusicLibrary,{2112AB0A-C86A-4FFE-A368-0DE96E47012E},
		NetHood,{C5ABBF53-E17F-4121-8900-86626FC2C973},19
		OriginalImages,{2C36C0AA-5812-4b87-BFD0-4CD0DFB19B39},
		PhotoAlbums,{69D2CF90-FC33-4FB7-9A0C-EBB0F0FCB43C},
		Pictures,{33E28130-4E1E-4676-835A-98395C3BC3BB},39
		PicturesLibrary,{A990AE9F-A03B-4E80-94BC-9912D7504104},
		Playlists,{DE92C1C7-837F-4F69-A3BB-86E631204A23},
		PrintHood,{9274BD8D-CFD1-41C3-B35E-B13F55A758F4},27
		Profile,{5E6C858F-0E22-4760-9AFE-EA3317B67173},40
		ProgramData,{62AB5D82-FDC1-4DC3-A9DD-070D1D495D97},35
		ProgramFiles,{905e63b6-c1bf-494e-b29c-65b732d3d21a},38
		ProgramFilesCommon,{F7F1ED05-9F6D-47A2-AAAE-29D317C6F066},43
		ProgramFilesCommonX64,{6365D5A7-0F0D-45E5-87F6-0DA56B6A4F7D},
		ProgramFilesCommonX86,{DE974D24-D9C6-4D3E-BF91-F4455120B917},44
		ProgramFilesX64,{6D809377-6AF0-444b-8957-A3773F02200E},
		ProgramFilesX86,{7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E},42
		Programs,{A77F5D77-2E2B-44C3-A6A2-ABA601054A51},2
		Public,{DFDF76A2-C82A-4D63-906A-5644AC457385},
		PublicDesktop,{C4AA340D-F20F-4863-AFEF-F87EF2E6BA25},25
		PublicDocuments,{ED4824AF-DCE4-45A8-81E2-FC7965083634},46
		PublicDownloads,{3D644C9B-1FB8-4f30-9B45-F670235F79C0},
		PublicGameTasks,{DEBF2536-E1A8-4c59-B6A2-414586476AEA},
		PublicLibraries,{48DAF80B-E6CF-4F4E-B800-0E69D84EE384},
		PublicMusic,{3214FAB5-9757-4298-BB61-92A9DEAA44FF},53
		PublicPictures,{B6EBFB86-6907-413C-9AF7-4FC2ABF07CC5},54
		PublicRingtones,{E555AB60-153B-4D17-9F04-A5FE99FC15EC},
		PublicVideos,{2400183A-6185-49FB-A2D8-4A392A602BA3},55
		QuickLaunch,{52a4f021-7b75-48a9-9f6b-4b87a210bc8f},
		Recent,{AE50C081-EBD2-438A-8655-8A092E34987A},8
		RecordedTVLibrary,{1A6FDBA2-F42D-4358-A798-B74D745926C5},
		ResourceDir,{8AD10C31-2ADB-4296-A8F7-E4701232C972},56
		Ringtones,{C870044B-F49E-4126-A9C3-B52A1FF411E8},
		RoamingAppData,{3EB685DB-65F9-4CF6-A03A-E3EF65729F3D},26
		SampleMusic,{B250C668-F57D-4EE1-A63C-290EE7D1AA1F},
		SamplePictures,{C4900540-2379-4C75-844B-64E6FAF8716B},
		SamplePlaylists,{15CA69B3-30EE-49C1-ACE1-6B5EC372AFB5},
		SampleVideos,{859EAD94-2E85-48AD-A71A-0969CB56A6CD},
		SavedGames,{4C5C32FF-BB9D-43b0-B5B4-2D72E54EAAA4},
		SavedSearches,{7d1d3a04-debb-4115-95cf-2f29da2920da},
		SendTo,{8983036C-27C0-404B-8F08-102D10DCFD74},9
		SidebarDefaultParts,{7B396E54-9EC5-4300-BE0A-2482EBAE1A26},
		SidebarParts,{A75D362E-50FC-4fb7-AC2C-A8BEAA314493},
		StartMenu,{625B53C3-AB48-4EC1-BA1F-A1EF4146FC19},11
		Startup,{B97D20BB-F46A-4C97-BA10-5E3608430854},7
		System,{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7},37
		SystemX86,{D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27},41
		Templates,{A63293E8-664E-48DB-A079-DF759E0509F7},21
		UserPinned,{9E3995AB-1F9C-4F13-B827-48B24B6C7174},
		UserProfiles,{0762D272-C50A-4BB0-A382-697DCD729B80},
		UserProgramFiles,{5CD7AEE2-2219-4A67-B85D-6C9CE15660CB},
		UserProgramFilesCommon,{BCBD3057-CA5C-4622-B42D-BC56DB0AE516},
		Videos,{18989B1D-99B5-455B-841C-AB7C74E4DDFC},
		VideosLibrary,{491E922F-5643-4AF4-A7EB-4E7A138D8174},
		Windows,{F38BF404-1D43-42F2-9305-67DE0B28FC23},36
		ALTSTARTUP,,29
		COMMON_ALTSTARTUP,,30
		COMMON_FAVORITES,,31
		COMPUTERSNEARME,,61
		DESKTOPDIRECTORY,,16
		PERSONAL,,5
	)
	return folderdata
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;; Helper functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Remote Desktop
RDLaunch(sInput)
{
	global g_aComputers
	global g_aDomainNames
	global g_aTypePrefixes
	LoadFromServerDatabase(g_aComputers, g_aDomainNames, g_aTypePrefixes)

	; Extract Computer name from v: parameter.
	ComputerStartPos := InStr(sInput, "v:")
	if (ComputerStartPos == 0)
	{
		; TODO: Gracefully allow a retry
		Msgbox Error! No computer name specified.`nSpecify a computer name with the following syntax: " v:ComputerNameOrAlias "`nStr:`t%sInput%
		return false
	}
	else ComputerStartPos := ComputerStartPos+2
	; Find the next parameter keyed off of ":" and use that as ComputerEndPos
	Pos1 := InStr(sInput, "w:", false, ComputerStartPos) ; CaseSensitive = false
	Pos2 := InStr(sInput, "h:", false, ComputerStartPos)
	ComputerEndPos := Pos2 > Pos1 ? Pos1 : Pos2
	if (ComputerEndPos != 0)
		ComputerEndPos := ComputerEndPos-1
	else ComputerEndPos := StrLen(sInput)+1 ; The only parameter specified was "v:".

	Computer := SubStr(sInput, ComputerStartPos, ComputerEndPos-ComputerStartPos)
	; Msgbox %Computer%`n%ComputerStartPos%`n%ComputerEndPos%

	Trim(Computer, A_Space)
	StringUpper, Computer, Computer
	; Allow direct addresses (e.g. MyServer.MyDomain.org:3520)
	; Limitation: No Computer aliases can be specified with a period " . "

	bMappedComputerToDomainName := true
	if (!(InStr(Computer, ".com") || InStr(Computer, ".org") || InStr(Computer, ".net")))
	{
		; Lookup Server Domain Name based on Computer name/alias.
		bMappedComputerToDomainName := false
		Loop, % g_aComputers.MaxIndex()
		{
			vCurComputer := g_aComputers[A_Index]
			StringUpper, vCurComputer, vCurComputer

			vCurDomainName := g_aDomainNames[A_Index]
			StringUpper, vCurDomainName, vCurDomainName

			vCurTypePrefix := g_aTypePrefixes[A_Index]
			StringUpper, vCurTypePrefix, vCurTypePrefix

			; Msgbox Computer_%Computer%`nvCurComputer_%vCurComputer%`nIndex:%A_Index%
			if (Computer == vCurComputer)
			{
				Computer := vCurDomainName
				bMappedComputerToDomainName := true
				break
			}
		}
	}
	if (!bMappedComputerToDomainName && !InStr(Computer, "."))
	{
		Msgbox Computer name, "%Computer%" was not found in the Server Names database.
		return false
	}

	; Width
	IfInString, sInput, W:
	{
		WStartPos := InStr(sInput, "W:")+2 ; CaseSensitive = false
		W := SubStr(sInput, WStartPos, 4)
		Trim(W, A_Space)
	}
	else W = 1280
	; Height
	IfInstring, sInput, H:
	{
		HStartPos := InStr(sInput, "H:")+2 ; CaseSensitive = false
		H := SubStr(sInput, HStartPos, 4)
		Trim(H, A_Space)
	}
	else H = 850
	Run mstsc.exe /w:%W% /h:%H% /v:%Computer%
	return true
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; MSDN search
MSDN(sSearch)
{
	StringReplace, sSearch, sSearch, +, `%2B, All
	StringReplace, sSearch, sSearch, :, `%3A, All
	return Run("http://social.msdn.microsoft.com/Search/en-US?query=" sSearch "&emptyWatermark=true&ac=4", "", "UseErrorLevel")
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Web search
WS(sPhrase, sEngine = "Google")
{
	; Replace + with web syntax for +
	; %2B = +
	StringReplace, sPhrase, sPhrase, +, `%2B, All

	; Replace {SPACE} with +
	StringReplace, sPhrase, sPhrase, %A_Space%, +, All

	if (sEngine = "Bing")
		return Run("http://www.bing.com/search?q=" sPhrase "&qs=n&form=QBLH&pq=" sPhrase "&sc=8-11&sp=-1&sk=", "", "UseErrorLevel")
	else if (sEngine = "Google")
		return Run("https://www.google.com/search?sclient=psy-ab&hl=en&site=&source=hp&q=" sPhrase "&btnG=Search", "", "UseErrorLevel")
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Web Page
WWW(sWebsite)
{
	return Run(sWebsite, "", "UseErrorLevel")
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Catalog Editor
LaunchCatalog(UserInput)
{
	global g_sLocationOfInvest
	sDir := Dev_Staging_or_Production(true, UserInput)

	; If the catalog is already open, activate that window.
	IfWinExist, %UserInput% - Components - Catalog Editor
		WinActivate
	else
	{
		sCatalog := GetCatalogWithFullPath(UserInput, sDir, sError)
		if (sError)
		{
			Msgbox %sError%
			return false
		}
		StringReplace, sCatalog, sCatalog, \\, \, All
		bRet := Run(g_sLocationOfInvest "\Invest.exe -editcatalog:""" sCatalog """", "", "UseErrorLevel")
	}

	return bRet
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Return Dev, Staging, or Production
;;;;;;;;;;;;;; + Components or Invest. dependant upon bUseComp,
;;;;;;;;;;;;;; and, lastly, trim suffix, if any, from InputString.
Dev_Staging_Or_Production(bUseComp, ByRef InputString)
{
	; I'm using 2 and 3 because I usually think of these directories
	; as being the 2nd and 3rd repository/release cycle in relation to
	; DevComponents
	bUseStaging := SubStr(InputString, StrLen(InputString), 1) == "2"
	bUseProd   := SubStr(InputString, StrLen(InputString), 1) == "3"

	; Now trim the suffix, if any, from InputString
	if (SubStr(InputString, StrLen(InputString), 1) == "1" || SubStr(InputString, StrLen(InputString), 1) == "2" || SubStr(InputString, StrLen(InputString), 1) == "3")
		InputString := SubStr(InputString, 1, StrLen(InputString)-1)

	if (bUseComp)
		CompOrInvest := "\Components"
	else CompOrInvest := "\code"

	ReturnString :=
	if (bUseStaging)
		ReturnString := "StagingCombined\" CompOrInvest
	if (bUseProd)
		ReturnString := "ProductionCombined\" CompOrInvest

	; If nothing is specified, assume DevComponents/DevInvest to be what we want
	if (ReturnString == A_Blank)
		ReturnString := "DevCombined\" CompOrInvest
	return ReturnString
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
GetCatalogWithFullPath(sCatalog, sDevStagOrProd, ByRef rsError)
{
	global g_sOfficialSourceDir

	if (!g_sOfficialSourceDir)
	{
		rsError := "You must set the location of Official Source before launching!"
		return false
	}

	; First, see if the name is a client code
	if (StrLen(sCatalog) == 3)
	{
		sPossibleCatalog := FindCatalogWithCode(sCatalog, sDevStagOrProd)
		if (sPossibleCatalog)
			return sPossibleCatalog
	}

	; Add an extension to the catalog name if necessary.
	if (!InStr(sCatalog, ".txt"))
		sCatalog .= ".txt"

		Loop, %g_sOfficialSourceDir%\%sDevStagOrProd%\Catalogs\*.txt, 1, 1 ; 1 = loop through folders; 1 = recurse through subfolders
		{
			if (InStr(A_LoopFileDir, ".svn") || InStr(A_LoopFileDir, "Editor") || InStr(A_LoopFileDir, "Subscriptions"))
				continue
			if (A_LoopFileName = sCatalog)
				return A_LoopFileDir "\" sCatalog
		}

	rsError := "Could not locate a catalog specified with the name or alias, " sCatalog "`n`nMake sure that both the location of Official Source and Invest.exe are set and pointing to the right location."
	return false
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
FindCatalogWithCode(sTLC, sDevStagOrProd)
{
	global g_sOfficialSourceDir
	; External and Outer
	sDirs := "External|Outer"
	Loop, Parse, sDirs, |
		Loop, %g_sOfficialSourceDir%\%sDevStagOrProd%\Catalogs\%A_LoopField%\*
		{
			sLoopTLC := SubStr(A_LoopFileName, InStr(A_LoopFileName, "[") + 1, 3)
			if (sLoopTLC = sTLC)
				return A_LoopFileDir "\" A_LoopFileName
		}
	return false
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; PC Scan
PCLookup(sInput)
{
	; Nothing should be case-sensitive
	bJobLookup := InStr(sInput, "[[") ; [[CCNNNNNN]]
	bPCLookup := InStr(sInput, "PC:") ; Product Changes Scan
	bQDLookup := InStr(sInput, "QD:") ; Queued Product Changes

	; Stuart3 is Stuart III in CLS, and I often forget that; since he is the only 3rd employee, then this is an effective way to search.
	StringReplace, sInput, sInput, Stuart3, iii, All

	if (bJobLookup || bPCLookup || bQDLookup)
	{
		if (bJobLookup)
		{
			StringReplace, sInput, sInput, [,, All
			StringReplace, sInput, sInput, ],, All
			;~ if (SubStr(sInput, 1, 2) = "WS")
			;~ {
				;~ sPageNum := SubStr(sInput, 3) + 15 ; For some strange reasons, pages are offset by 15.
				;~ return Run("https://clientscope.invtools.com/Detail/View/2?RecordType=WikiPages&StringID=" sInput "&NumberID=0&", "UseErrorLevel")
			;~ }
			;~ return Run("https://clientscope.invtools.com/Detail/View/2?RecordType=Holding&StringID=" sInput "&NumberID=0&", "UseErrorLevel")
			return Run("https://clientscope.invtools.com/Reports/Standard/Std_Find?Asks='" sInput "'", "UseErrorLevel")
		}
		else
		{
			; Search subject only?
			IfInString, sInput, Subject:T
			{
				SubjectOnly = `%2CvAskSearchSubj`%3Dtrue
				StringReplace, sInput, sInput, Subject:T, %A_Blank%, All
			}

			StringGetPos, ColPos, sInput, :
			sInput := SubStr(sInput, ColPos+2)

			; Remove any trailing spaces
			while (SubStr(sInput, 1, 1) == " ")
				sInput := SubStr(sInput, 2)
			StringReplace, sInput, sInput, %A_Space%, +, All

			StringReplace, sInput, sInput, :, `%3A, All
			if (SubStr(sInput, StrLen(sInput)-1) == ")")
				sInput := SubStr(sInput, StrLen(sInput)-1)
			if (bPCLookup)
				return Run("https://clientscope.invtools.com/Reports/Holding/Stuart3/SFG_Product_Change_Scan?Asks=vSearch`%3D`%22" sInput "`%22" SubjectOnly "&", "UseErrorLevel")
			if (bQDLookup)
				return Run("https://clientscope.invtools.com/Reports/Holding/Stuart3/SFG_Queued_Product_Change_Report?Asks=vSearch`%3D`%22" sInput "`%22" SubjectOnly "&", "UseErrorLevel")
		}
	}
	return true
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
InvLaunch(sInput)
{
	; Inv Databases
	; Loop through this folder and key off the TLC
	if (StrLen(sInput) = 4)
	{
	; Searches for window titles are case-sensitive.
		StringUpper, sInput, sInput
		; LocalSuffix = Directory. User inputs the TLC + LocalSuffix to inform the script where to search the directory.
		LocalSuffix := SubStr(sInput, 4)
		Dir = C:\Invtools\Databases
		bUseStdComp := (LocalSuffix == "S")
		if (bUseStdComp)
			Dir := "Z:\Source\DevCombined\Components\Std Components"
		Loop, %Dir%\*.*, 2
		{
			TargetDir := A_LoopFileName LocalSuffix
			IfInString, A_LoopFileName, [
			{
				StringGetPos, OpenBracePos, A_LoopFileName, [, R
				TargetDir := SubStr(A_LoopFileName, OpenBracePos+2, 3) LocalSuffix
			}
			if (sInput = TargetDir)
			{
				if (bUseStdComp)
					Run %Dir%\%A_LoopFileName%\Standard
				else Run %Dir%\%A_LoopFileName%
			}
		}
	}
	else
	{
		; Searches for window titles are case-sensitive.
		StringUpper, sInput, sInput
		Loop, C:\Invtools\Databases\*.*, 2
		{
			if (sInput == A_LoopFileName)
			{
				WinGetClass, WndClass, %sInput%
				if (WndClass != A_Blank && WndClass != "CabinetWClass") ; Don't activate an Explorer window instead.
				{
					WinActivate, ahk_class %WndClass%
					return true
				}
				else
				{
					; A_LoopFileName value is dynamic, so assign it to a local variable.
					DatabaseFolder = %A_LoopFileName%
					bHasShortcut := false
					Loop, C:\Invtools\Databases\%DatabaseFolder%\*.*,
					{
						IfInString, A_LoopFileName, Invest.exe - Shortcut.lnk
							bHasShortcut := true
					}
					; If the shortcut does not exist, create it.
					if (!bHasShortcut)
						FileCreateShortcut, C:\Invtools\Databases\%DatabaseFolder%\Invest.exe, C:\Invtools\Databases\%DatabaseFolder%\Invest.exe - Shortcut.lnk, C:\Invtools\Databases\%DatabaseFolder%\, -SplashOK

					Run, "C:\Invtools\Databases\%A_LoopFileName%\Invest.exe - Shortcut"
					return true
				}
			}
		}
	}
	return true
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Load up Server Names from Server Database
LoadFromServerDatabase(ByRef aComputers, ByRef aDomainNames, ByRef aTypePrefixes)
{
	; Load up Server information into these arrays.
	aComputers   := []
	aDomainNames := []
	aTypePrefixes  := []
	Loop, Read, Server Names.txt
	{
		if (InStr(A_LoopReadLine, ";") == 1)
			continue ; Skip commented-out lines TODO: Make lines that have to include " ; " work.
		Loop, Parse, A_LoopReadLine, `t
		{
			if (A_Index == 1)
				aComputers.Insert(A_LoopField)
			if (A_Index == 2)
				aDomainNames.Insert(A_LoopField)
			if (A_Index == 3)
				aTypePrefixes.Insert(A_LoopField)
			if (A_Index == 4)
			{
				Msgbox Error! The Server Names database has an unexpected column. Please correct the database and try again.
				return
			}
		}
	}
	if (aComputers.MaxIndex() != aDomainNames.MaxIndex() && aComputers != aTypePrefixes.MaxIndex())
	{
		Msgbox An error oocured during parsing of the Server Names database. There is likely a missing column/tab somewhere in the file. Please correct the database and try again.
		return
	}
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
Tmp_Restart()
{
	return Run("shutdown.exe /r -t 5", "UseErrorLevel")
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
Tmp_Reload()
{
	Reload
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Used specifically for scripts in
;;;;;;;;;;;;;; Quick Launcher.ahk.
;;;;;;;;;;;;;; It shows all the certain information
;;;;;;;;;;;;;; as a ToolTip dependant upon "sInputText" prefix.
WatchForSpecialPrefix:
{
	; TODO: Make into CFlyout GUI
	WinGet, ActiveHwnd, ID, A
	if (ActiveHwnd == g_hQL) ; See variable in Quick Launcher.ahk
	{
		GuiControlGet, QLEdit, QuickLauncher:
		sInputText := QLEdit
		bTargetTextInWnd := false
		if (InStr(sInputText, "RD:"))
		{
			bTargetTextInWnd := true
			g_ToolTipString = Computer Name`tDomain`tType`/Domain
			Loop, % g_aComputers.MaxIndex() 
			{
				; LoadFromServerDatabase verifies that the arrays all match
				vCurComputer := g_aComputers[A_Index]
				vCurDomainName := g_aDomainNames[A_Index]
				vCurTypePrefix := g_aTypePrefixes[A_Index]
				g_ToolTipString = %g_ToolTipString%`n%vCurComputer%`t%vCurDomainName%`t%vCurTypePrefix%
			}
		}
		else if (InStr(sInputText, "PC:") || InStr(sInputText, "QD:"))
		{
			bTargetTextInWnd := true
			g_ToolTipString =

			Loop, Read, C:\Invtools\PC Footnotes.txt
			{
				if (A_Index == 1)
					g_ToolTipString = %A_LoopReadLine%
				else g_ToolTipString = %g_ToolTipString%`n%A_LoopReadLine%
			}
		}

		; Flyout...
		if (!bTargetTextInWnd)
			ToolTip
		else if (g_ToolTipString != g_PrevToolTipString)
			ToolTip, %g_ToolTipString%
	}

	g_PrevToolTipString := g_ToolTipString
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Polythene
	Function: Functions.ahk
		Purpose: Wraps Commands into Functions
	Parameters
		
*/
GuiControlGet(Subcommand = "", ControlID = "", Param4 = "") {
	GuiControlGet, v, %Subcommand%, %ControlID%, %Param4%
	Return, v
}

Run(Target, WorkingDir = "", Mode = "") {
	Run, %Target%, %WorkingDir%, %Mode%, 
	Return, !v ? ErrorLevel == 0: A_Blank
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;