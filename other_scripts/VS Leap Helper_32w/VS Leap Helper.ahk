#SingleInstance Force

SetWinDelay, -1
StringCaseSense, Off
SendMode, Input
SetWorkingDir, %A_ScriptDir%

; 2008
FileInstall, SampleVS2008.vcproj, SampleVS2008.vcproj, 0
; 2010
FileInstall, SampleVS2010.vcxproj, SampleVS2010.vcxproj, 0
; 2012
FileInstall, SampleVS2012.vcxproj, SampleVS2012.vcxproj, 0
; 2013
FileInstall, SampleVS2013.vcxproj, SampleVS2013.vcxproj, 0

; --- Begin main
while (true)
{
	FileSelectFolder, sLeapSDKPath,, 3, Please select the folder containing the Leap SDK.
	if (ErrorLevel)
	{
		Msgbox 8192,, The application will now terminate.
		ExitApp
	}

	MsgBox, 8227, Confirm path to Leap SDK, Path to Leap SDK is: %sLeapSDKPath%`n`nIs this correct?
	IfMsgBox Yes
		break
	else IfMsgBox Cancel
	{
		Msgbox 8192,, The application will now terminate.
		ExitApp
	}
}

if (!MakeRegKey(sLeapSDKPath))
	Msgbox 8192,, Error: Unable to write to registry. Try running this program as administrator.`n`nPath:`tHKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\LEAP_SDK`nValue:`t%sLeapSDKPath%
	else Msgbox 8192,, Registry write was successful! The application will now exit.

ExitApp
return
; --- End main

MakeRegKey(ByRef rsLeapSDKPath)
{
	static WM_SETTINGCHANGE:=26

	RegWrite, REG_SZ, HKLM, SYSTEM\CurrentControlSet\Control\Session Manager\Environment, LEAP_SDK, %rsLeapSDKPath%
	if (ErrorLevel)
		return false

	SendMessage, WM_SETTINGCHANGE, 0, "Environment",, ahk_id 0xFFFF
	if (ErrorLevel)
		Msgbox 8192,, Note: Variable has been changed, but application was unable to notify the system about this change.`n`nIt is recommended that you exit Visual Studio, if it is open.

	return true
}