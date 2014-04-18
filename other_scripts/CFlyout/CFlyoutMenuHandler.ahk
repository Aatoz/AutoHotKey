class CFlyoutMenuHandler
{
	__New(sPathToAHKDll="AutoHotkey.dll", iX=0, iY=0, iW=0, iMaxRows=0, sIni="", sSlideFrom="Left")
{
		FileInstall, CFMH_res.dll, CFMH_res.dll, 1

		sOldWorkingDir := A_WorkingDir
		SetWorkingDir, %A_ScriptDir%

		if (iX == A_Blank)
			iX := 0
		if (iY == A_Blank)
			iY := 0
		if (iW == A_Blank)
			iW := 400
		if (iMaxRows == A_Blank)
			iMaxRows := 10

		; Load the resource file that gives us the file names to load.
		DllRead(pFileNames, this.m_sPathToResDll, "FILES", "FileNames.txt")
		sFilesToInclude := StrGet(&pFileNames, "")
		; Load all files into memory to be placed in thread.
		Loop, Parse, sFilesToInclude, `n, `r
		{
			if (A_LoopField == "")
				continue

			if (DllRead(pFile, this.m_sPathToResDll, "FILES", A_LoopField))
			{
				sFIle := StrGet(&pFile, "")
				sAllFiles .= "`n`n; -----Begin " A_LoopField " -----`n`n" sFile
			}
			else
			{
				Msgbox 8192,, Error: Resource file %A_LoopField% could not be found in CFMH_res.dll.
				ExitApp ; If the include fails, then the whole script will fail anyway.
			}
		}

		sLabels :="
			(LTrim
				FlyoutMenuHandler_MainMenu:
				{
					hActiveMenu := ""ahk_id"" g_aFlyouts[g_aFlyouts.MaxIndex()].m_hFlyout

					If (WinExist(hActiveMenu))
					{
						if (!WinActive(hActiveMenu))
							g_hActiveWndBeforeMenu := WinExist(""A"")

						WinActivate, %hActiveMenu%
						return
					}
					else g_hActiveWndBeforeMenu := WinExist(""A"")

					g_bCalledFromClick := false

					if (WinGetTitle() = ""Program Manager"")
						g_hActiveWndBeforeMenu := DllCall(""GetWindow"", uint, g_hActiveWndBeforeMenu, uint, 2)

					g_aFlyouts := []
					g_vTopmostFlyout := CreateFlyoutMenu(""MainMenu"", 0)

					g_aFlyouts.Insert(g_vTopmostFlyout)
					;~ WAnim_SlideIn(""Left"", g_iX, g_iY, g_vTopmostFlyout.m_hFlyout, ""GUI_Flyout1"", 50)
					WinMove, % ""ahk_id"" g_vTopmostFlyout.m_hFlyout,, g_iX, g_iY

					SetTimer FlyoutMenuHandler_ExitWhenInactive, 100
					return
				}
			)"

		this.m_sIni := sIni
		this.EnsureIniLoaded()

		; Sections are menus
		for sSec, aKeysAndVals in this.m_vMenuConfigIni
		{
			sLabel := sSec
			this.RemoveIllegalLabelChars(sLabel)

			; Set up links from parent menus to sub menus
			if (sSec != "MainMenu")
			{
				sLabels .="
					(

						FlyoutMenuHandler_" sLabel ":
						{
							Critical

							g_vTopmostFlyout := g_aFlyouts[g_aFlyouts.MaxIndex()]
							; Move selection to proper menu item
							if (!(A_ThisHotkey = ""Enter""
								|| A_ThisHotkey = ""NumpadEnter""
								|| A_ThisHotkey = ""Right""
								|| A_ThisHotkey = ""MButton""
								|| g_bCalledFromClick))
							{
								iMoveTo := 1
								for sHK in g_MenuHelperIni[g_vTopmostFlyout.m_hFlyout]
								{
									if (sHK = A_ThisHotkey)
									{
										iMoveTo := A_Index
										break
									}
								}
								g_vTopmostFlyout.MoveTo(iMoveTo)
							}

							g_bCalledFromClick := false

							if (g_vTopmostFlyout.GetCurSelNdx() == 0)
								iYOffset := 0
							else iYOffset := g_vTopmostFlyout.CalcHeightTo(g_vTopmostFlyout.GetCurSelNdx() - g_vTopmostFlyout.m_iDrawnAtNdx)

							vNewTopmostFlyout := CreateFlyoutMenu(""" sSec """, g_vTopmostFlyout.m_hFlyout)
							g_aFlyouts.Insert(vNewTopmostFlyout)

							FlyoutMenuHandler_GetRectForMenu(vNewTopmostFlyout, iX, iY, iYOffset)
							WinMove, % ""ahk_id"" vNewTopmostFlyout.m_hFlyout,, iX, iY
							g_vTopmostFlyout := vNewTopmostFlyout
							vNewTopmostFlyout := ; must release CFlyout object in order to delete it later
							return
						}
					)"
			}

			; Now create wrapper-labels for every function within this menu
			sVals := this.m_vMenuConfigIni.GetVals(sSec)
			Loop, Parse, sVals, `n, `r
			{
				if (!InStr(A_LoopField, "Func:") && !InStr(A_LoopField, "Label:") && !InStr(A_LoopField, "Internal:"))
					continue

				if (InStr(A_LoopField, "Func:"))
				{
					StringReplace, sFunc, A_LoopField, Func:, , All
					sFuncTrimmed := Trim(sFunc, A_Space)
					iPosOfFirstParen := InStr(sFuncTrimmed, "(") + 1
					iPosOfLastParen := StrLen(sFuncTrimmed) ; Passed in parameters may contain quotations, so using StrLen instead of InStr ensures we get the closing quotations
					sParms := SubStr(sFuncTrimmed, iPosOfFirstParen, iPosOfLastParen - iPosOfFirstParen)
					sFuncCallWithParms := """" SubStr(sFuncTrimmed, 1, InStr(sFuncTrimmed, "(")-1) """, " sParms
					sFuncOrLabelCall := "g_vExe.ahkPostFunction[" sFuncCallWithParms "]"
				}
				else if (InStr(A_LoopField, "Label:"))
				{
					StringReplace, sLabel, A_LoopField, Label:, , All
					sFuncOrLabelCall := "g_vExe.ahkLabel[""" Trim(sLabel, A_Space) """]"
				}
				else ; this is an "internal" function, that is, used within the thread instead of the parent...or whatever
				{
					StringReplace, sLabel, A_LoopField, Internal:, , All
					; For now, the only use I can think of is exiting, so I'm just implementing hard-code functionality unless the need for internal functions becomes greater
					if (sLabel = "Exit")
						continue ; This is already created.
					sFuncOrLabelCall := ; TODO: More internal functions.
				}

				sFuncWithParmsLabel := A_LoopField
				this.RemoveIllegalLabelChars(sFuncWithParmsLabel)

				sLabels .="
					(LTrim

						FlyoutMenuHandler_" sFuncWithParmsLabel ":
						{
							" sFuncOrLabelCall "
							gosub, FlyoutMenuHandler_ExitMainMenu
							return
						}
					)"
			}
		}
StringReplace, sIni, sIni, `", `"`", All
		sScript:="
			(LTrim

		`; Begin thread
		#Persistent
		#SingleInstance Force
		#NoTrayIcon
		SetBatchLines, -1
		SetWinDelay, -1
		Thread, interrupt, 1000

		#if WinGetClass(""A"") = ""AutoHotkeyGUI"" && InStr(WinGetActiveTitle(), ""GUI_Flyout"")
			Hotkey, Down, FlyoutMenuHandler_MoveDown
			Hotkey, WheelDown, FlyoutMenuHandler_MoveDown
			Hotkey, Up, FlyoutMenuHandler_MoveUp
			Hotkey, WheelUp, FlyoutMenuHandler_MoveUp
			Hotkey, Enter, FlyoutMenuHandler_SubmitSelected
			Hotkey, NumpadEnter, FlyoutMenuHandler_SubmitSelected
			Hotkey, MButton, FlyoutMenuHandler_SubmitSelected
			Hotkey, Right, FlyoutMenuHandler_SubmitSelected
			Hotkey, Left, FlyoutMenuHandler_ExitTopmost

		; INIs
		g_vMenuConfigIni := class_EasyIni("""", ""`n(`n" sIni ")"")
		if (FileExist(""Flyout_config.ini""))
			g_vFlyoutConfigIni := class_EasyIni(""Flyout_config.ini"")
		else
		{
			g_vFlyoutConfigIni := class_EasyIni(""Flyout_config.ini"", GetDefaultFlyoutConfig_AsParm())
			g_vFlyoutConfigIni.Save()
		}

		FileDelete, MenuHelper.ini
		g_MenuHelperIni := class_EasyIni(""MenuHelper.ini"")

		g_iX := " iX "
		g_iY := " iY "
		g_iW := g_vFlyoutConfigIni.Flyout.W
		if (g_iW == A_Blank)
			g_iW := 400
		if (" iMaxRows " == 0)
			g_iMaxRows := g_vFlyoutConfigIni.Flyout.MaxRows
		else g_iMaxRows := " iMaxRows "
		if (g_iMaxRows == A_Blank)
			g_iMaxRows := 10
		if (" iW " == 0)
			g_iXOffset := g_vFlyoutConfigIni.Flyout.W - 5 ; Pixels
		else g_iXOffset := " iW - 5 " ; Pixels
		if (g_iXOffset == A_Blank)
			g_iXOffset := g_iW - 5
		g_bRightJustify := true

		g_aFlyouts := []
		g_aiMapMenuNumsToLabels := []

		g_hActiveWndBeforeMenu := 0 ; Set in FlyoutMenuHandler_MainMenu 

		return ; end auto-execute

		; Each flyout menu is ~18MB!
		CreateFlyoutMenu(sMenuSec, hParent)
		{
			global g_vMenuConfigIni, g_MenuHelperIni, g_aiMapMenuNumsToLabels, g_iW, g_iMaxRows

			sMenuHKs :=
			aMenuItems := []
			sKeys := g_vMenuConfigIni.GetKeys(sMenuSec)
			Loop, Parse, sKeys, ``n, ``r
			{
				StringReplace, LoopField, A_LoopField, ``&,, All
				aMenuItems.Insert(LoopField)
			}

			vFlyout := new CFlyout(hParent, aMenuItems, false, false, -32768, -32768, g_iW, g_iMaxRows)
			WinGetPos, x, y, w, h, % ""ahk_id"" vFlyout.m_hFlyout
			WinSet, Disable,, ahk_id %hParent% ; will be enabled when deleted with FlyoutMenuHandler_ExitTopmost

			Hotkey, IfWinActive, % ""ahk_id"" vFlyout.m_hFlyout
				Hotkey, Esc, FlyoutMenuHandler_ExitTopmost

			g_MenuHelperIni.AddSection(vFlyout.m_hFlyout)
			asMapMenuItemsToHotkeys := {}
			aiMapMenuNumsToLabels := []
			sKeys := g_vMenuConfigIni.GetKeys(sMenuSec)
			Loop, Parse, sKeys, ``n, ``r
			{
				iPosOfHK := InStr(A_LoopField, ""&"")
				if (iPosOfHK < 0)
					iPosOfHK := 0
				sHK := SubStr(A_LoopField, iPosOfHK + 1, 1)

				sLabel := ""FlyoutMenuHandler_"" g_vMenuConfigIni[sMenuSec][A_LoopField]
				RemoveIllegalLabelChars(sLabel)

				; I think the below line is redudant...but, just in case...
				Hotkey, IfWinActive, `% ""ahk_id"" vFlyout.m_hFlyout
					Hotkey, %sHK%, %sLabel%

				g_MenuHelperIni.AddKey(vFlyout.m_hFlyout, sHK) ; TODO: Remove &s?
				asMapMenuItemsToHotkeys.Insert(A_LoopField, sHK)
				aiMapMenuNumsToLabels.Insert(A_Index, sLabel)
			}

			g_aiMapMenuNumsToLabels.Insert(vFlyout.m_iFlyoutNum, aiMapMenuNumsToLabels)
			g_MenuHelperIni.Save()

			static WM_LBUTTONDOWN:=513
			vFlyout.OnMessage(WM_LBUTTONDOWN, ""FlyoutMenuHandler_OnClick"")

			return vFlyout
		}

		FlyoutMenuHandler_MoveDown:
		{
			Critical

			g_aFlyouts[g_aFlyouts.MaxIndex()].Move(false)
			return
		}
		FlyoutMenuHandler_MoveDown()
		{
			SendLevel 1
			SendEvent {Blind}{Down}
			return
		}

		FlyoutMenuHandler_MoveUp:
		{
			Critical

			g_aFlyouts[g_aFlyouts.MaxIndex()].Move(true)
			return
		}
		FlyoutMenuHandler_MoveUp()
		{
			SendLevel 1
			SendEvent {Blind}{Up}
			return
		}

		FlyoutMenuHandler_SubmitSelected:
		{
			Critical

			global g_aiMapMenuNumsToLabels, g_vTopmostFlyout := g_aFlyouts[g_aFlyouts.MaxIndex()]

			sPossibleLabel := g_aiMapMenuNumsToLabels[g_vTopmostFlyout.m_iFlyoutNum][g_vTopmostFlyout.GetCurSelNdx() + 1]
			if (IsLabel(sPossibleLabel))
				gosub %sPossibleLabel%
			else Msgbox An error occured when trying to determine menu action for menu %iMenuNum% action %sAction%

			return
		}
		FlyoutMenuHandler_SubmitSelected()
		{
			SendLevel 1
			SendEvent {Blind}{Right}
			return
		}

		FlyoutMenuHandler_ExitTopmost:
		{
			Critical
			g_vTopmostFlyout := g_aFlyouts[g_aFlyouts.MaxIndex()]

			hParent := g_vTopmostFlyout.m_hParent
			if (hParent == 0)
				gosub FlyoutMenuHandler_ExitMainMenu ; Notify parent script that the menu routine has finished.
			else ; Delete the flyout and re-enable the parent
			{
				WinSet, Enable,, % ""ahk_id"" g_vTopmostFlyout.m_hParent
				WinActivate, % ""ahk_id"" g_vTopmostFlyout.m_hParent

				g_aFlyouts.Remove()
			}

			g_vTopmostFlyout :=
			return
		}
		FlyoutMenuHandler_ExitTopmost()
		{
			SendLevel 1
			SendEvent {Blind}{Esc}
			return
		}

		FlyoutMenuHandler_ExitMainMenu:
		{
			Critical

			g_vTopmostFlyout :=
			g_aFlyouts := []
			m_vExe.ahkPostFunction[""CFlyoutMenuHandler_FinishedMenuRoutine""]

			; Stop
			SetTimer FlyoutMenuHandler_ExitWhenInactive, Off

			return
		}

		RemoveIllegalLabelChars(ByRef sLabel)
		{
			StringReplace, sLabel, sLabel, `%A_Space`%, |A_Space|,, All
			StringReplace, sLabel, sLabel, " Chr(34) ", |A_DoubleQuote|,, All
			StringReplace, sLabel, sLabel, ``', |A_SingleQuote|,, All
			StringReplace, sLabel, sLabel, ``(, |A_OpenParen|,, All
			StringReplace, sLabel, sLabel, ``), |A_CloseParen|,, All
			StringReplace, sLabel, sLabel, ``,, |A_Comma|,, All
			StringReplace, sLabel, sLabel, ``:, |A_Colon|,, All
			return
		}

		FlyoutMenuHandler_ExitWhenInactive:
		{
			Critical

			if (WinGetClass(""A"") != ""AutoHotkeyGUI"" || !InStr(WinGetActiveTitle(), ""GUI_Flyout""))
			{
				gosub FlyoutMenuHandler_ExitMainMenu
				`; Send action on through.
			}
			return
		}

		FlyoutMenuHandler_OnClick(vFlyout, msg)
		{
			global
			g_bCalledFromClick := false

			if (!(WinActive(""ahk_id"" vFlyout.m_hFlyout) && DllCall(""IsWindowEnabled"", uint, vFlyout.m_hFlyout)))
				return

			sPossibleLabel := g_aiMapMenuNumsToLabels[vFlyout.m_iFlyoutNum][vFlyout.GetCurSelNdx() + 1]
			if (IsLabel(sPossibleLabel))
			{
				g_bCalledFromClick := true
				gosub %sPossibleLabel%
			}
			else Msgbox An error occured when trying to determine menu action for menu %iMenuNum% action %sAction%``n%sPossibleLabel%
			return true
		}

		FlyoutMenuHandler_GUIEditSettings(hParent, sGUI, bReloadOnExit)
		{
			CFlyout.GUIEditSettings(hParent, sGUI, bReloadOnExit)
			return
		}

		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;;;;;;;;;;;;;;
		FlyoutMenuHandler_GetRectForMenu(vFlyout, ByRef iTargetX, ByRef iTargetY, iYOffset)
		{
			global g_iXOffset, g_bRightJustify
			iTargetX := iTargetY := 0

			WinGetPos, iWndX, iWndY,,, % ""ahk_id"" vFlyout.m_hParent
			WinGetPos,,, iWndW, iWndH, % ""ahk_id"" vFlyout.m_hFlyout

			rect := FlyoutMenuHandler_GetMonitorRectAt(iWndX, iWndY)
			iMonWndIsOnLeft := rect.left
			iMonWndIsOnRight := rect.right
			iMonWndIsOnTop := rect.top
			iMonWndIsOnBottom := rect.bottom

			if (iWndX + g_iXOffset + (iWndW * 2 - (g_iXOffset)) > iMonWndIsOnRight)
				g_bRightJustify := false

			if (g_bRightJustify)
				iTargetX := iWndX + g_iXOffset
			else iTargetX := iWndW - g_iXOffset

			if (iTargetX + iWndW > iMonWndIsOnRight)
			{
				iTargetX := iWndX - iWndW
				g_bRightJustify := false
			}
			if (iTargetX < iMonWndIsOnLeft)
			{
				iTargetX := iMonWndIsOnLeft
				g_bRightJustify := true
			}

			iTargetY := iWndY + iYOffset

			if (iTargetY + iWndH > iMonWndIsOnBottom)
				iTargetY := iWndY - iWndH + iYOffset

			return
		}
		;;;;;;;;;;;;;;
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;;;;;;;;;;;;;;
		GetDefaultFlyoutConfig_AsParm()
		{
			return ""`n(`n" this.GetDefaultConfigIni() ")""
		}
		;;;;;;;;;;;;;;
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;;;;;;;;;;;;;;
		Suspend(sOnOrOff)
		{
			Suspend %sOnOrOff%
			return
		}
		;;;;;;;;;;;;;;
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		/*
		===============================================================================
		Function:   wp_GetMonitorAt (Modified by Verdlin to return monitor rect)
			Get the index of the monitor containing the specified x and y coordinates.

		Parameters:
			x,y - Coordinates
			default - Default monitor
		  
		Returns:
		   Index of the monitor at specified coordinates

		Author(s):
			Original - Lexikos - http://www.autohotkey.com/forum/topic21703.html
		===============================================================================
		*/
		FlyoutMenuHandler_GetMonitorRectAt(x, y, default=1)
		{
			; Temp workarounds until I can patiently wrap my head around the bug in this functions that returns
			; the monitor to the LEFT of the primary monitor whenever x == 02
			if (x == 0)
				x++
			if (y == 0)
				y++

			SysGet, m, MonitorCount
			; Iterate through all monitors.
			Loop, %m%
			{ ; Check if the window is on this monitor.
				SysGet, Mon%A_Index%, Monitor, %A_Index%
				if (x >= Mon%A_Index%Left && x <= Mon%A_Index%Right && y >= Mon%A_Index%Top && y <= Mon%A_Index%Bottom)
				{
					return {left: Mon%A_Index%Left, right: Mon%A_Index%Right, top: Mon%A_Index%Top, bottom: Mon%A_Index%Bottom}
				}
			}

			return {left: Mon%default%Left, right: Mon%default%Right, top: Mon%default%Top, bottom: Mon%default%Bottom}
		}
		/*
		===============================================================================
		*/

WinGetActiveTitle() {
	WinGetActiveTitle, v
	Return, v
}
WinGetClass(WinTitle = """", WinText = """", ExcludeTitle = """", ExcludeText = """") {
	WinGetClass, v, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%
	Return, v
}
WinGetTitle(WinTitle = "", WinText = "", ExcludeTitle = "", ExcludeText = "") {
	WinGetTitle, v, %WinTitle%, %WinText%, %ExcludeTitle%, %ExcludeText%
	Return, v
}

" sAllFiles "

			)" . sLabels
;~ if (!A_IsCompiled)
;~ {
	;~ FileDelete, test.ahk
	;~ FileAppend, %sScript%, test.ahk
;~ }

		; Start thread
		global g_hCFlyoutMenuHandlerThread := ; For some reason, if I do not do this initialization, then the whole thread execution fails. Will this be a problem for multiple instantiations of this class?
		g_hCFlyoutMenuHandlerThread := CriticalObject(AhkDllThread(sPathToAHKDll))
		g_hCFlyoutMenuHandlerThread.ahktextdll[ "g_vExe:=CriticalObject(" . &AhkExported() . ")`n"sScript]
		this.m_hThread := g_hCFlyoutMenuHandlerThread

		SetWorkingDir, %sOldWorkingDir%
		return this
	}

	__Delete()
	{
		this.m_hThread.ahkTerminate()
		return
	}

	Suspend(sOnOrOff)
	{
		this.m_hThread.ahkFunction["Suspend", sOnOrOff]
		return
	}

	MainMenuExists()
	{
		; Not ideal to simply match on title, but it is tricky triyng to use g_aFlyouts.
		; Also, it is nice that we don't need to use ahkfunction[]
		return WinExist("GUI_Flyout1")
	}

	ShowMenu()
	{
		this.m_hThread.ahklabel["FlyoutMenuHandler_MainMenu"]
		return
	}

	ExitMenu()
	{
		this.m_hThread.ahklabel["FlyoutMenuHandler_ExitMainMenu"]
		return
	}

	Submit(ByRef rbMainMenuExists=false) ; Defaulted in case callers don't care about this.
	{
		this.m_hThread.ahkfunction["FlyoutMenuHandler_SubmitSelected"]

		rbMainMenuExists := this.MainMenuExists()
		return
	}

	Escape(ByRef rbMainMenuExists=false) ; Defaulted in case callers don't care about this.
	{
		this.m_hThread.ahkfunction["FlyoutMenuHandler_ExitTopmost"]

		rbMainMenuExists := this.MainMenuExists()
		return
	}

	Move(bUp)
	{
		if (bUp)
			this.m_hThread.ahkfunction["FlyoutMenuHandler_MoveUp"]
		else this.m_hThread.ahkfunction["FlyoutMenuHandler_MoveDown"]

		return
	}

	EnsureIniLoaded()
	{
		if (IsObject(this.m_vMenuConfigIni))
			return

		if (this.m_sIni)
			this.m_vMenuConfigIni := class_EasyIni("", this.m_sIni)
		else this.m_vMenuConfigIni := class_EasyIni("menuconfig.ini")
		return
	}

	AddMenu(sMenu)
	{
		Msgbox In AddMenu`n%sMenu%
		this.EnsureIniLoaded()

		return true
	}

	AddSubMenu(sParentMenu, sSubMenu)
	{
		Msgbox In AddSubMenu`nAdd %sSubMenu% to %sParentMenu%
		this.EnsureIniLoaded()

		return true
	}

	RemoveIllegalLabelChars(ByRef sLabel)
	{
		StringReplace, sLabel, sLabel, %A_Space%, |A_Space|,, All
		StringReplace, sLabel, sLabel, `", |A_DoubleQuote|,, All
		StringReplace, sLabel, sLabel, `', |A_SingleQuote|,, All
		StringReplace, sLabel, sLabel, `(, |A_OpenParen|,, All
		StringReplace, sLabel, sLabel, `), |A_CloseParen|,, All
		StringReplace, sLabel, sLabel, `,, |A_Comma|,, All
		StringReplace, sLabel, sLabel, `:, |A_Colon|,, All
		return
	}

	GUIEditSettings(hParent=0, sGUI="", bReloadOnExit=false)
	{
		this.m_hThread.ahkFunction["FlyoutMenuHandler_GUIEditSettings", hParent, sGUI, bReloadOnExit]
	}

	GetDefaultConfigIni()
	{
		return "
			(
[Flyout]
AnchorAt=-99999
Background=Default.jpg
Font=Kozuka Mincho Pr6N R, s26 italic underline
FontColor=0x5AAC7
MaxRows=10
TextAlign=Center
W=400
X=0
Y=0
ReadOnly=0
ShowInTaskbar=0

			)"
	}

	static m_sPathToResDll := "CFMH_res.dll"
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; bDestroy is provided so that the thread can terminate itself

CFlyoutMenuHandler_FinishedMenuRoutine(bDestroy=false)
{
	if (bDestroy)
		gosub CFlyoutMenuHandler_DestroyThread
	return bDestroy
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
CFlyoutMenuHandler_DestroyThread:
{
	g_hCFlyoutMenuHandlerThread.ahkterminate()
	g_hCFlyoutMenuHandlerThread:=
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

/* 
                  By SKAN - Suresh Kumar A N  ( arian.suresh@gmail.com )
            Created: 05-Sep-2010 / Last Modified: 01-Jun-2011 / Version: 0.7u
 */
DllRead( ByRef Var, Filename, Section, Key ) {          ; Functionality and Parameters are
 VarSetCapacity( Var,64 ), VarSetCapacity( Var,0 )      ; identical to IniRead command ;-)
 If hMod := DllCall( "LoadLibrary", Str,Filename )
  If hRes := DllCall( "FindResource", UInt,hMod, Str,Key, Str,Section )
   If hData := DllCall( "LoadResource", UInt,hMod, UInt,hRes )
    If pData := DllCall( "LockResource", UInt,hData )
 Return VarSetCapacity( Var,nSize := DllCall( "SizeofResource", UInt,hMod, UInt,hRes ),32)
     , DllCall( "RtlMoveMemory", UInt,&Var, UInt,pData, UInt,nSize )
     , DllCall( "FreeLibrary", UInt,hMod )
Return DllCall( "FreeLibrary", UInt,hMod ) >> 32
}