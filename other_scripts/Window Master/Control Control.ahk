#Persistent
#SingleInstance, Force

; Hotkeys
;	1. Alt + LButton = Move control
;	2. Alt + Shift + LButton = Move control along X axis only
;	3. Alt + Ctrl + LButton = Move control along Y axis only
;	4. Alt + RButton = Resize control
;	5. Alt + Shift + RButton = Resize control width only
;	6. Alt + Ctrl + RButton = Resize control height only
;	7. Alt + MButton OR Alt + Win + C = Change text within control
;	8. Alt + Shift + C = Copy control coordinates to clipboard
;	9. Win + LButton = Enable/Disable Control

CoordMode, Mouse
SetControlDelay, -1

; For suspending Window Control script
g_sWindowControlWinTitle := "Window Control.ahk"
if (A_IsCompiled)
{
	g_sWindowControlWinTitle := "Window Control - 32.exe"
	if (A_PtrSize == 8)
		g_sWindowControlWinTitle := "Window Control - 64.exe"
}
g_sWindowControlWinTitle .= " ahk_class AutoHotkey"
OnMessage(WM_COPYDATA:=74, "OnCopyData")

return ; End auto-execute

#!c::
{
	gosub ChangeControlLabel
	return
}

; Simple hotkeys like ~Alt & ~LButton cannot be used becuase this does not disable clicks inside of windows
Shift & ~Alt::
Ctrl & ~Alt::
~Alt::
{
	Hotkey, *LButton, Alt_And_LButton, On
	Hotkey, *RButton, Alt_And_RButton, On
	Hotkey, *MButton, ChangeControlLabel, On
	KeyWait, Alt
	Hotkey, *LButton, Off
	Hotkey, *RButton, Off
	Hotkey, *MButton, Off

	if (A_ThisHotkey = "*LButton")
		gosub Alt_And_LButton
	else if (A_ThisHotkey = "*RButton")
		gosub Alt_And_RButton
	else if (A_ThisHotkey = "*MButton")
		gosub ChangeControlLabel

	return
}

Alt_And_LButton:
{
	iPrevMouseX := iPrevMouseY := A_Blank
	MouseGetPos,,,, hCtrl, 2

	while (GetKeyState("Alt", "P") && GetKeyState("LButton", "P"))
	{
		bIgnoreX := GetKeyState("Ctrl", "P")
		bIgnoreY := GetKeyState("Shift", "P")

		MouseGetPos, iMouseX, iMouseY
		iMouseX := iMouseX
		iMouseY := iMouseY

		ControlGetPos, iX, iY,,,, ahk_id %hCtrl%
		iXDelta := bIgnoreX ? 0 : iMouseX - (iPrevMouseX == A_Blank ? iMouseX : iPrevMouseX)
		iYDelta := bIgnoreY ? 0 : iMouseY - (iPrevMouseY == A_Blank ? iMouseY : iPrevMouseY)
		if (iXDelta <> 0 || iYDelta <> 0)
		{
			ControlMove,, iX + iXDelta, iY + iYDelta,,, ahk_id %hCtrl%
			DllCall("RedrawWindow", "Ptr", hCtrl, "Ptr", 0, "Ptr", 0, "UInt", RDW_INVALIDATE := 1 | RDW_ERASENOW := 0x200 | RDW_ERASE := 4)
		}

		iPrevMouseX := iMouseX
		iPrevMouseY := iMouseY
	}

	return
}

Alt_And_RButton:
{
	iPrevMouseX := iPrevMouseY := A_Blank
	MouseGetPos,,,, hCtrl, 2

	while (GetKeyState("Alt", "P") && GetKeyState("RButton", "P"))
	{
		bIgnoreW := GetKeyState("Ctrl", "P")
		bIgnoreH := GetKeyState("Shift", "P")

		MouseGetPos, iMouseX, iMouseY
		iMouseX := iMouseX
		iMouseY := iMouseY

		ControlGetPos,,, iW, iH,, ahk_id %hCtrl%
		iWDelta := bIgnoreW ? 0 : iMouseX - (iPrevMouseX == A_Blank ? iMouseX : iPrevMouseX)
		iHDelta := bIgnoreH ? 0 : iMouseY - (iPrevMouseY == A_Blank ? iMouseY : iPrevMouseY)
		if (iWDelta <> 0 || iHDelta <> 0)
		{
			ControlMove,,,, iW + iWDelta, iH + iHDelta, ahk_id %hCtrl%
			DllCall("RedrawWindow", "Ptr", hCtrl, "Ptr", 0, "Ptr", 0, "UInt", RDW_INVALIDATE:=1 | RDW_ERASENOW:=0x200 | RDW_ERASE:=4)
		}

		iPrevMouseX := iMouseX
		iPrevMouseY := iMouseY
	}

	return
}

ChangeControlLabel:
{
	; Turn off hotkeys so that the LButton is not responise
	Hotkey, *LButton, Off
	Hotkey, *RButton, Off
	Hotkey, *MButton, Off

	; This hotkey seems to be triggered twice every time it is activated, so g_iTimeAtThisExecution is used to prevent double-execution
	g_iTimeAtThisExecution := SubStr(A_Now, StrLen(A_Now) - 3, 4)
	if (A_ThisHotkey = "*MButton" && g_iTimeAtLastExecution != A_Blank && g_iTimeAtThisExecution - g_iTimeAtLastExecution < 1)
		return

	MouseGetPos,,,, hCtrl, 2
	ControlGetText, sExistingText,, ahk_id %hCtrl%
	InputBox, sText, Set Control Text,,,,,,,,, %sExistingText%

	g_iTimeAtLastExecution := SubStr(A_Now, StrLen(A_Now) - 3, 4)
	if (ErrorLevel)
		return

	ControlSetText,, %sText%, ahk_id %hCtrl%
	return
}

#LButton::
{
	MouseGetPos,,,, hCtrl, 2
	ControlGet, bEnabled, Enabled,,, ahk_id %hCtrl%
	Control, % bEnabled ? "Disable" : "Enable",,, ahk_id %hCtrl%
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
	if (Send_WM_COPYDATA("Suspend, 0", g_sWindowControlWinTitle) = "Fail")
		SuspendThisScriptOnly() ; this actually will never be called
	else ToggleSuspend(true)

	return
}

OnCopyData(wParam, lParam)
{
	sMsg := StrGet(NumGet(lParam + 2*A_PtrSize))
	StringSplit, aMsg, sMsg, `,

	if (Trim(aMsg1, " `t") = "Suspend")
		ToggleSuspend(Trim(aMsg2, " `t"))

	if (aMsg2)
		TT_Out("Window Control script is now active.`nControl Control script is now suspended.")
	else TT_Out("Control Control script is now active.`nWindow Control script is now suspended.")

	return true
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