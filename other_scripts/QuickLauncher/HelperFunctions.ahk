;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Remote Desktop
RDLaunch(sInput)
{
	global g_aComputers
	global g_aDomainNames
	global g_aTypePrefixes
	LoadFromServerDatabase(g_aComputers, g_aDomainNames, g_aTypePrefixes)

	; Extract Computer name from v: parameter.
	ComputerStartPos := InStr(sInput, "v:")
	if (ComputerStartPos == 0)
	{
		; TODO: Gracefully allow a retry
		Msgbox Error! No computer name specified.`nSpecify a computer name with the following syntax: " v:ComputerNameOrAlias "`nStr:`t%sInput%
		return false
	}
	else ComputerStartPos := ComputerStartPos+2
	; Find the next parameter keyed off of ":" and use that as ComputerEndPos
	Pos1 := InStr(sInput, "w:", false, ComputerStartPos) ; CaseSensitive = false
	Pos2 := InStr(sInput, "h:", false, ComputerStartPos)
	ComputerEndPos := Pos2 > Pos1 ? Pos1 : Pos2
	if (ComputerEndPos != 0)
		ComputerEndPos := ComputerEndPos-1
	else ComputerEndPos := StrLen(sInput)+1 ; The only parameter specified was "v:".

	Computer := SubStr(sInput, ComputerStartPos, ComputerEndPos-ComputerStartPos)
	; Msgbox %Computer%`n%ComputerStartPos%`n%ComputerEndPos%

	Trim(Computer, A_Space)
	StringUpper, Computer, Computer
	; Allow direct addresses (e.g. MyServer.MyDomain.org:3520)
	; Limitation: No Computer aliases can be specified with a period " . "

	bMappedComputerToDomainName := true
	if (!(InStr(Computer, ".com") || InStr(Computer, ".org") || InStr(Computer, ".net")))
	{
		; Lookup Server Domain Name based on Computer name/alias.
		bMappedComputerToDomainName := false
		Loop, % g_aComputers.MaxIndex()
		{
			vCurComputer := g_aComputers[A_Index]
			StringUpper, vCurComputer, vCurComputer

			vCurDomainName := g_aDomainNames[A_Index]
			StringUpper, vCurDomainName, vCurDomainName

			vCurTypePrefix := g_aTypePrefixes[A_Index]
			StringUpper, vCurTypePrefix, vCurTypePrefix

			; Msgbox Computer_%Computer%`nvCurComputer_%vCurComputer%`nIndex:%A_Index%
			if (Computer == vCurComputer)
			{
				Computer := vCurDomainName
				bMappedComputerToDomainName := true
				break
			}
		}
	}
	if (!bMappedComputerToDomainName && !InStr(Computer, "."))
	{
		Msgbox Computer name, "%Computer%" was not found in the Server Names database.
		return false
	}

	; Width
	IfInString, sInput, W:
	{
		WStartPos := InStr(sInput, "W:")+2 ; CaseSensitive = false
		W := SubStr(sInput, WStartPos, 4)
		Trim(W, A_Space)
	}
	else W := 1280
	; Height
	IfInstring, sInput, H:
	{
		HStartPos := InStr(sInput, "H:")+2 ; CaseSensitive = false
		H := SubStr(sInput, HStartPos, 4)
		Trim(H, A_Space)
	}
	else H := 850
	Run mstsc.exe /w:%W% /h:%H% /v:%Computer%
	return true
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; MSDN search
MSDN(sSearch)
{
	StringReplace, sSearch, sSearch, +, `%2B, All
	StringReplace, sSearch, sSearch, :, `%3A, All
	return Run("http://social.msdn.microsoft.com/Search/en-US?query=" sSearch "&emptyWatermark=true&ac=4", "", "UseErrorLevel")
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Web search
WS(sPhrase, sEngine = "Google")
{
	; Replace + with web syntax for +
	; %2B = +
	StringReplace, sPhrase, sPhrase, +, `%2B, All

	; Replace {SPACE} with +
	StringReplace, sPhrase, sPhrase, %A_Space%, +, All

	if (sEngine = "Bing")
		return Run("http://www.bing.com/search?q=" sPhrase "&qs=n&form=QBLH&pq=" sPhrase "&sc=8-11&sp=-1&sk=", "", "UseErrorLevel")
	else if (sEngine = "Google")
		return Run("https://www.google.com/search?sclient=psy-ab&hl=en&site=&source=hp&q=" sPhrase "&btnG=Search", "", "UseErrorLevel")
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Web Page
WWW(sWebsite)
{
	if (SubStr(sWebsite, 1, 4) != "www." && SubStr(sWebsite, 1, 4) != "http")
		sWebsite := "www." sWebsite

	return Run(sWebsite, "", "UseErrorLevel")
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: AHK
		Purpose: Lookup AutoHotKey command sCmd at AutoHotKey.com
	Parameters
		sCmd: AutoHotKey command.
*/
AHK(sCmd)
{
	return Run("https://autohotkey.com/docs/commands/" sCmd ".htm", "", "UseErrorLevel")
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
Reload()
{
	Reload
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
ExitApp()
{
	if (Msgbox_YesNo("Are you sure you want to exit Quick Launcher?", "Exit Quick Launcher?"))
		ExitApp

	return true
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
RestartComputer()
{
	if (Msgbox_YesNo("Are you sure you want to restart your computer?", "Restart Computer?"))
		Shutdown, 6

	return true
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
EditFlyout()
{
	global g_vGUIFlyout

	; We are going to reload...
	QL_Hide()

	Suspend ; the below function will reload on exit
	g_vGUIFlyout.GUIEditSettings("", "", true)

	return true
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: EditLauncHK
		Purpose: Change the hotkey which launches the Quick Launcher
	Parameters
		
*/
EditLaunchHK()
{
	global

	static s_iMSDNStdBtnW := 75
	static s_iMSDNStdBtnH := 23
	static s_iMSDNStdBtnSpacing := 6

	GUI, EditHKDlg_:New
	GUI, Add, Text, xm ym w100 r1, Hotkey:
	GUI, Add, Hotkey, xm yp+20 wp vg_vHotkey, %g_sQLHotkey%

	GUIControlGet, iGUI_, Pos, g_vHotkey

	local iBtnEdge := iGUI_X+8
	local iCancelX := (iGUI_X+iGUI_W)-iBtnEdge
	local iOKX := iCancelX-(s_iMSDNStdBtnW+s_iMSDNStdBtnSpacing)
	; Note: no hotkeys since this is a hotkey dialog!
	GUI, Add, Button, % "x" iOKX " yp+" iGUI_H+(s_iMSDNStdBtnSpacing*2) " w" s_iMSDNStdBtnW " h" s_iMSDNStdBtnH " gEditHKDlg_GUISubmit", OK
	GUI, Add, Button, x%iCancelX% yp wp hp gEditHKDlg_GUIClose, Cancel

	GUI, Show
	return true

	EditHKDlg_GUISubmit:
	{
		GUI, EditHKDlg_:Default
		g_vHotkey := GUIControlGet("", "g_vHotkey")

		; Disable old hotkey
		Hotkey, IfWinExist
			Hotkey, %g_sQLHotkey%, Off
		; Enable new hotkey
		Hotkey, IfWinExist
			Hotkey, %g_vHotkey%, QL_Show
			Hotkey, %g_vHotkey%, On

		; Save new settings.
		g_sQLHotkey := g_vHotkey
		g_ConfigIni.QLauncher.Hotkey := g_sQLHotkey
		g_ConfigIni.Save()

		; fall through
	}
	EditHKDlg_GUIClose:
	{
		GUI, EditHKDlg_:Destroy
		return
	}

}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: DoFileInstalls()
		Purpose: Encapsulate FileInstall prerequisites
	Parameters
		
*/
DoFileInstalls()
{
	if (!FileExist("images"))
		FileCreateDir, images
	; Images.
	FileInstall, images\background.jpg, images\background.jpg, 1
	FileInstall, images\background.jpg, images\background.jpg, 1
	; License and other help files.
	FileInstall, License.txt, License.txt, 1
	FileInstall, ReadMe.txt, ReadMe.txt, 1
	; Dependencies
	FileInstall, AddShortcutToQL.exe, AddShortcutToQL.exe, 1
	FileInstall, msvcr100.dll, msvcr100.dll, 1

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: AddContextMenuToRegistry
		Purpose:
	Parameters
		
*/
AddContextMenuToRegistryIfNeeded()
{
	; Is the key needed?
	RegRead, sTest, HKCR, *\shell\Add shortcut to Quick Launcher\command
	if (!ErrorLevel)
		return false ; key exists

	sPath := A_WorkingDir "\AddShortcutToQL.exe"
	RegWrite, REG_SZ, HKCR, *\shell\Add shortcut to Quick Launcher\command,, %sPath% "AddCmd=`%1"
	RegWrite, REG_SZ, HKCR, Directory\shell\Add shortcut to Quick Launcher\command,, %sPath% "AddCmd=`%1"

	; For debugging purposes.
	bDelete := false
	if (bDelete)
	{
		RegDelete, HKLM, *\shell\Add shortcut to Quick Launcher\command
		RegDelete, HKLM, Directory\shell\Add shortcut to Quick Launcher\command
	}

	return true
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: SaveDefaultCmdsToMasterIni
		Purpose: There's a default list of commands I think are useful. We load them into Master.ini
	Parameters
		
*/
SaveDefaultCmdsToMasterIni()
{
	global g_MasterIni

	g_MasterIni.Merge(new EasyIni("", GetDefaultIni()))
	g_MasterIni.Save()

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: SaveDefaultCmdsToMasterIni
		Purpose: I interactively test all the commands here. The ones that work get saved.
	Parameters
		
*/
Internal_SaveDefaultCmdsToMasterIni()
{
	global g_MasterIni

	vDefaultIniRaw := new EasyIni("", GetDefaultIniRaw())
	for sCmd, sAction in vDefaultIniRaw.Commands
	{
		; Don't overwrite existing keys!
		if (g_RecentIni.HasKey(sCmd))
			continue
		; Test the command. If it works, save it. If it doesn't, don't.
		sNewAction := "shell:" sAction
		if (Run(sNewAction, "", "UseErrorLevel"))
		{
			WinClose, A
			Msgbox
			g_MasterIni[sCmd] := {Func:"Run", Parms: sNewAction}
		}
	}

	g_MasterIni.Save()
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

GetDefaultConfigIni()
{
	return "
	(LTrim
		[QLauncher]
		Hotkey=!+e
		Background=images\background.jpg
		Font=
		H=175
		SubmitSelectedIfNoMatchFound=true
		W=Expr:A_ScreenWidth
		X=0
		Y=Expr:A_ScreenHeight - 175

		[Variables]
		OfficialSourceDir=Z:\Source
		INVDBDir=C:\Invtools\Databases
		LocationOfInvest=C:\Invtools\Databases\PFO\Invest.exe
	)"
}

GetDefaultFlyoutConfigIni()
{
	return "
	(LTrim
		[Flyout]
		AnchorAt=175
		Background=images\background.jpg
		Font=Arial, s18 c000000
		FontColor=0x48A4FF
		MaxRows=10
		W=800
		X=Expr:Floor((A_ScreenWidth - 800) / 2)
		Y=Expr:A_ScreenHeight - 165 - 175 ; iH = 165 iAnchorAt = 175
		ReadOnly=0
		ShowInTaskbar=false
		AlwaysOnTop=1
		ExitOnEsc=false
	)"
}

GetSpecialCmdsIni()
{
	return "
	(LTrim
		[Commands]
		run=Run
		d=Run
		WS=Web Search
		WWW=Website
		AHK=AutoHotKey
		RD=Remote Desktop
		ex=Expression
		i=Invest
		ca=Catalog
		[[=CLS Lookup
		PC=PC Scan
		QD=QD PC Scan
		cmds=View all saved commands
		int=Internal Function

		; The functions below are found in this file (or else in std lib). Just remember to add the actual function here when you make new ones.
		[Run]
		Func=Run
		Desc=Open a file or folder
		[d]
		Func=Run
		Desc=Open a folder
		[WS]
		Func=WS
		Desc=Search the web
		[WWW]
		Func=WWW
		Desc=Open a website (can exclude ""www."" prefix)
		[RD]
		Func=RDLaunch
		Desc=Remote Desktop session
		[AHK]
		Func=AHK
		Desc=Lookup AutoHotKey command
		[ex]
		Func=DynaExpr_Eval
		Desc=Eval AutoHotKey expression
		[i]
		Func=InvLaunch
		Desc=Open an Invtools system
		[ca]
		Func=LaunchCatalog
		Desc=Open an Invtools catalog
		[[[]
		Func=CLSLookup
		Desc=Open any type of CLS page
		[PC]
		Func=PCScan
		Desc=Scan product changes
		[QD]
		Func=QDPCScan
		Desc=Scan queued product changes
		[cmds]
		Desc=View all saved commands
		Func=InternalCmd
		[int]
		Desc=Run an internal command
		Func=InternalCmd
	)"
}

; These commands were tested and worked, at least on my computer.
GetDefaultIni()
{
	return "
	(LTrim
		; { Internal Commands }
		[int:Exit App (Quit)]
		Func=ExitApp
		Parms=
		[int:Reload App]
		Func=Reload
		Parms=
		[int:Mute/Unmute Volume]
		Func=DynaExpr_Eval
		Parms=Send {Volume_Mute}
		[int:Change Launch Hotkey]
		Func=EditLaunchHK
		Parms=
		[int:Restart Computer]
		Func=RestartComputer
		Parms=
		[int:Hibernate Computer]
		Func=DynaExpr_Eval
		Parms=DllCall(""PowrProf\SetSuspendState"", ""int"", 1, ""int"", 1, ""int"", 0)
		[int:Sleep Computer]
		Func=DynaExpr_Eval
		Parms=DllCall(""PowrProf\SetSuspendState"", ""int"", 0, ""int"", 1, ""int"", 0)
		[int:Edit Flyout]
		Func=EditFlyout
		[int:Set Invtools Database Paths]
		Func=SetInvPaths
		[Startup]
		Func=Run
		Parms=C:\Users\" A_UserName "\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup

		; { CLSIDS }
		[My Computer]
		Func=Run
		Parms=shell:::{20d04fe0-3aea-1069-a2d8-08002b30309d}
		[My Documents]
		Func=Run
		Parms=shell:::{450D8FBA-AD25-11D0-98A8-0800361B1103}
		[My Network Places]
		Func=Run
		Parms=shell:::{208d2c60-3aea-1069-a2d7-08002b30309d}
		[Network Connections]
		Func=Run
		Parms=shell:::{7007ACC7-3202-11D1-AAD2-00805FC1270E}
		[Printers and Faxes]
		Func=Run
		Parms=shell:::{2227a280-3aea-1069-a2de-08002b30309d}
		[Recycle Bin]
		Func=Run
		Parms=shell:::{645FF040-5081-101B-9F08-00AA002F954E}
		[Favorites]
		Func=Run
		Parms=shell:::{323CA680-C24D-4099-B94D-446DD2D7249E}
		[Libraries]
		Func=Run
		Parms=shell:::{031E4825-7B94-4dc3-B131-E946B44C8DD5}
		[System]
		Func=Run
		Parms=shell:::{BB06C0E4-D293-4f75-8A90-CB05B6477EEE}
		[User Pinned]
		Func=Run
		Parms=shell:::{1f3427c8-5c10-4210-aa03-2ee45287d668}
		[Add Network Location]
		Func=Run
		Parms=shell:::{D4480A50-BA28-11d1-8E75-00C04FA31A86}
		[Administrative Tools]
		Func=Run
		Parms=shell:::{D20EA4E1-3957-11d2-A40B-0C5020524153}
		[AutoPlay]
		Func=Run
		Parms=shell:::{9C60DE1E-E5FC-40f4-A487-460851A8D915}
		[Bluetooth Devices]
		Func=Run
		Parms=shell:::{28803F59-3A75-4058-995F-4EE5503B023C}
		[Color Management]
		Func=Run
		Parms=shell:::{B2C761C6-29BC-4f19-9251-E6195265BAF1}
		[Command Folder]
		Func=Run
		Parms=shell:::{437ff9c0-a07f-4fa0-af80-84b6c6440a16}
		[Common Places FS Folder]
		Func=Run
		Parms=shell:::{d34a6ca6-62c2-4c34-8a7c-14709c1ad938}
		[Control Panel]
		Func=Run
		Parms=shell:::{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}
		[Control Panel (All Tasks)]
		Func=Run
		Parms=shell:::{ED7BA470-8E54-465E-825C-99712043E01C}
		[Control Panel (always Category view)]
		Func=Run
		Parms=shell:::{26EE0668-A00A-44D7-9371-BEB064C98683}
		[Control Panel (always Icons view)]
		Func=Run
		Parms=shell:::{21EC2020-3AEA-1069-A2DD-08002B30309D}
		[Credential Manager]
		Func=Run
		Parms=shell:::{1206F5F1-0569-412C-8FEC-3204630DFB70}
		[Date and Time]
		Func=Run
		Parms=shell:::{E2E7934B-DCE5-43C4-9576-7FE4F75E7480}
		[Default Programs]
		Func=Run
		Parms=shell:::{17cd9488-1228-4b2f-88ce-4298e93e0966}
		[delegate folder that appears in Computer]
		Func=Run
		Parms=shell:::{b155bdf8-02f0-451e-9a26-ae317cfd7779}
		[Device Manager]
		Func=Run
		Parms=shell:::{74246bfc-4c96-11d0-abef-0020af6b0b7a}
		[Devices and Printers]
		Func=Run
		Parms=shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}
		[Display]
		Func=Run
		Parms=shell:::{C555438B-3C23-4769-A71F-B6D3D9B6053A}
		[Ease of Access Center]
		Func=Run
		Parms=shell:::{D555645E-D4F8-4c29-A827-D93C859C4F2A}
		[Family Safety]
		Func=Run
		Parms=shell:::{96AE8D84-A250-4520-95A5-A47A7E3C548B}
		[File Explorer Options]
		Func=Run
		Parms=shell:::{6DFD7C5C-2451-11d3-A299-00C04F8EF6AF}
		[Font Settings]
		Func=Run
		Parms=shell:::{93412589-74D4-4E4E-AD0E-E0CB621440FD}
		[Fonts (folder)]
		Func=Run
		Parms=shell:::{BD84B380-8CA2-1069-AB1D-08000948F534}
		[Games Explorer]
		Func=Run
		Parms=shell:::{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}
		[Get Programs]
		Func=Run
		Parms=shell:::{15eae92e-f17a-4431-9f28-805e482dafd4}
		[Help and Support]
		Func=Run
		Parms=shell:::{2559a1f1-21d7-11d4-bdaf-00c04f60b9f0}
		[HomeGroup (settings)]
		Func=Run
		Parms=shell:::{67CA7650-96E6-4FDD-BB43-A8E774F73A57}
		[HomeGroup (users)]
		Func=Run
		Parms=shell:::{B4FB3F98-C1EA-428d-A78A-D1F5659CBA93}
		[Indexing Options]
		Func=Run
		Parms=shell:::{87D66A43-7B11-4A28-9811-C86EE395ACF7}
		[Infared (if installed)]
		Func=Run
		Parms=shell:::{A0275511-0E86-4ECA-97C2-ECD8F1221D08}
		[Installed Updates]
		Func=Run
		Parms=shell:::{d450a8a1-9568-45c7-9c0e-b4f9fb4537bd}
		[Internet Options (Internet Explorer)]
		Func=Run
		Parms=shell:::{A3DD4F92-658A-410F-84FD-6FBBBEF2FFFE}
		[Keyboard Properties]
		Func=Run
		Parms=shell:::{725BE8F7-668E-4C7B-8F90-46BDB0936430}
		[Location Information (Phone and Modem)]
		Func=Run
		Parms=shell:::{40419485-C444-4567-851A-2DD7BFA1684D}
		[Location Settings]
		Func=Run
		Parms=shell:::{E9950154-C418-419e-A90A-20C5287AE24B}
		[Mouse Properties]
		Func=Run
		Parms=shell:::{6C8EEC18-8D75-41B2-A177-8831D59D2D50}
		[Network and Sharing Center]
		Func=Run
		Parms=shell:::{8E908FC9-BECC-40f6-915B-F4CA0E70D03D}
		[Network (WorkGroup)]
		Func=Run
		Parms=shell:::{208D2C60-3AEA-1069-A2D7-08002B30309D}
		[Notification Area Icons]
		Func=Run
		Parms=shell:::{05d7b0f4-2121-4eff-bf6b-ed3f69b894d9}
		[Offline Files Folder]
		Func=Run
		Parms=shell:::{AFDB1F70-2A4C-11d2-9039-00C04F8EEB3E}
		[Pen and Touch]
		Func=Run
		Parms=shell:::{F82DF8F7-8B9F-442E-A48C-818EA735FF9B}
		[Personalization]
		Func=Run
		Parms=shell:::{ED834ED6-4B5A-4bfe-8F11-A626DCB6A921}
		[Portable Devices]
		Func=Run
		Parms=shell:::{35786D3C-B075-49b9-88DD-029876E11C01}
		[Power Options]
		Func=Run
		Parms=shell:::{025A5937-A6BE-4686-A844-36FE4BEC8B6D}
		[Previous Versions Results Folder]
		Func=Run
		Parms=shell:::{f8c2ab3b-17bc-41da-9758-339d7dbf2d88}
		[printhood delegate folder]
		Func=Run
		Parms=shell:::{ed50fc29-b964-48a9-afb3-15ebb9b97f36}
		[Printers]
		Func=Run
		Parms=shell:::{2227A280-3AEA-1069-A2DE-08002B30309D}
		[Programs and Features]
		Func=Run
		Parms=shell:::{7b81be6a-ce2b-4676-a29e-eb907a5126c5}
		[Public (folder)]
		Func=Run
		Parms=shell:::{4336a54d-038b-4685-ab02-99bb52d3fb8b}
		[Recent places]
		Func=Run
		Parms=shell:::{22877a6d-37a1-461a-91b0-dbda5aaebc99}
		[Recovery]
		Func=Run
		Parms=shell:::{9FE63AFD-59CF-4419-9775-ABCC3849F861}
		[Region and Language]
		Func=Run
		Parms=shell:::{62D8ED13-C9D0-4CE8-A914-47DD628FB1B0}
		[RemoteApp and Desktop Connections]
		Func=Run
		Parms=shell:::{241D7C96-F8BF-4F85-B01F-E2B043341A4B}
		[Remote Printers]
		Func=Run
		Parms=shell:::{863aa9fd-42df-457b-8e4d-0de1b8015c60}
		[Results Folder]
		Func=Run
		Parms=shell:::{2965e715-eb66-4719-b53f-1672673bbefa}
		[Run]
		Func=Run
		Parms=shell:::{2559a1f3-21d7-11d4-bdaf-00c04f60b9f0}
		[Search]
		Func=Run
		Parms=shell:::{9343812e-1c37-4a49-a12e-4b2d810d956b}
		[Search Everywhere (modern)]
		Func=Run
		Parms=shell:::{2559a1f8-21d7-11d4-bdaf-00c04f60b9f0}
		[Search Files (modern)]
		Func=Run
		Parms=shell:::{2559a1f0-21d7-11d4-bdaf-00c04f60b9f0}
		[Security and Maintenance]
		Func=Run
		Parms=shell:::{BB64F8A7-BEE7-4E1A-AB8D-7D8273F7FDB6}
		[Show Desktop]
		Func=Run
		Parms=shell:::{3080F90D-D7AD-11D9-BD98-0000947B0257}
		[Sound]
		Func=Run
		Parms=shell:::{F2DDFC82-8F12-4CDD-B7DC-D4FE1425AA4D}
		[Speech Recognition]
		Func=Run
		Parms=shell:::{58E3C745-D971-4081-9034-86E34B30836A}
		[Sync Center]
		Func=Run
		Parms=shell:::{9C73F5E5-7AE7-4E32-A8E8-8D23B85255BF}
		[Sync Setup Folder]
		Func=Run
		Parms=shell:::{2E9E59C0-B437-4981-A647-9C34B9B90891}
		[System Icons]
		Func=Run
		Parms=shell:::{05d7b0f4-2121-4eff-bf6b-ed3f69b894d9}
		[Tablet PC Settings]
		Func=Run
		Parms=shell:::{80F3F1D5-FECA-45F3-BC32-752C152E456E}
		[Taskbar and Navigation properties]
		Func=Run
		Parms=shell:::{0DF44EAA-FF21-4412-828E-260A8728E7F1}
		[Text to Speech]
		Func=Run
		Parms=shell:::{D17D1D6D-CC3F-4815-8FE3-607E7D5D10B3}
		[This PC]
		Func=Run
		Parms=shell:::{20D04FE0-3AEA-1069-A2D8-08002B30309D}
		[Troubleshooting]
		Func=Run
		Parms=shell:::{C58C4893-3BE0-4B45-ABB5-A63E4B8C8651}
		[User Accounts]
		Func=Run
		Parms=shell:::{60632754-c523-4b62-b45c-4172da012619}
		[User Accounts (netplwiz)]
		Func=Run
		Parms=shell:::{7A9D77BD-5403-11d2-8785-2E0420524153}
		[%UserProfile%]
		Func=Run
		Parms=shell:::{59031a47-3f72-44a7-89c5-5595fe6b30ee}
		[Web browser (default)]
		Func=Run
		Parms=shell:::{871C5380-42A0-1069-A2EA-08002B30309D}
		[Windows Defender]
		Func=Run
		Parms=shell:::{D8559EB9-20C0-410E-BEDA-7ED416AECC2A}
		[Windows Mobility Center]
		Func=Run
		Parms=shell:::{5ea4f148-308c-46d7-98a9-49041b1dd468}
		[Windows Features]
		Func=Run
		Parms=shell:::{67718415-c450-4f3c-bf8a-b487642dc39b}
		[Windows Firewall]
		Func=Run
		Parms=shell:::{4026492F-2F69-46B8-B9BF-5654FC07E423}
		[Windows Update]
		Func=Run
		Parms=shell:::{36eef7db-88ad-4e81-ad49-0e313f0c35f8}
	)"
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

GetDefaultIniRaw()
{
	return "
	(LTrim
		[Commands]
		; Working commands
		My Computer=::{20d04fe0-3aea-1069-a2d8-08002b30309d}
		My Documents=::{450d8fba-ad25-11d0-98a8-0800361b1103}
		My Network Places=::{208d2c60-3aea-1069-a2d7-08002b30309d}
		Network Computers=::{1f4de370-d627-11d1-ba4f-00a0c91eedba}
		Network Connections=::{7007acc7-3202-11d1-aad2-00805fc1270e}
		Printers and Faxes=::{2227a280-3aea-1069-a2de-08002b30309d}
		Recycle Bin=::{645ff040-5081-101b-9f08-00aa002f954e}
		Scheduled Tasks=::{d6277990-4c6a-11cf-8d87-00aa0060f5bf}
		AdminTools=::{724EF170-A42D-4FEF-9F26-B60E846FBA4F}
		CD Burning=::{9E52AB10-F80D-49DF-ACB8-4330F5687855}
		Common Admin Tools=::{D0384E7D-BAC3-4797-8F14-CBA229B392B5}
		Common OEM Links=::{C1BAE2D0-10DF-4334-BEDD-7AA20B227A9D}
		Common Programs=::{0139D44E-6AFE-49F2-8690-3DAFCAE6FFB8}
		Common Start Menu=::{A4115719-D62E-491D-AA7C-E74B8BE3B067}
		Common Startup=::{82A5EA35-D9CD-47C5-9629-E15D2F714E6E}
		Common Templates=::{B94237E7-57AC-4347-9151-B08C6C32D1F7}
		Contacts=::{56784854-C6CB-462b-8169-88E350ACB882}
		Cookies=::{2B0F765D-C0E9-4171-908E-08A611B84FF6}
		Desktop=::{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}
		Device Metadata Store=::{5CE4A5E9-E4EB-479D-B89F-130C02886155}
		Documents Library=::{7B0DB17D-9CD2-4A93-9733-46CC89022E7C}
		Downloads=::{374DE290-123F-4565-9164-39C4925E467B}
		Favorites=::{1777F761-68AD-4D8A-87BD-30B759FA33DD}
		Fonts=::{FD228CB7-AE11-4AE3-864C-16F3910AB8FE}
		Game Tasks=::{054FAE61-4DD8-4787-80B6-090220C4B700}
		History=::{D9DC8A3B-B784-432E-A781-5A1130A75963}
		Implicit App Shortcuts=::{BCB5256F-79F6-4CEE-B725-DC34E402FD46}
		Internet Cache=::{352481E8-33BE-4251-BA85-6007CAEDCF9D}
		Libraries=::{1B3EA5DC-B587-4786-B4EF-BD1DC332AEAE}
		Links=::{bfb9d5e0-c6a9-404c-b2b2-ae6db6af4968}
		Local App Data=::{F1B32785-6FBA-4FCF-9D55-7B8E7F157091}
		Local App Data Low=::{A520A1A4-1780-4FF6-BD18-167343C5AF16}
		Localized Resources Dir=::{2A00375E-224C-49DE-B8D1-440DF7EF3DDC}
		Music=::{4BD8D571-6D19-48D3-BE97-422220080E43}
		Music Library=::{2112AB0A-C86A-4FFE-A368-0DE96E47012E}
		NetHood=::{C5ABBF53-E17F-4121-8900-86626FC2C973}
		Original Images=::{2C36C0AA-5812-4b87-BFD0-4CD0DFB19B39}
		Photo Albums=::{69D2CF90-FC33-4FB7-9A0C-EBB0F0FCB43C}
		Pictures=::{33E28130-4E1E-4676-835A-98395C3BC3BB}
		Pictures Library=::{A990AE9F-A03B-4E80-94BC-9912D7504104}
		Playlists=::{DE92C1C7-837F-4F69-A3BB-86E631204A23}
		Print Hood=::{9274BD8D-CFD1-41C3-B35E-B13F55A758F4}
		Profile=::{5E6C858F-0E22-4760-9AFE-EA3317B67173}
		Program Data=::{62AB5D82-FDC1-4DC3-A9DD-070D1D495D97}
		Program Files=::{905e63b6-c1bf-494e-b29c-65b732d3d21a}
		Program Files Common=::{F7F1ED05-9F6D-47A2-AAAE-29D317C6F066}
		Program Files Common (x64)=::{6365D5A7-0F0D-45E5-87F6-0DA56B6A4F7D}
		Program Files Common (x86)=::{DE974D24-D9C6-4D3E-BF91-F4455120B917}
		Program Files (x64)=::{6D809377-6AF0-444b-8957-A3773F02200E}
		Program Files (x86)=::{7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E}
		Programs=::{A77F5D77-2E2B-44C3-A6A2-ABA601054A51}
		Public=::{DFDF76A2-C82A-4D63-906A-5644AC457385}
		Public Desktop=::{C4AA340D-F20F-4863-AFEF-F87EF2E6BA25}
		Public Documents=::{ED4824AF-DCE4-45A8-81E2-FC7965083634}
		Public Downloads=::{3D644C9B-1FB8-4f30-9B45-F670235F79C0}
		Public Game Tasks=::{DEBF2536-E1A8-4c59-B6A2-414586476AEA}
		Public Libraries=::{48DAF80B-E6CF-4F4E-B800-0E69D84EE384}
		Public Music=::{3214FAB5-9757-4298-BB61-92A9DEAA44FF}
		Public Pictures=::{B6EBFB86-6907-413C-9AF7-4FC2ABF07CC5}
		Public Ringtones=::{E555AB60-153B-4D17-9F04-A5FE99FC15EC}
		Public Videos=::{2400183A-6185-49FB-A2D8-4A392A602BA3}
		Quick Launch=::{52a4f021-7b75-48a9-9f6b-4b87a210bc8f}
		Recent=::{AE50C081-EBD2-438A-8655-8A092E34987A}
		Recorded TV Library=::{1A6FDBA2-F42D-4358-A798-B74D745926C5}
		Resource Dir=::{8AD10C31-2ADB-4296-A8F7-E4701232C972}
		Ringtones=::{C870044B-F49E-4126-A9C3-B52A1FF411E8}
		Roaming App Data=::{3EB685DB-65F9-4CF6-A03A-E3EF65729F3D}
		Sample Music=::{B250C668-F57D-4EE1-A63C-290EE7D1AA1F}
		Sample Pictures=::{C4900540-2379-4C75-844B-64E6FAF8716B}
		Sample Playlists=::{15CA69B3-30EE-49C1-ACE1-6B5EC372AFB5}
		Sample Videos=::{859EAD94-2E85-48AD-A71A-0969CB56A6CD}
		Saved Games=::{4C5C32FF-BB9D-43b0-B5B4-2D72E54EAAA4}
		Saved Searches=::{7d1d3a04-debb-4115-95cf-2f29da2920da}
		Send To=::{8983036C-27C0-404B-8F08-102D10DCFD74}
		Sidebar Default Parts=::{7B396E54-9EC5-4300-BE0A-2482EBAE1A26}
		Sidebar Parts=::{A75D362E-50FC-4fb7-AC2C-A8BEAA314493}
		Start Menu=::{625B53C3-AB48-4EC1-BA1F-A1EF4146FC19}
		Startup=::{B97D20BB-F46A-4C97-BA10-5E3608430854}
		System=::{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}
		System (x86)=::{D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27}
		Templates=::{A63293E8-664E-48DB-A079-DF759E0509F7}
		User Pinned=::{9E3995AB-1F9C-4F13-B827-48B24B6C7174}
		User Profiles=::{0762D272-C50A-4BB0-A382-697DCD729B80}
		User ProgramFiles=::{5CD7AEE2-2219-4A67-B85D-6C9CE15660CB}
		User Program Files Common=::{BCBD3057-CA5C-4622-B42D-BC56DB0AE516}
		Videos=::{18989B1D-99B5-455B-841C-AB7C74E4DDFC}
		Videos Library=::{491E922F-5643-4AF4-A7EB-4E7A138D8174}
		Windows=::{F38BF404-1D43-42F2-9305-67DE0B28FC23}
		Add Network Location=::{D4480A50-BA28-11d1-8E75-00C04FA31A86}
		Administrative Tools=::{D20EA4E1-3957-11d2-A40B-0C5020524153}
		Applications=::{4234d49b-0245-4df3-b780-3893943456e1}
		AutoPlay=::{9C60DE1E-E5FC-40f4-A487-460851A8D915}
		BitLocker Drive Encryption=::{D9EF8727-CAC2-4e60-809E-86F80A666C91}
		Bluetooth Devices=::{28803F59-3A75-4058-995F-4EE5503B023C}
		Color Management=::{B2C761C6-29BC-4f19-9251-E6195265BAF1}
		Command Folder=::{437ff9c0-a07f-4fa0-af80-84b6c6440a16}
		Common Places FS Folder=::{d34a6ca6-62c2-4c34-8a7c-14709c1ad938}
		Control Panel=::{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}
		Control Panel (All Tasks)=::{ED7BA470-8E54-465E-825C-99712043E01C}
		Control Panel (always Category view)=::{26EE0668-A00A-44D7-9371-BEB064C98683}
		Control Panel (always Icons view)=::{21EC2020-3AEA-1069-A2DD-08002B30309D}
		Credential Manager=::{1206F5F1-0569-412C-8FEC-3204630DFB70}
		Date and Time=::{E2E7934B-DCE5-43C4-9576-7FE4F75E7480}
		Default Programs=::{17cd9488-1228-4b2f-88ce-4298e93e0966}
		delegate folder that appears in Computer=::{b155bdf8-02f0-451e-9a26-ae317cfd7779}
		Desktop (folder)=::{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}
		Device Manager=::{74246bfc-4c96-11d0-abef-0020af6b0b7a}
		Devices and Printers=::{A8A91A66-3A7D-4424-8D24-04E180695C7A}
		Display=::{C555438B-3C23-4769-A71F-B6D3D9B6053A}
		Documents (folder)=::{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}
		Downloads (folder)=::{374DE290-123F-4565-9164-39C4925E467B}
		Ease of Access Center=::{D555645E-D4F8-4c29-A827-D93C859C4F2A}
		E-mail (default e-mail program)=	::{2559a1f5-21d7-11d4-bdaf-00c04f60b9f0}
		Family Safety=::{96AE8D84-A250-4520-95A5-A47A7E3C548B}
		Favorites=::{323CA680-C24D-4099-B94D-446DD2D7249E}
		File Explorer Options=::{6DFD7C5C-2451-11d3-A299-00C04F8EF6AF}
		File History=::{F6B6E965-E9B2-444B-9286-10C9152EDBC5}
		Font Settings=::{93412589-74D4-4E4E-AD0E-E0CB621440FD}
		Fonts (folder)=::{BD84B380-8CA2-1069-AB1D-08000948F534}
		Frequent folders=::{3936E9E4-D92C-4EEE-A85A-BC16D5EA0819}
		Games Explorer=::{ED228FDF-9EA8-4870-83b1-96b02CFE0D52}
		Get Programs=::{15eae92e-f17a-4431-9f28-805e482dafd4}
		Help and Support=::{2559a1f1-21d7-11d4-bdaf-00c04f60b9f0}
		HomeGroup (settings)=::{67CA7650-96E6-4FDD-BB43-A8E774F73A57}
		HomeGroup (users)=::{B4FB3F98-C1EA-428d-A78A-D1F5659CBA93}
		Hyper-V Remote File Browsing=	::{0907616E-F5E6-48D8-9D61-A91C3D28106D}
		Indexing Options=::{87D66A43-7B11-4A28-9811-C86EE395ACF7}
		Infared (if installed)=::{A0275511-0E86-4ECA-97C2-ECD8F1221D08}
		Installed Updates=::{d450a8a1-9568-45c7-9c0e-b4f9fb4537bd}
		Internet Options (Internet Explorer)=::{A3DD4F92-658A-410F-84FD-6FBBBEF2FFFE}
		Keyboard Properties=::{725BE8F7-668E-4C7B-8F90-46BDB0936430}
		Language settings=::{BF782CC9-5A52-4A17-806C-2A894FFEEAC5}
		Libraries=::{031E4825-7B94-4dc3-B131-E946B44C8DD5}
		Location Information (Phone and Modem)=::{40419485-C444-4567-851A-2DD7BFA1684D}
		Location Settings=::{E9950154-C418-419e-A90A-20C5287AE24B}
		Media Servers=::{289AF617-1CC3-42A6-926C-E6A863F0E3BA}
		Mouse Properties=::{6C8EEC18-8D75-41B2-A177-8831D59D2D50}
		Music (folder)=::{1CF1260C-4DD0-4ebb-811F-33C572699FDE}
		My Documents=::{450D8FBA-AD25-11D0-98A8-0800361B1103}
		Network=::{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}
		Network and Sharing Center=::{8E908FC9-BECC-40f6-915B-F4CA0E70D03D}
		Network Connections (in PC settings)			::{38A98528-6CBF-4CA9-8DC0-B1E1D10F7B1B}
		Network Connections=::{7007ACC7-3202-11D1-AAD2-00805FC1270E}
		Network (WorkGroup)=::{208D2C60-3AEA-1069-A2D7-08002B30309D}
		Notification Area Icons=::{05d7b0f4-2121-4eff-bf6b-ed3f69b894d9}
		NVIDIA Control Panel (if installed)=::{0bbca823-e77d-419e-9a44-5adec2c8eeb0}
		Offline Files Folder=::{AFDB1F70-2A4C-11d2-9039-00C04F8EEB3E}
		OneDrive=::{018D5C66-4533-4307-9B53-224DE2ED1FE6}
		Pen and Touch=::{F82DF8F7-8B9F-442E-A48C-818EA735FF9B}
		Personalization=::{ED834ED6-4B5A-4bfe-8F11-A626DCB6A921}
		Pictures (folder)=::{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}
		Portable Devices=::{35786D3C-B075-49b9-88DD-029876E11C01}
		Power Options=::{025A5937-A6BE-4686-A844-36FE4BEC8B6D}
		Previous Versions Results Folder=::{f8c2ab3b-17bc-41da-9758-339d7dbf2d88}
		printhood delegate folder=::{ed50fc29-b964-48a9-afb3-15ebb9b97f36}
		Printers=::{2227A280-3AEA-1069-A2DE-08002B30309D}
		Programs and Features=::{7b81be6a-ce2b-4676-a29e-eb907a5126c5}
		Public (folder)=::{4336a54d-038b-4685-ab02-99bb52d3fb8b}
		Quick access=::{679f85cb-0220-4080-b29b-5540cc05aab6}
		Recent places=::{22877a6d-37a1-461a-91b0-dbda5aaebc99}
		Recovery=::{9FE63AFD-59CF-4419-9775-ABCC3849F861}
		Recycle Bin=::{645FF040-5081-101B-9F08-00AA002F954E}
		Region and Language=::{62D8ED13-C9D0-4CE8-A914-47DD628FB1B0}
		RemoteApp and Desktop Connections=::{241D7C96-F8BF-4F85-B01F-E2B043341A4B}
		Remote Printers=::{863aa9fd-42df-457b-8e4d-0de1b8015c60}
		Removable Storage Devices=::{a6482830-08eb-41e2-84c1-73920c2badb9}
		Results Folder=::{2965e715-eb66-4719-b53f-1672673bbefa}
		Run=::{2559a1f3-21d7-11d4-bdaf-00c04f60b9f0}
		Search=::{9343812e-1c37-4a49-a12e-4b2d810d956b}
		Search Everywhere (modern)=::{2559a1f8-21d7-11d4-bdaf-00c04f60b9f0}
		Search Files (modern)=::{2559a1f0-21d7-11d4-bdaf-00c04f60b9f0}
		Security and Maintenance=::{BB64F8A7-BEE7-4E1A-AB8D-7D8273F7FDB6}
		Set Program Access and Computer Defaults		::{2559a1f7-21d7-11d4-bdaf-00c04f60b9f0}
		Show Desktop=::{3080F90D-D7AD-11D9-BD98-0000947B0257}
		Sound=::{F2DDFC82-8F12-4CDD-B7DC-D4FE1425AA4D}
		Speech Recognition=::{58E3C745-D971-4081-9034-86E34B30836A}
		Storage Spaces=::{F942C606-0914-47AB-BE56-1321B8035096}
		Sync Center=::{9C73F5E5-7AE7-4E32-A8E8-8D23B85255BF}
		Sync Setup Folder=::{2E9E59C0-B437-4981-A647-9C34B9B90891}
		System=::{BB06C0E4-D293-4f75-8A90-CB05B6477EEE}
		System Icons=::{05d7b0f4-2121-4eff-bf6b-ed3f69b894d9}
		Tablet PC Settings=::{80F3F1D5-FECA-45F3-BC32-752C152E456E}
		Taskbar and Navigation properties=::{0DF44EAA-FF21-4412-828E-260A8728E7F1}
		Text to Speech=::{D17D1D6D-CC3F-4815-8FE3-607E7D5D10B3}
		This PC=::{20D04FE0-3AEA-1069-A2D8-08002B30309D}
		Troubleshooting=::{C58C4893-3BE0-4B45-ABB5-A63E4B8C8651}
		User Accounts=::{60632754-c523-4b62-b45c-4172da012619}
		User Accounts (netplwiz)=::{7A9D77BD-5403-11d2-8785-2E0420524153}
		User Pinned=::{1f3427c8-5c10-4210-aa03-2ee45287d668}
		%UserProfile%=::{59031a47-3f72-44a7-89c5-5595fe6b30ee}
		Videos (folder)=::{A0953C92-50DC-43bf-BE83-3742FED03C9C}
		Web browser (default)=::{871C5380-42A0-1069-A2EA-08002B30309D}
		Windows Defender=::{D8559EB9-20C0-410E-BEDA-7ED416AECC2A}
		Windows Mobility Center=::{5ea4f148-308c-46d7-98a9-49041b1dd468}
		Windows Features=::{67718415-c450-4f3c-bf8a-b487642dc39b}
		Windows Firewall=::{4026492F-2F69-46B8-B9BF-5654FC07E423}
		Windows To Go=::{8E0C279D-0BD1-43C3-9EBD-31C3DC5B8A77}
		Windows Update=::{36eef7db-88ad-4e81-ad49-0e313f0c35f8}
		Work Folders=::{ECDB0924-4208-451E-8EE0-373C0956DE16}
	)"
}
;;;;;;;;;;;;;;
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: Msgbox_Error
		Purpose:
	Parameters
		
*/
Msgbox_Error(sMsg, iErrorMsg=1)
{
	static aStdMsg := ["", "An internal error occured:`n`n"]

	if (iErrorMsg > 1)
		Msgbox 8208,, % aStdMsg[iErrorMsg] sMsg
	else Msgbox 8256,, %sMsg%

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Polythene
	Function: Functions.ahk
		Purpose: Wraps Commands into Functions
	Parameters
		
*/
GUIControlGet(Subcommand = "", ControlID = "", Param4 = "")
{
	GUIControlGet, v, %Subcommand%, %ControlID%, %Param4%
	Return, v
}

Run(Target, WorkingDir = "", Mode = "UseErrorLevel", ByRef riPID="")
{
	Run, %Target%, %WorkingDir%, %Mode%, riPID
	Return, !v ? ErrorLevel == 0: A_Blank
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;