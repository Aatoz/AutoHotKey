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
		vCmd := {Func: "Run", Parms: sParms}
		AddCmdProc(vCmd)
	}
}

g_hQuickLauncher := WinExist("Quick Launcher ahk_class AutoHotkeyGUI")
if (g_hQuickLauncher)
	SendMessage, WM_SETTINGCHANGE:=26, 0, 0,, % "ahk_id" g_hQuickLauncher
else Msgbox 8192,, Error:`n`nCould not find Quick Launcher window

ExitApp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: AddCmdProc
		Purpose: To localize logic to add a command to the database
	Parameters
		vCmd
*/
AddCmdProc(vCmd)
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

		InputBox, sAddUserCmd, Add Command to Quick Launcher, % "Specify a shortcut for " vCmd.Parms
		if (ErrorLevel)
		{
			bContinue := false
			sAddUserCmd :=
		}
		else sAddUserCmd := Trim(sAddUserCmd) ; Spaces mess things up.
	}

	if (sAddUserCmd) ; If a valid shortcut was specified
	{
		vMasterIni := class_EasyIni("Master")
		if (vMasterIni.AddSection(sAddUserCmd, "", "", sError))
		{
			vMasterIni[sAddUserCmd] := vCmd
			vMasterIni.Save()
		}
		else Msgbox 8192,, %sError%
	}

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: Msgbox_YesNo
		Purpose:
	Parameters
		sMsg: Actual prompt (should be a question)
		sTitle="": Dialog header (should *not* end with a question mark)
*/
Msgbox_YesNo(sMsg, sTitle="")
{
	MsgBox, 8228, %sTitle%, %sMsg%

	IfMsgBox Yes
		return true
	return false
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;