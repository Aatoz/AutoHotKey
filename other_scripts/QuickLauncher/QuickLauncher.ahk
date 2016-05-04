/*
QL 2.0

This rewrite of the QL is going to be amazing. I am dedicating it to my newfound friendship in the Holy Spirit.
I have never coded an app in such a way where I paused to ask the Holy Spirit's direction for each thing.

He is my friend, my helper, and He told me we're going to build this app together.
No need to look online for help for how to build a great app, just ask Him.

Let's do this!

TODO:
	1. Batch compiling
	2. Hotstring for my standard script init (#NoEvn and everything below)
*/

#SingleInstance Force

#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SetBatchLines -1
SetWinDelay, -1
SetWorkingDir, %A_ScriptDir%
StringCaseSense, Off
Thread, interrupt, 1000

if (A_IsCompiled)
	DoFileInstalls()

g_bIsFirstRun := AddContextMenuToRegistryIfNeeded()
InitEverything()

OnMessage(WM_DISPLAYCHANGE:=126, "InitEverything")
OnMessage(WM_SETTINGCHANGE:=26, "LoadQLDB") ; TODO: This may be better to split out into a separate function beacuse it's inefficient to reload everything (including the defaults)

; TODO: Command to reload instead of hotkey
^+Q::Reload

return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: InitEverything
		Purpose: Initialize everything
	Parameters
		
*/
InitEverything()
{
	InitGlobals()
	InitializeQuickLauncher()

	; Merge flyout configuration.
	vDefaultFlyoutConfig := new EasyIni("", GetDefaultFlyoutConfigIni())
	vTmpFlyoutConfig := new EasyIni("Flyout_config")
	vTmpFlyoutConfig.Merge(vDefaultFlyoutConfig)
	; Now save so the the CFlyout gets these changes.
	vTmpFlyoutConfig.Save()

	; Create CFlyout but start with it hidden (last parameter hides it for us).
	global g_hQL, g_iQLY, g_iTaskBarH
	global g_vGUIFlyout := new CFlyout(g_hQL, 0, false, false, "", "", "", 10, A_ScreenHeight - g_iQLY - g_iTaskBarH, false, vTmpFlyoutConfig.Flyout.Background, 0, 0, "", false, false)
	g_vGUIFlyout.OnMessage(WM_LBUTTONDOWN:=513
		. "," WM_LBUTTONUP:=514
		. "," WM_LBUTTONDBLCLK:=515
		. "," WM_RBUTTONDOWN:=516
		, "QL_OnCFlyoutClick")

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: InitGlobals
		Purpose: Initialize all globals here
	Parameters
		
*/
InitGlobals()
{
	global g_bIsFirstRun

	; http://msdn.microsoft.com/en-us/library/windows/desktop/aa511453.aspx#sizing
	global g_iMSDNStdBtnW := 75
	global g_iMSDNStdBtnH := 23
	global g_iMSDNStdBtnSpacing := 6

	SysGet, iPrimary, MonitorPrimary
	SysGet, iPrimaryMon, Monitor, %iPrimary%
	SysGet, iPrimaryMonWorkArea, MonitorWorkArea, %iPrimary%
	WinGetPos,,,, iH, ahk_class Shell_TrayWnd
	bTaskBarAffectsHeight := (PrimaryMonTop != iPrimaryMonWorkAreaTop && iPrimaryMonBottom != iPrimaryMonWorkAreaBottom)
	global g_iTaskBarH := (bTaskBarAffectsHeight ? iH : 0)

	global g_avSpecialCmds := new EasyIni("", GetSpecialCmdsIni())
	global g_asCommandsHelp := ["---Welcome to Quick Launcher", "||Command`tDescription"]
	for sec, aData in g_avSpecialCmds.Commands
	{
		StringLower, sec, sec ; lower-case commands look better to me.
		g_asCommandsHelp.Insert(sec ":`t`t" g_avSpecialCmds[sec].Desc)
	}

	vDefaultConfigIni := new EasyIni("", GetDefaultConfigIni())
	global g_ConfigIni := new EasyIni("config.ini")
	g_ConfigIni.Merge(vDefaultConfigIni)

	LoadInvPaths()

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: InitializeQuickLauncher
		Purpose: Initialize the QL GUI
	Parameters
		
*/
InitializeQuickLauncher()
{
	global

	for key, val in g_ConfigIni.QLauncher
	{
		if (InStr(val, "Expr:"))
			NewVal := Trim(DynaExpr_EvalToVar(SubStr(val, InStr(val, "Expr:") + 5)), A_Space)
		else NewVal := val

		if (key = "Background" || key = "Font")
			s%key% := NewVal

		if (key = "SubmitSelectedIfNoMatchFound")
			g_bQL%key% := (NewVal = "true" || NewVal = "1" ? true : false)
		else if (key = "Hotkey")
			g_sQL%key% := NewVal
		else g_iQL%key% := NewVal
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

	GUI, Add, Button, x0 y0 h32 w36 hwndg_hQLSettings , `n&s ; gLaunchQuickLauncherEditor
	ILButton(g_hQLSettings, "images\Settings.ico", 32, 32, 4)

	GUI, Color, Black
	GUI, +LastFound -Caption
	;~ WinSet, Transparent, 0
	;~ GUI, Show, X-32768 Y-32768 W%g_iQLW% h%g_iQLH%

	;~ WAnim_SlideViewInOutFrom(true, "Bottom", g_iQLX, g_iQLY, g_hQL, "QuickLauncher")
	;~ WAnim_FadeViewInOut(g_hQL, 20, true, "QuickLauncher")

	; Hotkeys
	Hotkey, IfWinActive, ahk_id %g_hQL%
	{
		; Hotkey to launch Flyout.
		; Arrows
		Hotkey, Down, Flyout_MoveDown
		Hotkey, Up, Flyout_MoveUp
		; PageUp/PageDown
		Hotkey, PgDn, Flyout_PgDown
		Hotkey, PgUp, Flyout_PgUp
		; Scrolling
		Hotkey, WheelDown, Flyout_WheelDown
		Hotkey, WheelUp, Flyout_WheelUp

		; Delete keys
		Hotkey, +Delete, QL_RemoveSelectedCmd

		; Submit keys.
		Hotkey, Enter, QLEnterProc
		Hotkey, NumpadEnter, QLEnterProc
		Hotkey, MButton, QLEnterProc
		Hotkey, ^Enter, Submit_Selected_From_Flyout
		Hotkey, ^NumpadEnter, Submit_Selected_From_Flyout
		Hotkey, ^MButton, Submit_Selected_From_Flyout

		; Navigation keys.
		asCaretHKs := ["Home", "End", "Left", "Right", "Up", "Down"]
		for iHK, sHK in asCaretHKs
		{
			if (sHK != "Up" && sHK != "Down")
				Hotkey, %sHK%, QLCaretProc

			Hotkey, ^%sHK%, QLCaretProc
			Hotkey, +%sHK%, QLCaretProc
			Hotkey, ^+%sHK%, QLCaretProc
		}
	}

	Hotkey, IfWinExist
		Hotkey, %g_sQLHotkey%, QL_Show

	_DragDrop() ; Init stb lib.
	if (DragDrop.ShouldUseDD())
		g_vQLDD := new DragDrop("QL_SimulateDragNDrop", g_hQL)

	; For Flyout
	; Load the arrays even if we don't use a flyout, because, most of the time, we will.
	; Also I think this may be faster than loading the arrays upon creation.
	LoadQLDB()

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;; Flyout helper
Flyout_MoveDown:
{
	g_vGUIFlyout.Move(false) ; false = Down
	return
}

Flyout_MoveUp:
{
	g_vGUIFlyout.Move(true) ; true = Up
	return
}

Flyout_PgDown:
{
	g_vGUIFlyout.MovePage(false)
	return
}

Flyout_PgUp:
{
	g_vGUIFlyout.MovePage(true)
	return
}

Flyout_WheelDown:
{
	g_vGUIFlyout.Scroll(false)
	return
}

Flyout_WheelUp:
{
	g_vGUIFlyout.Scroll(true)
	return
}

Submit_Selected_From_Flyout:
{
	QuickLaunch()
	return
}

QL_RemoveSelectedCmd:
{	; RRRR method
	if (IsDisplayingHelpInfo())
		return

	; Prompt to delete.
	if (!Msgbox_YesNo("Remove the following command: " g_vGUIFlyout.GetCurSel(), "Remove command"))
		return

	; Remember last selected item.
	g_iLastSel := g_vGUIFlyout.GetCurSelNdx()
	; Remove command from DB.
	RemoveCmdFromDB(g_vGUIFlyout.GetCurSel())
	; Remove command flyout.
	g_vGUIFlyout.RemoveItem(g_iLastSel+1) ; Number is 0-based but RemoveItem is 1-based.
	; Restore last selected item.
	if (g_iLastSel == 0)
		g_iLastSel := 1
	g_vGUIFlyout.MoveTo(g_iLastSel)

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: QuickLauncherGUIDropFiles
		Purpose: Allow Drag 'n Drop files onto GUI for an easy way to add commands! See also QL_WatchForDD.
	Parameters
		
*/
QuickLauncherGUIDropFiles:
{
	QL_SimulateDragNDrop(A_GUIEvent)
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: QL_SimulateDragNDrop
		Purpose: Drag n Drop happens here, but it doesn't work on Win8+. So I use the DragDrop class to simulate it -- hah!
	Parameters
		DDContents: Either the string from native DD or else COM object from DragDrop callback -- cool!
*/
QL_SimulateDragNDrop(DDContents)
{
	if (IsObject(DDContents))
	{
		for vItem in DDContents
		{
			vCmd := {Func: "Run", Parms: vItem.path}
			AddCmdProc(vCmd)
		}
	}
	else ; we have a list of files from the native DD -- great!
	{
		Loop, Parse, DDContents, `n
		{
			vCmd := {Func: "Run", Parms: A_LoopField}
			AddCmdProc(vCmd)
		}
	}

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: AddCmdProc
		Purpose: To localize logic to add a command to the database
	Parameters
		vCmd
*/
AddCmdProc(vCmd)
{
	bContinue := true
	while (!sAddUserCmd && bContinue)
	{
		if (A_Index > 1)
		{
			if (!Msgbox_YesNo("An invalid name was specified for this command. Do you want to try to specify a different name?`n"
				. "`nCmd:`t"sAddUserCmd
				. "`nPath:`t" vCmd.Parms
				, "Cancel adding command?"))
				break
		}

		InputBox, sAddUserCmd, Add Command to Quick Launcher, % "Specify a shortcut for " vCmd.Parms
		if (ErrorLevel)
		{
			bContinue := false
			sAddUserCmd :=
		}
		else sAddUserCmd := Trim(sAddUserCmd) ; Spaces mess things up.
	}

	if (sAddUserCmd) ; If a valid shortcut was specified
		SaveToDB(sAddUserCmd, vCmd, "Master")

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: QL_Show
		Purpose: Show Quick Launcher
	Parameters
		
*/
QL_Show:
{
	QL_Show()
	return
}

QL_Show()
{
	global g_hQL, g_iQLX, g_iQLY, g_iQLW, g_iQLH
		, g_vGUIFlyout, g_asCommandsHelp

	; Before showing the quick launcher, store the currently active
	; window in a variable so that we can, potentially, call functions
	; that would make changes to that window.
	global g_hActiveWndBeforeQLInit :=
	WinGet, g_hActiveWndBeforeQLInit, ID, A

	IfWinExist, ahk_id %g_hQL%
		WinActivate, ahk_id %g_hQL%
	else
	{
		; On startup, display list of available commands.
		g_vGUIFlyout.Show()
		DisplayListOfAvailCommands()

		GUI, QuickLauncher:Default
		GUIControl, Enable, QLEdit ; See QuickLaunch().
		GUIControl, Focus, QLEdit
		GUI, Show, X%g_iQLX% Y%g_iQLY% W%g_iQLW% h%g_iQLH%
	}
	WinSet, Trans, Off, ahk_id %g_hQL%

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: QL_Hide
		Purpose: Hide the launcher and flyout.
	Parameters
		
*/
QL_Hide()
{
	global g_vGUIFlyout, g_hQL

	g_vGUIFlyout.UpdateFlyout("") ; Clears the list.
	g_vGUIFlyout.Hide()

	; Note: we have to disable/enable the edit when exiting;
	; otherwise, you can type while we are sliding out, which reactives the flyout.
	GUI, QuickLauncher:Default
	GUIControl, Disable, QLEdit
	WAnim_SlideOut("Bottom", g_hQL, "QuickLauncher", 20, false)
	; Don't enable yet because WAnim returns immediately after setting a timer.
	; Reactivate in QL_Show.

	GUIControl,, QLEdit, ; Clear out edit
	global g_sLastTxtFromEdit := ""

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function:
		Purpose:
	Parameters
		sKeyInput: Update with commands keyed off this input.
*/
UpdateCommands(sKeyInput, bShowAllCmds=false)
{
	global g_vGUIFlyout
	global g_bShowAllCmds := bShowAllCmds

	asShortcuts := GetMatchingCommands(sKeyInput)
	if (asShortcuts[1] != "" || IsDisplayingHelpInfo() || g_bShowAllCmds)
	{
		g_vGUIFlyout.UpdateFlyout(asShortcuts)
		g_vGUIFlyout.MoveTo(1)
	}

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: DisplayListOfAvailCommands
		Purpose:
	Parameters
		
*/
DisplayListOfAvailCommands()
{
	global g_vGUIFlyout, g_asCommandsHelp
	if (!g_vGUIFlyout.m_bIsHidden)
		g_vGUIFlyout.UpdateFlyout(g_asCommandsHelp)
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: IsDisplayingHelpInfo
		Purpose: Indicates whether or not the flyout is showing the available commands
	Parameters
		
*/
IsDisplayingHelpInfo()
{
	global g_vGUIFlyout, g_asCommandsHelp
	return g_vGUIFlyout.FindString(g_asCommandsHelp[1]) == 1
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: QL_ShowFlyoutMenu
		Purpose:
	Parameters
		
*/
QL_ShowFlyoutMenu()
{
	Menu, CFlyoutMenu, Add, &Delete, QL_RemoveSelectedCmd
	Menu, CFlyoutMenu, Show
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;; API ;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function:
		Purpose:
	Parameters
		
*/
LoadQLDB()
{
	global g_MasterIni := new EasyIni("Master.ini")
	global g_RecentIni := new EasyIni("Recent.ini")

	; We won't overwrite any existing keys.
	SaveDefaultCmdsToMasterIni()

	global g_vCommandsIni := new EasyIni("Master.ini") ; ObjCopy is actually not copying properly, so, at least for now, just init to Master.ini
	g_vCommandsIni.Merge(g_RecentIni)

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: QuickLaunch
		Purpose: The main quick launch routine
	Parameters
		sCmd="": Command to launch
*/
QuickLaunch(sCmd="")
{
	global g_vGUIFlyout, g_hQL, g_vCommandsIni, g_asCommandsHelp
		, g_vCommandsIni, g_MasterIni, g_RecentIni

	; Are we displaying help text?
	if (IsDisplayingHelpInfo())
		return

	vCmd := ParseCmd(sCmd, false)

	; This wasn't parsed, so try again using the currently selected item in the flyout.
	bIsNewCmd := !g_vCommandsIni.HasKey(sCmd)
	;~ Msgbox % st_concat("`n", !vCmd && bIsNewCmd, bIsNewCmd)
	if (!vCmd && bIsNewCmd)
	{
		sValidCmd := g_vGUIFlyout.GetCurSel()
		vCmd := ParseCmd(sValidCmd, true)
		bUsedExistingCmd := true
	}

	;~ Msgbox % "about to call " vCmd.Func
	if (vCmd.Func)
		bCmdWorked := (Func(vCmd.Func).(vCmd.Parms) || vCmd.Func = "DynaExpr_Eval") ; return val for this function is unreliable
	;~ Msgbox % st_concat("`n", bUsedExistingCmd, bCmdWorked)
	; TODO: Maybe revert. I'm trying to allow shorthand such as i:perf (matched selected for i:PerformSmartBase)
	; This seems good, but maybe it will prevent other valid commands from registering...
	if (bIsNewCmd && bCmdWorked && !bUsedExistingCmd)
		bSaveCmd := true 
	else if (!bCmdWorked)
	{
		sValidCmd := g_vGUIFlyout.GetCurSel()
		vCmd := ParseCmd(sValidCmd, true)
		; I like this functionality even less now that I'm hard-coding things to avoid ExitApp (and possibly all internal (int:) commands...)
		if (vCmd.Func != "ExitApp")
			bCmdWorked := Func(vCmd.Func).(vCmd.Parms)
	}
	;~ Msgbox % st_concat("`n", bIsNewCmd, bCmdWorked, bUsedExistingCmd, "Save?`t" bSaveCmd)
	; Hide
	QL_Hide()

	; Save
	if (bSaveCmd)
		SaveToDB(sCmd, vCmd, "Recent")
	else if (bCmdWorked) ; If the command succeeded, update the hit count.
	{
		if (g_vCommandsIni[sValidCmd].HasKey("HitCount") && g_vCommandsIni[sValidCmd].HitCount != "")
			g_vCommandsIni[sValidCmd].HitCount := g_vCommandsIni[sValidCmd].HitCount+1
		else g_vCommandsIni[sValidCmd].HitCount := 1

		if (g_MasterIni.HasKey(sValidCmd))
		{
			if (g_MasterIni[sValidCmd].HasKey("HitCount") && g_MasterIni[sValidCmd].HitCount != "")
				g_MasterIni[sValidCmd].HitCount := g_MasterIni[sValidCmd].HitCount+1
			else g_MasterIni[sValidCmd].HitCount := 1

			g_MasterIni.Save()
		}
		else if (g_RecentIni.HasKey(sValidCmd))
		{
			if (g_RecentIni[sValidCmd].HasKey("HitCount") && g_RecentIni[sValidCmd].HitCount != "")
				g_RecentIni[sValidCmd].HitCount := g_RecentIni[sValidCmd].HitCount+1
			else g_RecentIni[sValidCmd].HitCount := 1

			g_RecentIni.Save()
		}
	}

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function:
		Purpose:
	Parameters
		sCmd: 
		bIsDefinitelyCmd: 
*/
ParseCmd(sCmd, bDefinitelyIsCmd)
{
	global g_vCommandsIni, g_avSpecialCmds

	if (sCmd == "")
		return false

	; First see if this is a saved command
	if (g_vCommandsIni.HasKey(sCmd))
		return g_vCommandsIni[sCmd]

	; Allow a few shorthand commands...
	;~ Msgbox % st_concat("`n", bSaveCmd, sCmd, SubStr(sCmd, 1, 2), SubStr(sCmd, StrLen(sCmd)-1, 2))
	if (SubStr(sCmd, 1, 2) = "[[" && SubStr(sCmd, StrLen(sCmd)-1, 2) = "]]")
	{
		sOldCmd := sCmd
		sCmd := "[[:" sCmd
	}

	iPosOfColon := InStr(sCmd, ":") ; Paths, such as C:\Program Files, have colons, and we don't want to split that.
	StringLeft, sSubCmd, sCmd, iPosOfColon-1
	StringRight, sParms, sCmd, StrLen(sCmd)-iPosOfColon

	; Not a special cmd.
	bIsSpecialCmd := sSubCmd && sParms
	;~ Msgbox % st_concat("`n", sCmd, sSubCmd, sParms, bDefinitelyIsCmd)
	if (!bIsSpecialCmd && !bDefinitelyIsCmd)
		return false

	sDo := g_avSpecialCmds["Commands"][sSubCmd]
	;~ Msgbox % st_concat("`n", sCmd, sSubCmd, sParms, sDo, bDefinitelyIsCmd)

	; Straight up copies copy of g_avSpecialCmds causes duplicate keys -- it's weird.
	vCmd := {Func: g_avSpecialCmds[sSubCmd].Func, Parms: sParms}

	if (sDo = "CLS Lookup")
		sCmd := sOldCmd

	return vCmd
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: SaveToDB
		Purpose: Saves to Master Commands or Recent Quick Launcher Commands ini
	Parameters
		sCmd: 
		vCmdInfo: 
		sIni: 
*/
SaveToDB(sCmd, vCmdInfo, sIni)
{
	global g_vCommandsIni, g_MasterIni, g_RecentIni

	if (sIni = "Master")
	{
		if (g_MasterIni.AddSection(sCmd, "", "", sError))
		{
			g_MasterIni[sCmd] := vCmdInfo
			g_MasterIni.Save()
		}
		else Msgbox 8192,, %sError%
	}
	else
	{
		if (g_RecentIni.AddSection(sCmd, "", "", sError))
		{
			g_RecentIni[sCmd] := vCmdInfo
			g_RecentIni.Save()
		}
		else Msgbox 8192,, %sError%
	}

	if (g_vCommandsIni.AddSection(sCmd, "", "", sError))
		g_vCommandsIni[sCmd] := vCmdInfo
	else Msgbox 8192,, %sError%

	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: RemoveCmdFromDB
		Purpose:
	Parameters
		sCmd: Command to remove
*/
RemoveCmdFromDB(sCmd)
{
	global g_vCommandsIni, g_MasterIni, g_RecentIni

	g_vCommandsIni.Remove(sCmd)
	if (g_MasterIni.HasKey(sCmd))
	{
		g_MasterIni.Remove(sCmd)
		g_MasterIni.Save()
	}
	else
	{
		g_RecentIni.Remove(sCmd)
		g_RecentIni.Save()
	}

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: QL_OnCFlyoutClick
		Purpose: Callback for CFlyout click events
	Parameters
		vFlyout: Flyout clicked
		msg: window message
*/
QL_OnCFlyoutClick(vFlyout, msg)
{
	global g_hQL
	static WM_LBUTTONDOWN:=513, WM_LBUTTONDBLCLK := 515, WM_RBUTTONDOWN:=516
	Critical

	MouseGetPos,,, hActiveWndUnderCursor
	if (hActiveWndUnderCursor = g_hQL)
		return ; Clicking on the quick launcher shouldn't invoke anything.

	if (msg == WM_RBUTTONDOWN)
	{
		CoordMode, Mouse, Relative
		MouseGetPos,, iMouseY
		vFlyout.Click(iMouseY)
		QL_ShowFlyoutMenu() ; RClick messages are getting lost a LOT; it's slightly better, though unconventional, to show the menu on RClick.
	}
	else if (msg == WM_LBUTTONDBLCLK && vFlyout.GetCurSel() != "")
		QuickLaunch()

	; Parenting QL to flyout...
	WinActivate, ahk_id %g_hQL%

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: QLCaretProc
		Purpose: On caret change
	Parameters
		
*/
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
		sSendStr := SubStr(A_ThisHotkey, InStr(A_ThisHotkey, "^"), 1)
	}
	if (InStr(A_ThisHotkey, "+"))
	{
		iHasShift := InStr(A_ThisHotkey, "+")
		sSendStr .= SubStr(A_ThisHotkey, InStr(A_ThisHotkey, "+"), 1)
	}

	iTextPos := iHasShift
	if (iHasCtrl > iTextPos)
		iTextPos := iHasCtrl
	iTextPos++

	sSendStrText := SubStr(A_ThisHotkey, iTextPos)

	SendInput %sSendStr%{%sSendStrText%}
	QLEditProc()

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: QLEditProc
		Purpose: Event handler for edit in QL
	Parameters
		
*/
QLEditProc:
{
	QLEditProc()
	return
}

QLEditProc()
{
	global g_hQLEdit, g_vGUIFlyout, g_sLastTxtFromEdit, g_bShowAllCmds

	GUI, QuickLauncher:Default
	sCaret := "|" ; With regular fonts, this actually looks better. The actual caret -- Chr(5) -- leaves a large spacing between letters.

	sTxtFromEdit := QL_GetEditText()
	sTxtFromEditWithCaret := sTxtFromEdit sCaret

	if (sTxtFromEdit = "cmds:")
	{
		QL_SetEditText()
		QL_SetText()
		g_sLastTxtFromEdit := ""

		UpdateCommands("", true) ; true=Show all commands.
		return
	}

	ControlGet, iCaretPos, CurrentCol,,, ahk_id %g_hQLEdit%
	if (iCaretPos != StrLen(sTxtFromEdit) + 1) ; if the caret is no longer at the end of the text.
	{
		sLeftStr := SubStr(sTxtFromEdit, 1, iCaretPos - 1)
		sRightStr := SubStr(sTxtFromEdit, StrLen(sLeftStr) + 1)
		sTxtFromEditWithCaret := sLeftStr sCaret sRightStr
	}

	QL_SetText(sTxtFromEditWithCaret)

	if (sTxtFromEdit == "" || sTxtFromEdit == g_sLastTxtFromEdit)
	{
		if (sTxtFromEdit == "" && !g_bShowAllCmds)
			DisplayListOfAvailCommands() ; When there is no text, display list of available commands.
	}
	else UpdateCommands(sTxtFromEdit)

	g_sLastTxtFromEdit := sTxtFromEdit
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: QL_GetEditText
		Purpose: Get edit text from quick launcher edit
	Parameters
		
*/
QL_GetEditText()
{
	GUI, QuickLauncher:Default ; I like this better in case callers assume QuickLauncher is the default.
	return GUIControlGet("", "QLEdit")
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: QL_SetEditText
		Purpose: Set edit text for quick launcher edit
	Parameters
		
*/
QL_SetEditText(sText="")
{
	GUI, QuickLauncher:Default
	GUIControl,, QLEdit, %sText%
	return ErrorLevel
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: QL_SetText
		Purpose: Set text for quick launcher edit
	Parameters
		sText=""
*/
QL_SetText(sText="")
{
	GUI, QuickLauncher:Default
	GUIControl,, QLText, %sText%
	return ErrorLevel
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: GetMatchingCommands
		Purpose: Get matching commands out of commands ini. Commands are sorted by HitCount
	Parameters
		sCmdToMatch="": Blank parameter means all
*/
GetMatchingCommands(sCmdToMatch="")
{
	StringReplace, sCmdToMatch, sCmdToMatch, \, \\, All
	StringReplace, sCmdToMatch, sCmdToMatch, ., \., All
	StringReplace, sCmdToMatch, sCmdToMatch, *, \*, All
	StringReplace, sCmdToMatch, sCmdToMatch, ?, \?, All
	StringReplace, sCmdToMatch, sCmdToMatch, +, \+, All
	StringReplace, sCmdToMatch, sCmdToMatch, [, \[, All
	StringReplace, sCmdToMatch, sCmdToMatch, `{, \`}, All
	StringReplace, sCmdToMatch, sCmdToMatch, |, \|, All
	StringReplace, sCmdToMatch, sCmdToMatch, `(, \`(, All
	StringReplace, sCmdToMatch, sCmdToMatch, `), \`), All
	StringReplace, sCmdToMatch, sCmdToMatch, ^, \^, All
	StringReplace, sCmdToMatch, sCmdToMatch, $, \$, All

	return GetCmdsByHitCount(sCmdToMatch)
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: GetCmdsByHitCount
		Purpose: Get commands sorted by their hit count. Higher hit counts go first!
	Parameters
		sCmdToMatch="": Blank parameter means all
*/
GetCmdsByHitCount(sCmdToMatch)
{
	global g_vCommandsIni

	sExpr := "i)" sCmdToMatch ".*"
	for sec in g_vCommandsIni
	{
		if (RegExMatch(sec, sExpr))
		{
			if (sCmdToMatch = sec)
			{
				sExactMatch := sec ; use the sec to match case-sensitivity.
				continue
			}

			sNewSec := sec
			StringReplace, sNewSec, sNewSec, &, &&, All ; Escape ampersands so they aren't underlined.

			sCmds .= (sCmds ? "`n" : "") . g_vCommandsIni[sec].HitCount "_" sNewSec
		}
	}

	; Sort everything by hit count.
	Sort, sCmds, N R ; Numeric-reverse sort
	; Now build array based off hit count.
	aCmds := []
	Loop, Parse, sCmds, `n, `r
	{
		sCmd := SubStr(A_LoopField, InStr(A_LoopField, "_")+1)
		aCmds.Insert(sCmd)
	}

	; Exact matches should be first.
	if (sExactMatch)
		aCmds.InsertAt(1, sExactMatch)

	return aCmds
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
******************************************
	Purpose: Hotkeys for Quick Launcher
******************************************
*/
QLEnterProc:
{
	QuickLaunch(QL_GetEditText())
	return
}

QuickLauncherGUIClose:
QuickLauncherGUIEscape:
{
	QL_Hide()
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#Include %A_ScriptDir%\CFlyout.ahk
#Include %A_ScriptDir%\HelperFunctions.ahk
#Include %A_ScriptDir%\Classified.ahk ; This is not under source control for security reasons. It includes custom things for me.