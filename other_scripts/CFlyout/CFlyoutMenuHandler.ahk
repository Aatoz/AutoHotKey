class CFlyoutMenuHandler
{
	__New(sPathToAHKDll="AutoHotkey.dll", iX=0, iY=0, iW=0, iMaxRows=0, sIni="", sSlideFrom="Left")
	{
		global g_iLastClassID := 1
		this.m_iClassID := g_iLastClassID

		sOldWorkingDir := A_WorkingDir
		SetWorkingDir, %A_ScriptDir%

		; INIs
		if (FileExist("Flyout_config.ini"))
			this.m_vFlyoutConfigIni := class_EasyIni("Flyout_config.ini")
		else
		{
			this.m_vFlyoutConfigIni := class_EasyIni("Flyout_config.ini", GetDefaultFlyoutConfig_AsParm())
			this.m_vFlyoutConfigIni.Save()
		}
		FileDelete, MenuHelper.ini
		this.m_vMenuHelperIni := class_EasyIni("MenuHelper.ini")
		this.m_sIni := sIni
		this.EnsureIniLoaded()

		this.m_iX := iX
		this.m_iY := iY
		this.m_iW := this.m_vFlyoutConfigIni.Flyout.W
		if (this.m_iW == A_Blank)
			this.m_iW := 400
		; Height/Rows
		if (iMaxRows == 0)
			this.m_iMaxRows := this.m_vFlyoutConfigIni.Flyout.MaxRows
		else this.m_iMaxRows := iMaxRows
		if (this.m_iMaxRows == A_Blank)
			this.m_iMaxRows := 10
		; Offsets for menus.
		if (iW == 0)
			this.m_iXOffset := this.m_vFlyoutConfigIni.Flyout.W - 5 ; Pixels
		else this.m_iXOffset := iW - 5 ; Pixels
		if (this.m_iXOffset == A_Blank)
			this.m_iXOffset := this.m_iW - 5
		this.m_bRightJustify := true

		; ---Menu objects---

		; Create tmp CFlyout for font-sensitive vars.
		vTmpFlyout := new CFlyout(0, ["a"], false, false, -32768, -32768, this.m_iW, this.m_iMaxRows)
		; Set default height, then delete tmp CFlyout.
		Str_Wrap("a", this.m_iW, vTmpFlyout.m_hFont, true, iH)
		vTmpFlyout :=
		this.m_iDefH := iH
		; End tmp CFlyout.

		this.m_aFlyouts := []
		this.m_aiMapMenuNumsToLabels := []
		; Handle for active window before main menu activation.
		this.m_hActiveWndBeforeMenu := 0 ; Set in FlyoutMenuHandler_MainMenu.

		; Create labels for each menu and all it's items.
		; Sections are menus
		for sSec, aKeysAndVals in this.m_vMenuConfigIni
		{
			iMenuNum := A_Index
			sLabel := sSec
			this.RemoveIllegalLabelChars(sLabel)

			; Set up links from parent menus to sub menus
			sLabels .="
				(

FlyoutMenuHandler_" sLabel ":
{
	Critical
	; Note ahkPostFunction should not be used because it allows users to trigger multiple hotkeys on one menu.
	g_vExe.ahkFunction[""FlyoutMenuHandler_MenuProc"", A_ThisHotkey, """ sSec """, " this.m_iClassID "]
	return
}

				)"

			; Now create wrapper-labels for every function within this menu
			; TODO: aKeysAndVals
			sVals := this.m_vMenuConfigIni.GetVals(sSec)
			Loop, Parse, sVals, `n, `r
			{
				if (!InStr(A_LoopField, "Func:") && !InStr(A_LoopField, "Label:") && !InStr(A_LoopField, "Internal:"))
					continue

				aPostFuncParms := """[Data]``n"
				if (InStr(A_LoopField, "Func:"))
				{
					StringReplace, sFunc, A_LoopField, Func:,, All
					sFunc := Trim(sFunc, A_Space)
					iPosOfFirstParen := InStr(sFunc, "(") + 1
					; Passed in parameters may contain quotations, so using StrLen instead of InStr ensures we get the closing quotations.
					iPosOfLastParen := StrLen(sFunc)
					sParms := SubStr(sFunc, iPosOfFirstParen, iPosOfLastParen - iPosOfFirstParen)
					; Escape single quotes with double quotes.
					; Note: See ThreadCallback for unescape.
					StringReplace, sParms, sParms, `", `"`", All
					sFuncName  := SubStr(sFunc, 1, InStr(sFunc, "(")-1)
					aPostFuncParms .= "Func=" sFuncName "``nParms=" sParms """"
				}
				else if (InStr(A_LoopField, "Label:"))
				{
					StringReplace, sLabel, A_LoopField, Label:,, All
					aPostFuncParms .= "Label=" Trim(sLabel, A_Space) """"
				}
				else ; this is an "internal" function, that is, used within the thread instead of the parent.
				{
					StringReplace, sLabel, A_LoopField, Internal:, , All
					; For now, the only use I can think of is exiting, so I'm just implementing hard-code functionality unless the need for internal functions becomes greater.
					if (sLabel = "ExitAllMenus")
						continue ; This is already created.
					aPostFuncParms := ; TODO: More internal functions.
				}

				sFuncWithParmsLabel := A_LoopField
				this.RemoveIllegalLabelChars(sFuncWithParmsLabel)

				sLabels .="
					(

FlyoutMenuHandler_" sFuncWithParmsLabel ":
{
	Critical
	; Note ahkPostFunction should not be used because it allows users to trigger multiple hotkeys on one menu.
	g_vExe.ahkFunction[""FlyoutMenuHandler_ThreadCallback"", " aPostFuncParms ", " this.m_iClassID "]
	gosub FlyoutMenuHandler_ExitAllMenus
	return
}

					)"
			}
		}
StringReplace, sIni, sIni, `", `"`", All
		sScript:="
			(

`; Begin thread
#Persistent
#SingleInstance Force
#NoTrayIcon
SetBatchLines, -1
SetWinDelay, -1
Thread, interrupt, 1000

return ; end auto-execute

FlyoutMenuHandler_MoveDown:
FlyoutMenuHandler_MoveUp:
FlyoutMenuHandler_SubmitSelected:
FlyoutMenuHandler_ExitTopmost:
FlyoutMenuHandler_ExitAllMenus:
FlyoutMenuHandler_ExitAllMenus_OnFocusLost:
{
	Critical
	g_vExe.ahkPostFunction[A_ThisLabel, " this.m_iClassID "]
	return
}

FlyoutMenuHandler_StartExitTimer()
{
	SetTimer, FlyoutMenuHandler_ExitOnFocusLost, 100
	return
}

FlyoutMenuHandler_ExitOnFocusLost:
{
	Critical

	WinGetClass, sClass, A
	WinGetActiveTitle, sActiveTitle

	if (sClass != ""AutoHotkeyGUI"" || !InStr(sActiveTitle, ""CFMH_""))
	{
		gosub FlyoutMenuHandler_ExitAllMenus_OnFocusLost
		`; Send action on through.
	}
	return
}

SetHotkeys(sHK, sMenuLabel, hWnd)
{
	Hotkey, IfWinActive, ahk_id %hWnd%
		Hotkey, %sHK%, %sMenuLabel%
		Hotkey, Down, FlyoutMenuHandler_MoveDown
		Hotkey, WheelDown, FlyoutMenuHandler_MoveDown
		Hotkey, Up, FlyoutMenuHandler_MoveUp
		Hotkey, WheelUp, FlyoutMenuHandler_MoveUp
		Hotkey, Enter, FlyoutMenuHandler_SubmitSelected
		Hotkey, NumpadEnter, FlyoutMenuHandler_SubmitSelected
		Hotkey, MButton, FlyoutMenuHandler_SubmitSelected
		Hotkey, Right, FlyoutMenuHandler_SubmitSelected
		Hotkey, Left, FlyoutMenuHandler_ExitTopmost
		Hotkey, Esc, FlyoutMenuHandler_ExitTopmost
	return
}

Suspend(sOnOff)
{
	Suspend %sOnOff%
	return
}

			)" . sLabels
;~ if (!A_IsCompiled)
;~ {
	;~ FileDelete, test2.ahk
	;~ FileAppend, %sScript%, test2.ahk
;~ }

		; Start thread
		global g_hCFlyoutMenuHandlerThread := ; For some reason, if I do not do this initialization, then the whole thread execution fails. Will this be a problem for multiple instantiations of this class?
		g_hCFlyoutMenuHandlerThread := CriticalObject(AhkDllThread(sPathToAHKDll))
		g_hCFlyoutMenuHandlerThread.ahkTextDll[ "g_vExe:=CriticalObject(" . &AhkExported() . ")`n" . sScript]
		this.m_hThread := g_hCFlyoutMenuHandlerThread

		SetWorkingDir, %sOldWorkingDir%
		CFlyoutMenuHandler[g_iLastClassID++] := &this ; for multiple menu handlers
		return this
	}

	__Get(aName)
	{
		if (aName = "m_vTopmostMenu")
			return this.m_aFlyouts[this.m_aFlyouts.MaxIndex()]
		if (aName = "m_vMainMenu")
			return this.m_aFlyouts.1
		if (aName = "m_iNumMenus")
			return this.m_aFlyouts.MaxIndex()

		return
	}

	__Delete()
	{
		this.m_hThread.ahkTerminate()
		CFlyoutMenuHandler.Remove(this.m_iClassID)
		return
	}

	GetMenu_Ref(iMenuNum)
	{
		; If this were C++, this function would be returning a const pointer.
		; Instead we are returning the actual object, and I really don't like that.
		return this.m_aFlyouts[iMenuNum]
	}

	Suspend(sOnOrOff)
	{
		this.m_hThread.ahkPostFunction["Suspend", sOnOrOff]
		return
	}

	MainMenuExist()
	{
		; Not ideal to simply match on title, but it is tricky triyng to use g_aFlyouts.
		return WinExist("ahk_id" this.m_vMainMenu.m_hFlyout)
	}

	ShowMenu()
	{
		hActiveMenu := "ahk_id" this.m_vTopmostMenu.m_hFlyout

		; If the main menu is not active, activate it.
		If (WinExist(hActiveMenu))
		{
			; If the menu exists but is not active, set the previsouly active window here.
			if (!WinActive(hActiveMenu))
				this.m_hActiveWndBeforeMenu := WinExist("A")

			WinActivate, %hActiveMenu%
			return
		}
		else this.m_hActiveWndBeforeMenu := WinExist("A")

		; Reset this var since we are starting the menu.
		this.m_bCalledFromClick := false

		; Can't act upon Program Manager, so get the next window.
		WinGetActiveTitle, sTitle
		if (sTitle = "Program Manager")
			this.m_hActiveWndBeforeMenu := DllCall("GetWindow", uint, this.m_hActiveWndBeforeMenu, uint, 2)

		this.CreateFlyoutMenu("MainMenu", 0)

		;~ WAnim_SlideIn("Left", g_iX, g_iY, g_vTopmostFlyout.m_hFlyout, "GUI_Flyout1", 50)
		WinMove, % "ahk_id" this.m_vMainMenu.m_hFlyout,, this.m_iX, this.m_iY
		WinActivate

		return
	}

	MoveUp()
	{
		this.m_vTopmostMenu.Move(true)
		return
	}
	MoveDown()
	{
		this.m_vTopmostMenu.Move(false)
		return
	}

	SubmitSelected(ByRef rbMainMenuExists=false) ; Defaulted in case callers don't care about this.
	{
		return this.Submit(this.m_vTopmostMenu.GetCurSelNdx() + 1, rbMainMenuExists)
	}

	Submit(iRow, ByRef rbMainMenuExists=false) ; Defaulted in case callers don't care about this.
	{
		; When used through thread callbacks, it is unnecessary to move
		; however, when used externally, it is necessary to move.
		this.m_vTopmostMenu.MoveTo(iRow + this.m_vTopmostMenu.m_iDrawnAtNdx) ; TODO: MoveTo should handle m_iDrawnAtNdx
		sSubmitted := this.m_vTopmostMenu.GetCurSel()
		sMenuID := this.m_aiMapMenuNumsToLabels[this.m_vTopmostMenu.m_iFlyoutNum, iRow]
		this.DoActionFromMenuID(sMenuID)

		rbMainMenuExists := this.MainMenuExist()
		return sSubmitted
	}

	OnClick(vFlyout, msg="")
	{
		this.m_bCalledFromClick := true

		; If the mouse is hovering over the previous menu and the mouse is about to click what is already selected, do nothing.
		vPrevMenu := this.GetMenu_Ref(this.m_iNumMenus - 1)
		iFocRow := this.GetRowFromPos("", iFlyoutUnderCircle)

		if (iFlyoutUnderCircle == vPrevMenu.m_iFlyoutNum && iFocRow == vPrevMenu.GetCurSelNdx()+1)
			return

		; Perform actual mouse click on flyout
		CoordMode, Mouse, Relative
		MouseGetPos,, iMouseY
		vFlyout.Click(iMouseY)

		; Exit to the hovered menu, if needed.
		while (this.m_iNumMenus > vFlyout.m_iFlyoutNum)
			this.ExitTopmost()

		sMenuID := this.m_aiMapMenuNumsToLabels[vFlyout.m_iFlyoutNum, vFlyout.GetCurSelNdx() + 1]
		this.DoActionFromMenuID(sMenuID)

		return true
	}

	DoActionFromMenuID(sMenuID)
	{
		this.RemoveIllegalLabelChars(sMenuID2:="FlyoutMenuHandler_"sMenuID)
		; Dynamically call class functions. We can't use this.HasKey(sFuncName), so instead check this way. It seems to work well...
		if (IsFunc(SubStr(A_ThisFunc, 1, InStr(A_ThisFunc, ".")) sMenuID))
		{
			this[sMenuID]()
		}
		; else call an action in the thread.
		else if (InStr(sMenuID, "Func:") || InStr(sMenuID, "Label:"))
			this.m_hThread.ahkLabel[sMenuID2]
		; else launch a new menu.
		else this.MenuProc("MButton", sMenuID)
	}

	ExitTopmost(ByRef rbMainMenuExists=false)
	{
		if (this.m_vMainMenu.m_hFlyout == this.m_vTopmostMenu.m_hFlyout)
		{
			this.ExitAllMenus()

			; This hack is used by CLeapMenu
			; It is used to determine whether or not an item was actually submitted.
			if (this.m_hCallbackHack)
				this.m_hCallbackHack.()

			return
		}

		hParent := this.m_vTopmostMenu.m_hParent
		if (hParent != 0)
			WinActivate, % "ahk_id" Parent

		this.m_aFlyouts.Remove()
		rbMainMenuExists := this.MainMenuExist()
		return
	}

	ExitAllMenus(bFromExitTimer=false)
	{
		; To avoid crashes from infinite recursion, only reload when needed.
		if (this.m_aFlyouts.MaxIndex() == A_Blank)
			return

		this.m_aFlyouts := []

		; Reloading gets around some strange issue that has to do with click vs. hotkeys.
		; When you use hotkeys, clicks fail. I've encountered the converse, too.
		; Reloading is fast, so let's just be happy with this workaround.
		this.m_hThread.ahkReload()

		; See comment in ExitTopmost()
		if (bFromExitTimer && this.m_hCallbackHack)
			this.m_hCallbackHack.()

		return
	}

	ThreadCallback(sIniParms)
	{
		vData := class_EasyIni("", sIniParms)
		if (vData.Data.Label)
		{
			gosub % vData.Data.Label
		}
		else if (vData.Data.Func)
		{
			aParms := st_split(vData.Data.Parms, ",")
			for, iNdx, val in aParms
			{
				; Resolve dynamic class variables.
				sClassVar := Trim(val) ; Trim, just in case, but don't trim actual val beacuse some function may want tabs, spaces, etc.
				if (this.HasKey(sClassVar))
					aParms[iNdx] := this[sClassVar]
				else
				{
					; Unescape double-quotes with single quotes.
					StringReplace, val, val, `",, All ; TODO: Just remove first and last quotes...
					aParms[iNdx] := val
				}
			}

			; Call function.
			vFunc := Func(vData.Data.Func)
			if (vFunc)
				vFunc.(aParms*)
			else Msgbox, 8192,, % "Error: Function " vData.Data.Func " does not exist."
		}

		return
	}

	MenuProc(sThisHotkey, sMenuID)
	{
		; Create a new flyout menu based on sMenuID.
		; But before doing so, move selection on current flyout to proper menu item.
		if (!(sThisHotkey = "Enter"
			|| sThisHotkey = "NumpadEnter"
			|| sThisHotkey = "Right"
			|| sThisHotkey = "MButton"
			|| this.m_bCalledFromClick))
		{
			iMoveTo := 1
			for sHK in this.m_vMenuHelperIni[this.m_vTopmostMenu.m_hFlyout]
			{
				if (sHK = sThisHotkey)
				{
					iMoveTo := A_Index
					break
				}
			}
			this.m_vTopmostMenu.MoveTo(iMoveTo)
		}
		; Reset m_bCalledFromClick because we are creating a new flyout.
		this.m_bCalledFromClick := false

		if (this.m_vTopmostMenu.GetCurSelNdx() == 0)
			iYOffset := 0
		else iYOffset := this.m_vTopmostMenu.CalcHeightTo(this.m_vTopmostMenu.GetCurSelNdx() - this.m_vTopmostMenu.m_iDrawnAtNdx) - 1
			; Note: not sure why we need to -1, but it works. Maybe it has to do with aligning with the selection vs. the menu window itself?

		this.CreateFlyoutMenu(sMenuID, this.m_vTopmostMenu.m_hFlyout)
		; Note: m_vTopmostMenu is now the newly created menu ( See __Get() ).
		this.GetRectForMenu(this.m_vTopmostMenu, iX, iY, iYOffset)
		WinMove, % "ahk_id" this.m_vTopmostMenu.m_hFlyout,, iX, iY
		WinActivate
		return
	}

	; Each flyout menu is ~18MB! This comes from loading the entire picture into the GUI...
	; (regardless of whether the picture spans outside the GUI).
	CreateFlyoutMenu(sMenuSec, hParent)
	{
		aMenuItems := []
		for sMenuItem, v in this.m_vMenuConfigIni[sMenuSec]
		{
			StringReplace, sMenuItem, sMenuItem, ``&,, All
			aMenuItems.Insert(sMenuItem)
		}

		vFlyout := new CFlyout(hParent, aMenuItems, false, false, -32768, -32768, this.m_iW, this.m_iMaxRows)
		; We need unique CFlyout titles for class functions (Like MainMenuExist() ).
		sTitle := "CFMH_" (sMenuSec = "MainMenu" ? sMenuSec : "Submenu")
		WinSetTitle, % "ahk_id" vFlyout.m_hFlyout,, %sTitle%

		this.m_vMenuHelperIni.AddSection(vFlyout.m_hFlyout)
		aiMapMenuNumsToLabels := []
		for sMenuItem, sMenuLabel in this.m_vMenuConfigIni[sMenuSec]
		{
			iPosOfHK := InStr(sMenuItem, "&")
			if (iPosOfHK < 0)
				iPosOfHK := 0
			sHK := SubStr(sMenuItem, iPosOfHK + 1, 1)

			sLabel := "FlyoutMenuHandler_" sMenuLabel
			this.RemoveIllegalLabelChars(sLabel)

			this.m_vMenuHelperIni.AddKey(vFlyout.m_hFlyout, sHK) ; TODO: Remove &s?
			aiMapMenuNumsToLabels.Insert(sMenuLabel)

			; Set hotkey for this menu item in thread
			this.m_hThread.ahkPostFunction["SetHotkeys", sHK, sLabel, vFlyout.m_hFlyout]
		}

		this.m_aiMapMenuNumsToLabels.Insert(vFlyout.m_iFlyoutNum, aiMapMenuNumsToLabels)

		static WM_LBUTTONDOWN:=513
		vFlyout.OnMessage(WM_LBUTTONDOWN, "FlyoutMenuHandler_OnClick")

		; Tack on class ID so we can map hotkeys and clicks back up to the appropriate CFMH class.
		; Note: See FlyoutMenuHandler_OnClick.
		vFlyout.m_iCFMH_ClassID := this.m_iClassID
		this.m_aFlyouts.Insert(vFlyout)

		this.m_hThread.ahkPostFunction["FlyoutMenuHandler_StartExitTimer"]

		return
	}

	EnsureIniLoaded()
	{
		if (IsObject(this.m_vMenuConfigIni))
			return

		if (this.m_sIni)
			this.m_vMenuConfigIni := class_EasyIni("MenuConfig", this.m_sIni)
		else this.m_vMenuConfigIni := class_EasyIni("MenuConfig")

		;~ this.m_vMenuConfigIni.Save()
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
		return CFlyout.GUIEditSettings(hParent, sGUI, bReloadOnExit)
	}

	GetRectForMenu(vFlyout, ByRef iTargetX, ByRef iTargetY, iYOffset)
	{
		iTargetX := iTargetY := 0

		WinGetPos, iWndX, iWndY,,, % "ahk_id" vFlyout.m_hParent
		WinGetPos,,, iWndW, iWndH, % "ahk_id" vFlyout.m_hFlyout

		rect := FlyoutMenuHandler_GetMonitorRectAt(iWndX, iWndY)
		iMonWndIsOnLeft := rect.left
		iMonWndIsOnRight := rect.right
		iMonWndIsOnTop := rect.top
		iMonWndIsOnBottom := rect.bottom

		if (iWndX + this.m_iXOffset + (iWndW * 2 - (this.m_iXOffset)) > iMonWndIsOnRight)
			this.m_bRightJustify := false

		if (this.m_bRightJustify)
			iTargetX := iWndX + this.m_iXOffset
		else iTargetX := iWndW - this.m_iXOffset

		if (iTargetX + iWndW > iMonWndIsOnRight)
		{
			iTargetX := iWndX - iWndW
			this.m_bRightJustify := false
		}
		if (iTargetX < iMonWndIsOnLeft)
		{
			iTargetX := iMonWndIsOnLeft
			this.m_bRightJustify := true
		}

		iTargetY := iWndY + iYOffset

		if (iTargetY + iWndH > iMonWndIsOnBottom)
			iTargetY := iWndY - iWndH + iYOffset

		return
	}

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GetRowFromPos
			Purpose: Useful in order to determine which menu item an object is hovering over.
				Note: when ahkGetVar is pinged too often, we crash.
				This is why the class stores menu positions instead.
		Parameters
			hWnd="": if blank, uses hWnd under mouse.
			bUseCenterPos=false: if true, clicks on the flyout in centralized coordinates (makes sense with a circle GUI, as used in CLeapMenu)
			riFlyoutNum=1: Which flyout number the mouse or hWnd is under.
			rbIsUnderTopmost=false: If topmost flyout is under mouse or hWnd
	*/
	GetRowFromPos(hWnd="", ByRef riFlyoutNum=1, ByRef rbIsUnderTopmost=false)
	{
		; Get the current wnd under the mouse;
		MouseGetPos,, iPosY, hMouseWnd
		bUseMouse := (hWnd == A_Blank)
		if (bUseMouse)
			iClickY := iPosY
		else
		{
			WinGetPos, iPosX, iPosY, iPosW, iPosH, ahk_id %hWnd%
			iClickX += iPosX+(iPosW*0.5)
			iClickY += iPosY+(iPosH*0.5)
		}

		; See if wnd matches any of our flyout menus...
		for iFlyout, vFlyout in this.m_aFlyouts
		{
			if (bUseMouse)
			{
				if (hMouseWnd != vFlyout.m_hFlyout)
					continue
			}
			else ; match on hWnd X/Y coord.
			{
				; Determine whether the center of the hWnd is on this flyout.

				;~ if (A_Index == 3)
					;~ Msgbox % st_concat("`n", A_ThisFunc "()", "iPosX`t" iPosX, "iPosY`t" iPosY, "iPosW`t"iPosW, "iPosH`t" iPosH
						;~ , "FX:`t" vFlyout.GetFlyoutX, "FY:`t"vFlyout.GetFlyoutY, "FW:`t" vFlyout.GetFlyoutW, "FH:`t" vFlyout.GetFlyoutH, "FN:`t"vFlyout.m_iFlyoutNum "`n"
						;~ , "b1:`t" (iClickX >= vFlyout.GetFlyoutX)
						;~ , "b2:`t" (iClickX <= (vFlyout.GetFlyoutW + vFlyout.GetFlyoutX))
						;~ , "b3:`t" (iClickY >= vFlyout.GetFlyoutY)
						;~ , "b4:`t" (iClickY <= (vFlyout.GetFlyoutH + vFlyout.GetFlyoutY)))

				 if (!(iClickX >= vFlyout.GetFlyoutX && iClickX <= (vFlyout.GetFlyoutW + vFlyout.GetFlyoutX)
					&& iClickY >= vFlyout.GetFlyoutY && iClickY <= (vFlyout.GetFlyoutH + vFlyout.GetFlyoutY)))
				{
					continue
				}
			}

			riFlyoutNum := vFlyout.m_iFlyoutNum
			rbIsUnderTopmost := vFlyout.m_hFlyout = this.m_vTopmostMenu.m_hFlyout

			; Note: Click function takes coordinates relative to the window, so we need to eliminate the Y
			return vFlyout.Click(iClickY-vFlyout.GetFlyoutY, false) ; match, return row under mouse.
		}

		riFlyoutNum := -1 ; Not under any CFlyout.
		return ; no match found, return blank.
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
}

FlyoutMenuHandler_MenuProc(sThisHotkey, sMenuID, iClassID)
{
	vMH := _CFlyoutMenuHandler(iClassID)
	return vMH.MenuProc(sThisHotkey, sMenuID)
}

FlyoutMenuHandler_ThreadCallback(sIniParms, iClassID)
{
	vMH := _CFlyoutMenuHandler(iClassID)
	return vMH.ThreadCallback(sIniParms)
}

FlyoutMenuHandler_MoveDown(iClassID)
{
	vMH := _CFlyoutMenuHandler(iClassID)
	return vMH.MoveDown()
}

FlyoutMenuHandler_MoveUp(iClassID)
{
	vMH := _CFlyoutMenuHandler(iClassID)
	return vMH.MoveUp()
}

FlyoutMenuHandler_SubmitSelected(iClassID)
{
	vMH := _CFlyoutMenuHandler(iClassID)
	return vMH.SubmitSelected()
}

FlyoutMenuHandler_ExitTopmost(iClassID)
{
	vMH := _CFlyoutMenuHandler(iClassID)
	return vMH.ExitTopmost()
}

FlyoutMenuHandler_ExitAllMenus(iClassID)
{
	vMH := _CFlyoutMenuHandler(iClassID)
	return vMH.ExitAllMenus()
}

FlyoutMenuHandler_ExitAllMenus_OnFocusLost(iClassID)
{
	vMH := _CFlyoutMenuHandler(iClassID)
	return vMH.ExitAllMenus(true)
}

FlyoutMenuHandler_OnClick(vFlyout, msg)
{
	vMH := _CFlyoutMenuHandler(vFlyout.m_iCFMH_ClassID)
	return vMH.OnClick(vFlyout, msg)
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: _CFlyoutMenuHandler
		Purpose: To retrieve appropriate CFlyoutMenuHandler class object
			IMPORTANT: Caller *must* delete object when finished with it.
	Parameters
		iClassID: Used to get the appropriate CFlyoutMenuHandler class.
*/
_CFlyoutMenuHandler(iClassID)
{
	global g_hCFlyoutMenuHandlerThread

	vMH := Object(CFlyoutMenuHandler[iClassID])
	if (!IsObject(vMH))
	{
		Msgbox 8192,, Error: Could not map class ID (%iClassID%) to menu handler class object.
		g_hCFlyoutMenuHandlerThread := ; Kill the menu
		return
	}
	return vMH
}
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


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
GetDefaultFlyoutConfig_AsParm()
{
	return "`n(`n" this.GetDefaultConfigIni() ")"
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#Include %A_ScriptDir%\CFlyout.ahk