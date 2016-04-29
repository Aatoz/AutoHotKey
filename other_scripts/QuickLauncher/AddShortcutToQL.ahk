/*
	AddShortcutToQL
	This needs to be a standalone application because there were issues on Win8+
	when trying to run the QuickLauncher itself to add the context menu entry

	We'll simply add a listener to QuickLauncher and use PostMessage to let QuickLauncher know it should update the Database
*/

#SingleInstance Force

SetBatchLines -1
SetWorkingDir, %A_ScriptDir%
DetectHiddenWindows, On ; Needed for PostMessage

; Process command line.
Loop %0% ; for each parameter
{
	sParm := %A_Index%
	StringSplit, aCmd, sParm, `=
	sCmd := aCmd1
	sParms := aCmd2

	if (sCmd = "AddCmd")
	{
		vCmdInfo := {Func: "Run", Parms: sParms}
		InputBox, sAddUserCmd, Add Command to Quick Launcher, Specify a shortcut for %sParms%
		sAddUserCmd := Trim(sAddUserCmd) ; Spaces mess things up.

		g_MasterIni := new EasyIni("Master")
		if (sAddUserCmd && g_MasterIni.AddSection(sAddUserCmd, "", "", sError))
		{
			g_MasterIni[sAddUserCmd] := vCmdInfo
			g_MasterIni.Save()
		}
		else Msgbox 8192,, %sError%
	}
}

g_hQuickLauncher := WinExist("Quick Launcher ahk_class AutoHotkeyGUI")
if (g_hQuickLauncher)
	SendMessage, WM_SETTINGCHANGE:=26, 0, 0,, % "ahk_id" g_hQuickLauncher
else Msgbox 8192,, Error:`n`nCould not find Quick Launcher window

ExitApp