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

OnMessage(WM_DISPLAYCHANGE:=126, "OnDisplayChange")
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
	InitQuickLauncher()
	InitFlyout()
	InitTrayMenu()

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: OnDisplayChange
		Purpose: To make sure GUIs retain the window positions.
			This particular window message tends to really screw things up, moving windows to weird places.
	Parameters
		
*/
OnDisplayChange()
{
	global g_hQL, g_iQLX, g_iQLY, g_iQLW, g_iQLH, g_vGUIFlyout

	WinMove, ahk_id %g_hQL%,, g_iQLX, g_iQLY, g_iQLW, g_iQLH

	iX := g_vGUIFlyout.GetFlyoutX
	iY := g_vGUIFlyout.mGetFlyoutY
	iW := g_vGUIFlyout.m_vConfigIni.Flyout.W
	iH := g_vGUIFlyout.m_vConfigIni.Flyout.H
	WinMove, % "ahk_id" g_vGUIFlyout.m_hFlyout,, iX, iY, iW, iH

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
	Function: InitTrayMenu
		Purpose: Set up tray menu
	Parameters
		
*/
InitTrayMenu()
{
	; Tray icon
	;Menu, TRAY, Icon, images\Main.ico,, 1

	OnExit, ExitProc

	Menu, TRAY, NoStandard
	Menu, TRAY, MainWindow ; For compiled scripts
	Menu, Tray, Tip, Quick Launcher
	Menu, TRAY, Add, &Open, QL_Show
	;Menu, TRAY, Icon, &Open, images\Open.ico,, 16
	Menu, TRAY, Add, E&xit, ExitApp
	Menu, TRAY, Default, &Open
	Menu, TRAY, Click, 1

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: InitQuickLauncher
		Purpose: Initialize the QL GUI
	Parameters
		
*/
InitQuickLauncher()
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

	GUI, QuickLauncher:New, +Hwndg_hQL +LastFound -Caption, Quick Launcher
	GUI, Color, Black

	GUI, Add, Picture, AltSubmit x0 y0 w%g_iQLW%, %sBackground% ; H%g_iQLH%

	GUI, Font, s55 c0x48A4FF, %sFont% ; c83B2F7 ; c000080 ; c83B2F7 ; q
	GUI, Add, Text, hwndg_hQLText vQLText x0 y0 w%g_iQLW% h%g_iQLH% Center BackgroundTrans +0x80, |

	GUI, Add, Edit, +Hwndg_hQLEdit BackgroundTrans vQLEdit gQLEditProc ; Can't use hidden because keystrokes are actually sent to this edit.

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

		; Editing commands
		Hotkey, AppsKey, QL_ShowFlyoutMenu
		Hotkey, ^Delete, QL_RemoveSelectedCmd
		Hotkey, ^r, QL_RenameSelectedCmd

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

		; Copy
		Hotkey, $^c, QL_Copy
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: InitFlyout
		Purpose: Initialize flyout
	Parameters
		
*/
InitFlyout()
{
	; Merge flyout configuration.
	vDefaultFlyoutConfig := new EasyIni("", GetDefaultFlyoutConfigIni())
	vTmpFlyoutConfig := new EasyIni("Flyout_config")
	vTmpFlyoutConfig.Merge(vDefaultFlyoutConfig)
	; Now save so the the CFlyout gets these changes.
	vTmpFlyoutConfig.Save()

	; Create CFlyout but start with it hidden (last parameter hides it for us).
	global g_hQL, g_iQLY, g_iTaskBarH
	;global g_vGUIFlyout := new CFlyout(g_hQL, 0, false, false, "", "", "", 10, A_ScreenHeight - g_iQLY - g_iTaskBarH, false, vTmpFlyoutConfig.Flyout.Background, 0, 0, "", false, false)

	global g_vGUIFlyout := new CFlyout(0, "Parent="g_hQL,
		, "Y=" A_ScreenHeight - g_iQLY - g_iTaskBarH
		, "Background=" vTmpFlyoutConfig.Flyout.Background)

	g_vGUIFlyout.OnMessage(WM_LBUTTONDOWN:=513
		. "," WM_LBUTTONUP:=514
		. "," WM_LBUTTONDBLCLK:=515
		. "," WM_RBUTTONDOWN:=516
		, "QL_OnFlyoutMessage")

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
	if (!Msgbox_YesNo("Remove this command?`n`n" g_vGUIFlyout.GetCurSel(), "Remove command"))
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

QL_RenameSelectedCmd:
{
	if (IsDisplayingHelpInfo())
		return

	vCmd := g_vCommandsIni[g_vGUIFlyout.GetCurSel()]
	sNewCmd := AddCmdProc(vCmd, false, g_vGUIFlyout.GetCurSel())

	if (sNewCmd = "")
		return

	if (g_MasterIni.HasKey(g_vGUIFlyout.GetCurSel()))
	{
		g_MasterIni.RenameSection(g_vGUIFlyout.GetCurSel(), sNewCmd, sError)
		g_MasterIni.Save()
	}
	else if (g_RecentIni.HasKey(g_vGUIFlyout.GetCurSel()))
	{
		g_RecentIni.RenameSection(g_vGUIFlyout.GetCurSel(), sNewCmd, sError)
		g_RecentIni.Save()
	}
	; Instead of reloading inis, update commands ini.
	if (g_vCommandsIni.HasKey(g_vGUIFlyout.GetCurSel()))
		g_vCommandsIni.RenameSection(g_vGUIFlyout.GetCurSel(), sNewCmd, sError)

	if (sError)
		Msgbox_Error(sError, 2)

	iLastSel := g_vGUIFlyout.GetCurSelNdx()+1
	UpdateCommands(QL_GetEditText())
	g_vGUIFlyout.MoveTo(iLastSel)

	return
}

QL_ResetSelCmdHitCount:
{
	vCmd := g_vCommandsIni[g_vGUIFlyout.GetCurSel()]
	vCmd.HitCount := 1
	if (g_MasterIni.HasKey(g_vGUIFlyout.GetCurSel()))
	{
		g_MasterIni[g_vGUIFlyout.GetCurSel()].HitCount := 1
		g_MasterIni.Save()
	}
	else if (g_RecentIni.HasKey(g_vGUIFlyout.GetCurSel()))
	{
		g_RecentIni[g_vGUIFlyout.GetCurSel()].HitCount := 1
		g_RecentIni.Save()
	}

	return
}

QL_Copy:
{
	VarSetCapacity(iStart, 4), VarSetCapacity(iEnd, 4)
	SendMessage, EM_GETSEL:=176, &iStart, &iEnd,, ahk_id %g_hQLEdit%
	iStart := NumGet(iStart)
	iEnd := NumGet(iEnd)

	; If text is selected, copy that text; otherwise copy what is selected in the flyout.
	if (iStart != iEnd || ErrorLevel = "FAIL")
		Send ^c
	else clipboard := g_vGUIFlyout.m_sCurSel

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
		Purpose: To localize logic to add a command to the database. Returns the new command name, if any.
	Parameters
		vCmd
		bSaveToDB=true: Set to false when we first want to prompt for a new command.
		sDefaultName="": Suggested name for command
*/
AddCmdProc(vCmd, bSaveToDB=true, sDefaultName="")
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

		Inputbox, sAddUserCmd, Add Command to Quick Launcher, % "Specify a shortcut for " vCmd.Parms,,,,,,,, %sDefaultName%
		if (ErrorLevel)
		{
			bContinue := false
			sAddUserCmd :=
		}
		else sAddUserCmd := Trim(sAddUserCmd) ; Spaces mess things up.
	}

	if (bSaveToDB && sAddUserCmd) ; If a valid shortcut was specified and we need to save to the DB.
		SaveToDB(sAddUserCmd, vCmd, "Master")

	return sAddUserCmd
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

	aCmds := GetMatchingCommands(sKeyInput)
	if (aCmds[1] != "" || IsDisplayingHelpInfo() || g_bShowAllCmds)
	{
		; Reduce flickering by only updating when necessary.
		; Don't check prev cmds if the arrays don't match or are huge.
		bUpdate := true
		aPrevCmds := g_vGUIFlyout.m_asItems
		if (aCmds.MaxIndex() == aPrevCmds.MaxIndex() && aCmds.MaxIndex() < 25)
		{
			sPrevCmds := st_glue(aPrevCmds)
			sCmds := st_glue(aCmds)
			bUpdate := (sPrevCmds != sCmds)
		}

		if (bUpdate)
		{
			g_vGUIFlyout.UpdateFlyout(aCmds)
			g_vGUIFlyout.MoveTo(1)
		}
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
QL_ShowFlyoutMenu:
{
	QL_ShowFlyoutMenu()
	return
}

QL_ShowFlyoutMenu()
{
	global g_vCommandsIni, g_vGUIFlyout
	static s_bInit := false

	; Disable context-menu on help info.
	if (IsDisplayingHelpInfo())
		return

	if (s_bInit)
		Menu, CFlyoutMenu, Delete

	Menu, CFlyoutMenu, Add, &Delete, QL_RemoveSelectedCmd
	Menu, CFlyoutMenu, Icon, &Delete, images\Delete.ico,, 16
	Menu, CFlyoutMenu, Add, &Rename, QL_RenameSelectedCmd
	Menu, CFlyoutMenu, Icon, &Rename, images\Edit.ico,, 16

	iHitCount := g_vCommandsIni[g_vGUIFlyout.GetCurSel()].HitCount
	Menu, CFlyoutMenu, Add, Reset hit &count`t(%iHitCount%), QL_ResetSelCmdHitCount
	Menu, CFlyoutMenu, Icon, Reset hit &count`t(%iHitCount%), images\Revert.ico,, 16

	Menu, CFlyoutMenu, Show

	s_bInit := true
	return
}

DummyLabel:
{
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

	RegisterCommandsToVoiceControl()

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: RegisterCommandsToVoiceControl
		Purpose:
	Parameters
		
*/
RegisterCommandsToVoiceControl()
{
	global g_vCommandsIni

	global g_vVoiceCtrl := new CustomSpeech

	g_vVoiceCtrl.Recognize(true)
	g_vVoiceCtrl.Listen(false)
	this.m_bListen := false
	return

	aVoiceCmds := []
	for sec in g_vCommandsIni
		aVoiceCmds.Insert(sec)

	g_vVoiceCtrl.Recognize(aVoiceCmds)
	g_vVoiceCtrl.Listen(false)

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
		bFromGUI=true: We can QuickLaunch from the backdoor, such as through the voice interface.
*/
QuickLaunch(sCmd="", bFromGUI=true)
{
	global g_vGUIFlyout, g_hQL, g_vCommandsIni, g_asCommandsHelp
		, g_vCommandsIni, g_MasterIni, g_RecentIni

	; Are we displaying help text?
	if (bFromGUI && IsDisplayingHelpInfo())
		return

	vCmd := ParseCmd(sCmd, false)
	if (IsObject(vCmd))
		sValidCmd := sCmd

	; This wasn't parsed, so try again using the currently selected item in the flyout.
	bIsNewCmd := !g_vCommandsIni.HasKey(sCmd)
	;~ Msgbox % st_concat("`n", !vCmd && bIsNewCmd, bIsNewCmd)
	if (!vCmd && bIsNewCmd)
	{
		if (bFromGui)
			sValidCmd := g_vGUIFlyout.GetCurSel()
		else
		{
			sValidCmd := GetMatchingCommands(sCmd)[1]
			if (!sValidCmd)
				return

			; Give a brief prompt to give the user a chance to cancel the command.
			bCancel := false
			CornerNotify(0.5, sValidCmd, "Press escape if you do not want to launch this command.")
			global cornernotify_hwnd
			Msgbox %cornernotify_hwnd%
			while (WinExist("ahk_id" cornernotify_hwnd))
			{
				if (bCancel := GetKeyState("Esc", "D"))
					break
				continue
			}

			if (bCancel)
				return
		}

		vCmd := ParseCmd(sValidCmd, true)
		bUsedExistingCmd := true
	}

	;~ Msgbox % st_concat("`n", "about to call " vCmd.Func, vCmd.Parms)
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
	if (bFromGUI)
		QL_Hide()

	; Save
	if (bSaveCmd)
		SaveToDB(sCmd, vCmd, "Recent")
	else if (bCmdWorked) ; If the command succeeded, update the hit count.
	{
		if (sValidCmd = "")
		{
			Msgbox_Error("Could not get a valid command.", 2)
			return
		}

		if (g_vCommandsIni[sValidCmd].HasKey("HitCount") && g_vCommandsIni[sValidCmd].HitCount != "")
			g_vCommandsIni[sValidCmd].HitCount := g_vCommandsIni[sValidCmd].HitCount+1
		else g_vCommandsIni[sValidCmd].HitCount := 1

		if (g_MasterIni.HasKey(sValidCmd))
		{
			if (g_MasterIni[sValidCmd].HasKey("HitCount") && g_MasterIni[sValidCmd].HitCount != "")
				g_MasterIni[sValidCmd].HitCount := g_MasterIni[sValidCmd].HitCount+1
			else g_MasterIni[sValidCmd].HitCount := 1

			; Save on exit.
		}
		else if (g_RecentIni.HasKey(sValidCmd))
		{
			if (g_RecentIni[sValidCmd].HasKey("HitCount") && g_RecentIni[sValidCmd].HitCount != "")
				g_RecentIni[sValidCmd].HitCount := g_RecentIni[sValidCmd].HitCount+1
			else g_RecentIni[sValidCmd].HitCount := 1

			; Save on exit.
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

	; Escape ampersands (and then unescape later).

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
	Function: QL_OnFlyoutMessage
		Purpose: Callback for CFlyout click events
	Parameters
		vFlyout: Flyout clicked
		msg: window message
*/
QL_OnFlyoutMessage(vFlyout, msg)
{
	global g_hQL
	static WM_LBUTTONDOWN:=513, WM_LBUTTONUP:=514, WM_LBUTTONDBLCLK := 515, WM_RBUTTONDOWN:=516
	Critical

	MouseGetPos,,, hActiveWndUnderCursor
	if (hActiveWndUnderCursor = g_hQL)
		return ; Clicking on the quick launcher shouldn't invoke anything.

	if (msg == WM_RBUTTONDOWN)
	{
		CoordMode, Mouse, Relative
		MouseGetPos,, iMouseY
		vFlyout.Click(iMouseY)
		; RClick messages are getting lost a LOT!
		; it's slightly better, though unconventional, to show the menu on WM_RBUTTONDOWN.
		QL_ShowFlyoutMenu()
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
	if (iHasCtrl := InStr(A_ThisHotkey, "^"))
		sSendStr := SubStr(A_ThisHotkey, iHasCtrl, 1)
	if (iHasShift := InStr(A_ThisHotkey, "+"))
		sSendStr .= SubStr(A_ThisHotkey, iHasShift, 1)

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
	sTxtFromEditWithCaret := sTxtFromEdit . sCaret

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
		sTxtFromEditWithCaret := sLeftStr . sCaret . sRightStr
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: OnExit
		Purpose: Save settings on close.
	Parameters
		
*/
ExitProc:
{
	g_MasterIni.Save()
	g_RecentIni.Save()
	ExitApp
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Class CustomSpeech
*/
class CustomSpeech extends SpeechRecognizer
{
	OnRecognize(sCmd)
	{
		this.m_bListen := false

		if (StrLen(sCmd) == 1)
			return

		_SimpleOSD().PostMsg(sCmd)
		QuickLaunch(sCmd, false)
	}

	RegisterCmd(sCmd, sAction)
	{
		this.Recognize([sCmd])
		return
	}

	m_bListen := false
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: 
		Purpose: Listen whenever Ctrl and Win is pressed down.
	Parameters
		
*/
~LControl & ~LWin::
{
	g_vVoiceCtrl.m_bListen := true
	g_vVoiceCtrl.Listen(true)

	while (g_vVoiceCtrl.m_bListen && (GetKeyState("LCtrl", "D") && GetKeyState("LWin", "D")))
		continue

	g_vVoiceCtrl.m_bListen := false
	g_vVoiceCtrl.Listen(false)

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#Include %A_ScriptDir%\CFlyout.ahk
#Include %A_ScriptDir%\HelperFunctions.ahk
#Include %A_ScriptDir%\Classified.ahk ; This is not under source control for security reasons. It includes custom things for me.
#Include %A_ScriptDir%\Speech Recognition.ahk