#SingleInstance Force

; TODO: licenses

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
res\icons\I Like Buttons\Info.ico
res\icons\I Like Buttons\Off.ico
res\icons\I Like Buttons\Win2.ico
res\icons\Orb\Down.ico
res\icons\Primo\Pause.ico
res\icons\Primo\Play.ico
res\icons\Windows Master\Default Flyout Menu 1.jpg
res\icons\Windows Master\Default Flyout Menu 2.jpg
res\icons\Windows Master\Default Flyout Menu 3.jpg
res\icons\Windows Master\Main.ico
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
sFileInstalls .= "FileInstall, License.txt, License.txt, 1`n"
sFileInstalls .= "FileInstall, ReadMe.txt, ReadMe.txt, 1`n"
sFileInstalls .= "`t; Dependencies`n"
/*
	1. msvcp120.dll -- Beacuse Leap Forwarder is compiled with Visual Studio 2013.
	2. msvcr120.dll -- Beacuse Leap Forwarder is compiled with Visual Studio 2013.
	3. msvcr100.dll -- Beacuse AutoHotkey_H is compiled with Visual Studio 2010.
	4. Leap.dll -- Because every app needs to include its own copy. See https://community.leapmotion.com/t/resolved-c-how-to-make-app-load-leap-dll-from-core-services-folder/939/2
*/
sFileInstalls .= "FileInstall, msvcp120.dll, msvcp120.dll, 1`n"
sFileInstalls .= "FileInstall, msvcr120.dll, msvcr120.dll, 1`n"
sFileInstalls .= "FileInstall, msvcr100.dll, msvcr100.dll, 1`n"
sFileInstalls .= "FileInstall, Leap.dll, Leap.dll, 1"

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