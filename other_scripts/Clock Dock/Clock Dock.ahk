#SingleInstance Force
#Persistent
#NoTrayIcon

SetWorkingDir, %A_ScriptDir%

; This is a cool clock OSD which uses CFlyout.
InitClock()
g_vClock.Show()

SetTimer, ClockProc, 3000 ; Only update every 3 seconds since we are only updating minutes, and I don't care if we are 2 seconds late.
return

InitClock()
{
	global g_vClock
		, g_sBgdSize, g_sDesktopBgd

	RegRead, g_sDesktopBgd, HKEY_CURRENT_USER, Control Panel\Desktop, Wallpaper
	FileGetSize, g_sBgdSize, %g_sDesktopBgd%

	g_vClock := new CFlyout([GetTime(), GetDay(), GetDate()]
		, "Parent=" WinExist("ahk_class Progman")
		, "Background=" g_sDesktopBgd
		, "ShowBorder=" false) ; good font color 0xF8F86D.
	g_vClock.OnMessage("Copy", "OnCopy")

	Hotkey, IfWinActive, % "ahk_id" g_vClock.m_hFlyout
		Hotkey, !r, Reload
		Hotkey, !e, Edit
		Hotkey, Esc, ExitApp
}

ReInitClock(iCurSel) ; iCurSel is 0-based.
{
	global g_vClock

	InitClock()
	g_vClock.MoveTo(iCurSel+1)

	return
}

ClockProc:
{
	; If the desktop background has changed, change this background now.
	FileGetSize, sBgdSize, %g_sDesktopBgd%
	if (g_sBgdSize != sBgdSize)
	{
		ReInitClock(g_vClock.GetCurSelNdx())
		return ; Times have been updated.
	}

	if (GetTime() != g_vClock.m_asItems[1])
		g_vClock.SetItem(GetTime(), 1)
	if (GetDay() != g_vClock.m_asItems[2])
		g_vClock.SetItem(GetDay(), 2)
	if (GetDate() != g_vClock.m_asItems[3])
		g_vClock.SetItem(GetDate(), 3)

	return
}

GetTime()
{
	return "   " . A_Hour ":" A_Min
}

GetDay()
{
	return "   " . A_DDDD
}

GetDate()
{
	return "   " . A_MM "/" A_DD "/" A_YYYY
}

OnCopy(vFlyout, msg)
{
	if (msg = "Copy")
		clipboard := Trim(vFlyout.m_sCurSel)

	return
}

Edit:
{
	CFlyout.GUIEditSettings(0, "", true)
	return
}

Reload:
	Reload

ExitApp:
	ExitApp


#Include %A_ScriptDir%\CFlyout.ahk