#SingleInstance Force
#Persistent

SetWorkingDir, %A_ScriptDir%

; This is a cool clock OSD which uses CFlyout

g_vClock := new CFlyout(WinExist("ahk_class Progman"), [GetTime(), GetDay(), GetDate()], false, true)

Hotkey, IfWinActive, % "ahk_id" g_vClock.m_hFlyout
	Hotkey, !r, Reload
	Hotkey, !e, Edit
	Hotkey, Esc, ExitApp

g_vClock.Show()

SetTimer, ClockProc, 3000 ; Only update every 3 seconds since we are only updating minutes, and I don't care if we are 2 seconds late.
return

ClockProc:
{
	;~ if (GetTime() == g_vClock.m_asItems[1])
		;~ return ; No update necessary.

	g_vClock.SetItem(GetTime(), 1)

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