#Persistent
#SingleInstance, Force

; Hotkeys
;	1. Alt + LButton = Move window
;	2. Alt + Shift + LButton = Move window along X axis only
;	3. Alt + Ctrl + LButton = Move window along Y axis only
;	4. Alt + RButton = Resize
;	5. Alt + Shift + RButton = Resize window width only
;	6. Alt + Ctrl + RButton = Resize window height only
;	7. Alt + MButton OR Alt + Win + C = Change text within window
;	8. Win + LButton = Enable/Disable Window
;	9. Win + Ctrl RButton = Toggle Window Border

InitWC()
{
	global

	CoordMode, Mouse
	SetWinDelay, -1

	g_iIntraMonitorThreshold := 350 ; pixels

	; For suspending Control Control script
	g_sControlControlWinTitle := "Control Control.ahk"
	if (A_IsCompiled)
	{
		g_sControlControlWinTitle := "Control Control - 32.exe"
		if (A_PtrSize == 8)
			g_sControlControlWinTitle := "Control Control - 64.exe"
	}
	g_sControlControlWinTitle .= " ahk_class AutoHotkey"

	return ; End auto-execute
}

#!c::
{
	gosub ChangeWindowTitle
	return
}

; Simple hotkeys like ~Alt & ~LButton cannot be used becuase this does not disable clicks inside of windows
Shift & ~Alt::
Ctrl & ~Alt::
~Alt::
{
	Hotkey, IfWinActive

	Hotkey, *LButton, Alt_And_LButton, On
	Hotkey, *RButton, Alt_And_RButton, On
	Hotkey, *MButton, ChangeWindowTitle, On
	KeyWait, Alt
	Hotkey, *LButton, Off
	Hotkey, *RButton, Off
	Hotkey, *MButton, Off

	if (A_ThisHotkey = "*LButton")
		gosub Alt_And_LButton
	else if (A_ThisHotkey = "*RButton")
		gosub Alt_And_RButton
	else if (A_ThisHotkey = "*MButton")
		gosub ChangeWindowTitle

	return
}

Alt_And_LButton:
{
	iPrevMouseX := iPrevMouseY := A_Blank
	MouseGetPos,,, hWnd

	if (IsApprovedHwnd(hWnd))
	{
		g_bUseXThreshold := g_bUseYThreshold := true
		g_iXDeltaAtLeftCorner := g_iXDeltaAtRightCorner := g_iYDeltaAtTopCorner := g_iYDeltaAtBottomCorner := 0

		while (GetKeyState("Alt", "P") && GetKeyState("LButton", "P"))
		{
			bIgnoreX := GetKeyState("Ctrl", "P")
			bIgnoreY := GetKeyState("Shift", "P")

			MouseGetPos, iMouseX, iMouseY
			iMouseX := iMouseX
			iMouseY := iMouseY

			WinGetPos, iX, iY, iWndW, iWndH, ahk_id %hWnd%

			iXDelta := bIgnoreX ? 0 : iMouseX - (iPrevMouseX == A_Blank ? iMouseX : iPrevMouseX)
			iYDelta := bIgnoreY ? 0 : iMouseY - (iPrevMouseY == A_Blank ? iMouseY : iPrevMouseY)

			if (iXDelta == 0 && iYDelta == 0)
			{
				iPrevMouseX := iMouseX
				iPrevMouseY := iMouseY
				continue
			}

			iX := iX + iXDelta
			iY := iY + iYDelta

			bMoveX := bMoveY := true
			rectMonMouseIsOn := myGetMonitorRectAt(iMouseX, iMouseY)

			; if we have passed a monitor corner over onto another monitor, or else we have shifted directions towards to opposite corner of the monitor, reset
			if (abs(iMouseX) - abs(iMouseXPosAtCorner) < g_iIntraMonitorThreshold)
				g_bUseXThreshold := true
			if (abs(iMouseY) - abs(iMouseYPosAtCorner) < g_iIntraMonitorThreshold)
				g_bUseYThreshold := true

			WinGetClass, sClass, ahk_id %hWnd%
			if (IsWin10() && WndHasBorder(hWnd) && sClass != "Chrome_WidgetWin_1") ; !VivaldiIsActive()
			{
				if (!bIgnoreX)
				{
					iX -= 7
					iXDelta -= 7
					iMouseX -= 7
					rectMonMouseIsOn.Left -= 7
					rectMonMouseIsOn.Right += 7
				}
				if (!bIgnoreY)
				{
					iY += 7
					iYDelta += 7
					iMouseY += 7
					rectMonMouseIsOn.Bottom += 7
				}
			}
			;~ Tooltip % st_concat("`n", iMouseX, iX, rectMonMouseIsOn.Left, g_iXDeltaAtLeftCorner
				;~ , "UseXThresh:`t" g_bUseXThreshold
				;~ , "iXDelta < 0:`t" (iXDelta < 0)
				;~ , "iX w/ change `t" iX - iXDelta
				;~ , "Left corner not past monitor left corner`t" (iX - iXDelta >= rectMonMouseIsOn.Left)
				;~ , "Trying to move past left corner`t" (iX < rectMonMouseIsOn.Left))

			if (g_bUseXThreshold)
			{
				if (!bIgnoreX)
				{
					if (iXDelta < 0 ; moving window to the left
					&& iX - iXDelta >= rectMonMouseIsOn.left ; the left corner of the wnd is not already past the monitor's left corner
					&& iX < rectMonMouseIsOn.left) ; we are trying to move the window past the left corner
					{
						g_iXDeltaAtLeftCorner += abs(iXDelta)

						if (g_iXDeltaAtLeftCorner < g_iIntraMonitorThreshold)
						{
							bMoveX := false
							g_bUseXThreshold := true
						}
						else
						{
							bMoveX := true
							g_bUseXThreshold := false

							iMouseXPosAtCorner := iMouseX
							g_iXDeltaAtLeftCorner := 0
						}
					}
					else if (iXDelta > 0 ; moving window to the right
					&& iX - iXDelta + iWndW <= rectMonMouseIsOn.right ; the right corner of the wnd is not already past the monitor's right corner
					&& (iX + iWndW) > rectMonMouseIsOn.right) ; we are trying to move the window past the right corner
					{
						g_iXDeltaAtRightCorner += abs(iXDelta)

						if (g_iXDeltaAtRightCorner < g_iIntraMonitorThreshold)
						{
							bMoveX := false
							g_bUseXThreshold := true
						}
						else
						{
							bMoveX := true
							g_bUseXThreshold := false

							iMouseXPosAtCorner := iMouseX
							g_iXDeltaAtRightCorner := 0
						}
					}
				}
			}
			if (g_bUseYThreshold)
			{
				if (!bIgnoreY)
				{
					if (iYDelta < 0 ; moving window to the bottom
					&& iY - iYDelta >= rectMonMouseIsOn.top ; the top corner of the wnd is not already past the monitor's top corner
					&& iY < rectMonMouseIsOn.top) ; we are trying to move the window past the top corner
					{
						g_iYDeltaAtBottomCorner += abs(iYDelta)

						if (g_iYDeltaAtBottomCorner < g_iIntraMonitorThreshold)
						{
							bMoveY := false
							g_bUseYThreshold := true
						}
						else
						{
							bMoveY := true
							g_bUseYThreshold := false

							iMouseYPosAtCorner := iMouseY
							g_iYDeltaAtBottomCorner := 0
						}
					}
					else if (iYDelta > 0 ; moving window to the right
					&& iY - iYDelta + iWndH <= rectMonMouseIsOn.bottom ; the right corner of the wnd is not already past the monitor's bottom corner
					&& (iY + iWndH) > rectMonMouseIsOn.bottom) ; we are trying to move the window past the bottom corner
					{
						g_iYDeltaAtTopCorner += abs(iYDelta)

						if (g_iYDeltaAtTopCorner < g_iIntraMonitorThreshold)
						{
							bMoveY := false
							g_bUseYThreshold := true
						}
						else
						{
							bMoveY := true
							g_bUseYThreshold := false

							iMouseYPosAtCorner := iMouseY
							g_iYDeltaAtTopCorner := 0
						}
					}
				}
			}

			WinMove, ahk_id %hWnd%,, % bMoveX ? iX : "", bMoveY ? iY : ""

			iPrevMouseX := iMouseX
			iPrevMouseY := iMouseY
		}
	}

	return
}

Alt_And_RButton:
{
	iPrevMouseX := iPrevMouseY := A_Blank
	g_bUseWThreshold := g_bUseHThreshold := true
	MouseGetPos,,, hWnd

	if (IsApprovedHwnd(hWnd))
	{
		while (GetKeyState("Alt", "P") && GetKeyState("RButton", "P"))
		{
			bIgnoreW := GetKeyState("Ctrl", "P")
			bIgnoreH := GetKeyState("Shift", "P")

			MouseGetPos, iMouseX, iMouseY
			iMouseX := iMouseX
			iMouseY := iMouseY

			WinGetPos, iX, iY, iWndW, iWndH, ahk_id %hWnd%
			iXDelta := bIgnoreW ? 0 : iMouseX - (iPrevMouseX == A_Blank ? iMouseX : iPrevMouseX)
			iYDelta := bIgnoreH ? 0 : iMouseY - (iPrevMouseY == A_Blank ? iMouseY : iPrevMouseY)

			if (iXDelta == 0 && iYDelta == 0)
			{
				iPrevMouseX := iMouseX
				iPrevMouseY := iMouseY
				continue
			}

			iWndW := iWndW + iXDelta
			iWndH := iWndH + iYDelta

			bMoveW := bMoveH := true
			rectMonMouseIsOn := myGetMonitorRectAt(iMouseX, iMouseY)

			; if we have passed a monitor corner over onto another monitor, or else we have shifted directions towards to opposite corner of the monitor, reset
			if (abs(iMouseX) - abs(iMouseXPosAtCorner) < g_iIntraMonitorThreshold)
				g_bUseWThreshold := true
			if (abs(iMouseY) - abs(iMouseYPosAtCorner) < g_iIntraMonitorThreshold)
				g_bUseHThreshold := true

			WinGetClass, sClass, ahk_id %hWnd%
			if (IsWin10() && WndHasBorder(hWnd) && sClass != "Chrome_WidgetWin_1") ; !VivaldiIsActive()
			{
				if (!bIgnoreW)
				{
					rectMonMouseIsOn.Right += 7
				}
				if (!bIgnoreH)
				{
					rectMonMouseIsOn.Bottom += 7
				}
			}

			if (g_bUseWThreshold)
			{
				if (!bIgnoreW)
				{
					if (iXDelta < 0 ; moving window to the left
					&& iX - iXDelta >= rectMonMouseIsOn.left ; the left corner of the wnd is not already past the monitor's left corner
					&& iX < rectMonMouseIsOn.left) ; we are trying to move the window past the left corner
					{
						g_iXDeltaAtLeftCorner += abs(iXDelta)

						if (g_iXDeltaAtLeftCorner < g_iIntraMonitorThreshold)
						{
							bMoveW := false
							g_bUseWThreshold := true
						}
						else
						{
							bMoveW := true
							g_bUseWThreshold := false

							iMouseXPosAtCorner := iMouseX
							g_iXDeltaAtLeftCorner := 0
						}
					}
					else if (iXDelta > 0 ; moving window to the right
					&& iX - iXDelta + iWndW <= rectMonMouseIsOn.right ; the right corner of the wnd is not already past the monitor's right corner
					&& (iX + iWndW) > rectMonMouseIsOn.right) ; we are trying to move the window past the right corner
					{
						g_iXDeltaAtRightCorner += abs(iXDelta)

						if (g_iXDeltaAtRightCorner < g_iIntraMonitorThreshold)
						{
							bMoveW := false
							g_bUseWThreshold := true
						}
						else
						{
							bMoveW := true
							g_bUseWThreshold := false

							iMouseXPosAtCorner := iMouseX
							g_iXDeltaAtRightCorner := 0
						}
					}
				}
			}
			if (g_bUseHThreshold)
			{
				if (!bIgnoreH)
				{
					if (iYDelta < 0 ; moving window to the bottom
					&& iY - iYDelta >= rectMonMouseIsOn.top ; the top corner of the wnd is not already past the monitor's top corner
					&& iY < rectMonMouseIsOn.top) ; we are trying to move the window past the top corner
					{
						g_iYDeltaAtBottomCorner += abs(iYDelta)

						if (g_iYDeltaAtBottomCorner < g_iIntraMonitorThreshold)
						{
							bMoveH := false
							g_bUseHThreshold := true
						}
						else
						{
							bMoveH := true
							g_bUseHThreshold := false

							iMouseYPosAtCorner := iMouseY
							g_iYDeltaAtBottomCorner := 0
						}
					}
					else if (iYDelta > 0 ; moving window to the right
					&& iY - iYDelta + iWndH <= rectMonMouseIsOn.bottom ; the right corner of the wnd is not already past the monitor's bottom corner
					&& (iY + iWndH) > rectMonMouseIsOn.bottom) ; we are trying to move the window past the bottom corner
					{
						g_iYDeltaAtTopCorner += abs(iYDelta)

						if (g_iYDeltaAtTopCorner < g_iIntraMonitorThreshold)
						{
							bMoveH := false
							g_bUseHThreshold := true
						}
						else
						{
							bMoveH := true
							g_bUseHThreshold := false

							iMouseYPosAtCorner := iMouseY
							g_iYDeltaAtTopCorner := 0
						}
					}
				}
			}

			WinMove, ahk_id %hWnd%,,,, % bMoveW ? iWndW : "", bMoveH ? iWndH : ""

			iPrevMouseX := iMouseX
			iPrevMouseY := iMouseY
		}
	}

	return
}

ChangeWindowTitle:
{
	; Turn off hotkeys so that the LButton is not responise
	Hotkey, *LButton, Off
	Hotkey, *RButton, Off
	Hotkey, *MButton, Off

	; This hotkey seems to be triggered twice every time it is activated, so g_iTimeAtThisExecution is used to prevent double-execution
	g_iTimeAtThisExecution := SubStr(A_Now, StrLen(A_Now) - 3, 4)
	if (A_ThisHotkey = "*MButton" && g_iTimeAtLastExecution != A_Blank && g_iTimeAtThisExecution - g_iTimeAtLastExecution < 1)
		return

	MouseGetPos,,, hWnd

	if (IsApprovedHwnd(hWnd))
	{
		WinGetTitle, sExistingTitle, ahk_id %hWnd%
		InputBox, sNewTitle, Set Window Title,,,,,,,,, %sExistingTitle%

		g_iTimeAtLastExecution := SubStr(A_Now, StrLen(A_Now) - 3, 4)
		if (ErrorLevel)
			return

		WinSetTitle, ahk_id %hWnd%,, %sNewTitle%
	}

	return
}

#LButton::
{
	MouseGetPos,,, hWnd

	if (IsApprovedHwnd(hWnd))
	{
		sEnable := (DllCall("IsWindowEnabled", uint, hWnd) ? "Disable" : "Enable")
		WinSet, %sEnable%,, ahk_id %hWnd%
		TT_Out("Window " sEnable "d!")
	}

	return
}

*#RButton::
{
	if (GetKeyState("Ctrl", "P"))
	{
		MouseGetPos,,, hMouseWnd
		ToggleWindowBorder(hMouseWnd)
	}
	else
	{
		Send #{RButton Up}
	}

	return
}

!+C::
{
	MouseGetPos,,,, hCtrl, 2
	ControlGetText, sCtrlTxt,, ahk_id %hCtrl%
	ControlGetPos, iX, iY, iW, iH,, ahk_id %hCtrl%
	if !((iX == A_Blank || iY == A_Blank || iW == A_Blank || iH == A_Blank))
		clipboard := "Control:`t" sCtrlTxt "`nLeft:`t" iX "`nTop:`t" iY "`nRight:`t" iW "`nBottom:`t" iH
	return
}

TT_Out(sOutput)
{
	Tooltip, %sOutput%
	SetTimer, TT_Out, 2500
	return
}

TT_Out:
{
	Tooltip
	SetTimer, TT_Out, Off
	return
}

IsApprovedHwnd(hWnd)
{
	WinGetClass, sClass, ahk_id %hWnd%
	return !(sClass== "WorkerW"
				|| sClass == "Shell_TrayWnd"
				|| sClass== "Progman"
				|| sClass== "SideBar_HTMLHostWindow")
}

#+s::
{
	; If the script is suspended, then this hotkey will NOT be triggered, so the only thing to do is
	; suspend this script and unsuspend the other script, if it exists
	if (Send_WM_COPYDATA("Suspend, 0", g_sControlControlWinTitle) = "Fail")
		SuspendThisScriptOnly() ; this actually will never be called
	else ToggleSuspend(true)

	return
}

ToggleSuspend(bOn)
{
	if (bOn)
		Suspend, On
	else Suspend, Off

	return
}

SuspendThisScriptOnly()
{
	Suspend, On
	SetTimer, WatchForUnsuspend, 100
	return
}

WatchForUnsuspend:
{
	if ((GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))&& GetKeyState("Shift", "P") && GetKeyState("S", "P"))
	{
		Suspend, Off
		SetTimer, WatchForUnsuspend, Off
	}
	return
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: myGetMonitorRectAt
		Purpose: Wrapper for GetMonitorRectAt
	Parameters
		x, y, default=1
*/
myGetMonitorRectAt(x, y, default=1)
{
	vRect := GetMonitorRectAt(x, y, default)

	if (IsWin10() && WndHasBorder())
	{
		;~ vRect.Left += 7
		;~ vRect.Right += 14
		;~ vRect.Bottom += 7
	}

	return vRect
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


Send_WM_COPYDATA(ByRef StringToSend, ByRef TargetScriptTitle)  ; ByRef saves a little memory in this case.
; This function sends the specified string to the specified window and returns the reply.
; The reply is 1 if the target window processed the message, or 0 if it ignored it.
{
	VarSetCapacity(CopyDataStruct, 3*A_PtrSize, 0)  ; Set up the structure's memory area.
	; First set the structure's cbData member to the size of the string, including its zero terminator:
	SizeInBytes := (StrLen(StringToSend) + 1) * (A_IsUnicode ? 2 : 1)
	NumPut(SizeInBytes, CopyDataStruct, A_PtrSize)  ; OS requires that this be done.
	NumPut(&StringToSend, CopyDataStruct, 2*A_PtrSize)  ; Set lpData to point to the string itself.
	Prev_DetectHiddenWindows := A_DetectHiddenWindows
	Prev_TitleMatchMode := A_TitleMatchMode
	DetectHiddenWindows On
	SetTitleMatchMode 2
	SendMessage, 0x4a, 0, &CopyDataStruct,, %TargetScriptTitle%  ; 0x4a is WM_COPYDATA. Must use Send not Post.
	DetectHiddenWindows %Prev_DetectHiddenWindows%  ; Restore original setting for the caller.
	SetTitleMatchMode %Prev_TitleMatchMode%         ; Same.
	return ErrorLevel  ; Return SendMessage's reply back to our caller.
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: IsWin10
		Purpose: To tell whether the user is running any version of Windows 10
	Parameters
		
*/
IsWin10()
{
	return SubStr(A_OSVersion, 1, 2) == "10"
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;