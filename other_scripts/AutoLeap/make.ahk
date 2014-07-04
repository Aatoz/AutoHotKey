#SingleInstance Force
SetFormat, float, 4.2

sFilesToInclude := "
(
res\Icons\Leap.ico
res\icons\Bunch of Bluish\Exit.ico
res\icons\Bunch of Bluish\Save2.ico
res\icons\Bunch of Bluish\Save As.ico
res\icons\Bunch of Bluish\Info.ico
res\icons\Free Blue Buttons\Measure.ico
res\icons\Free Blue Buttons\Download.ico
res\icons\Free Blue Buttons\Rotate 3D.ico
res\Icons\I Like Buttons\Red.ico
res\Icons\Orb\Add.ico
res\Icons\Orb\Delete.ico
msvcr100.dll
)"

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
	else FileError(A_WorkingDir "\" A_LoopField)
}

; Copy over exes and dlls.
aBinaries := ["M:\Documents\Visual Studio\Leap Forwarder\Release\Leap Forwarder_32.exe"
	, "M:\Documents\Visual Studio\Leap Forwarder\Release\Leap.dll"
	, "M:\Documents\Visual Studio\Leap Forwarder\x64\Release\Leap Forwarder_64.exe"
	, "M:\Documents\Visual Studio\Leap Forwarder\x64\Release\Leap.dll"]
for i, sFullFilePath in aBinaries
{
	if (!FileExist(sFullFilePath))
		FileError(sFullFilePath)

	; Extract just the filename
	StringSplit, aFileName, sFullFilePath, \
	sFileName := aFileName%aFileName0%
	if (sFileName = "Leap.dll")
	{
		sPrevFile := aBinaries[i-1]
		s32_64 := SubStr(sPrevFile, InStr(sPrevFile, "_"), 3)
		StringReplace, sFileName, sFileName, Leap, Leap%s32_64%
	}

	FileCopy, %sFullFilePath%, %A_ScriptDir%\%sFileName%, 1
}
sFileInstalls .= "`; License and other help files.`n"
sFileInstalls .= "FileInstall, AutoLeap\version, AutoLeap\version, 1`n"
sFileInstalls .= "FileInstall, AutoLeap\License.txt, AutoLeap\License.txt, 1`n"
sFileInstalls .= "FileInstall, AutoLeap\ReadMe.txt, AutoLeap\ReadMe.txt, 1`n"
sFileInstalls .= "`n`; Exes and dependencies`n"
/*
	1. msvcp120.dll -- Beacuse Leap Forwarder is compiled with Visual Studio 2013.
	2. msvcr120.dll -- Beacuse Leap Forwarder is compiled with Visual Studio 2013.
	3. Leap.dll -- Because every app needs to include its own copy. See https://community.leapmotion.com/t/resolved-c-how-to-make-app-load-leap-dll-from-core-services-folder/939/2
			Note: Dlls will be renamed based upon 32bit or 64bit build.
*/
sFileInstalls .= "FileInstall, AutoLeap\Leap Forwarder_32.exe, AutoLeap\Leap Forwarder_32.exe, 1`n"
sFileInstalls .= "FileInstall, AutoLeap\Leap Forwarder_64.exe, AutoLeap\Leap Forwarder_64.exe, 1`n"
sFileInstalls .= "FileInstall, AutoLeap\Leap_32.dll, AutoLeap\Leap_32.dll, 1`n"
sFileInstalls .= "FileInstall, AutoLeap\Leap_64.dll, AutoLeap\Leap_64.dll, 1`n"
sFileInstalls .= "FileInstall, AutoLeap\msvcr120.dll, AutoLeap\msvcr120.dll, 1`n"
sFileInstalls .= "FileInstall, AutoLeap\msvcr120.dll, AutoLeap\msvcr120.dll, 1"

clipboard := sFileInstalls
Msgbox Done! List of FileInstalls are on the clipboard.`n`n%sFileInstalls%
return

FileError(sFile)
{
	Msgbox 8192,, Error: Include file %sFile% does not exist.
	ExitApp
}