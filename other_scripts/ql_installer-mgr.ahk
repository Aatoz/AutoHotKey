; Quick Launcher Installer/Updater

; TODO: Don't remind me again, feature!

if (!FileExist("Master Commands.txt"))
	Install()

	SetTimer, CheckForUpdate, 300000 ; Check every 5 minutes

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
Install()
{
	FileSelectFolder, sDir, , 3, Choose where you want to install this application:
	FileMove, ql.exe, %sDir%\ql.exe
	FileMove, background.jpg, %sDir%\background.jpg
	FileCopy, ql_installer-mgr.exe, %sDir%\ql_installer-mgr.exe

	; Create the config.ini file.
	FileAppend,
	(
; This is the config file!
[QLauncher]
X=0
Y=880
W=Expr:A_ScreenWidth
H=200
Background="background.jpg"
Font=""
[Flyout]
X=Expr:Floor(A_ScreenWidth * .33)
Y=Expr:A_ScreenHeight - 165 - 200 ; iH = 165 iAnchorAt = 200
W=800
H=165
AnchorAt=200
MaxWidth=800
WidthFactor=20
MaxHeight=10
HeightFactor=33
Background="background.jpg"
Font="Consolas"
	)
	, %sDir%\config.ini

	; Creat Master commands file.
	FileAppend,
	(
; This is the Master Commands file!
; The format is like this:
; Shortcut	Command
; Shortcuts are *not* case-sensitive.
; Examples:
Downloads%A_Tab%C:\Users\%A_UserName%\Downloads
Comp	::{20D04FE0-3AEA-1069-A2D8-08002B30309D}
Network	::{208d2c60-3aea-1069-a2d7-08002b30309d}
Rbin	::{645FF040-5081-101B-9F08-00AA002F954E}
CtrlPan	::{20D04FE0-3AEA-1069-A2D8-08002B30309D}\::{21EC2020-3AEA-1069-A2DD-08002B30309D}
Regedit	C:\Windows\regedit.exe
; You can call functions, too.
; EmptyRBin	EmptyRecycleBin()
	)
	, %sDir%\Master Commands.txt
	ExitApp
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
CheckForUpdate:
{
	if (!FileExist("ql.exe"))
		return

	; TODO: For upload, only.
	bIsAdmin := FileExist("other_scripts/Update/admin.ini")
	if (bIsAdmin)
	{
		sStartingDir = Users/Scripts/
		IniRead, sPwd, other_scripts/Update/admin.ini, Credentials, pwd
		IniRead, sUser, other_scripts/Update/admin.ini, Credentials, user
	}

	; Get creation date of file on server.
	;~ sResponse := URLDownloadToVar("") ; TODO: Download from AHK FTP or github
	sQLFileKey = <a href="ql.exe">ql.exe
	sServerModDtKeyBeg = <td align="right">
	sServerModDtKeyEnd = </td><td align="right">
	Loop, Parse, sResponse, `r`n
	{
		if (InStr(A_LoopField, sQLFileKey))
		{
			s := SubStr(A_LoopField, InStr(A_LoopField, sQLFileKey)+StrLen(sQLFileKey))
			sServerModDt := SubStr(s, InStr(s, sServerModDtKeyBeg)+StrLen(sServerModDtKeyBeg))
			sServerModDt := SubStr(sServerModDt, 1, InStr(sServerModDt, ":")+2)
		}
	}

	FileGetTime, sClientCreationDt , ql.exe, C
	FormatTime, sClientCreationDt, %sClientCreationDt%, dd-MMM-yyyy H:m
	if (sClientCreationDt < sServerModDt)
	{ ; Retrieve the file off of the Server
		;~ UrlDownloadToFile,  TODO: Download from AHK FTP or github

		if (bIsAdmin) ; Upload the new file.
			b = true ; TODO: FTPUploadFile(RetVal, sStartingDir, sPwd, sUser, RetVal, false)
		else
		{
			Msgbox, 3,, An update is available for the Quick Launcher.`nDo you want to update it now?`n(Note, the update requires a restart of the application, and this will automatically be performed.)
			IfMsgBox No
				return

			; Close. No harm if done if it is already closed.
			Process, Close, ql.exe
			FileMove, server_ql.exe, ql.exe
			if (!ErrorLevel)
				Msgbox Successfully updated the Quick Launcher! Re-launching.
			Process, Wait, ql.exe
		}
	}

	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
UrlDownloadToVar(URL)
{
	WebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	WebRequest.Open("GET", URL)
	WebRequest.Send()
	Response := WebRequest.ResponseText
	WebRequest :=
	StringReplace, Response, Response, `r`n, , All
	Trim(Response, A_Space)

	return Response
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
