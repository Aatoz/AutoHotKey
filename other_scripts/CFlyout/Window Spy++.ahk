#Persistent
#SingleInstance Force
#include %A_ScriptDir%\CFlyout.ahk

SetWorkingDir, %A_ScriptDir%
SendMode, Input

g_vSpy := new CFlyout(0, 0, false, true, A_ScreenWidth - 465, "", 465, 28, 0, false, "", "", "", "", true, "", "", "", "-") ; c0xFF0080
g_vSpy.OnMessage(WM_LBUTTONDBLCLK:=515 ",Copy", "WSpy_OnMessage")

WinSetTitle, % "ahk_id" g_vSpy.m_hFlyout,, Window Spy++ ; b/c default title is "GUI_FlyoutN" (where N = the number of flyouts currently running in the script)

Hotkey, IfWinActive
	Hotkey, ^+~, Show_Hide
	Hotkey, #+Tab, Play_Pause

Hotkey, IfWinActive, % "ahk_id" g_vSpy.m_hFlyout
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
	bShowControlPos := (g_vSpy.m_asItems[18] = "Hide Control Positions")
	UpdateSpecs(bShowControlPos)

	sActiveWndTitle := g_vSpy.m_asItems[1]
	sActiveClass := g_vSpy.m_asItems[2]
	hActiveWndUnderCursor := g_vSpy.m_asItems[3]
	; ----------------------------------------
	hWinCtrlClass := g_vSpy.m_asItems[5]
	hWinCtrl := g_vSpy.m_asItems[6]
	; ----------------------------------------
	bAlwaysOnTop := g_vSpy.m_asItems[8]
	bIsEnabled := g_vSpy.m_asItems[9]
	iMinMaxState := g_vSpy.m_asItems[10]
	iTransparent := g_vSpy.m_asItems[11]
	; ----------------------------------------
	iWndX := g_vSpy.m_asItems[13]
	iWndY := g_vSpy.m_asItems[14]
	iWndW :=g_vSpy.m_asItemsaSpecs[15]
	iWndH := g_vSpy.m_asItems[16]
	; ----------------------------------------
	; "Show/Hide Control Positions"
	if (bShowControlPos)
		iSelOffset := 6
	else iSelOffset := 0
	; ----------------------------------------

	iMouseX := g_vSpy.m_asItems[18 + iSelOffset]
	iMouseY := g_vSpy.m_asItems[19 + iSelOffset]
	; ----------------------------------------
	sCurrentDate := g_vSpy.m_asItems[21 + iSelOffset]

	if (SubStr(hActiveWndUnderCursor, 19) != g_vSpy.m_hFlyout
		&& (sPrevActiveWndTitle != sActiveWndTitle
		|| hPrevActiveWndUnderCursor != hActiveWndUnderCursor || sPrevActiveClass != sActiveClass
		|| hPrevWinCtrl != hWinCtrl || hPrevWinCtrlClass != hWinCtrlClass || iPrevTransparent != iTransparent
		|| iPrevMinMaxState != iMinMaxState || iPrevWndX != iWndX || iPrevWndY != iWndY
		|| iPrevWndW != iWndW || iPrevWndH != iWndH || iPrevMouseX != iMouseX
		|| iPrevMouseY != iMouseY || bPrevAlwaysOnTop != bAlwaysOnTop || bPrevIsEnabled != bisEnabled
		|| iPrevHour != A_Hour || iPrevMin != A_Min || sPrevCurrentDate != sCurrentDate))
		{
			; An update, rightfully so, sets the selection back to 1. This is OK because how is CFlyout supposed to now you are updating it with the same contents?
			iPrevSel := g_vSpy.GetCurSelNdx() + 1
			g_vSpy.UpdateFlyout()
			g_vSpy.MoveTo(iPrevSel)
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

UpdateSpecs(bShowControlSpecs)
{
	global g_vSpy

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
	if (ExStyle & WS_EX_TOPMOST:=8)
		AlwaysOnTop := "Yes"

	g_vSpy.Clear()

	g_vSpy.AddText("ActiveTitle: " sActiveTitle)
	g_vSpy.AddText("ActiveClass: ahk_class " sActiveClass)
	g_vSpy.AddText("ActiveWnd: ahk_id " hActiveWndUnderCursor)
	g_vSpy.AddLine()
	g_vSpy.AddText("WinCtrlClass: " (hWinCtrlClass ? "ahk_class " hWinCtrlClass : ""))
	g_vSpy.AddText("WinCtrl: " (hWinCtrl ? "ahk_id "hWinCtrl : ""))
	g_vSpy.AddLine()
	g_vSpy.AddText("Always on top?: " AlwaysOnTop)
	g_vSpy.AddText("Enabled?: " DllCall("IsWindowEnabled", uint, hActiveWndUnderCursor))
	g_vSpy.AddText("MinMaxState: " iMinMaxState)
	g_vSpy.AddText("Translucency: " iTransparent "")
	g_vSpy.AddLine()
	g_vSpy.AddText("WndX: " iWndX)
	g_vSpy.AddText("WndY: " iWndY)
	g_vSpy.AddText("WndW: " iWndW)
	g_vSpy.AddText("WndH: " iWndH)
	g_vSpy.AddLine()

	if (bShowControlSpecs)
	{
		g_vSpy.AddText("Hide Control Positions")
		g_vSpy.AddLine()
		ControlGetPos, iX, iY, iW, iH,, ahk_id %hWinCtrl%
		g_vSpy.AddText("CtrlX: " iX)
		g_vSpy.AddText("CtrlY: " iY)
		g_vSpy.AddText("CtrlW: " iW)
		g_vSpy.AddText("CtrlH: " iH)
	}
	else g_vSpy.AddText("Show Control Positions")

	g_vSpy.AddLine()
	g_vSpy.AddText("MouseX: " iMouseX)
	g_vSpy.AddText("MouseY: " iMouseY)
	g_vSpy.AddLine()
	g_vSpy.AddText("Current Time: " A_Hour ":" A_Min)
	g_vSpy.AddText("Current Date: " sCurrentDate)

	return
}

WSpy_OnMessage(vFlyout, msg)
{
	static WM_LBUTTONDBLCLK:=515,WM_COPYDATA:=74

	if (msg == WM_LBUTTONDBLCLK)
	{
		if (vFlyout.GetCurSelNdx() == 17)
		{
			bShowControlPos := (vFlyout.m_asItems[18] = "Show Control Positions")
			UpdateSpecs(bShowControlPos)
			vFlyout.UpdateFlyout()
			vFlyout.MoveTo(18)
		}
	}
	else if (msg = "Copy")
	{
		sCopy := vFlyout.GetCurSel()
		if (iColonPos := InStr(sCopy, ":"))
			sCopy := SubStr(sCopy, iColonPos+2)

		clipboard := sCopy
	}

	return true
}

OnWheelUp:
{
	g_vSpy.Move(true)
	; TODO: Check on previous sel and move - 2
	if (g_vSpy.GetCurSel() == g_vSpy.m_sSeparatorLine)
		g_vSpy.Move(true)

	return
}

OnWheelDown:
{
	g_vSpy.Move(false)
	; TODO: Check on next sel and move + 2
	if (g_vSpy.GetCurSel() == g_vSpy.m_sSeparatorLine)
		g_vSpy.Move(false)

	return
}

OnEnter:
{
	if (g_vSpy.GetCurSelNdx() == 17)
	{
		bShowControlPos := (g_vSpy.m_asItems[18] = "Show Control Positions")
		UpdateSpecs(bShowControlPos)
		g_vSpy.MoveTo(18)
	}

	return
}

Show_Hide:
{
	if (g_vSpy.m_bIsHidden)
	{
		SetTimer, TooltipProc, 100
		gosub TooltipProc
		g_vSpy.MoveTo(g_iPrevSel)
		g_vSpy.Show()
	}
	else
	{
		SetTimer, TooltipProc, Off
		g_iPrevSel := g_vSpy.GetCurSelNdx() + 1
		g_vSpy.Hide()
	}

	return
}

Play_Pause:
{
	if (g_vSpy.m_bIsHidden)
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