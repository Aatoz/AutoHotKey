#SingleInstance Force

; TODO: licenses

sFilesToInclude := "
(
res\Icons\Leap.ico
res\icons\Bunch of Bluish\Exit.ico
res\icons\Bunch of Bluish\Save2.ico
res\icons\Bunch of Bluish\Save As.ico
res\icons\Bunch of Bluish\Info.ico
res\icons\Free Blue Buttons\Measure.ico
res\Icons\I Like Buttons\Red.ico
res\Icons\Orb\Add.ico
res\Icons\Orb\Delete.ico
)"

; Load all files into memory to be placed in thread.
SetWorkingDir, % A_AhkDir()

; Begin version number
sDir := A_ScriptDir
FileRead, iVersion, %sDir%\version
if (iVersion)
	iVersion += 0.01
else iVersion := 1.0
FileDelete, %sDir%\version
FileAppend, %iVersion%, %sDir%\version

sFileInstalls .= "; v" iVersion "`n"
; End verion number

Loop, Parse, sFilesToInclude, `n
{
	;Save files to tmp folder
	if (FileExist(A_LoopField))
	{
		; Extract just the filename
		StringSplit, aFileName, A_LoopField, \
		sFileName := aFileName%aFileName0%

		StringReplace, sFileName, sFileName, Save2, Save
		StringReplace, sFileName, sFileName, Measure, Config

		; Copy the file over to images folder
		sFileInstalls .= "FileInstall, AutoLeap\" sFileName ", AutoLeap\" sFileName ", 1`n"
		FileCopy, %A_LoopField%, %A_ScriptDir%\%sFileName%, 1
	}
	else FileError()
}

sFileInstalls .= "`; License and other help files.`n"
sFileInstalls .= "FileInstall, version, version, 1`n"
sFileInstalls .= "FileInstall, License.txt, License.txt, 1`n"
sFileInstalls .= "FileInstall, ReadMe.txt, ReadMe.txt, 1`n"
sFileInstalls .= "FileInstall, msvcp120.dll, msvcp120.dll, 1`n"
sFileInstalls .= "FileInstall, msvcr120.dll, msvcr120.dll, 1"

clipboard := sFileInstalls
Msgbox Done! List of FileInstalls are on the clipboard.`n`n%sFileInstalls%
return

FileError()
{
	Msgbox 8192,, Error: Include file %A_WorkingDir%\%A_LoopField% does not exist.
	ExitApp
}