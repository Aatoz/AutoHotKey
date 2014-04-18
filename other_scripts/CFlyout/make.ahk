#SingleInstance Force

sFilesToInclude := "
(
lib\class_EasyIni.ahk
other_scripts\CFlyout\CFlyout.ahk
lib\DynaRun.ahk
lib\Dlg.ahk
lib\DynaExpr.ahk
lib\Fnt.ahk
lib\LV_Colors.ahk
lib\St.ahk
lib\Str.ahk
lib\WAnim.ahk
)"

; Load all files into memory to be placed in thread.
sTmpDir := A_ScriptDir "\CFMH_TEMP"
SetWorkingDir, % A_AhkDir()

FileRemoveDir, %sTmpDir%, 1
FileCreateDir, %sTmpDir%

Loop, Parse, sFilesToInclude, `n
{ ;Save files to tmp folder
	if (FileExist(A_LoopField))
	{
		; Read the file into memory
		FileRead, sFile, %A_LoopField%
		; Extract just the filename
		StringSplit, aFileName, A_LoopField, \
		sFileName := aFileName%aFileName0%
		; Save the file to the tmp directory
		FileAppend, %sFile%, %sTmpDir%\%sFileName%
		; For dynamically iterating through file names
		FileAppend, %sFileName%`n, %sTmpDir%\FileNames.txt
	}
	else
	{
		Msgbox 8192,, Error: Include file %A_WorkingDir%\%A_LoopField% does not exist.
		return
	}
}

DllPackFiles(sTmpDir, A_ScriptDir "\CFMH_res.dll")
DllRead(pFile, A_ScriptDir "\CFMH_res.dll", "FILES", "FileNames.txt")
Msgbox % StrGet(&pFile, "")

FileRemoveDir, %sTmpDir%, 1
return

#include <DllPack>