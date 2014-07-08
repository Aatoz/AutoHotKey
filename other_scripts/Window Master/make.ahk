#SingleInstance Force
SetFormat, float, 4.2

sFilesToInclude := "
(
res\Default Wnd.png
res\Monitor Frame.png
res\icons\Sequence.ico
res\icons\Settings_Pressed_16.ico
res\icons\Snap.ico
res\icons\Bunch of Bluish\Add.ico
res\icons\Bunch of Bluish\Close.ico
res\icons\Bunch of Bluish\Edit.ico
res\icons\Bunch of Bluish\Delete.ico
res\icons\Bunch of Bluish\Save.ico
res\icons\Bunch of Bluish\Refresh.ico
res\icons\Free Blue Buttons\Resize2.ico
res\icons\Free Blue Buttons\Browse2.ico
res\icons\Free Object Icons\Revert.ico
res\icons\I Like Buttons\Green.ico
res\icons\I Like Buttons\Info.ico
res\icons\I Like Buttons\Off.ico
res\icons\I Like Buttons\Red.ico
res\icons\I Like Buttons\Win2.ico
res\icons\Orb\Down.ico
res\icons\Orb\Up.ico
res\icons\Primo\Pause.ico
res\icons\Primo\Play.ico
res\icons\Windows Master\Default Flyout Menu 1.jpg
res\icons\Windows Master\Default Flyout Menu 2.jpg
res\icons\Windows Master\Main.ico
res\icons\Windows Master\Main_Disconnected.ico
res\icons\Windows Master\Splash with rounded edges.png
)"

; Begin version number
sDir := A_AhkDir() "\other_scripts\Window Master"
FileRead, iVersion, %sDir%\version
if (iVersion)
	iVersion += 0.01
else iVersion := 1.0
FileDelete, %sDir%\version
FileAppend, %iVersion%, %sDir%\version

sFileInstalls .= "; v" iVersion "`n"
; End verion number

; Begin images
sDir := A_ScriptDir "\images"
SetWorkingDir, % A_AhkDir()

FileRemoveDir, %sDir%, 1
FileCreateDir, %sDir%

Loop, Parse, sFilesToInclude, `n
{ ;Save files to tmp folder
	if (FileExist(A_LoopField))
	{
		; Extract just the filename
		StringSplit, aFileName, A_LoopField, \
		sFileName := aFileName%aFileName0%
		; Copy the file over to images folder

		; Silly filename handling
		; Trim _T
		iPosOfDot := InStr(sFileName, ".")
		if (SubStr(sFileName, iPosOfDot - 2, 2) = "_T")
		{
			sFileExt := SubStr(sFileName, iPosOfDot)
			sFileName := SubStr(sFileName, 1, iPosOfDot-3) sFileExt
		}
		StringReplace, sFileName, sFileName, Off, Close
		StringReplace, sFileName, sFileName, Settings_Pressed_16, Menu Settings
		StringReplace, sFileName, sFileName, Browse2, Window
		StringReplace, sFileName, sFileName, Resize2, Resize
		StringReplace, sFileName, sFileName, Win2, Open
		StringReplace, sFileName, sFileName, Down, Import
		StringReplace, sFileName, sFileName, Up, Export
		StringReplace, sFileName, sFileName, Splash with rounded edges, Splash

		sFileInstalls .= "FileInstall, images\" sFileName ", images\" sFileName ", 1`n"
		FileCopy, %A_LoopField%, %sDir%\%sFileName%
	}
	else FileError()

}
; End images

; Begin ahk files
sAHKFiles := "
(
other_scripts\CFlyout\CFlyout.ahk
other_scripts\CFlyout\CFlyoutMenuHandler.ahk
other_scripts\CFlyout\CLeapMenu.ahk
)"

Loop, Parse, sAHKFiles, `n
{
	if (FileExist(A_LoopField))
	{
		; Extract just the filename
		StringSplit, aFileName, A_LoopField, \
		sFileName := aFileName%aFileName0%
		; Copy the file over to tha main folder
		FileCopy, %A_LoopField%, %A_ScriptDir%\%sFileName%, 1
	}
	else FileError()
}
; End ahk files

sFileInstalls .= "`; License and other help files.`n"
sFileInstalls .= "FileInstall, version, version, 1`n"
sFileInstalls .= "FileInstall, License.txt, License.txt, 1`n"
sFileInstalls .= "FileInstall, ReadMe.txt, ReadMe.txt, 1`n"
sFileInstalls .= "`; Dependencies`n"
; msvcr100.dll -- Beacuse AutoHotkey_H is compiled with Visual Studio 2010.
sFileInstalls .= "FileInstall, msvcr100.dll, msvcr100.dll, 1`n"

clipboard := sFileInstalls
Msgbox Done! List of FileInstalls are on the clipboard.`n`n%sFileInstalls%

; Make AutoLeap
RunWait, % A_AhkExe() " """ A_WorkingDir "\other_scripts\AutoLeap\make.ahk"""
FileCopyDir, other_scripts\AutoLeap, %A_ScriptDir%\AutoLeap, 1
Msgbox % "Copy of AutoLeap directory " (ErrorLevel ? "failed" : "suceeded") "."

return

FileError()
{
	Msgbox 8192,, Error: Include file %A_WorkingDir%\%A_LoopField% does not exist.
	ExitApp
}

/* 
sInfo := "
(


1 VERSIONINFO
FILEVERSION 1,0,20,0
PRODUCTVERSION 1,0,20,0
FILEOS 0x4
FILETYPE 0x1
{
BLOCK "StringFileInfo"
{
	BLOCK "040904B0"
	{
		VALUE "FileDescription", "Windows Master"
		VALUE "FileVersion", "1.0.20.00"
		VALUE "InternalName", "Windows Master"
		VALUE "LegalCopyright", "Copyright (C) 2014"
		VALUE "OriginalFilename", "WindowsMaster_LM.exe"
		VALUE "ProductName", "Windows Master"
		VALUE "ProductVersion", "1.0.20.00"
	}
}

BLOCK "VarFileInfo"
{
	VALUE "Translation", 0x0409 0x04B0
}
}

)
Msgbox % "Here is the string info for ResHacker`n`n"
 */
