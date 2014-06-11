#Persistent
#SingleInstance Force
#include %A_ScriptDir%\CFlyout.ahk

SetWorkingDir, %A_ScriptDir%
SendMode, Input

g_vTooltipFlyout := new CFlyout(0, GetLatestSpecs(false), false, true, A_ScreenWidth - 465, "", 465, 28, 0, false, "", "", "", "Center") ; c0xFF0080
g_vTooltipFlyout.OnMessage(WM_LBUTTONDOWN:=513 "," WM_LBUTTONDBLCLK:=515, "WSpy_OnMessage")

WinSetTitle, % "ahk_id" g_vTooltipFlyout.m_hFlyout,, Window Spy++ ; default title is "GUI_FlyoutN" (where N = the number of flyouts currently running in the script)

Hotkey, IfWinActive
	Hotkey, ^+~, Show_Hide
	Hotkey, #+Tab, Play_Pause

Hotkey, IfWinActive, % "ahk_id" g_vTooltipFlyout.m_hFlyout
	Hotkey, WheelUp, OnWheelUp
	Hotkey, WheelDown, OnWheelDown
	Hotkey, Up, OnWheelUp
	Hotkey, Down, OnWheelDown
	Hotkey, Enter, OnEnter
	Hotkey, NumpadEnter, OnEnter
	Hotkey, Space, OnEnter
	Hotkey, !E, GUIEditSettings
	Hotkey, ^R, Reload
	Hotkey, Esc, ExitApp

SetTimer, TooltipProc, 100

TooltipProc:
{
	bShowControlPos := (g_vTooltipFlyout.m_asItems[18] = "Hide Control Positions")
	aSpecs := GetLatestSpecs(bShowControlPos)

	sActiveWndTitle := aSpecs[1]
	sActiveClass := aSpecs[2]
	hActiveWndUnderCursor := aSpecs[3]
	; ----------------------------------------
	hWinCtrlClass := aSpecs[5]
	hWinCtrl := aSpecs[6]
	; ----------------------------------------
	bAlwaysOnTop := aSpecs[8]
	bIsEnabled := aSpecs[9]
	iMinMaxState := aSpecs[10]
	iTransparent := aSpecs[11]
	; ----------------------------------------
	iWndX := aSpecs[13]
	iWndY := aSpecs[14]
	iWndW := aSpecs[15]
	iWndH := aSpecs[16]
	; ----------------------------------------
	; "Show/Hide Control Positions"
	if (bShowControlPos)
		iSelectionOffset := 6
	else iSelectionOffset := 0
	; ----------------------------------------

	iMouseX := aSpecs[18 + iSelectionOffset]
	iMouseY := aSpecs[19 + iSelectionOffset]
	; ----------------------------------------
	sCurrentDate := aSpecs[21 + iSelectionOffset]

	if (SubStr(hActiveWndUnderCursor, 19) != g_vTooltipFlyout.m_hFlyout && (sPrevActiveWndTitle != sActiveWndTitle || hPrevActiveWndUnderCursor != hActiveWndUnderCursor || sPrevActiveClass != sActiveClass || hPrevWinCtrl != hWinCtrl || hPrevWinCtrlClass != hWinCtrlClass || iPrevTransparent != iTransparent || iPrevMinMaxState != iMinMaxState || iPrevWndX != iWndX || iPrevWndY != iWndY || iPrevWndW != iWndW || iPrevWndH != iWndH || iPrevMouseX != iMouseX || iPrevMouseY != iMouseY || bPrevAlwaysOnTop != bAlwaysOnTop || bPrevIsEnabled != bisEnabled || iPrevHour != A_Hour || iPrevMin != A_Min || sPrevCurrentDate != sCurrentDate))
		{
			; An update, rightfully so, sets the selection back to 1. This is OK because how is CFlyout supposed to now you are updating it with the same contents?
			iPrevSel := g_vTooltipFlyout.GetCurSelNdx() + 1
			g_vTooltipFlyout.UpdateFlyout(aSpecs)
			g_vTooltipFlyout.MoveTo(iPrevSel)
		}

	; Store previous values so that we don't force an update whenever it is is unnecessary.
	sPrevActiveWndTitle := sActiveWndTitle
	sPrevActiveClass := sActiveClass
	hPrevActiveWndUnderCursor := hActiveWndUnderCursor
	hPrevWinCtrlClass := hWinCtrlClass
	hPrevWinCtrl := hWinCtrl
	bPrevAlwaysOnTop := bAlwaysOnTop
	bPrevIsEnabled := bisEnabled
	iPrevMinMaxState := iMinMaxState
	iPrevTransparent := iTransparent
	iPrevWndX := iWndX
	iPrevWndY := iWndY
	iPrevWndW := iWndW
	iPrevWndH := iWndH
	iPrevMouseX := iMouseX
	iPrevMouseY := iMouseY
	iPrevHour := A_Hour
	iPrevMin := A_Min
	sPrevCurrentDate := sCurrentDate
	return
}

GetLatestSpecs(bShowControlSpecs)
{
	aSpecs := []

	MouseGetPos, iMouseX, iMouseY, hActiveWndUnderCursor
	WinGet, iTransparent, Transparent, ahk_id %hActiveWndUnderCursor%
	WinGet, iMinMaxState, MinMax, ahk_id %hActiveWndUnderCursor%
	WinGetPos, iWndX, iWndY, iWndW, iWndH, ahk_id %hActiveWndUnderCursor%
	MouseGetPos,,,, hWinCtrlClass
	MouseGetPos,,,, hWinCtrl, 2
	WinGetTitle, sActiveTitle, ahk_id %hActiveWndUnderCursor%
	WinGetClass, sActiveClass, ahk_id %hActiveWndUnderCursor%
	FormatTime, sCurrentDate,, M/d/yy

	AlwaysOnTop := "No"
	WinGet, ExStyle, ExStyle, ahk_id %hActiveWndUnderCursor%
	if (ExStyle & 0x8)  ; 0x8 is WS_EX_TOPMOST.
		AlwaysOnTop := "Yes"

	aSpecs.Insert("ActiveTitle: " sActiveTitle)
	aSpecs.Insert("ActiveClass: ahk_class " sActiveClass)
	aSpecs.Insert("ActiveWnd: ahk_id " hActiveWndUnderCursor)
	aSpecs.Insert("-------------------------------")
	aSpecs.Insert("WinCtrlClass: " (hWinCtrlClass ? "ahk_class " hWinCtrlClass : ""))
	aSpecs.Insert("WinCtrl: " (hWinCtrl ? "ahk_id "hWinCtrl : ""))
	aSpecs.Insert("-------------------------------")
	aSpecs.Insert("Always on top?: " AlwaysOnTop)
	aSpecs.Insert("Enabled?: " DllCall("IsWindowEnabled", uint, hActiveWndUnderCursor))
	aSpecs.Insert("MinMaxState: " iMinMaxState)
	aSpecs.Insert("Translucency: " iTransparent "")
	aSpecs.Insert("-------------------------------")
	aSpecs.Insert("WndX: " iWndX)
	aSpecs.Insert("WndY: " iWndY)
	aSpecs.Insert("WndW: " iWndW)
	aSpecs.Insert("WndH: " iWndH)
	aSpecs.Insert("-------------------------------")
	if (bShowControlSpecs)
	{
		aSpecs.Insert("Hide Control Positions")
		ControlGetPos, iX, iY, iW, iH,, ahk_id %hWinCtrl%
		aSpecs.Insert("CtrlX: " iX)
		aSpecs.Insert("CtrlY: " iY)
		aSpecs.Insert("CtrlW: " iW)
		aSpecs.Insert("CtrlH: " iH)
	}
	else aSpecs.Insert("Show Control Positions")
	aSpecs.Insert("-------------------------------")
	aSpecs.Insert("MouseX: " iMouseX)
	aSpecs.Insert("MouseY: " iMouseY)
	aSpecs.Insert("-------------------------------")
	aSpecs.Insert("Current Time: " A_Hour ":" A_Min)
	aSpecs.Insert("Current Date: " sCurrentDate)
	return aSpecs
}

WSpy_OnMessage(vFlyout, msg)
{
	static WM_LBUTTONDBLCLK:=515

	if (msg = WM_LBUTTONDBLCLK)
	{
		if (vFlyout.GetCurSelNdx() == 17)
		{
			bShowControlPos := (vFlyout.m_asItems[18] = "Show Control Positions")
			aSpecs := GetLatestSpecs(bShowControlPos)
			vFlyout.UpdateFlyout(aSpecs)
			vFlyout.MoveTo(18)
		}
	}

	return true
}

OnWheelUp:
{
	g_vTooltipFlyout.Move(true)
	if (g_vTooltipFlyout.GetCurSel() = "-------------------------------")
		g_vTooltipFlyout.Move(true)
	return
}

OnWheelDown:
{
	g_vTooltipFlyout.Move(false)
	if (g_vTooltipFlyout.GetCurSel() = "-------------------------------")
		g_vTooltipFlyout.Move(false)
	return
}

OnEnter:
{
	if (g_vTooltipFlyout.GetCurSelNdx() = 17)
	{
		bShowControlPos := (g_vTooltipFlyout.m_asItems[18] = "Show Control Positions")
		aSpecs := GetLatestSpecs(bShowControlPos)
		g_vTooltipFlyout.UpdateFlyout(aSpecs)
		g_vTooltipFlyout.MoveTo(18)
	}
	return
}

Show_Hide:
{
	if (g_vTooltipFlyout.m_bIsHidden)
	{
		SetTimer, TooltipProc, 100
		g_vTooltipFlyout.MoveTo(g_iPrevSel)
		g_vTooltipFlyout.Show()
	}
	else
	{
		SetTimer, TooltipProc, Off
		g_iPrevSel := g_vTooltipFlyout.GetCurSelNdx() + 1
		g_vTooltipFlyout.Hide()
	}
	return
}

Play_Pause:
{
	if (g_vTooltipFlyout.m_bIsHidden)
	{
		Send #+{Tab}
		return
	}

	if (g_bPaused)
	{
		SetTimer, TooltipProc, 100
		g_bPaused := false
	}
	else
	{
		SetTimer, TooltipProc, Off
		g_bPaused := true
	}
	return
}

GUIEditSettings:
{
	CFlyout.GUIEditSettings(0, "", true)
	return
}

Reload:
	Reload

ExitApp:
	ExitApp