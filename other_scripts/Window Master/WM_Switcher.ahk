;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	***Window Master Switcher App***

	Ensures the following dependencies are present:
		1. msvcp120.dll -- Beacuse Leap Forwarder is compiled with Visual Studio 2013.
		2. msvcr120.dll -- Beacuse Leap Forwarder is compiled with Visual Studio 2013.
		3. msvcr100.dll -- Beacuse AutoHotkey_H is compiled with Visual Studio 2010.
*/
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#SingleInstance Force

aDependencies := ["msvcp120.dll", "msvcr120.dll", "msvcr100.dll"]

; Windows Master unconditionally installs these files, so we will delete these files if they are unnecessary.
for i, sFile in aDependencies
{
	if (FileExist(A_WinDir "\system32\" sFile))
		FileDelete, %sFile%
}

Run, Windows Master.exe
ExitApp