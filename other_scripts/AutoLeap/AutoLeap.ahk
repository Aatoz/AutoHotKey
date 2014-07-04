/*
	License: MIT LICENSE (See License.txt)
	Credits: See ReadMe.txt
*/

; Compiler errors if at bottom.
#Include %A_ScriptDir%\AutoLeap\ILButton.ahk

class AutoLeap
{
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: Leap
			Purpose: A single-call function to load basic leap functionality into one object
		Parameters
			hMsgHandlerFunc: Memory address of function that will be used as a callback for Leap events.
				Address to any function may be retrieved via Func("NameOfFunc").
			vLeapGestureSettings: class_EasyIni object used to configure gesture sensitivity.
	*/
	__New(sMsgHandlerFunc, sGesturesIni="", sGesturesConfigIni="")
	{
		global AutoLeap

		this.m_hMsgHandlerFunc := Func(sMsgHandlerFunc)
		this.m_sLeapWorkingDir := A_ScriptDir "\AutoLeap"
		this.m_sNameOfExe := "Leap Forwarder.exe"

		; Install exes and dlls (installs both 64bit and 32bit).
		this.FileInstalls()
		; Remove _32/_64 extensions from exes and dlls.
		; Also remove unnecessary files.
		bIs64Bit := (A_PtrSize == 8)
		if (bIs64Bit)
		{
			FileMove, % this.m_sLeapWorkingDir "\Leap Forwarder_64.exe", % this.m_sLeapWorkingDir "\" this.m_sNameOfExe, 1
			FileMove, % this.m_sLeapWorkingDir "\Leap_64.dll", % this.m_sLeapWorkingDir "\Leap.dll", 1
			; Don't delete files for non-compiled scripts, because they are needed for compiling.
			if (A_IsCompiled)
			{
				FileDelete, % this.m_sLeapWorkingDir "\Leap Forwarder_32.exe"
				FileDelete, % this.m_sLeapWorkingDir "\Leap_32.dll"
			}
		}
		else
		{
			FileMove, % this.m_sLeapWorkingDir "\Leap Forwarder_32.exe", % this.m_sLeapWorkingDir "\" this.m_sNameOfExe, 1
			FileMove, % this.m_sLeapWorkingDir "\Leap_32.dll", % this.m_sLeapWorkingDir "\Leap.dll", 1
			if (A_IsCompiled)
			{
				FileDelete, % this.m_sLeapWorkingDir "\Leap Forwarder_64.exe"
				FileDelete, % this.m_sLeapWorkingDir "\Leap_64.dll"
			}
		}

		; Check to see if core LeapMotion software is even installed on this machine.
		RegRead, sKey, HKCR, airspace\shell\open\command
		if (!InStr(sKey, "\Leap Motion"))
		{
			Msgbox, 8208,, Error: Leap Motion software is required to run this script.
			return false
		}
		; Ensure that AutoLeap.exe is present.
		if (!FIleExist(this.m_sLeapWorkingDir "\" this.m_sNameOfExe))
		{
			Msgbox, 8208,, % "Error: " this.m_sNameOfExe " is not present in " this.m_sLeapWorkingDir "`nIt is required to run this program."
			return false
		}

		if (sGesturesIni == A_Blank)
			this.m_vGesturesIni := class_EasyIni(this.m_sLeapWorkingDir "\Gestures.ini")
		else this.m_vGesturesIni := class_EasyIni(sGesturesIni)
		if (!FileExist(this.m_vGesturesIni.GetFileName()))
			this.m_vGesturesIni.Save()

		if (sGesturesConfigIni == A_Blank)
			this.m_vGesturesConfigIni := class_EasyIni(this.m_sLeapWorkingDir "\Gestures Config.ini")
		else this.m_vGesturesConfigIni := class_EasyIni(sGesturesConfigIni)
		; To allow removal of old settings and additions of new settings, merge m_vGesturesConfigIni with our defaults.
		vDefaultGesturesConfigIni := class_EasyIni("", this.GetDefaultGesturesConfigIni())
		this.m_vGesturesConfigIni.Merge(vDefaultGesturesConfigIni, true, false)
		this.m_vGesturesConfigIni.Save() ; This effectively updates the local ini with new settings from GetDefaultGesturesConfigIni().

		; Anywhere we display, "Leap" we *must* say, "Leap Motion Controller"
		; Failure to do so results in automatic rejection from Airspace
		this.m_sLeapMC := "Leap Motion Controller"

		this.m_bIsFirstRun := true
		this.StartLeap()
		AutoLeap.PID[this.m_iAutoLeapPID] := &this

		; Creating the dialogs could take a long time, so do it after we have launched AutoLeap.exe.
		this.m_vDlgs := new LeapDlgs()

		this.m_bInit := true
		this.m_bIsFirstRun := false

		SetWorkingDir, %sOldWorkingDir%
		return this
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	__Delete()
	{
		if (this.m_bInit)
		{
			bExeClosed := this.CloseExe()
			AutoLeap.PID.Remove(this.m_iAutoLeapPID)
		}
		else bExeClosed := true ; because the exe was never launched.

		this:=""

		return bExeClosed
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	__Get(var)
	{
		global

		if (var = "m_iAutoLeapPID")
			return g_iAutoLeapPID

		if (var = "m_hAutoLeapOSD")
			return g_hAutoLeapOSD

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: CloseExe
			Purpose: Terminates AutoLeap.exe
		Parameters
			bUpdateOSD=true: If we are reloading, we don't want to spam the OSD.
	*/
	CloseExe(bUpdateOSD=true)
	{
		static WM_CLOSE:=16

		; If we post a message after this.SendMessageToExe, then there's not enough time to actually see this message.
		if (bUpdateOSD)
			this.OSD_PostMsg(this.m_sLeapMC " listener is closing")

		sOld := A_DetectHiddenWindows
		DetectHiddenWindows, On

		SendMessage, WM_CLOSE, 0, 0,, % "ahk_id" this.m_hAutoLeapWnd
		bRet := ErrorLevel

		DetectHiddenWindows, %sOld%

		return bRet
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: Reload
			Purpose: So that users may reload without destroying the object.
		Parameters
			bReloadExe=true
	*/
	Reload()
	{
		this.m_bReloaded := false

		; Reload inis.
		; IMPORTANT: m_vGesturesConfigIni should be reloaded BEFORE we relaunch the exe
		; because it changes settings within the exe.
		this.m_vGesturesIni := this.m_vGesturesIni.Reload()
		this.m_vGesturesConfigIni := this.m_vGesturesConfigIni.Reload()

		this.CloseExe(false)
		this.StartLeap()

		; New PID from StartLeap, so reassign super-global.
		AutoLeap.PID[this.m_iAutoLeapPID] := &this

		this.m_bReloaded := true
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: FileInstalls
			Purpose: To FileInstall before initializing class object
		Parameters
			
	*/
	FileInstalls()
	{
		; Directory.
		if (!FileExist("AutoLeap"))
			FileCreateDir, AutoLeap

		; v1.0
		FileInstall, AutoLeap\Leap.ico, AutoLeap\Leap.ico, 1
		FileInstall, AutoLeap\Exit.ico, AutoLeap\Exit.ico, 1
		FileInstall, AutoLeap\Save.ico, AutoLeap\Save.ico, 1
		FileInstall, AutoLeap\Save As.ico, AutoLeap\Save As.ico, 1
		FileInstall, AutoLeap\Info.ico, AutoLeap\Info.ico, 1
		FileInstall, AutoLeap\Config.ico, AutoLeap\Config.ico, 1
		FileInstall, AutoLeap\Download.ico, AutoLeap\Download.ico, 1
		FileInstall, AutoLeap\Rotate 3D.ico, AutoLeap\Rotate 3D.ico, 1
		FileInstall, AutoLeap\Red.ico, AutoLeap\Red.ico, 1
		FileInstall, AutoLeap\Add.ico, AutoLeap\Add.ico, 1
		FileInstall, AutoLeap\Delete.ico, AutoLeap\Delete.ico, 1
		FileInstall, AutoLeap\msvcr100.dll, AutoLeap\msvcr100.dll, 1
		; License and other help files.
		FileInstall, AutoLeap\version, AutoLeap\version, 1
		FileInstall, AutoLeap\License.txt, AutoLeap\License.txt, 1
		FileInstall, AutoLeap\ReadMe.txt, AutoLeap\ReadMe.txt, 1

		; Exes and dependencies
		FileInstall, AutoLeap\Leap Forwarder_32.exe, AutoLeap\Leap Forwarder_32.exe, 1
		FileInstall, AutoLeap\Leap Forwarder_64.exe, AutoLeap\Leap Forwarder_64.exe, 1
		FileInstall, AutoLeap\Leap_32.dll, AutoLeap\Leap_32.dll, 1
		FileInstall, AutoLeap\Leap_64.dll, AutoLeap\Leap_64.dll, 1
		FileInstall, AutoLeap\msvcr120.dll, AutoLeap\msvcr120.dll, 1
		FileInstall, AutoLeap\msvcr120.dll, AutoLeap\msvcr120.dll, 1

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: SetTrackState
			Purpose: Pauses/unpauses tracking in AutoLeap.exe
		Parameters
			None
	*/
	SetTrackState(bTrack)
	{
		this.SendMessageToExe((bTrack ? "Resume" : "Pause"))
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: MergeGesturesIni
			Purpose: To merge OtherIni with m_vGesturesIni
		Parameters
			OtherIni
	*/
	MergeGesturesIni(OtherIni)
	{
		if (!IsObject(OtherIni))
			vOtherIni := class_EasyIni(this.m_vGesturesIni.GetFileName(), OtherIni)
		else vOtherIni := OtherIni

		this.m_vGesturesIni.Merge(vOtherIni)
		this.m_vGesturesIni.Save()
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GetDefaultLeapGesturesConfigIni
			Purpose: Retrieves default leap gesture configuration settings as defined by me, Verdlin.
				Any setting that will not be set by the user will be set based on the values from ths ini.
		Parameters
			None

	Information as of: 11/25/2013
	Source: https://developer.leapmotion.com/documentation/Languages/CSharpandUnity/API/class_leap_1_1_config.html

	Key															Type		Val			Unit
	----------------------------------------------------------------------------------------------
	Gesture.Circle.MinRadius						float		5.0		mm
	Gesture.Circle.MinArc								float		1.5*pi	radians
	Gesture.Swipe.MinLength						float		150		mm
	Gesture.Swipe.MinVelocity						float		1000	mm/s
	Gesture.KeyTap.MinDownVelocity			float		50		mm/s
	Gesture.KeyTap.HistorySeconds				float		0.1		s
	Gesture.KeyTap.MinDistance					float		3.0		mm
	Gesture.ScreenTap.MinForwardVelocity	float		50		mm/s
	Gesture.ScreenTap.HistorySeconds		float		0.1		s
	Gesture.ScreenTap.MinDistance				float		5.0		mm
	----------------------------------------------------------------------------------------------

	*/
	GetDefaultGesturesConfigIni()
	{
		return "
			(LTrim
				[Sliders]
				Circle.MinRadius=9
				; Note: Circle.MinArc is multipled by pi.
				Circle.MinArc=1.8
				Swipe.MinLength=150
				Swipe.MinVelocity=270
				KeyTap.MinDownVelocity=440
				KeyTap.HistorySeconds=1.50
				KeyTap.MinDistance=60
				ScreenTap.MinForwardVelocity=140
				ScreenTap.HistorySeconds=0.75
				ScreenTap.MinDistance=55

				[AvailableGestures]
				EnableSwipe=1
				EnableCircle=1
				EnableKeyTap=1
				EnableScreenTap=0
			)"
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	StartLeap()
	{
		this.StartAutoLeapExe()
		this.OSD_Init()

		; Listener
		OnMessage(WM_COPYDATA:=74, "AutoLeap_OnCopyData")

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	StartAutoLeapExe()
	{
		global g_iAutoLeapPID

		; TODO: Pinch.
		this.m_sGestureParse := "Swipe|Circle|KeyTap|ScreenTap" ; Houses all supported gestures.
		this.m_vProcessor.m_avGestureData := class_EasyIni(this.m_sLeapWorkingDir "\Leap.ini")

		this.m_iGestureSecCnt := 0
		this.m_bOSDShouldSlideOut := true

		; When his.m_vGesturesConfigIni is modifed from LeapDlgs, even though it looks like it uses this same object,
		; it doesn't, but the settings get saved, so a Reload() works around this oddity.
		this.m_vGesturesConfigIni := this.m_vGesturesConfigIni.Reload()

		for sec, aData in this.m_vGesturesConfigIni
		{
			if (sec != "Sliders" && sec != "AvailableGestures")
				continue

			for key, val in aData
			{
				if (key = "Circle.MinArc")
					val *= this.m_iPi

				sLeapParms .=  " """ key "=" val """"
			}
		}
		; TODO: Allow an option for this.
		sLeapParms .= " ""OneGestureTypePerFrame=True"""

		sHide := "HIDE"
		Run, % comspec " /c " """""" this.m_sLeapWorkingDir "\" this.m_sNameOfExe """ ""hWnd=" A_ScriptHwnd """ " sLeapParms """",, %sHide%, g_iAutoLeapPID ; g_iAutoLeapPID is used in case the call to Quit fails in __Delete

		if (!this.m_iAutoLeapPID) ; Resolved in __Get
			ExitApp ; Warning dialog should have been shown.

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	OSD_Init()
	{
		global

		this.m_bDismiss := false ; Used in OSD_DismissAfterNMS.
		this.m_iMaxWidth := A_ScreenWidth ; used for clarity, and also ease of changeability.

		GUI AutoLeapOSD: New, hwndg_hAutoLeapOSD
		GUI, +AlwaysOnTop -Caption +Owner +LastFound +ToolWindow +E0x20
		WinSet, Transparent, 240
		GUI, Color, 202020
		GUI, Font, s15 c5C5CF0 wnorm ; c0xF52C5F

		GUI, Add, Text, x0 y0 hwndg_hAutoLeapOSD_MainOutput vg_vAutoLeapOSD_MainOutput Wrap Left
		GUI, Add, Text, % "x0 y0 w" this.m_iMaxWidth " r1 vg_vAutoLeapOSD_PostDataOutput +Center Hidden" ; Switch out these two text controls for output
		this.m_hFont := Fnt_GetFont(g_hAutoLeapOSD_MainOutput)
		this.m_iOneLineOfText := Str_MeasureText("a", this.m_hFont).bottom

		GUI, AutoLeapOSD:Show, x0 y0 NoActivate
		GUI, AutoLeapOSD:Hide ; Not using WinMove for sizing since it activates the window

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ProcessAutoLeapData
			Purpose: Process data sent from AutoLeap.exe as fast as possible
		Parameters
			rsData -- String retrieved from COPYDATA struct

			Currently data is sent in ini-format like so...
			[Hand]
			Normal=X=N|Y=N|Z=N
			Direction=X=N|Y=N|Z=N
			[GestureType]
			State=N
			etc=etc
			...

			As I've studied and wrestled with the idiosyncracies of the Leap SDK,
			I've discovered the following concerning gestures:
				1. KeyTaps and ScreenTaps only ever have a State of 3
				2. Circles and Swipes always have a state of 1, 2, and 3. (Except for weird cases like on one of my computers where the config settings don't take place and these sometimes only have states of 2 and 3)

				This means that some odd handling has to happen. Namely:
				1. KeyTap and ScreenTap must be handling separately from other gestures
				2. Circles and Swipes should be registered only when the state is 1.
	*/
	ProcessAutoLeapData(ByRef rsData)
	{
		static s_sLastGesture, s_iLastState
		vLeapData := class_EasyIni("", rsData)

		; [Header]
		if (vLeapData.Header.DataType = "Post")
			bPostData := true

		this.m_hAutoLeapWnd := vLeapData.Header.hWnd ; This key should always be present.

		; Handle Connected, Disconnected events as per Leap Motion's app requirements.
		if (vLeapData.Header.HasKey("Initialized") && this.m_bIsFirstRun)
		{
			this.OSD_PostMsg("Ready to receive " this.m_sLeapMC " input")
			return
		}
		else if (vLeapData.Header.HasKey("Connected") && !this.m_bReloaded)
		{
			this.OSD_PostMsg(this.m_sLeapMC " is connected")
			this.m_hMsgHandlerFunc.("Connect", "", "", "")
			return
		}
		else if (vLeapData.Header.HasKey("Disconnected"))
		{
			this.OSD_PostMsg(this.m_sLeapMC " was disconnected")
			this.m_hMsgHandlerFunc.("Disconnect", "", "", "")
			return
		}

		; If any other header keys are added, process them above here.
		; [End Header]

		if (!this.m_vProcessor.m_bIgnoreGestures)
		{
			sGestureParse := this.m_sGestureParse
			Loop, Parse, sGestureParse, |
			{
				if (vLeapData.HasKey(A_LoopField))
				{ ; Gesture matched!

					sGestureToAdd := A_LoopField
					if (vLeapData[A_LoopField].HasKey("Direction"))
						sGestureToAdd .= " " vLeapData[A_LoopField].Direction

					if ((vLeapData[A_LoopField].State == 1)
						|| this.GestureIsKeyTapOrScreenTap(A_LoopField) ; KeyTap and ScreenTap only have a state of 3.
						|| sGestureToAdd != s_sLastGesture) ; Sometime Leap Forwarder.exe messes up and misses a state, I think it's due to slow responses through SendMessage.
					{
						this.m_iGestureSecCnt++

						; Copy gesture over to this.m_vProcessor.m_avGestureData.
						if (!this.m_vProcessor.m_avGestureData.AddSection(A_LoopField "_" this.m_iGestureSecCnt, "", "", sError))
						{
							Msgbox 8208,, An internal error occured:`n`n%sError%
							return ; no break because these errors could just keep recurring.
						}

						; Copy over keys and vals.
						for key, val in vLeapData[A_LoopField]
						{
							if (!this.m_vProcessor.m_avGestureData.AddKey(A_LoopField "_" this.m_iGestureSecCnt, key, val, sError))
							{
								Msgbox 8208,, An internal error occured:`n`n%sError%
								return
							}
						}
					}

					s_sLastGesture := sGestureToAdd
					s_iLastState := vLeapData[A_LoopField].State
					break ; Only one gesture should have come through, so we can break.
				}
			}

			; Enumature gestures in this.m_vProcessor.m_avGestureData.
			asGestures := []
			; Note: Enumeration over class_EasyIni is *very* fast, at least on my computer.
			; There wasn't even a discernable difference measuring with A_TickCount.
			; Still, I'm keeping my timing code in here so I remember to be aware of timing.
			;~ iStart := A_TickCount
			if (this.m_vProcessor.m_bOnlyUseLatestGesture)
				asGestures.1 := sGestureToAdd
			else for sec in this.m_vProcessor.m_avGestureData
			{
				sGesture := SubStr(sec, 1, InStr(sec, "_") - 1) ; SubStr and InStr...eek.
				if (this.GestureIsKeyTapOrScreenTap(sGesture))
					asGestures.Insert(sGesture)
				else asGestures.Insert(sGesture " " this.m_vProcessor.m_avGestureData[sec].Direction)
			}
			;~ Tooltip % "Process:`t" (A_TickCount - iStart) "`n" iStart "`n" A_TickCount

			if (bPostData)
				this.PostRecordedData(vLeapData, asGestures)
			else
			{
				this.OSD_Update(vLeapData, asGestures)

				if (this.m_vDlgs.m_bIsRecording && asGestures.MaxIndex() > 0)
				{
					GUI, ControlCenterDlg_:Default
					; The gestures will actually be added in PostRecordedData().
					GUIControl,, g_vControlCenterDlg_GestureChainEdit, % st_glue(asGestures, ", ")
				}
			}
		}

		if (!bPostData && this.m_hMsgHandlerFunc)
			this.m_hMsgHandlerFunc.("Forward", vLeapData, asGestures, "")

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GestureIsKeyTapOrScreenTap
			Purpose: Legibility. ByRef for speed.
		Parameters
			1. rsGesture: KeyTap, ScreenTap, Circle, or Swipe
	*/
	GestureIsKeyTapOrScreenTap(ByRef rsGesture)
	{
		return (rsGesture = "KeyTap" || rsGesture = "ScreenTap")
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	IsMakingFist(ByRef rLeapData)
	{
		; TODO: Comment

		if (rLeapData.HasKey("Hand2"))
			return !rLeapData.HasKey("Finger1") && !rLeapData.HasKey("Finger6")
		return rLeapData.HasKey("Hand1") && !rLeapData.HasKey("Finger1")

		;~ return (rLeapData.HasKey("Hand1") || (rLeapData.HasKey("Hand2")) && !rLeapData.HasKey("Finger1"))
			;~ && rLeapData.Hand1.SphereRadius < 70
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function:
			Purpose: To take into account the velocity of a given Leap object.
			Cursory testing shows the following about velocity:
				1. 0-399 = Relatively slow movement.
				2. 400-999 = Relatively moderate movement.
				3. 1000+ = Relatively fast movement.
				Note: This function is pretty basic, but it is used in multiple contexts, so I like to keep the comments about
					velocity localized so that we understand what the purpose of this factor is.
		Parameters
			iVelocity: May be velocity X, Y, or Z. When we figure out how to manipulate time, then we'll have VelocityT ;)
			iDenom: A denominator used to help scale the velocity to a number that is interpretable by the caller.
	*/
	CalcVelocityFactor(iVelocity, iDenom)
	{
		return iVelocity/iDenom
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GetPalmDelta
			Purpose: Palm Movement. Various factors will be based upon the difference of
			 palm location between the call to this function and the previous call.
				Note: Currently Z and Hand2 are ignored.
		Parameters
			rLeapData
			riPalmXDelta
			riPalmYDelta
			riLastPalmX
			riLastPalmY
	*/
	GetPalmDelta(ByRef rLeapData
		, ByRef riPalmXDelta, ByRef riPalmYDelta
		, ByRef riLastPalmX="", ByRef riLastPalmY="")
	{
		static s_iLastPalmX, s_iLastPalmY

		iPalmX := rLeapData.Hand1.PalmX
		iPalmY := rLeapData.Hand1.PalmY

		if (s_iLastPalmX == A_Blank)
			s_iLastPalmX := iPalmX
		if (s_iLastPalmY == A_Blank)
			s_iLastPalmY := iPalmY

		; The palm values will be blank when there is no palm in the FOV.
		; In order to prevent glicthing in calling functions, we only set the delta
		; when we have non-blank values for our delta vars.
		if (iPalmX != A_Blank)
			riPalmXDelta := s_iLastPalmX-iPalmX
		if (iPalmY != A_Blank)
			riPalmYDelta := s_iLastPalmY-iPalmY

		riLastPalmX := s_iLastPalmX
		riLastPalmY := s_iLastPalmY

		; Set values for next call.
		s_iLastPalmX := iPalmX
		s_iLastPalmY := iPalmY

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GetPalmDiffDelta
			Purpose: Palm Movement. Various factors will be based upon the difference of
			 palm location between the call to this function and the previous call.
				Note: Currently Z and Hand2 are ignored.
		Parameters
			rLeapData
			riPalmDiffXDelta
			riPalmDiffYDelta
			riLastPalmDiffX
			riLastPalmDiffY
	*/
	GetPalmDiffDelta(ByRef rLeapData
		, ByRef riPalmDiffXDelta, ByRef riPalmDiffYDelta
		, ByRef riLastPalmDiffX="", ByRef riLastPalmDiffY="")
	{
		static s_iLastPalmDiffX, s_iLastPalmDiffY

		iPalmDiffX := rLeapData.Header.PalmDiffX
		iPalmDiffY := rLeapData.Header.PalmDiffY

		if (s_iLastPalmDiffX == A_Blank)
			s_iLastPalmDiffX := iPalmDiffX
		if (s_iLastPalmDiffY == A_Blank)
			s_iLastPalmDiffY := iPalmDiffY

		; See comment in GetPalmDelta()
		if (iPalmDiffX != A_Blank)
			riPalmDiffXDelta := s_iLastPalmDiffX-iPalmDiffX
		if (iPalmDiffY != A_Blank)
			riPalmDiffYDelta := s_iLastPalmDiffY-iPalmDiffY

		riLastPalmDiffX := s_iLastPalmDiffX
		riLastPalmDiffY := s_iLastPalmDiffY

		; Set values for next call.
		s_iLastPalmDiffX := iPalmDiffX
		s_iLastPalmDiffY := iPalmDiffY

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GetScaleFactor
			Purpose: Scaling factor as retrieved through Leap ScaleFactor function..
				Note: This is used for pinching actions only, so once Leap adds native pinch support,
				this function needs to be chagned.
				Note: Currently Hand2 is ignored.
		Parameters
			rLeapData
			riLastScaleFactor
	*/
	GetScaleFactor(ByRef rLeapData, ByRef riLastScaleFactor="")
	{
		static s_iLastScaleFactor

		if (s_iLastScaleFactor == A_Blank)
			s_iLastScaleFactor := iScaleFactor

		iScaleFactor := rLeapData.Hand1.ScaleFactor

		riLastScaleFactor := s_iLastScaleFactor
		; Set value for next call.
		s_iLastScaleFactor := iScaleFactor

		return iScaleFactor
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	ResetGestures()
	{
		; Clear gestures in the processor
		this.m_vProcessor.m_avGestureData := class_EasyIni(this.m_sLeapWorkingDir "\Leap.ini")
		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: OSD_Update
			Purpose: To update the OSD with a new string of gestures.
		Parameters
			rLeapData
			rasGestures
	*/
	OSD_Update(ByRef rLeapData, ByRef rasGestures)
	{
		; TODO: Fix bug here where we don't display double gestures if one came before a post and one came after
		static s_sLastGestures
		GUI, AutoLeapOSD:Default

		sGestures := st_glue(rasGestures, ", ")
		if (sGestures == A_Blank || sGestures == s_sLastGestures)
		{
			s_sLastGestures := sGestures
			return
		}

		; If data has been posted, then we displayed a little banner showing what action was executed.
		; There is a timer running, OSD_DismissAfterNMS, which is going to hide this GUI unless this.m_bDismiss := false
		if (s_sLastGestures == A_Blank)
			this.OSD_Init() ; Reset the OSD because it doesn't always stay on top, for some reason.

		this.m_bOverrideHide := true ; Prevents us from hiding the OSD in case OSD_DismissAfterNMS is running from a different message being posted.

		rect := Str_MeasureTextWrap(sGestures, this.m_iMaxWidth, this.m_hFont)
		if (this.m_vProcessor.m_bGestureSuggestions)
		{
			sSuggestions := this.GetGestureSuggestions(sGestures)
			if (sSuggestions)
			{
				rect2 := Str_MeasureTextWrap(sSuggestions, this.m_iMaxWidth, this.m_hFont)
				; If we have to wrap text, then it looks better to expand the OSD the full width.
				if (rect.bottom > this.m_iOneLineOfText)
					rect.right := this.m_iMaxWidth
				else if (rect2.right > rect.right)
					rect.right := rect2.right

				rect.bottom += rect2.bottom-this.m_iOneLineOfText
			}
		}
		else if (rect.bottom > this.m_iOneLineOfText)
			rect.right := this.m_iMaxWidth

		GUIControl, Hide, g_vAutoLeapOSD_PostDataOutput
		GUIControl, Show, g_vAutoLeapOSD_MainOutput
		GUIControl, MoveDraw, g_vAutoLeapOSD_MainOutput, % "W" rect.right " H" rect.bottom
		GUIControl,, g_vAutoLeapOSD_MainOutput, %sGestures%%sSuggestions%

		if (this.m_bOSDShouldSlideOut)
		{
			GUI, Show, % "X0 Y-" rect.bottom " W" rect.right " H" rect.bottom " NoActivate"
			WAnim_SlideIn("Top", 0, 0, this.m_hAutoLeapOSD, "AutoLeapOSD", rect.bottom/4)
			this.m_bOSDShouldSlideOut := false
		}
		else
		{
			; Note: The OSD has to be updated so rapidly that any visuals just irritate instead of dazzle.
			GUI, Show, % "X0 y0 W" rect.right " H" rect.bottom " NoActivate"
		}

		; Post data for gesture recorders...
		if (this.m_hMsgHandlerFunc)
			this.m_hMsgHandlerFunc.("Forward", rLeapData, rasGestures, "")

		s_sLastGestures := sGestures
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	PostRecordedData(ByRef rLeapData, ByRef rasGestures)
	{
		if (rasGestures.MaxIndex())
		{
			if (this.m_hMsgHandlerFunc)
			{
				this.m_hMsgHandlerFunc.("Post", rLeapData, rasGestures, sOutput)
				if (sOutput)
					this.OSD_PostMsg(sOutput)
				else this.OSD_Dismiss()
			}
			else this.OSD_Dismiss()

			this.m_bOSDShouldSlideOut := true
		}

		if (this.m_vDlgs.m_bIsRecording)
			this.m_vDlgs.AddGestureToName(rasGestures)

		this.m_vProcessor.m_avGestureData := class_EasyIni(this.m_sLeapWorkingDir "\Leap.ini")
		this.m_iGestureSecCnt := 0

		GUIControl,, g_vAutoLeapOSD_MainOutput ; Clear this.
		return
	}

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	OSD_PostMsg(sMsg)
	{
		global
		GUI, AutoLeapOSD:Default

		rect := Str_MeasureTextWrap(sMsg, this.m_iMaxWidth, this.m_hFont)
		this.OSD_Init() ; Reset the OSD because it doesn't always stay on top, for some reason.

		GUIControl, Hide, g_vAutoLeapOSD_MainOutput
		GUIControl, Show, g_vAutoLeapOSD_PostDataOutput
		GUIControl, MoveDraw, g_vAutoLeapOSD_PostDataOutput, % "W" this.m_iMaxWidth " H" rect.bottom
		GUIControl,, g_vAutoLeapOSD_PostDataOutput, %sMsg%

		GUI, Show, % "W" this.m_iMaxWidth " H" rect.bottom " NoActivate"
		this.OSD_DismissAfterNMS(1000)

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	OSD_DismissAfterNMS(iNMS)
	{
		global

		this.m_bDismiss := false
		this.m_bOverrideHide := false
		this.m_hOldAutoLeapOSD := this.m_hAutoLeapOSD

		SetTimer, OSD_DismissAfterNMS, %iNMS%
		return

		OSD_DismissAfterNMS:
		{
			vAutoLeap := _AutoLeap()

			if (vAutoLeap.m_bDismiss)
			{
				vAutoLeap.m_bDismiss := false

				if (vAutoLeap.m_hOldAutoLeapOSD == vAutoLeap.m_hAutoLeapOSD)
				{
					if (!vAutoLeap.m_bOverrideHide)
						vAutoLeap.OSD_Dismiss()
					vAutoLeap.m_bOSDShouldSlideOut := true
				}

				SetTimer, %A_ThisLabel%, Off
			}
			else vAutoLeap.m_bDismiss := true

			return
		}
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: OSD_Dismiss
			Purpose:
		Parameters
			
	*/
	OSD_Dismiss()
	{
		WinGetPos,,,, iH, % "ahk_id" this.m_hAutoLeapOSD
		WAnim_SlideOut("Top", this.m_hAutoLeapOSD, "AutoLeapOSD", iH/15, false)
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;; This function safely prevents recording of double gestures
	;;;;;;;;;;;;;; i.e. "RIght, Right" or "Left, Left," etc.
	AddGesture_Safe(sGesture, ByRef rasGestures)
	{
		if (rasGestures[rasGestures.MaxIndex()] != sGesture)
			rasGestures.Insert(sGesture)
		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin and http://l.autohotkey.net/docs/commands/OnMessage.htm
		Function: SendMessageToExe
			Purpose: To send messages to AutoLeap.exe
		Parameters
			StringToSend: ByRef saves a little memory in this case.
	*/
	SendMessageToExe(ByRef StringToSend)
	{
		sOld := A_DetectHiddenWindows
		DetectHiddenWindows, On

		VarSetCapacity(CopyDataStruct, 3*A_PtrSize, 0)
		SizeInBytes := (StrLen(StringToSend) + 1) * (A_IsUnicode ? 2 : 1)
		NumPut(SizeInBytes, CopyDataStruct, A_PtrSize)
		NumPut(&StringToSend, CopyDataStruct, 2*A_PtrSize)

		SendMessage, 0x4a, 0, &CopyDataStruct,, % "ahk_id" this.m_hAutoLeapWnd
		bRet := ErrorLevel

		DetectHiddenWindows, %sOld%

		return bRet
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GetGestureSuggestions
			Purpose: To provide relevant gesture chain suggestions on the OSD.
		Parameters
			sGestureChain: I.e. "Circle Left, Swipe Down" then we find all gestures starting with those two gestures.
	*/
	GetGestureSuggestions(sGestureChain)
	{
		iSuggestions := 0
		for sec, aData in this.m_vGesturesIni
		{
			; We have limited space on the OSD.
			if (iSuggestions > 15)
				break

			if (RegExMatch(aData.Gesture, "^" sGestureChain))
			{
				sSuggestions .= sec ": " aData.Gesture "`n"
				iSuggestions++
			}
		}

		; Trim newline from end.
		if (iSuggestions)
			sSuggestions := "`n`n" RTrim(sSuggestions, "`n")

		return sSuggestions
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ShowControlCenterDlg
			Purpose: Wrapper to Dlgs.ShowControlCenterDlg()
		Parameters
			hOwner: Optional window handle to the owner of this dialog.
			sSelect: Existing gesture name to select.
			bReloadOnExit: If true, reloads AutoLeap.exe after the dialog has been dismissed.
	*/
	ShowControlCenterDlg(hOwner=0, sSelect="", bReloadOnExit=true)
	{
		return this.m_vDlgs.ShowControlCenterDlg(hOwner, sSelect, bReloadOnExit)
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ShowControlCenterDlg
			Purpose: Wrapper to LeapDlgs.ShowGesturesConfigDlg()
		Parameters
			hOwner: Optional window handle to the owner of this dialog
	*/
	ShowGesturesConfigDlg(hOwner=0)
	{
		this.m_vDlgs.ShowGesturesConfigDlg(hOwner)
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

/*
	-------------------------------------------------------------------
	-------------------------------------------------------------------
	--------------------Begin Member Variables--------------------
	-------------------------------------------------------------------
	-------------------------------------------------------------------
*/

	; Member variables.
	m_iPI := 3.14159265
	m_vProcessor := {m_bIgnoreGestures:false
		, m_bOnlyUseLatestGesture:0
		, m_bGestureSuggestions:true
		, m_avGestureData:Object()
		, m_iGestureSecCnt:0}

}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: _AutoLeap
		Purpose: Wrapper to retrieve AutoLeap object associated with g_iAutoLeapPID.
	Parameters
		
*/
_AutoLeap()
{
	global g_iAutoLeapPID
	return Object(AutoLeap.PID[g_iAutoLeapPID])
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: _Dlgs
		Purpose: Wrapper to retrieve Dlgs object associated with _AutoLeap()
	Parameters
		
*/
_Dlgs()
{
	return _AutoLeap().m_vDlgs
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: AutoLeap_OnCopyData
		Purpose: Receive Leap motion data from AutoLeap.exe
	Parameters
		wParam
		lParam
*/
AutoLeap_OnCopyData(wParam, lParam)
{
	StringAddress := NumGet(lParam+2*A_PtrSize)
	sData := StrGet(StringAddress)

	; Note: it is important to return in a timely fashion, so it may be better to post data with ahkPostFunction.
	_AutoLeap().ProcessAutoLeapData(sData)
	return true
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

/*
	-------------------------------------------------------------------
	-------------------------------------------------------------------
	-------------------------Begin LeapDlgs-------------------------
	-------------------------------------------------------------------
	-------------------------------------------------------------------
*/

class LeapDlgs
{
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: __New
			Purpose:
		Parameters
			
	*/
	__New()
	{
		static WM_KEYDOWN:=256

		sOldWorkingDir := A_WorkingDir
		SetWorkingDir, % this.m_sLeapWorkingDir

		; Note: we *must* set up separate inis here. Writing to memory doesn't work when calling inis _AutoLeap().
		this.m_vGesturesIni := class_EasyIni(_AutoLeap().m_vGesturesIni.GetFileName())
		this.m_vGesturesConfigIni := class_EasyIni(_AutoLeap().m_vGesturesConfigIni.GetFileName())

		this.MakeControlCenterDlg()
		this.MakeGesturesConfigDlg()

		; For dlg-specific hotkeys.
		OnMessage(WM_KEYDOWN, "ControlCenterDlg_OnKeyDown")

		SetWorkingDir, %sOldWorkingDir%
		return this
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: __Get
			Purpose: Use of global objects will be more intuitive if wrapped to class objects.
				Readers will understand that variables, such as m_hControlCenterDlg, are owned by Dlgs.
		Parameters
			var = var to get
	*/
	; TODO: When __Call() fails, try to perform dynamic function calls on _AutoLeap().%sFuncName%.
	__Get(var)
	{
		global

		if (var = "m_hControlCenterDlg")
			return g_hControlCenterDlg
		if (var = "m_hControlCenterDlgOwner")
			return g_hControlCenterDlgOwner
		if (var = "m_hGesturesConfigDlg")
			return g_hGesturesConfigDlg
		if (var = "m_hControlCenterDlg_GestureIDLV")
			return g_hControlCenterDlg_GestureIDLV
		if (var = "m_hControlCenterDlg_NameEdit")
			return g_hControlCenterDlg_NameEdit

		if (var = "m_sLeapWorkingDir")
			return _AutoLeap().m_sLeapWorkingDir
		if (var = "m_iPI")
			return _AutoLeap().m_iPI
		if (var = "m_sLeapTM")
			return _AutoLeap().m_sLeapTM
		if (var = "m_sLeapMC")
			return _AutoLeap().m_sLeapMC

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	GetCurSel()
	{
		this._SetLV()
		return LV_GetSel()
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	GetSelText()
	{
		this._SetLV()
		return LV_GetSelText()
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	GetCount()
	{
		this._SetLV()
		return LV_GetCount()
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	GetGestureID()
	{
		GUIControlGet, sGestureID,, g_vControlCenterDlg_NameEdit
		return Trim(sGestureID)
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	SetSel(iRow=1, bSelEdit=true)
	{
		this._SetLV()
		LV_SetSel(iRow, sOptsOverride)

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	SetSelText(sToSel, sOptsOverride="", iCol=1, bPartialMatch=false, bCaseSensitive=false)
	{
		this._SetLV()
		LV_SetSelText(sToSel, sOptsOverride, iCol, bPartialMatch, bCaseSensitive)

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: CtrlBaseNameFromKey
			Purpose: Get the base control variables names we derive from ini keys
		Parameters
			sCtrl
	*/
	CtrlBaseNameFromKey(key)
	{
		StringReplace, sCtrlBaseName, key, `., PERIOD, All
		return "v" sCtrlBaseName
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: KeyFromCtrl
			Purpose: Get a key for an ini based upon a slider control variable name.
		Parameters
			sCtrl
	*/
	KeyFromSliderCtrl(sCtrl)
	{
		StringReplace, sec, sCtrl, PERIOD, `., All
		StringLeft, sec, sec, % InStr(sec, "_Slider")-1
		StringRight, key, sec, StrLen(sec)-1
		return key
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: CtrlFromKey
			Purpose: Get a slider control variable name based upon a key for an ini.
		Parameters
			key
	*/
	SliderCtrlFromKey(key)
	{
		StringReplace, sCtrlBaseName, key, `., PERIOD, All
		return this.CtrlBaseNameFromKey(key) "_Slider"
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	__Delete()
	{
		GUI, ControlCenterDlg_:Destroy
		GUI, GesturesConfigDlg_:Destroy

		this:=""
		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	ControlCenterDlg_AddAllMenuItems()
	{
		GUI, ControlCenterDlg_:Default

		; File
		Menu, ControlCenterDlg_FileMenu, Add, &Save`tCtrl + S, ControlCenterDlg_Save
		Menu, ControlCenterDlg_FileMenu, Icon, &Save`tCtrl + S, Save.ico,, 16
		Menu, ControlCenterDlg_FileMenu, Add, Save &As...`tCtrl + Alt + S, ControlCenterDlg_SaveAs
		Menu, ControlCenterDlg_FileMenu, Icon, Save &As...`tCtrl + Alt + S, Save As.ico,, 16
		Menu, ControlCenterDlg_FileMenu, Add, &Import Settings`tCtrl + I, ControlCenterDlg_Import
		Menu, ControlCenterDlg_FileMenu, Icon, &Import Settings`tCtrl + I, Download.ico,, 16
		Menu, ControlCenterDlg_FileMenu, Add, E&xit, ControlCenterDlg_GUIClose
		Menu, ControlCenterDlg_FileMenu, Icon, E&xit, Exit.ico,, 16

		; Edit
		Menu, ControlCenterDlg_EditMenu, Add, &Record`tCtrl + R, ControlCenterDlg_RecordBtn
		Menu, ControlCenterDlg_EditMenu, Icon, &Record`tCtrl + R, Red.ico,, 16
		Menu, ControlCenterDlg_EditMenu, Add, &Undo`tCtrl + Z, ControlCenterDlg_UndoOnceBtn
		Menu, ControlCenterDlg_EditMenu, Icon, &Undo`tCtrl + Z, Rotate 3D.ico,, 16
		Menu, ControlCenterDlg_EditMenu, Add, &Gesture Settings`tCtrl + G, ControlCenterDlg_EditMenu_GestureConfig
		Menu, ControlCenterDlg_EditMenu, Icon, &Gesture Settings`tCtrl + G, Config.ico,, 16

		; Help
		Menu, ControlCenterDlg_HelpMenu, Add, &About`tF1, ControlCenterDlg_HelpMenu_About
		Menu, ControlCenterDlg_HelpMenu, Icon, &About`tF1, Info.ico,, 16

		Menu, ControlCenterDlg_MainMenu, Add, &File, :ControlCenterDlg_FileMenu
		Menu, ControlCenterDlg_MainMenu, Add, &Edit, :ControlCenterDlg_EditMenu
		Menu, ControlCenterDlg_MainMenu, Add, &Help, :ControlCenterDlg_HelpMenu

		GUI, Menu, ControlCenterDlg_MainMenu

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: MakeControlCenterDlg
			Purpose: To create the Control Center Dialog.
		Parameters
			
	*/
	MakeControlCenterDlg()
	{
		global

		; http://msdn.microsoft.com/en-us/library/windows/desktop/aa511453.aspx#sizing
		static s_iMSDNStdBtnW := 75, s_iMSDNStdBtnH := 23, s_iMSDNStdBtnSpacing := 6

		GUI, ControlCenterDlg_:New, hwndg_hControlCenterDlg, % this.m_sLeapMC " Settings"

		;~ -------------------------------------------------------------------------------------------------------
		GUI, Font, s12 c83B8G7
		GUI, Add, GroupBox, % "x18 y11 h" 230+(s_iMSDNStdBtnSpacing*2)+s_iMSDNStdBtnH " w743 Center", Gestures Control Center
		GUI, Font, s8
		GUI, Add, Button, % "xp+588 yp+" 239+s_iMSDNStdBtnH+s_iMSDNStdBtnSpacing " w" s_iMSDNStdBtnW " h" s_iMSDNStdBtnH " vg_vControlCenterDlg_OKBtn gControlCenterDlg_OKBtn", &OK
		GUI, Add, Button, xp+80 yp wp hp vg_vControlCenterDlg_CancelBtn gControlCenterDlg_GUIClose, &Cancel ; This will bypass a Save
		;~ -------------------------------------------------------------------------------------------------------

		;~ -------------------------------------------------------------------------------------------------------
		GUI, Font, s10 c83B8G7
		GUI, Add, GroupBox, x22 y40 h232 w237 Center, Select or add a gesture
		GUI, Font, s8
		GUI, Add, Text, % "xp+" s_iMSDNStdBtnSpacing " yp+" s_iMSDNStdBtnH+2 " r1 vg_vControlCenterDlg_NameText", &Name:
		GUI, Add, Edit, xp+35 yp-3 w131 r1 vg_vControlCenterDlg_NameEdit hwndg_hControlCenterDlg_NameEdit gControlCenterDlg_NameEditProc
		GUI, Add, Button, xp+136 yp-1 w24 hp+2 hwndg_hControlCenterDlg_DeleteBtn vg_vControlCenterDlg_DeleteBtn gControlCenterDlg_DeleteBtn, `n`n`n&-
		ILButton(g_hControlCenterDlg_DeleteBtn, "Delete.ico", 16, 16, 4)
		GUI, Add, Button, xp+29 yp wp hp hwndg_hControlCenterDlg_AddGestureID vg_vControlCenterDlg_AddBtn gControlCenterDlg_AddGestureID, `n`n`n&=
		ILButton(g_hControlCenterDlg_AddGestureID,  "Add.ico", 16, 16, 4)
		GUI, Add, ListView, % "xp-201 yp+" s_iMSDNStdBtnH+2 " w225 r9 vg_vControlCenterDlg_GestureIDLV hwndg_hControlCenterDlg_GestureIDLV gControlCenterDlg_GestureLVProc Sort -Multi AltSubmit", Gesture Name
		LV_ModifyCol(1, 204)
		local sLocGestures := this.m_vGesturesIni.GetSections()
		Loop, Parse, sLocGestures, `n
			LV_Add("", A_LoopField)
		this.ControlCenterDlg_GestureLVProc()
		;~ -------------------------------------------------------------------------------------------------------

		;~ -------------------------------------------------------------------------------------------------------
		local sBtns := "Swipe_&Left|Swipe_&Right|Swipe_&Up|Swipe_Fw&d|&KeyTap|Circle_Lef&t|Circle_Ri&ght|Swipe_Do&wn|Swipe_&Bwd|&ScreenTap"
		local aBtns
		local iGestureBtnSpacing := (s_iMSDNStdBtnW+1)
		StringSplit, aBtns, sBtns, |
		local iNumCols := aBtns0/2

		GUI, Font, s10 c83B8G7
		GUI, Add, GroupBox, % "x263 y40 h" (s_iMSDNStdBtnH*2)+(s_iMSDNStdBtnSpacing*7) " w" s_iMSDNStdBtnW*5+s_iMSDNStdBtnSpacing*3 " Center", Press to insert gesture
		GUI, Font, s8

		Loop %aBtns0%
		{
			local sBtnName, sBtnLabel
			StringReplace, sBtnLabel, aBtns%A_Index%, _, %A_Space%, All
			StringReplace, sBtnName, aBtns%A_Index%, &,, All

			if (sBtnName = "Swipe_Bwd")
				sBtnName := "Swipe_Backward"
			else if (sBtnName = "Swipe_Fwd")
				sBtnName := "Swipe_Forward"

			if (A_Index == 1)
			{
				GUI, Add, Button, % "xp+" s_iMSDNStdBtnSpacing " yp+" s_iMSDNStdBtnH " w" s_iMSDNStdBtnW " h" s_iMSDNStdBtnH " gControlCenterDlg_GestureBtnProc vg_vControlCenterDlg_" sBtnName "Btn", %sBtnLabel%
			}
			else if (A_Index == iNumCols+1)
			{
				GUI, Add, Button, % "xp-" (iGestureBtnSpacing)*(iNumCols-1) " yp+" s_iMSDNStdBtnH+s_iMSDNStdBtnSpacing " wp hp gControlCenterDlg_GestureBtnProc vg_vControlCenterDlg_" sBtnName "Btn", %sBtnlabel%
			}
			else
			{
				GUI, Add, Button, % "xp+" iGestureBtnSpacing " yp wp hp gControlCenterDlg_GestureBtnProc vg_vControlCenterDlg_" sBtnName "Btn", %sBtnLabel%
			}
		}
		;~ -------------------------------------------------------------------------------------------------------

		GUI, Font, s12 c83B8G7
		GUI, Add, Edit, xp-310 yp+51 r6 w409 ReadOnly -TabStop vg_vControlCenterDlg_GestureChainEdit
		GUI, Font, s8
		GUI, Add, Button, xp+415 yp+45 w%s_iMSDNStdBtnW% h%s_iMSDNStdBtnH% vg_vControlCenterDlg_RecordBtn gControlCenterDlg_RecordBtn, Record
		GUI, Add, Button, xp yp+30 w%s_iMSDNStdBtnW% h%s_iMSDNStdBtnH% vg_vControlCenterDlg_UndoOnceBtn gControlCenterDlg_UndoOnceBtn, U&ndo Once
		GUI, Add, Button, xp yp+30 wp hp vg_vControlCenterDlg_ClearBtn gControlCenterDlg_ClearBtn, Cle&ar

		this.ControlCenterDlg_AddAllMenuItems()

		return

		; TODO: If _AutoLeap fails on unique PIDs, then make dlg name ControlCenterDlgN, and pass this on.
		ControlCenterDlg_NameEditProc:
		ControlCenterDlg_AddGestureID:
		ControlCenterDlg_DeleteBtn:
		ControlCenterDlg_GestureLVProc:
		ControlCenterDlg_RecordBtn:
		ControlCenterDlg_UndoOnceBtn:
		ControlCenterDlg_ClearBtn:
		ControlCenterDlg_OKBtn:
		ControlCenterDlg_Save:
		ControlCenterDlg_SaveAs:
		ControlCenterDlg_Import:
		ControlCenterDlg_HelpMenu_About:
		{
			if (IsFunc("LeapDlgs." A_ThisLabel))
				_Dlgs()[A_ThisLabel]()
			else Msgbox, 8208,, % "An internal error occured within the dialog procedure`n`nThis function does not exist: " A_ThisLabel

			return
		}

		ControlCenterDlg_GestureBtnProc:
		{
			_Dlgs()[A_ThisLabel](A_GUIControl)
			return
		}

		ControlCenterDlg_EditMenu_GestureConfig:
		{
			_Dlgs().ShowGesturesConfigDlg(g_hControlCenterDlg)
			return
		}

		ControlCenterDlg_GUIEscape:
		ControlCenterDlg_GUIClose:
		{
			_Dlgs().ControlCenterDlg_Close()
			return
		}
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ShowControlCenterDlg
			Purpose: For launching the dialog
		Parameters
			hOwner: Optional window handle to the owner of this dialog.
			sSelect: Existing gesture name to select.
			bReloadOnExit: If true, reloads AutoLeap.exe after the dialog has been dismissed.
	*/
	ShowControlCenterDlg(hOwner=0, sSelect="", bReloadOnExit=true)
	{
		this._SetLV()

		this.m_vGesturesIni := this.m_vGesturesIni.Reload() ; Need to be certain that ini is up-to-date!
		; Note: ObjClone was incorrectly copying the address instead of the memory.
		this.m_vOriginalGesturesIni := EasyIni.Copy(this.m_vGesturesIni, false)
		this.m_bControlCenterDlg_IsSaved := true

		if (hOwner)
		{
			global g_hControlCenterDlgOwner := hOwner
			GUI, +Owner%g_hControlCenterDlgOwner%
			WinSet, Disable,, ahk_id %g_hControlCenterDlgOwner%
		}

		this.LoadGestureIDs(sSelect)

		GUI, Show, x-32768 AutoSize
		if (g_hControlCenterDlgOwner)
			this.CenterWndOnOwner(this.m_hControlCenterDlg, g_hControlCenterDlgOwner)

		; Wait for dialog to be dismissed
		this.m_bSubmit := false ; See ControlCenterDlg_OKBtn.
		while (WinExist("ahk_id" this.m_hControlCenterDlg))
		{
			if (hOwner && !WinExist("ahk_id" hOwner))
				break ; If the owner was closed somehow, then this dialog should also be closed.
			continue
		}

		if (bReloadOnExit)
			_AutoLeap().Reload()

		if (!this.m_bSubmit)
			return
		return this.GetSelText()
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: LoadGestureIDs
			Purpose: To load gesture IDs into the LV
		Parameters
			
	*/
	LoadGestureIDs(sSelect="")
	{
		; Update the LV with the (possibly new) gestures from this.m_vGesturesIni.
		LV_Delete()
		sGestureIDs := this.m_vGesturesIni.GetSections()
		Loop, Parse, sGestureIDs, `n
			LV_Add("", A_LoopField)

		this.m_bSelectInEdit := true ; so that we select the whole gesture ID in the edit.
		if (sSelect == A_Blank)
			this.SetSel(1) ; Select and focus the first item in the LV.
		else this.SetSelText(sSelect) ; Select and focus this item in the LV.

		GUIControl, Focus, g_vControlCenterDlg_NameEdit
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	GesturesConfigDlg_AddAllMenuItems()
	{
		GUI, GesturesConfigDlg_:Default

		; File
		Menu, GesturesConfigDlg_FileMenu, Add, &Save`tCtrl + S, GesturesConfigDlg_Save
		Menu, GesturesConfigDlg_FileMenu, Icon, &Save`tCtrl + S, Save.ico,, 16
		Menu, GesturesConfigDlg_FileMenu, Add, Save &As...`tCtrl + Alt + S, GesturesConfigDlg_SaveAs
		Menu, GesturesConfigDlg_FileMenu, Icon, Save &As...`tCtrl + Alt + S, Save As.ico,, 16
		Menu, GesturesConfigDlg_FileMenu, Add, &Import Settings`tCtrl + I, GesturesConfigDlg_Import
		Menu, GesturesConfigDlg_FileMenu, Icon, &Import Settings`tCtrl + I, Download.ico,, 16
		Menu, GesturesConfigDlg_FileMenu, Add, E&xit, GesturesConfigDlg_GUIClose
		Menu, GesturesConfigDlg_FileMenu, Icon, E&xit, Exit.ico,, 16

		Menu, GesturesConfigDlg_MainMenu, Add, &File, :GesturesConfigDlg_FileMenu

		GUI, Menu, GesturesConfigDlg_MainMenu

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: MakeGesturesConfigDlg
			Purpose: User interface to adjust senstivity of Leap gestures
		Parameters
			None
	*/
	MakeGesturesConfigDlg()
	{
		global
		SetFormat, float, 2.2

		; http://msdn.microsoft.com/en-us/library/windows/desktop/aa511453.aspx#sizing
		static s_iMSDNStdBtnW := 75, s_iMSDNStdBtnH := 23, s_iMSDNStdBtnSpacing := 6

		local vDefaultConfigIni := class_EasyIni("", _AutoLeap().GetDefaultGesturesConfigIni())
		this.m_vGesturesConfigIni.Merge(vDefaultConfigIni)

		GUI, GesturesConfigDlg_:New, hwndg_hGesturesConfigDlg MinSize, Gesture Settings

		GUI, Add, Groupbox, xm w180 vvGestureBox Center, Enable or Disable
		GUIControlGet, iGestureBoxPos, Pos, vGestureBox ; Needed for dynamic position of controls to follow.
		GUI, Add, Checkbox, xp+5 yp+20 vEnableCircle gGesturesConfigDlg_GestureCheckProc, Circles
		GUI, Add, Checkbox, xp+82 yp vEnableSwipe gGesturesConfigDlg_GestureCheckProc, Swipes
		GUI, Add, Checkbox, xm+5 yp+20 vEnableKeyTap gGesturesConfigDlg_GestureCheckProc, KeyTaps
		GUI, Add, Checkbox, xp+82 yp vEnableScreenTap gGesturesConfigDlg_GestureCheckProc, ScreenTaps

		iSliderFarLeft := iGestureBoxPosX+25
		iNewRow := 3
		iNdx := 0
		for key, val in this.m_vGesturesConfigIni.Sliders
		{
			sTxtX := "X" iSliderFarLeft

			if (iNdx == iNewRow)
			{
				iNdx := 0
				sTxtY := ""
			}
			else
			{
				if (A_Index == 1)
				{
					sTxtY := "YP+40"
				}
				else
				{
					sTxtY := "YP-30"
					if (iNdx == 0)
						sTxtX := "X" iSliderFarLeft
					else sTxtX := "X" iSliderFarLeft+(iNdx*200)
				}
			}

			iMin := 1
			iMax := iSliderMax := this.m_vGesturesConfigMaxValsMapping[key]

			if (InStr(key, "seconds") || InStr(key, "MinArc"))
			{
				iMin *= 0.01
				iSliderMax *= 100
			}

			StringReplace, sCtrlBaseName, key, `., PERIOD, All

			GUI, Font, cBlue
			GUI, Add, Text, %sTxtX% %sTxtY% w180 r2 vv%sCtrlBaseName%_MainText
			GUI, Font, cBlack
			GUI, Add, Text, xp yp Vv%sCtrlBaseName%_LeftText, %iMin%
			GUI, Add, Text, xp yp Vv%sCtrlBaseName%_RightText, %iMax%

			GUI, Add, Slider, % sTxtX " YP+30 vv" sCtrlBaseName "_Slider gGesturesConfigDlg_SliderProc AltSubmit TickInterval1 Buddy1v" sCtrlBaseName "_LeftText Buddy2v" sCtrlBaseName "_RightText Range0-" iSliderMax

			iNdx++
		}
		SetFormat, integer, d

		GUIControlGet, iLastSliderPos, Pos, v%sCtrlBaseName%_Slider
		iGestureBoxW := (180+iSliderFarLeft)*iNewRow
		iTotalBtnSpacing := s_iMSDNStdBtnW+s_iMSDNStdBtnSpacing
		iDefaultBtnY := iLastSliderPosY+iLastSliderPosH+15
		iOKBtnXSansMargin := iGestureBoxW-s_iMSDNStdBtnW-iTotalBtnSpacing
		GUI, Add, Button, xm Y%iDefaultBtnY% w%s_iMSDNStdBtnW% h%s_iMSDNStdBtnH% gGesturesConfigDlg_DefaultBtn, &Default
		GUI, Add, Button, xm+%iOKBtnXSansMargin% yp wp hp vvGesturesConfigDlg_OKBtn gGesturesConfigDlg_OKBtn, &OK
		GUI, Add, Button, xp+%iTotalBtnSpacing% yp wp hp vvGesturesConfigDlg_CancelBtn gGesturesConfigDlg_GUIClose, &Cancel

		; Add the encompassing GroupBox *afterwards* so that we can dynamically place it based upon the last sliders that were added.
		iBoxY := iGestureBoxPosY+iGestureBoxPosH
		iBoxH := iLastSliderPosY+iLastSliderPosH-iBoxY+10
		GUI, Add, Groupbox, Xm Y%iBoxY% W%iGestureBoxW% H%iBoxH% Center, Sensitivity

		this.GesturesConfigDlg_AddAllMenuItems()
		this.LoadSettings()

		return

		GesturesConfigDlg_SliderProc:
		GesturesConfigDlg_GestureCheckProc:
		{
			Critical
			if (IsFunc("LeapDlgs." A_ThisLabel))
				_Dlgs()[A_ThisLabel]()
			else Msgbox, 8208,, % "An internal error occured within the dialog procedure`n`nThis function does not exist: " A_ThisLabel

			return
		}

		GesturesConfigDlg_DefaultBtn:
		GesturesConfigDlg_SaveAs:
		GesturesConfigDlg_Save:
		GesturesConfigDlg_Import:
		GesturesConfigDlg_OKBtn:
		{
			if (IsFunc("LeapDlgs." A_ThisLabel))
				_Dlgs()[A_ThisLabel]()
			else Msgbox, 8208,, % "An internal error occured within the dialog procedure`n`nThis function does not exist: " A_ThisLabel

			return
		}

		GesturesConfigDlg_GUIEscape:
		GesturesConfigDlg_GUIClose:
		{
			_Dlgs().GesturesConfigDlg_GUIClose()
			return
		}
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GesturesConfigDlg_SliderProc
			Purpose: To modify settings in m_vGesturesConfigIni via slider events
		Parameters
			None
	*/
	GesturesConfigDlg_SliderProc()
	{
		GUIControlGet, iVal,, %A_GuiControl%
		iAdjVal := this.GeturesConfigDlg_UpdateSliderCtrl(A_GuiControl, iVal, true)

		if (A_GuiEvent == 5)
			return ; 5 means that the user is dragging the slider.

		key := this.KeyFromSliderCtrl(A_GuiControl)
		if (this.m_vGesturesConfigIni.Sliders[key] != iAdjVal)
		{
			this.m_vGesturesConfigIni.Sliders[key] := iAdjVal
			this.m_bGesturesConfigDlg_IsSaved := false
		}

		SetFormat, Integer, d
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GesturesConfigDlg_GestureCheckProc
			Purpose: To modify settings in m_vGesturesConfigIni via checkbox events or sCtrl
		Parameters
			sCtlr="": Should be a valid GUIControl parm.
	*/
	GesturesConfigDlg_GestureCheckProc(sCtrl="")
	{
		if (sCtrl == A_Blank)
			sCtrl := A_GuiControl
		GUIControlGet, bEnable,, %sCtrl%

		if (this.m_vGesturesConfigIni.AvailableGestures.HasKey(sCtrl))
		{
			if (this.m_vGesturesConfigIni.AvailableGestures[sCtrl] != bEnable)
			{
				this.m_vGesturesConfigIni.AvailableGestures[sCtrl] := bEnable
				this.m_bGesturesConfigDlg_IsSaved := false
			}
		}
		else Msgbox Assert.`n`nKey not found in ini: %sCtrl%.

		sPartKey := SubStr(sCtrl, InStr(sCtrl, "Enable")+6) "."
		aKeys := this.m_vGesturesConfigIni.FindKeys("Sliders", "Ai)" sPartKey) ; Anchored, case-insensitive.
		for k, v in aKeys
		{
			sCtrl := this.SliderCtrlFromKey(v)
			sCtrlBaseName := this.CtrlBaseNameFromKey(v)
			sMainTxtCtrl := sCtrlBaseName "_MainText"
			sLeftTxtCtrl := sCtrlBaseName "_LeftText"
			sRightTxtCtrl := sCtrlBaseName "_RightText"
			sEnableDisable := (bEnable ? "Enable" : "Disable")
			GUIControl, %sEnableDisable%, %sCtrl%
			GUIControl, %sEnableDisable%, %sMainTxtCtrl%
			GUIControl, %sEnableDisable%, %sLeftTxtCtrl%
			GUIControl, %sEnableDisable%, %sRightTxtCtrl%
		}

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GeturesConfigDlg_UpdateSliderCtrl
			Purpose: Some sliders are handling differently than others; this function takes care of the specifics.
			Returns the adjusted value derived from iVal.
		Parameters
			sSlider
			iVal
			bDivideForSave: Saving functions will need to divide certain slider values by 100.
	*/
	GeturesConfigDlg_UpdateSliderCtrl(sSlider, iVal, bDivideForSave)
	{
		SetFormat, Float, 2.2

		key := this.KeyFromSliderCtrl(sSlider)

		if (iVal == 0)
			iVal := 1

		iValForSlider := iVal
		iValToReturn := iVal

		bIsMinArc := InStr(sSlider, "MinArc")
		if (InStr(sSlider, "seconds") || bIsMinArc)
		{
			SetFormat, Float, 2.2

			if (bDivideForSave)
				iValToReturn /= 100.00

			if (bIsMinArc)
			{
				iMinArcMult := iValToReturn*this.m_iPI
				if (!bDivideForSave)
					iValForSlider *= 100
			}
			else
			{
				if (!bDivideForSave)
					iValForSlider *= 100
			}
		}
		else SetFormat, integer, d

		StringLeft, sCtrlBaseName, sSlider, % InStr(sSlider, "_Slider")-1
		sHelperCtrl := sCtrlBaseName "_MainText"

		if (bIsMinArc)
		{
			sHelperTxt := this.m_vGesturesConfigLabelsMapping[key] ":`n" iValToReturn " " 
			sWithUnits := this.m_vGesturesConfigUnitsMapping[key]
			StringReplace, sWithoutUnits, sWithUnits, radians,, All
			StringReplace, sWithUnits, sWithUnits, (*PI),, All
			sHelperTxt .= sWithoutUnits "= " iMinArcMult "" sWithUnits
		}
		else sHelperTxt := this.m_vGesturesConfigLabelsMapping[key] ":`n" iValToReturn " " this.m_vGesturesConfigUnitsMapping[key]

		GUIControl,, %sSlider%, %iValForSlider%
		GUIControl,, %sHelperCtrl%, %sHelperTxt%

		SetFormat, Integer, d
		return iValToReturn
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GesturesConfigDlg_DefaultBtn
			Purpose: To restore m_vGesturesConfigIni to default settings.
		Parameters
			None
	*/
	GesturesConfigDlg_DefaultBtn()
	{
		this.m_vGesturesConfigIni := class_EasyIni(this.m_vGesturesConfigIni.GetFileName(), _AutoLeap().GetDefaultGesturesConfigIni())
		this.m_bGesturesConfigDlg_IsSaved := false

		; Gesture sensitivity sliders.
		this.LoadSettings()
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: LoadSettings
			Purpose: Loading keys and values from Config.ini into their appropriate sliders
				
		Parameters
			None
	*/
	LoadSettings()
	{
		GUI, GesturesConfigDlg_:Default

		; Gesture enabling/disabling.
		for key, val in this.m_vGesturesConfigIni.AvailableGestures
			GUIControl,, %key%, %val%

		; Enable/Disable sliders.
		sChecks := "EnableCircle|EnableSwipe|EnableKeyTap|EnableScreenTap"
		Loop, Parse, sChecks, |
			this.GesturesConfigDlg_GestureCheckProc(A_LoopField)

		; Load values into sliders.
		for key, val in this.m_vGesturesConfigIni.Sliders
		{
			sSliderCtrl := this.SliderCtrlFromKey(key)
			this.GeturesConfigDlg_UpdateSliderCtrl(sSliderCtrl, val, false)
		}

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GesturesConfigDlg_SaveAs
			Purpose:
		Parameters
			To export settings to an ini.
	*/
	GesturesConfigDlg_SaveAs()
	{
		GUI GesturesConfigDlg_: +OwnDialogs

		FileSelectFile, sFile, S, % this.m_vGesturesConfigIni.GetFileName(), Select a location to save ini, *ini

		if (sFile != A_Blank && this.m_vGesturesConfigIni.Save(sFile, true))
			this._ShowSaveMsg(" to """ sFile """")

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GesturesConfigDlg_OKBtn
			Purpose:
		Parameters
			
	*/
	GesturesConfigDlg_OKBtn()
	{
		this.GesturesConfigDlg_Save()
		this.GesturesConfigDlg_GUIClose()
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GesturesConfigDlg_Save
			Purpose:
		Parameters
			None
	*/
	GesturesConfigDlg_Save()
	{
		this.m_vGesturesConfigIni.Save()
		this._ShowSaveMsg()

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GesturesConfigDlg_Import
			Purpose: To import exported settings from the gestures configuration dialog.
		Parameters
			
	*/
	GesturesConfigDlg_Import()
	{
		FileSelectFile, sFile, 1, % this.m_vGesturesConfigIni.GetFileName(), Select ini to import, *ini

		if (sFile)
		{
			this.m_vGesturesConfigIni := this.m_vGesturesConfigIni.Copy(sFile)

			; We aren't saved beacuse we just overwrote the original ini.
			; This gives a user a chance to revert the ini back to it's previous state.
			this.m_bGesturesConfigDlg_IsSaved := false

			this.LoadSettings()
		}

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GesturesConfigDlg_GUIClose
			Purpose:
		Parameters
			
	*/
	GesturesConfigDlg_GUIClose()
	{
		global g_hGesturesConfigDlgOwner

		; If the user, Canceled, Escaped, Alt+F4'd, etc.
		if (!this.m_bGesturesConfigDlg_IsSaved && (A_GuiControl = "&Cancel" || A_GuiControl == A_Blank))
		{
			MsgBox, 8228, % "Close Gesture Settings", Save your settings before closing?

			IfMsgBox Cancel
				return
			IfMsgBox No ; undo all changes.
			{
				this.m_vGesturesConfigIni := this.m_vGesturesConfigIni.Copy(this.m_vOriginalGesturesConfigIni) ; We don't want to save settings, so this use the old settings.
				this.m_vGesturesConfigIni.Save() ; Save, but don't alert the user because that will be confusing.
			}
			else IfMsgBox Yes
				this.GesturesConfigDlg_Save()
		}

		GUI, GesturesConfigDlg_:Hide
		if (g_hGesturesConfigDlgOwner)
		{
			GUI, ControlCenterDlg_:-Owner%g_hGesturesConfigDlgOwner%
			WInset, Enable,, ahk_id %g_hGesturesConfigDlgOwner%
			WinActivate, ahk_id %g_hGesturesConfigDlgOwner%
		}

		this.m_bGesturesConfigDlg_IsSaved := true
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ShowGesturesConfigDlg
			Purpose: To show the Gestures Configuration Dialog.
		Parameters
			hOwner: Optional window handle to the owner of this dialog
			bReloadOnExit: If true, reloads AutoLeap.exe once the dialog has been dismissed
	*/
	ShowGesturesConfigDlg(hOwner=0)
	{
		global g_hGesturesConfigDlgOwner
		GUI, GesturesConfigDlg_:Default

		if (this.m_bIsRecording)
		{
			this._ShowRecordError()
			return false
		}

		this.m_vGesturesConfigIni := this.m_vGesturesConfigIni.Reload() ; Need to be certain that ini is up-to-date!
		; Note: ObjClone was incorrectly copying the address instead of the memory.
		this.m_vOriginalGesturesConfigIni := EasyIni.Copy(this.m_vGesturesConfigIni, false)

		if (hOwner)
		{
			global g_hGesturesConfigDlgOwner := hOwner
			GUI, +Owner%g_hGesturesConfigDlgOwner%
			WinSet, Disable,, ahk_id %g_hGesturesConfigDlgOwner%
		}

		; Update with the (possibly new) options from this.m_vGesturesConfigIni.
		this.LoadSettings()

		GUI, Show, x-32768 AutoSize
		if (g_hGesturesConfigDlgOwner)
			this.CenterWndOnOwner(this.m_hGesturesConfigDlg, g_hGesturesConfigDlgOwner)

		; Wait for dialog to be dismissed.
		while (WinExist("ahk_id" this.m_hGesturesConfigDlg))
		{
			if (hOwner && !WinExist("ahk_id" hOwner))
				break ; If the owner was somehow closed, then this dialog should also be closed.
			continue
		}

		; Reload settings so they take effect in the exe.
		_AutoLeap().Reload()

		return true
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ControlCenterDlg_HelpMenu_About
			Purpose: To show the About dialog for license and credits.
		Parameters
			
	*/
	ControlCenterDlg_HelpMenu_About()
	{
		FileRead, sFile, % this.m_sLeapWorkingDir "\ReadMe.txt"
		this.ShowInfoDlg(sFile, this.m_hControlCenterDlg)
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ShowInfoDlg
			Purpose: To show an information dialog.
		Parameters
			sFile: File to display on dlg.
			hOwner: Owner to center wnd on.
			iWidthOverride: Specify this for a wider dialog.
	*/
	ShowInfoDlg(sFile, hOwner, iWidthOverride=450)
	{
		global
		; http://msdn.microsoft.com/en-us/library/windows/desktop/aa511453.aspx#sizing
		static s_iMSDNStdBtnW := 75, s_iMSDNStdBtnH := 23, s_iMSDNStdBtnSpacing := 6
		local iVersion, iFarRight, iBtnX

		StringReplace, sFile, sFile, `t, %A_Space%%A_Space%%A_Space%%A_Space%, All
		FileRead, iVersion, version
		StringReplace, sFile, sFile, `%VERSION`%, %iVersion%, All

		GUI, InfoDlg_:New, hwndg_hInfoDlg, %g_sName%

		iFarRight := iWidthOverride-s_iMSDNStdBtnW
		GUI, Add, Link, w%iFarRight%, %sFile%
		iBtnX := iFarRight-s_iMSDNStdBtnW-s_iMSDNStdBtnSpacing
		GUI, Add, Button, X%iBtnX% W%s_iMSDNStdBtnW% H%s_iMSDNStdBtnH% gInfoDlg_GUIEscape, &OK

		GUI, Show, x-32768 AutoSize
		this.CenterWndOnOwner(g_hInfoDlg, hOwner)

		Hotkey, IfWinActive, ahk_id %g_hInfoDlg%
			Hotkey, Enter, InfoDlg_GUIEscape
			Hotkey, NumpadEnter, InfoDlg_GUIEscape

		return

		InfoDlg_GUIEscape:
		InfoDlg_GUIClose:
		{
			GUI, InfoDlg_:Destroy
			return
		}
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	ControlCenterDlg_GestureLVProc()
	{
		static EM_SETSEL:=177

		if (A_GUIEvent = "K" && GetKeyState("A", "P"))
		{
			this.ControlCenterDlg_ClearBtn()
			return
		}

		if (A_GuiEvent = "S") ; Allow scrolling.
			return

		sGestureID := this.GetSelText()
		sGesture := this.m_vGesturesIni[sGestureID].Gesture

		GUIControl,, g_vControlCenterDlg_NameEdit, %sGestureID%
		GUIControl,, g_vControlCenterDlg_GestureChainEdit, % sGesture
		if (this.m_bSelectInEdit)
			SendMessage, EM_SETSEL, 0, -1,, % "ahk_id" this.m_hControlCenterDlg_NameEdit
		else SendMessage, EM_SETSEL, -2, -1,, % "ahk_id" this.m_hControlCenterDlg_NameEdit

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	ControlCenterDlg_GestureBtnProc(sBtn)
	{
		; Btn control names will be in the following format: g_vControlCenterDlg_(Gesture)_(Direction)Btn.
		sGesture := SubStr(sBtn, StrLen("g_vControlCenterDlg_")+1)
		StringLeft, sGesture, sGesture, StrLen(sGesture) -3
		StringReplace, sGesture, sGesture, _, % " ", All

		this.AppendGestureToName(sGesture)

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: AddGestureToName
			Purpose: To locaize logic of adding a gesture to a gesture name.
		Parameters
			sGesture: Gesture to add. May be a string chain of gestures such as, "Swipe Left, Swipe Right...etc".
				May also be an array of gestures; if so, this will be converted into a string chain.
			sGestureID: Name of gesture. If blank, is set to the selected gesture in the ControlCenterDlg LV.
	*/
	AddGestureToName(sGesture, sGestureID="")
	{
		GUI, ControlCenterDlg_:Default

		if (IsObject(sGesture))
			sGesture := st_glue(sGesture, ", ")

		if (sGesture == A_Blank)
			return

		if (sGestureID == A_Blank)
			sGestureID := this.GetGestureID()

		; If sGestureID does not exist, add it.
		if (!this.m_vGesturesIni.HasKey(sGestureID))
			this.ControlCenterDlg_AddGestureID(sGestureID)

		GUIControl,, g_vControlCenterDlg_GestureChainEdit, %sGesture% ; Replace the output with sGesture.

		this.m_vGesturesIni[sGestureID].Gesture := sGesture
		this.m_bControlCenterDlg_IsSaved := false

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function:AppendGestureToName
			Purpose: To localize logic of adding gestures to gesture names
		Parameters
			sGesture: Gesture to append
			sGestureID: Name of gesture. If blank, is set to the selected gesture in the ControlCenterDlg LV.
	*/
	AppendGestureToName(sGesture, sGestureID="")
	{
		GUI, ControlCenterDlg_:Default

		if (sGesture == A_Blank)
			return

		if (sGestureID == A_Blank)
			sGestureID := this.GetGestureID()

		; If sGestureID does not exist, add it.
		if (!this.m_vGesturesIni.HasKey(sGestureID))
			this.ControlCenterDlg_AddGestureID(sGestureID)

		GUIControlGet, sCurGestures,, g_vControlCenterDlg_GestureChainEdit

		sAllGestures := sGesture
		if (sCurGestures != A_Blank)
			sAllGestures := sCurGestures ", " sGesture

		GUIControl,, g_vControlCenterDlg_GestureChainEdit, %sAllGestures%

		this.m_vGesturesIni[sGestureID].Gesture := sAllGestures
		this.m_bControlCenterDlg_IsSaved := false

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	ControlCenterDlg_AddGestureID(sGestureID="")
	{
		if (sGestureID == A_Blank)
			sGestureID := this.GetGestureID()
		if (sGestureID == A_Blank)
			return

		if (this.m_bLastGestureIDExisted)
		{
			; Clear the output since that is specific to whatever gesture is selected in the LV...
			GUIControl,, g_vControlCenterDlg_GestureChainEdit
		}
		else
		{
			GUIControlGet, sGesture,, g_vControlCenterDlg_GestureChainEdit
			if (!this.ValidateGesture(sGestureID, sGesture, false, sError))
			{
				; Validate, but allow the adding no matter what.
				Msgbox, 8208,, %sError%
			}
		}

		GUIControlGet, sLastFocused, Focus
		GUIControlGet, hLastFocused, hWnd, %sLastFocused%

		; Add the gesture to the LV.
		LV_Add("", sGestureID)
		; Select the new gesture in the LV.
		this.SetSelText(sGestureID)

		; We forced a selection in the LV, so do LVProc.
		this.ControlCenterDlg_GestureLVProc()

		if (hLastFocused == this.m_hControlCenterDlg_GestureIDLV)
			GUIControl, Focus, g_vControlCenterDlg_GestureIDLV
		else GUIControl, Focus, g_vControlCenterDlg_NameEdit

		; Finally, add gesture to ini
		this.m_vGesturesIni.AddSection(sGestureID, "Gesture", sGesture)
		this.m_bControlCenterDlg_IsSaved := false

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	ControlCenterDlg_DeleteBtn()
	{
		GUIControlGet, sLastFocused, Focus
		GUIControlGet, hLastFocused, hWnd, %sLastFocused%

		; Retrieve values from LV, then delete this row.
		sLastSel := this.GetSelText()
		iLastSel := this.GetCurSel()
		LV_Delete(iLastSel)

		GUIControl,, g_vControlCenterDlg_NameEdit

		GUIControl, Choose, g_vControlCenterDlg_GestureIDLV, % (iLastSel <= 0 ? 1 : iLastSel)
		this.ControlCenterDlg_GestureLVProc()

		this.m_vGesturesIni.DeleteSection(sLastSel)
		this.m_bControlCenterDlg_IsSaved := false

		if (hLastFocused == this.m_hControlCenterDlg_GestureIDLV)
			GUIControl, Focus, g_vControlCenterDlg_GestureIDLV
		else GUIControl, Focus, g_vControlCenterDlg_NameEdit

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	ControlCenterDlg_NameEditProc()
	{
		this._SetLV()
		this.m_bSelectInEdit := false

		sGestureID := Trim(this.GetGestureID())

		if (!sGestureID)
			return

		if (this.m_vGesturesIni.HasKey(sGestureID))
		{
			; This gesture exists in the LV, so disable the add button.
			GUIControl, Disable, g_vControlCenterDlg_AddBtn

			; Find this gesture in the LV.
			this.SetSelText(sGestureID)

			; Update the output Edit with this gesture.
			GUIControl,, g_vControlCenterDlg_GestureChainEdit, % this.m_vGesturesIni[sGestureID].Gesture
		}
		else
		{
			GUIControl, Enable, g_vControlCenterDlg_AddBtn

			if (this.m_bLastGestureIDExisted)
				GUIControl,, g_vControlCenterDlg_GestureChainEdit, ; Clear the output.
		}

		this.m_bLastGestureIDExisted := this.m_vGesturesIni.HasKey(sGestureID)
		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	ControlCenterDlg_RecordBtn()
	{
		this._SetLV()

		this.m_bIsRecording := !this.m_bIsRecording ; Toggle.

		this.ControlCenterDlg_EnableDisableAllControls()

		if (this.m_bIsRecording)
		{
			GUIControl,, g_vControlCenterDlg_RecordBtn, Stop (Ctrl + R)
			GUIControl,, g_vControlCenterDlg_GestureChainEdit
			this.m_vGesturesIni[sGestureID].Gesture := ""
		}
		else ; finished recording, so restore Record button and register this gesture.
		{
			GUIControl,, g_vControlCenterDlg_RecordBtn, Record
			GUIControlGet, sInput,, g_vControlCenterDlg_GestureChainEdit
			sGestureToUse := this.GetSelText()
			this.GetGesturesIni()[sGestureToUse].Gesture := sInput
		}

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ControlCenterDlg_UndoOnceBtn
			Purpose: To remove the last gesture from the chain
		Parameters
			
	*/
	ControlCenterDlg_UndoOnceBtn()
	{
		GUI, ControlCenterDlg_:Default

		sGestureID := this.GetGestureID()
		GUIControlGet, sGestureChain,, g_vControlCenterDlg_GestureChainEdit

		if (sGestureChain == A_Blank)
			return

		; Remove final item from chain.
		iPosOfComma := InStr(sGestureChain, ",", false, -1) - 1
		if (iPosOfComma > 0) ; If there is a single gesture, then there won't be a comma.
			sGestureChain := SubStr(sGestureChain, 1, iPosOfComma) ; Search RTL.
		else sGestureChain := ""

		GUIControl,, g_vControlCenterDlg_GestureChainEdit, %sGestureChain%

		; Make changes in ini.
		this.m_vGesturesIni[sGestureID].Gesture := sGestureChain
		this.m_bControlCenterDlg_IsSaved := false

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ControlCenterDlg_ClearBtn
			Purpose: To clear out all gestures associated with the currently selected gesture ID (triggered by Clear button)
		Parameters
			
	*/
	ControlCenterDlg_ClearBtn()
	{
		GUI, ControlCenterDlg_:Default

		; Clear entire chain.
		GUIControl,, g_vControlCenterDlg_GestureChainEdit
		; Make changes in ini.
		this.m_vGesturesIni[this.GetGestureID()].Gesture := A_Blank
		this.m_bControlCenterDlg_IsSaved := false

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ControlCenterDlg_OKBtn
			Purpose:
		Parameters
			
	*/
	ControlCenterDlg_OKBtn()
	{
		if (!this.m_bControlCenterDlg_IsSaved)
		{
			if (this.ValidateAndSaveAllGestures(sError))
				this._ShowSaveMsg()
			else
			{
				Msgbox, 8208,, %sError%
				return
			}
		}

		this.m_bSubmit := true
		this.ControlCenterDlg_Close()
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	ControlCenterDlg_Save()
	{
		GUI ControlCenterDlg_: +OwnDialogs

		if (this.ValidateAndSaveAllGestures(sError))
			this._ShowSaveMsg()
		else if (sError != "Internal:IsRecording")
		{
			Msgbox, 8208,, %sError%
			return false
		}

		return true
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	ControlCenterDlg_SaveAs()
	{
		GUI ControlCenterDlg_: +OwnDialogs

		if (!this.ValidateAndSaveAllGestures(sError))
		{
			if (sError != "Internal:IsRecording")
				Msgbox, 8208,, %sError%
			return
		}

		FileSelectFile, sFile, S, % this.m_vGesturesIni.GetFileName(), Select a location to save ini, *ini

		if (sFile != A_Blank && this.m_vGesturesIni.Save(sFile, true))
			this._ShowSaveMsg(" to """ sFile """")

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ControlCenterDlg_Import
			Purpose: To import exported settings from the control center.
		Parameters
			
	*/
	ControlCenterDlg_Import()
	{
		FileSelectFile, sFile, 1, % this.m_vGesturesIni.GetFileName(), Select ini to import, *ini

		if (sFile)
		{
			this.m_vGesturesIni := this.m_vGesturesIni.Copy(sFile)

			; We aren't saved beacuse we just overwrote the original ini.
			; This gives a user a chance to revert the ini back to it's previous state.
			this.m_bControlCenterDlg_IsSaved := false

			this.LoadGestureIDs(this.GetSelText())
		}

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	ControlCenterDlg_Close()
	{
		if (this.m_bIsRecording)
		{
			MsgBox, 8228, % "Close Control Center", Are you sure that you want to stop recording?
			IfMsgBox No
				return

			this.ControlCenterDlg_RecordBtn() ; This will toggle the recording.
		}

		; If the user, Canceled, Escaped, Alt+F4'd, etc.
		if (!this.m_bControlCenterDlg_IsSaved && (A_GuiControl = "&Cancel" || A_GuiControl == A_Blank))
		{
			MsgBox, 8228, % "Close Control Center", Save your settings before closing?

			IfMsgBox Cancel
				return
			IfMsgBox No ; undo all changes.
			{
				this.m_vGesturesIni := this.m_vGesturesIni.Copy(this.m_vOriginalGesturesIni) ; We don't want to save settings, so this use the old settings.
				this.m_vGesturesIni.Save()
			}
			else IfMsgBox Yes
			{
				if (!this.ControlCenterDlg_Save())
					return
			}
		}

		GUI, ControlCenterDlg_:Hide
		if (this.m_hControlCenterDlgOwner)
		{
			GUI, % "ControlCenterDlg_:-Owner" this.m_hControlCenterDlgOwner
			WInSet, Enable,, % "ahk_id" this.m_hControlCenterDlgOwner
			WinActivate, % "ahk_id" this.m_hControlCenterDlgOwner
		}

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	ControlCenterDlg_EnableDisableAllControls(bEnable="")
	{
		if (bEnable == "")
			bEnable := !this.m_bIsRecording

		if (bEnable)
			s := "Enable"
		else
		{
			s := "Disable"
			GUIControlGet, sFocus, Focus
			this.m_sLastFocus := sFocus
		}

		; Keep order in the order they are added in MakeControlCenterDlg().
		GUIControl, %s%, g_vControlCenterDlg_OKBtn
		GUIControl, %s%, g_vControlCenterDlg_CancelBtn
		GUIControl, %s%, g_vControlCenterDlg_NameText
		GUIControl, %s%, g_vControlCenterDlg_NameEdit
		GUIControl, %s%, g_vControlCenterDlg_DeleteBtn ; Note: At this point the add button should always be disabled.
		GUIControl, %s%, g_vControlCenterDlg_GestureIDLV
		GUIControl, %s%, g_vControlCenterDlg_Swipe_LeftBtn
		GUIControl, %s%, g_vControlCenterDlg_Swipe_RightBtn
		GUIControl, %s%, g_vControlCenterDlg_Swipe_UpBtn
		GUIControl, %s%, g_vControlCenterDlg_Swipe_ForwardBtn
		GUIControl, %s%, g_vControlCenterDlg_KeyTapBtn
		GUIControl, %s%, g_vControlCenterDlg_Circle_LeftBtn
		GUIControl, %s%, g_vControlCenterDlg_Circle_RightBtn
		GUIControl, %s%, g_vControlCenterDlg_Swipe_DownBtn
		GUIControl, %s%, g_vControlCenterDlg_Swipe_BackwardBtn
		GUIControl, %s%, g_vControlCenterDlg_ScreenTapBtn
		GUIControl, %s%, g_vControlCenterDlg_GestureChainEdit
		GUIControl, %s%, g_vControlCenterDlg_ClearBtn

		if (bEnable)
			GUIControl, Focus, % this.m_sLastFocus

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	ControlCenterDlg_GetLastGesture()
	{
		sGestureID := this.GetGestureID()

		if (iPosOfLastComma := InStr(this.m_vGesturesIni[sGestureID].Gesture, ",", false, -1))
			sLastGesture := SubStr(this.m_vGesturesIni[sGestureID].Gesture, iPosOfLastComma + 2)
		else sLastGesture := this.m_vGesturesIni[sGestureID].Gesture

		StringReplace, sLastGesture, sLastGesture, % " ", _, All
		return sLastGesture
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ValidateAndSaveAllGestures
			Purpose:To validate that no gesture conflicts with another in this.m_vGesturesIni.
		Parameters
			rsError: So that gestures may be validated from outside the context of this class without getting a MsgBox.
	*/
	ValidateAndSaveAllGestures(ByRef rsError)
	{
		if (this.m_bIsRecording)
		{
			this._ShowRecordError()
			rsError := "Internal:IsRecording"
			return false
		}

		for sec, aData in this.m_vGesturesIni
		{
			for subSec, aSubData in this.m_vGesturesIni
			{
				if (sec = subSec)
					continue ; Skip over its own section.

				; Validate against any gesture conflict within the ini.
				if (aData.Gesture = aSubData.Gesture)
				{
					rsError := this._GetGestureError(sec, aData.Gesture, subSec, aSubData.Gesture)
					return false
				}
			}
		}

		this.m_vGesturesIni.Save()
		return true
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ValidateGesture
			Purpose:To validate sGesture does not conflict with another gesture in this.m_vGesturesIni.
		Parameters
			sGesture
			rsError: So that gestures may be validated from outside the context of this class without getting a MsgBox.
	*/
	ValidateGesture(sGestureID, sGesture, bSkipMatchingName=false, ByRef rsError="")
	{
		if ((sGesture == A_Blank && !this.m_vGesturesIni.HasKey(sGestureID))
			|| (sGesture == A_Blank && bSkipMatchingName && this.m_vGesturesIni.HasKey(sGestureID)))
			return true

		for sec, aData in this.m_vGesturesIni
		{
			if (bSkipMatchingName && sec = sGestureID)
				continue

			; Validate that sGesture does not conflict with any gestures within the ini
			if (aData.Gesture = sGesture)
			{
				rsError := this._GetGestureError(sec, aData.Gesture, sGestureID, sGesture)
				return false
			}
		}

		return true
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ValidateSelGesture
			Purpose: To validate the selected gesture in the LV
		Parameters
			None
	*/
	ValidateSelGesture()
	{
		sGestureID := this.GetSelText()
		sGesture := this.m_vGesturesIni[sGestureID].Gesture

		if (!this.ValidateGesture(sGestureID, sGesture, true, sError))
		{
			Msgbox, 8208,, %sError%
			return false
		}

		return true
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	ControlCenterDlg_OnKeyDown(wParam, lParam, msg, hWnd)
	{
		if (this.m_bIsRecording)
			return ; All controls, except for the record button, should be disabled, so nothing to do but forward the keys.

		if (hWnd == this.m_hControlCenterDlg_NameEdit || hWnd == this.m_hControlCenterDlg_GestureIDLV)
		{
			iCurSel := this.GetCurSel()
			iCnt := this.GetCount()

			bIsUp :=			(wParam == GetKeyVK("Up"))
			bIsDown :=	(wParam == GetKeyVK("Down"))
			bIsPgUp :=	(wParam == GetKeyVK("PgUp"))
			bIsPgDn :=	(wParam == GetKeyVK("PgDn"))
			bIsDelete :=	(wParam == GetKeyVK("Delete"))

			this.m_bSelectInEdit := true
			if (bIsUp)
			{
				this.SetSel((iCurSel-1 < 0 ? iCnt-1 : iCurSel-1))
				this.ControlCenterDlg_GestureLVProc()
				return 0 ; Prevents Edit from acting on WM_KeyDown.
			}
			else if (bIsDown)
			{
				this.SetSel((iCurSel+1 > iCnt ? 1 : iCurSel+1))
				this.ControlCenterDlg_GestureLVProc()
				return 0
			}
			else if (bIsPgUp || bIsPgDn)
			{
				; Unfortuntaely, WinGet...ControlList seems to be the only reliable way to retrieve the class name of the LV;
				; furthermore, ControlSend to the CLASS name of the control seems to be the only reliable way the send keys.
				WinGet, ActiveControlList, ControlList, A
				Loop, Parse, ActiveControlList, `n
				{
					GUIControlGet, hWnd, hWnd, %A_LoopFIeld%
					if (hWnd == this.m_hControlCenterDlg_GestureIDLV)
					{
						sCtrlClass := A_LoopField
						break
					}
				}

				; Note: If sCtrlClass is blank, then there is a likely a problem with WinGet, and that is unlikely.
				ControlSend, %sCtrlClass%, % (bIsPgUp ? "{PgUp}" : "{PgDn}"), % "ahk_id" this.m_hControlCenterDlg
				this.ControlCenterDlg_GestureLVProc()

				return 0
			}
			else if (hWnd == this.m_hControlCenterDlg_GestureIDLV && bIsDelete)
			{
				this.ControlCenterDlg_DeleteBtn()
				return 0
			}
		}

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: CenterWndOnOwner
			Purpose:
		Parameters
			hWnd: Window to center.
			hOwner=0: Owner of hWnd with which to center hWnd upon. If 0 or WinGetPos fails,
				window is centered on primary monitor.
	*/
	CenterWndOnOwner(hWnd, hOwner=0)
	{
		WinGetPos,,, iW, iH, ahk_id %hWnd%

		WinGetPos, iOwnerX, iOwnerY, iOwnerW, iOwnerH, ahk_id %hOwner%
		if (iOwnerX == A_Blank)
		{
			iOwnerX := 0
			iOwnerY := 0
			iOwnerW := A_ScreenWidth
			iOwnerH := A_ScreenHeight
		}

		iXPct := (100 - ((iW * 100) / (iOwnerW)))*0.5
		iYPct := (100 - ((iH * 100) / (iOwnerH)))*0.5

		iX := Round((iXPct / 100) * iOwnerW + iOwnerX)
		iY := Round((iYPct / 100) * iOwnerH + iOwnerY)

		WinMove, ahk_id %hWnd%, , iX, iY

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

/*
	private:
*/

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	_SetLV()
	{
		if (WinActive("ahk_id" this.m_hGesturesConfigDlg))
			LV_SetDefault("GesturesConfigDlg_", "g_vGesturesConfigDlg_LV")
		else LV_SetDefault("ControlCenterDlg_", "g_vControlCenterDlg_GestureIDLV")

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	_GetGestureError(sGestureID1, sGesture1, sGestureID2, sGesture2)
	{
		return "Error: Duplicate gesture definitions found.`n`n" sGestureID1 ":`t" sGesture1 "`n" sGestureID2 ":`t" sGesture2
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	_ShowRecordError()
	{
		Msgbox, 8208,, You cannot perform this action while you are recording a gesture.
		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: _ShowSaveMsg
			Purpose: To reduce cloning because this message needs to be displayed from multiple contexts.
		Parameters
			sOptMsg: Any additional message to append.
	*/
	_ShowSaveMsg(sOptMsg="")
	{
		bSaveControlCenterIni := (WinActive("ahk_id" this.m_hControlCenterDlg))
		bSaveGesturesConfigIni := (WinActive("ahk_id" this.m_hGesturesConfigDlg))

		Msgbox, 8256,, % "Your settings have been saved" sOptMsg

		if (bSaveControlCenterIni)
			this.m_bControlCenterDlg_IsSaved := true
		else if (bSaveGesturesConfigIni)
			this.m_bGesturesConfigDlg_IsSaved := true
		else
		{
			if (!A_IsCompiled)
				Msgbox, 8208,, Assert!`nSomehow neither expected dialogs are active.`nSettings will not be saved.
		}

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; Member variables
	m_bLastGestureIDExisted					:= true ; Because the first gesture is always selected by default.
	m_bControlCenterDlg_IsSaved		:= true
	m_bGesturesConfigDlg_IsSaved		:= true
	m_hMsgHandlerFunc						:=
	m_vGesturesIni									:=
	m_vLeap												:=
	m_vGesturesConfigUnitsMapping	:= Object("Circle.MinRadius", "mm"
		, "Circle.MinArc", "(*pi) radians"
		, "Swipe.MinLength", "mm"
		, "Swipe.MinVelocity", "mm/s"
		, "KeyTap.MinDownVelocity", "mm/s"
		, "KeyTap.HistorySeconds", "s"
		, "KeyTap.MinDistance", "mm"
		, "ScreenTap.MinForwardVelocity", "mm/s"
		, "ScreenTap.HistorySeconds", "s"
		, "ScreenTap.MinDistance", "mm")
	m_vGesturesConfigMaxValsMapping := {"Circle.MinRadius":70
		, "Circle.MinArc":2.50
		, "Swipe.MinLength":800
		, "Swipe.MinVelocity":1500
		, "KeyTap.MinDownVelocity":450
		, "KeyTap.HistorySeconds":4.00
		, "KeyTap.MinDistance":75
		, "ScreenTap.MinForwardVelocity":700
		, "ScreenTap.HistorySeconds":4.00
		, "ScreenTap.MinDistance":150}
	m_vGesturesConfigLabelsMapping := {"Circle.MinRadius":"Radius for Circles"
		, "Circle.MinArc":"Arcs for Circles"
		, "Swipe.MinLength":"Length for Swipes"
		, "Swipe.MinVelocity":"Velocity for Swipes"
		, "KeyTap.MinDownVelocity":"Downward velocity for KeyTaps"
		, "KeyTap.HistorySeconds":"Seconds for KeyTaps"
		, "KeyTap.MinDistance":"Distance for KeyTaps"
		, "ScreenTap.MinForwardVelocity":"Forward velocity for ScreenTaps"
		, "ScreenTap.HistorySeconds":"Seconds for ScreenTaps"
		, "ScreenTap.MinDistance":"Distance for ScreenTaps"}
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
ControlCenterDlg_OnKeyDown(wParam, lParam, msg, hWnd)
{
	if (WinActive("A") = _Dlgs().m_hControlCenterDlg)
		return _Dlgs().ControlCenterDlg_OnKeyDown(wParam, lParam, msg, hWnd)

	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;