class WM_Dlg
{
	__New()
	{
		global WM_Dlg

		; Spacing is deliberate to indicate that these dialogs are needed by the other one.
		this.HKDlg := new HKDlg("AddHKForSequence", "ModifyHKForSequence", "ValidateHK") ; Note: Pay close attention to the ShowHKDlg_ methods.
		this.PrecisionDlg := new PrecisionDlg("AddPrecisionItem", "ModifyPrecisionItem", "ValidatePrecisionItem", "ValidateHK") ; Also uses WindowSetDlg.

		this.SequenceDlg := new SequenceDlg("AddSequence", "ModifySequence")  ; Also uses WindowSetDlg.

		;~ this.LeapGesturesDlg := new LeapGestureDlg()

		WM_Dlg.1 := &this
	}

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ShowHKDlg_ForSequence
			Purpose:
		Parameters
			hOwner
			bFromEdit
	*/
	ShowHKDlg_ForSequence(hOwner, bFromEdit, sHKBeingEdited="", sGestureBeingEdited="", sAppendToTitle="Add a Sequence Hotkey")
	{
		global g_bHasLeap

		this.HKDlg.m_sAddFunc := "AddHKForSequence"
		this.HKDlg.m_sEditFunc := "ModifyHKForSequence"
		this.HKDlg.m_bMustHaveHotkey := !g_bHasLeap

		this.HKDlg.ShowDlg(hOwner, bFromEdit, sHKBeingEdited, sGestureBeingEdited, sAppendToTitle)

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ShowHKDlg_ForGenericLV
			Purpose:
		Parameters
			hOwner
	*/
	ShowHKDlg_ForGenericLV(hOwner,  sHKBeingEdited="", sGestureBeingEdited="", sAppendToTitle="")
	{
		global g_bHasLeap

		; No add function because, with the current design, you cannot add to the GenericLV (except for PrecisionDlg the override).
		this.HKDlg.m_sAddFunc := "" 
		this.HKDlg.m_sEditFunc := "GenericLV_ModifyHK"
		this.HKDlg.m_bMustHaveHotkey := !g_bHasLeap

		this.HKDlg.ShowDlg(hOwner, true, sHKBeingEdited, sGestureBeingEdited, sAppendToTitle)

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ShowHKDlg_ForLeap
			Purpose:
		Parameters
			hOwner
	*/
	ShowHKDlg_ForLeap(hOwner, sHKBeingEdited="", sGestureBeingEdited="", sAppendToTitle="")
	{
		; No add function because, with the current design, you cannot add to GenericLV (except for PrecisionDlg the override).
		this.HKDlg.m_sAddFunc := ""
		this.HKDlg.m_sEditFunc := "GenericLV_ModifyLeap"
		this.HKDlg.m_bMustHaveHotkey := false

		this.HKDlg.ShowDlg(hOwner, true, sHKBeingEdited, sGestureBeingEdited, sAppendToTitle)

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
}

class PrecisionDlg
{
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: __New
			Purpose:
		Parameters
			sAddFunc:
			sEditFunc:
			sValidateFunc:
	*/
	__New(sAddFunc, sEditFunc, sValidateFunc, sHKDlgValidateFunc)
	{
		global

		this.m_sAddFunc := sAddFunc
		this.m_sEditFunc := sEditFunc
		this.m_sValidateFunc := sValidateFunc

		this.m_iOldX := iX
		this.m_iOldY := iY
		this.m_iOldW := iW
		this.m_iOldH := iH

		GUI PrecisionDlg_: New, hwndg_hPrecisionDlg -MaximizeBox -MinimizeBox

		;------------------------------------------------------------------------
		GUI, Add, GroupBox, x5 y0 w165 r8, Placement
		GUI, Add, Text, x15 y25 w10 h13, %A_Space%x
		GUI, Add, Text, x15 y53 w8 hp, %A_Space%y
		GUI, Add, Text, x15 y81 w29 hp, %A_Space%width
		GUI, Add, Text, x15 y109 w33 hp, %A_Space%height
		GUI, Add, Edit, x92 y21 w40 h21 Limit5 Number vg_vEditX, %iX%
		GUI, Add, Edit, x92 y49 wp hp Limit5 Number vg_vEditY, %iY%
		GUI, Add, Edit, x92 y77 wp hp Limit5 Number vg_vEditW, %iW%
		GUI, Add, Edit, x92 y105 wp hp Limit5 Number vg_vEditH, %iH%
		GUI, Add, Button, x12 y146 w154 h23 gPrecisionDlg_WindowSet, &Set with Window
		;------------------------------------------------------------------------

		;------------------------------------------------------------------------
		GUI, Add, GroupBox, x175 y0 w340 r14, Hotkey
		this.HKDlg := new HKDlg(this.m_sAddFunc, this.m_sEditFunc, sHKDlgValidateFunc, "PrecisionDlg_", 175, 20)
		;------------------------------------------------------------------------

		GUI, Add, Button, x356 y260 w%g_iMSDNStdBtnW% h%g_iMSDNStdBtnH% gPrecisionDlg_OK vg_vHKDlg_OKBtn, OK ; g_vHKDlg_OKBtn is currentl;y enable/disabled in Validate_Error_Msg, ValidateHK, and HKDlg_GestureDDLProc
		GUI, Add, Button, % "xp+" g_iMSDNStdBtnW+g_iMSDNStdBtnSpacing " yp wp hp gPrecisionDlg_Cancel", Cancel

		this.WindowSetDlg := new WindowSetDlg("PrecisionDlg_")

		return this

		; HKDlg overries.
		PrecisionDlg_WinProc:
		{
			g_vDlgs.PrecisionDlg.HKDlg.WinProc()
			return
		}
		PrecisionDlg_RecordHK:
		{
			g_vDlgs.PrecisionDlg.HKDlg.RecordHK()
			return
		}

		PrecisionDlg_LaunchGesturesDlg:
		{
			g_vDlgs.PrecisionDlg.HKDlg.LaunchGesturesDlg(g_hPrecisionDlg)
			return
		}

		PrecisionDlg_GestureDDLProc:
		{
			g_vDlgs.PrecisionDlg.HKDlg.GestureDDLProc()
			return
		}
		; End HKDlg overrides.
		PrecisionDlg_WindowSet:
		{
			g_vDlgs.PrecisionDlg.WindowSetDlg.ShowDlg(g_hPrecisionDlg, "PrecisionDlg_")
			return
		}
		PrecisionDlg_OK:
		{
			g_vDlgs.PrecisionDlg.GUIOK()
			return
		}
		PrecisionDlg_GUIEscape:
		{
			g_vDlgs.PrecisionDlg.GUIEscape()
			return
		}
		PrecisionDlg_Cancel:
		PrecisionDlg_GUIClose:
		{
			g_vDlgs.PrecisionDlg.GUIClose()
			return
		}
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: __Get
			Purpose:
		Parameters
			
	*/
	__Get(aName)
	{
		global
		GUI, PrecisionDlg_:Default

		if (aName = "m_hDlg")
			return g_hPrecisionDlg

		if (aName = "m_bHasLeap")
			return g_bHasLeap

		if (aName = "m_iX")
			return GUIControlGet("", "g_vEditX")
		if (aName = "m_iY")
			return GUIControlGet("", "g_vEditY")
		if (aName = "m_iWidth")
			return GUIControlGet("", "g_vEditW")
		if (aName = "m_iHeight")
			return GUIControlGet("", "g_vEditH")

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: Add
			Purpose: To locaize dynamical function calls for Add (note: I tried to override __Call, but I was to dull to get that working properly.)
		Parameters
			
	*/
	Add(sPlacement, sHK, sGestureID)
	{
		sFunc := this.m_sAddFunc ; Note; I also tried using Func() instead, for some reason, only the first parameter ever gets passed into the function.
		return %sFunc%(sPlacement, sHK, sGestureID)
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: Edit
			Purpose:
		Parameters
			
	*/
	Edit(sPlacement, sHK, sGestureID)
	{
		sFunc := this.m_sEditFunc
		return %sFunc%(sPlacement, sHK, sGestureID)
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: Validate
			Purpose:
		Parameters
			
	*/
	Validate(sHK, ByRef rsError)
	{
		sFunc := this.m_sValidateFunc
		return %sFunc%(sHK, this.m_bUseEditFunc, rsError)
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GUIOK
			Purpose:
		Parameters
			
	*/
	GUIOK()
	{
		GUI PrecisionDlg_:Default

		sHK := this.HKDlg.TranslateHKForSave()
		if (!this.Validate(sHK, sError))
		{
			Msgbox(sError)
			return ; Validation failed
		}

		; Not using associative array because that sorts members alphabetically.
		sParse := "x|y|width|height"
		sPlacement :=
		Loop, Parse, sParse, |
			sPlacement .= " " A_LoopField ": " this["m_i" A_LoopField] "   "

		sGestureID := this.HKDlg.m_sGesture
		if (this.m_bUseEditFunc)
			bSuccess := this.Edit(sPlacement, sHK, sGestureID)
		else bSuccess := this.Add(sPlacement, sHK, sGestureID)

		if (bSuccess)
			this.GUIClose()

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GUIEscape
			Purpose: Basically a wrapper to HKDlg.GUIEscape
		Parameters
			
	*/
	GUIEscape()
	{
		if (this.HKDlg.GUIEscape())
			this.GUIClose()

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GUIClose
			Purpose:
		Parameters
			
	*/
	GUIClose()
	{
		GUI, PrecisionDlg_: Hide

		WinSet, Enable, , % "ahk_id" this.m_hOwner
		WinActivate, % "ahk_id" this.m_hOwner

		this.m_bIsActive := false
		SuspendThreads("Off")
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ShowDlg
			Purpose:
		Parameters
			hOwner:
			sHKBeingEdited:
			sGestureBeingEdited:
			iX:
			iY:
			iW:
			iH:
			sAppendToTitle:
	*/
	ShowDlg(hOwner=0, sHKBeingEdited="", sGestureBeingEdited="", iX="", iY="", iW="", iH="", sAppendToTitle="Add a Placement")
	{
		GUI, PrecisionDlg_:Default

		GUI, +Owner%hOwner%
		WinSet, Disable,, ahk_id %hOwner%
		this.m_hOwner := this.HKDlg.m_hOwner := hOwner

		this.m_sHKBeingEdited			:= this.HKDlg.m_sHKBeingEdited			:= sHKBeingEdited
		this.m_sGestureBeingEdited	:= this.HKDlg.m_sGestureBeingEdited	:= sGestureBeingEdited
		this.m_bUseEditFunc := this.HKDlg.m_bUseEditFunc := !(sHKBeingEdited == A_Blank && sGestureBeingEdited == A_Blank)

		; By settings the HKDlg vars, OnShowDlg will update controls that HKDlg are responsible for.
		this.HKDlg.OnShowDlg()

		; iX, iY, iW, iH.
		this.m_iOldX := iX
		this.m_iOldY := iY
		this.m_iOldW := iW
		this.m_iOldH := iH

		GUI, PrecisionDlg_:Default
		GUIControl,, g_vEditX, % this.m_iOldX
		GUIControl,, g_vEditY, % this.m_iOldY
		GUIControl,, g_vEditW, % this.m_iOldW
		GUIControl,, g_vEditH,  % this.m_iOldH

		GUI, Show, x-32768 AutoSize, % "Precise Window Placement - " sAppendToTitle
		CenterWndOnOwner(this.m_hDlg, this.m_hOwner)
		GUIControl, Focus, g_vEditX

		this.m_bIsActive := true
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
}

class HKDlg
{
	__New(sAddFunc, sEditFunc, sValidateFunc, sGUI="HKDlg_", iXOffset=0, iYOffset=0)
	{
		global

		; The first three parameters here may be overriden externally.
		this.m_bMustHaveHotkey := true
		this.m_sAddFunc := sAddFunc
		this.m_sEditFunc := sEditFunc
		this.m_sValidateFunc := sValidateFunc
		this.m_sGUI := sGUI

		if (sGUI = "HKDlg_")
		{
			GUI %sGUI%: New, hwndg_hHKDlg, Record a Hotkey
			GUI, Add, Button, x182 y244 w%g_iMSDNStdBtnW% h%g_iMSDNStdBtnH% vg_vHKDlg_OKBtn gHKDlg_OK, OK
			GUI, Add, Button, % "xp+" g_iMSDNStdBtnW+g_iMSDNStdBtnSpacing " yp wp hp vg_vHKDlg_GUICancelBtn g" this.m_sGUI "GUIClose", Cancel
		}
		else GUI %sGUI%:Default

		; Offset first controls by offsets passed in, and be sure that every following GUI, Add call uses coordinates relative to the last control that was added.
		GUI, Add, Hotkey, % "x" 5+iXOffset " y" 8+iYOffset " w155 h20 hwndg_hHKDlg_Hotkey vg_vHKDlg_Hotkey g" this.m_sGUI "RecordHK"
		GUI, Add, Checkbox, % "xp+175 yp+3 vg_vHKDlg_WinCheck g" this.m_sGUI "WinProc", Win

		local iX := iXOffset+5
		local iY := 0
		local iYInc := 21
		sModifiersAsPipes := this.m_sModifiersAsPipes
		Loop, Parse, sModifiersAsPipes, |
		{
			iY := iYOffset+56

			GUI, Add, Radio, % "x" iX " y" iY " w70 h21 Group vbMod" A_LoopField "Left g" this.m_sGUI "RecordHK", Left %A_LoopField%
			GUI, Add, Radio, % "xp yp+" iYInc " wp hp vbMod" A_LoopField "Right g" this.m_sGUI "RecordHK ", Right %A_LoopField%
			GUI, Add, Radio, % "xp yp+" iYInc  "wp hp vbMod" A_LoopField "Either g" this.m_sGUI "RecordHK +Checked", Either %A_LoopField%

			iX += 83
		}

		iX := iXOffset+5
		iY := iYOffset+34

		if (this.m_bHasLeap)
		{
			GUI, Add, Text, % "x" iX " yp+" iY-iYOffset " w50 h25", Gesture:
			GUI, Add, DropDownList, % "xp+45 yp-3 w257 g" this.m_sGUI "GestureDDLProc vg_vHKDlg_Gesture", % "|" g_vLeap.m_vGesturesIni.GetSections("|", "C")

			GUI, Add, Button, % "xp+258 yp-1 w25 hp+2 hwndg_hHKDlg_LeapGesturesBtn g" this.m_sGUI "LaunchGesturesDlg"
			ILButton(g_hHKDlg_LeapGesturesBtn, "AutoLeap\Add.ico", 16, 16, 4)
			iY := iYOffset+161
		}
		else iY := iYOffset+131
		GUI, Add, Text, % "x" iX " y" iY " w" 330 " r5 vHotkeyWarnTxt Hidden", % g_sDefaultHotkeyWarnTxt

		return this

		HKDlg_GUIEscape:
		{
			g_vDlgs.HKDlg.GUIEscape()
			return
		}
		HKDlg_GUIClose:
		{
			g_vDlgs.HKDlg.GUIClose()
			return
		}
		HKDlg_WinProc:
		{
			g_vDlgs.HKDlg.WinProc()
			return
		}

		HKDlg_RecordHK:
		{
			g_vDlgs.HKDlg.RecordHK()
			return
		}

		HKDlg_LaunchGesturesDlg:
		{
			g_vDlgs.HKDlg.LaunchGesturesDlg(g_hHKDlg)
			return
		}

		HKDlg_GestureDDLProc:
		{
			g_vDlgs.HKDlg.GestureDDLProc()
			return
		}

		HKDlg_OK:
		{
			g_vDlgs.HKDlg.GUIOK()
			return
		}
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: __Get
			Purpose:
		Parameters
			
	*/
	__Get(aName)
	{
		global
		GUI, % this.m_sGUI ":Default"

		if (aName = "m_hDlg")
			return g_hHKDlg

		if (aName = "m_sModifiersAsPipes")
			return g_sModParse
		if (aName = "m_sAbbrModParse")
			return g_sAbbrModParse
		if (aName = "m_bHasLeap")
			return g_bHasLeap

		if (aName = "m_sHotkey")
		{
			if (GUIControlGet("", "g_vHKDlg_WinCheck"))
				local sWin := "#"
			return sWin GUIControlGet("", "g_vHKDlg_Hotkey")
		}
		if (aName = "m_sGesture")
			return GUIControlGet("", "g_vHKDlg_Gesture")
		if (aName = "m_bWin")
			return GUIControlGet("", "g_vHKDlg_WinCheck")
		if (aName = "m_hFocused")
		{
			local sFocused, hFocused
			GUIControlGet, sFocused, Focus
			ControlGet, hFocused, hwnd,, %sFocused%
			return hFocused
		}
		if (aName = "m_sFocused")
			return GUIControlGet("Focus")

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: Add
			Purpose: To locaize dynamical function calls for Add (note: I tried to override __Call, but I was too dull to get that working properly.)
		Parameters
			sHK
			sGestureID
	*/
	Add(sHK, sGestureID)
	{
		if (this.m_bUseEditFunc)
		{
			Msgbox("Internal Error: Hotkey Dialog is using the Add function when it should be using the Edit function")
			return
		}

		sFunc := this.m_sAddFunc ; Note; I also tried using Func() instead, for some reason, only the first parameter ever gets passed into the function.
		return %sFunc%(sHK, sGestureID)
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: Edit
			Purpose:
		Parameters
			sHK
			sGestureID
	*/
	Edit(sHK, sGestureID)
	{
		if (!this.m_bUseEditFunc)
		{
			Msgbox("Internal Error: Hotkey Dialog is using the Edit function when it should be using the Add function")
			return
		}

		sFunc := this.m_sEditFunc
		return %sFunc%(sHK, sGestureID, this.m_bMustHaveHotkey)
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: Validate
			Purpose:
		Parameters
			sHK
	*/
	Validate(sHK, ByRef rsError)
	{
		sFunc := this.m_sValidateFunc
		return %sFunc%(sHK, this.m_bUseEditFunc, rsError)
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: WinProc
			Purpose:
		Parameters
			
	*/
	WinProc()
	{
		if (this.m_bWin)
		{
			GUIControl, Show, bModWinLeft
			GUIControl, Show, bModWinRight
			GUIControl, Show, bModWinEither
		}
		else
		{
			GUIControl, Hide, bModWinLeft
			GUIControl, Hide, bModWinRight
			GUIControl, Hide, bModWinEither
		}

		; Outputs an error or warning on HotkeyWarnTxt.
		if (this.ValidateHK())
			this.GestureDDLProc()

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: RecordHK
			Purpose:
		Parameters
			
	*/
	RecordHK()
	{
		global g_VKsIni

		this.ShowHideRadios()

		if (this.HKHasTriggerKey(this.m_sHotkey))
		{
			; Outputs an error or warning on HotkeyWarnTxt
			if (this.ValidateHK())
				this.GestureDDLProc()
		}

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: LaunchGesturesDlg()
			Purpose:
		Parameters
			
	*/
	LaunchGesturesDlg(hOwner)
	{
		ShowControlCenterDlg(hOwner, this.m_sGesture, this.m_sGUI, "g_vHKDlg_Gesture")
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GestureDDLProc
			Purpose:
		Parameters
			
	*/
	GestureDDLProc()
	{
		sGestureID := this.m_sGesture

		/*
			g_vLeap.m_vGesturesIni := Gestures.ini
				[Snap to Corner Left]
				Activate=true
				Hotkey=Win + Ctrl + Alt + L
				GestureName=Left
				[....]
		*/

		; Validate that this gesture is not mapped to any other action
		bIsValid := core_ValidateGesture(sGestureID, this.m_bUseEditFunc, sError)
		GUI, % this.m_sGUI ":Default"
		if (bIsValid)
		{ ; The gesture may be valid, but the hotkey may not!
			if (this.ValidateHK())
			{
				sWarnTxt := GUIControlGet("", "HotkeyWarnTxt")
				; Don't override validation if the hotkey is invalid.
				if (sWarnTxt == A_Blank || sWarnTxt == this.m_sDefaultHotkeyWarnTxt)
					GUIControl, Enable, g_vHKDlg_OKBtn
			}
		}
		else
		{
			GUIControl,, HotkeyWarnTxt, % sError
			GUIControl, Show, HotkeyWarnTxt
			GUIControl, Disable, g_vHKDlg_OKBtn ; Instead of intruding with a MsgBox prompt, disable the OK button.
		}

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GUIOK
			Purpose:
		Parameters
			
	*/
	GUIOK()
	{
		GUI, % this.m_sGUI ":Default"
		sGestureID := this.m_sGesture
		sHK := this.TranslateHKForSave()

		if (sHK != "FALSE" && sHK != A_Blank) ; if there was an error, such as a blank hotkey, TranslateHKForSave returns "FALSE".
			bCanClose := this.ValidateHK()
		if (sGestureID != A_Blank)
			bCanClose := core_ValidateGesture(sGestureID, this.m_bUseEditFunc, sError)

		if (bCanClose)
		{
			if (this.m_bUseEditFunc)
				bSuccess := this.Edit(sHK, sGestureID)
			else bSuccess := this.Add(sHK, sGestureID)

			if (bSuccess)
				this.GUIClose()
		}
		else if (sError)
			Msgbox(sError)

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GUIEscape
			Purpose: To help avoid escaping while recording hotkeys, but still allow escaping in every other situation
		Parameters
			
	*/
	GUIEscape()
	{
		if (InStr(this.m_sFocused, "msctls_hotkey32"))
		{
			sHK := this.m_sHotkey
			StringReplace, sHK, sHK, Escape
			GUIControl,, g_vHKDlg_Hotkey, % sHK "Escape"

			return false
		}

		this.GUIClose()

		return true
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GUIClose
			Purpose:
		Parameters
			
	*/
	GUIClose()
	{
		GUI HKDlg_:Hide
		WinSetTitle, % "ahk_id" this.m_hDlg, Record a Hotkey

		; Clear controls
		GUIControl,, g_vHKDlg_Hotkey
		GUIControl,, g_vHKDlg_Gesture, |
		GUIControl,, g_vHKDlg_WinCheck, 0
		this.CheckRadioBtns("Junk") ; This unchecks the radios.
		this.ShowHideRadios("Junk") ; This hides the radios.

		WinSet, Enable,, % "ahk_id" this.m_hOwner
		WinActivate, % "ahk_id" this.m_hOwner

		this.m_bIsActive := false
		SuspendThreads("Off")
		return true
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	ValidateHK()
	{
		sHK := this.TranslateHKForSave(true)
		if (sHK == A_Blank)
		{
			GUIControl,, HotkeyWarnTxt
			return true
		}

		SetFormat, Integer, d
		bFuncRet := this.Validate(sHK, sError)

		GUI, % this.m_sGUI ":Default"
		if (bFuncRet) ; Hotkey passed application validation.
		{
			sHKInAHKFormat := this.m_sHotkey
			Loop 4 ; Up to 3 Modifier keys, and 1 trigger key.
			{
				sThisKey := SubStr(sHKInAHKFormat, A_Index, 1)
				if (sThisKey != "" && sThisKey != "^" && sThisKey != "!" && sThisKey != "+" && sThisKey != "#")
				{
					sTriggerKey := SubStr(sHKInAHKFormat, A_Index)
					break
				}
			}
			this.EscapeSpecialKeys(sTriggerKey)
			iVK := g_VKsIni[sTriggerKey][sTriggerKey] ; TODO: Simple ini with just section and key, no val
			; Ini is not perfect, but neither is GetKeyVK. Use ini first. If key is blank, use GetKeyVK.
			iVKTest := GetKeyVK(sTriggerKey)
			SetFormat, Integer, hex
			iVKTest += 0
			if (!iVK)
				iVK := iVKTest

			; I've tried using hex numbers, but AHK keeps removing the 000 parts in 0x0001
			; I tested to see if this was OK; it's not. The 000s MUST be there for this to work
			iModifiers := 0
			if (InStr(sHKInAHKFormat, "^"))
				iModifiers = 1
			if (InStr(sHKInAHKFormat, "!"))
				iModifiers += 2
			if (InStr(sHKInAHKFormat, "+"))
				iModifiers += 4
			if (InStr(sHKInAHKFormat, "#"))
				iModifiers += 8
			if (iModifiers > 9)
				iModifiers := (iModifiers == 10 ? 0x000a : iModifiers == 11 ? 0x000b : iModifiers == 12 ? 0x000c : iModifiers == 13 ? 0x000d : iModifiers == 14 ? 0x000e : iModifiers == 15 ? 0x000f : "")

			if (DllCall("RegisterHotKey", "Ptr", "", "Int", iVK, "UInt", iModifiers, "UInt", iVK))
			{
				DllCall("UnregisterHotKey", "Ptr", "", "Int", iVK)
				GUIControl,, HotkeyWarnTxt,
				GUIControl, Hide, HotkeyWarnTxt
			}
			else
			{
				GUIControl,, HotkeyWarnTxt, % this.m_sDefaultHotkeyWarnTxt
				GUIControl, Show, HotkeyWarnTxt
			}
			SetFormat, Integer, d
			GUIControl, Enable, g_vHKDlg_OKBtn
		}
		else
		{
			GUIControl,, HotkeyWarnTxt, %sError%
			GUIControl, Show, HotkeyWarnTxt
			GUIControl, Disable, g_vHKDlg_OKBtn ; Instead of intruding with a MsgBox prompt, disable the OK button.
		}

		return bFuncRet
	}

	TranslateHKForDisplay()
	{
		sKey := this.m_sHotkey

		StringReplace, sKey, sKey, `^, % this.GetLeftRightEither("bModCtrl") "Ctrl" A_Space
		StringReplace, sKey, sKey, `!,  % this.GetLeftRightEither("bModAlt") "Alt" A_Space
		StringReplace, sKey, sKey, `+, % this.GetLeftRightEither("bModShift") "Shift" A_Space
		StringReplace, sKey, sKey, `#, % this.GetLeftRightEither("bModWin") "Win" A_Space

		StringReplace, sKey, sKey, sc135, NumpadDiv

		StringReplace, sKey, sKey, `r,, All
		Trim(sKey, A_Space)
		Trim(sKey, "+")

		Loop, Parse, sKey, %A_Space%
			iCnt++

		Loop, Parse, sKey, %A_Space%
		{
			if (A_Index == iCnt)
				s .= A_LoopField
			else s .= A_LoopField " + "
		}
		return s
	}

	TranslateHKForDlg(sHK, ByRef rbWin=0, ByRef rsLRCtrl="", ByRef rsLRAlt="", ByRef rsLRShift="", ByRef rsLRWin="")
	{
		rbWin := rsLRCtrl := rsLRAlt := rsLRShift := rsLRWin :=

		sModifiersAsPipes := this.m_sModifiersAsPipes
		Loop, Parse, sModifiersAsPipes, |
		{
			sMod := A_LoopField
			Loop, Parse, sHK, +
			{
				sHKMod := Trim(A_LoopField)
				if (Trim(sHKMod = "L" sMod))
					rsLR%sMod% := "L"
				else if (Trim(sHKMod = "R" sMod))
					rsLR%sMod% := "R"
			}
		}

		if (InStr(sHK, "Win"))
		{
			StringReplace, sHK, sHK, LWin%A_Space%,, All
			StringReplace, sHK, sHK, RWin%A_Space%,, All
			StringReplace, sHK, sHK, Win%A_Space%,, All
			rbWin := true
		}

		return TranslateHKForHotkeyCmd(sHK) ; In Window Master.ahk
	}

	TranslateHKForSave(bValidateOnly=false)
	{
		sHK := this.TranslateHKForDisplay()

		if (sHK == A_Blank && this.m_bMustHaveHotkey && !bValidateOnly)
		{
			Msgbox("You must record a complete hotkey to be used!")
			return "FALSE"
		}

		; If the dialog is dismissed without ever recording a hotkey, then the hotkey is blank.
		if (sHK == A_Blank && this.m_bMustHaveHotkey)
			sHK := this.m_sHKBeingEdited
		return sHK
	}

	GetLeftRightEither(sRadioCtrl)
	{
		return GUIControlGet("", sRadioCtrl "Left") ? "L" : GUIControlGet("", sRadioCtrl "Right") ? "R" : GUIControlGet("", sRadioCtrl "Either") ? "" : ""
	}

	CheckRadioBtns(sHK)
	{
		GUI, % this.m_sGUI ":Default"

		this.TranslateHKForDlg(sHK, bWin, sLRCtrl, sLRAlt, sLRShift, sLRWin)

		sVars := "sLRCtrl|sLRAlt|sLRShift|sLRWin"
		Loop, Parse, sVars, |
		{
			sMod := SubStr(A_LoopFIeld, 4)

			if (%A_LoopField% = "L")
				GUIControl,, bMod%sMod%Left, 1
			else if (%A_LoopField% = "R")
				GUIControl,, bMod%sMod%Right, 1
			else ; either
				GUIControl,, bMod%sMod%Either, 1
		}

		return
	}

	HKHasTriggerKey(sKey)
	{
		return sKey != "^" && sKey != "!" && sKey != "+" && sKey != "+^" && sKey != "^!" && sKey != "+!" && sKey != "+^!"
	}

	HKHasModifier(sHK)
	{
		return (this.GetModifiersFromHK(sHK) != A_Blank)
	}

	GetModifiersFromHK(sHK)
	{
		if (InStr(sHK, "^"))
			sMods .= "^|"
		if (InStr(sHK, "!"))
			sMods .= "!|"
		if (InStr(sHK, "+"))
			sMods .= "+|"
		if (InStr(sHK, "#"))
			sMods .= "#|"

		return SubStr(sMods, 1, StrLen(sMods)-1)
	}

	GetModifiersFromHK_Friendly(sHK)
	{
		sModParse := this.m_sModifiersAsPipes
		Loop, Parse, sModParse, |
		{
			iStartOfMod := InStr(sHK, A_LoopField)
			iEndOfMod := InStr(sHK, A_Space, false, iStartOfMod)
			if (iStartOfMod)
			{
				sMod := Trim(SubStr(sHK, iStartOfMod-1, iEndOfMod-iStartOfMod+1))
				sMods .= (A_Index == 1 ? sMod : "|" sMod)
			}
		}

		return sMods
	}

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ShowHideRadios
			Purpose: To show or hide the modifier radios buttons based upon the modifers contained in sHK
		Parameters
			sHK="":
	*/
	ShowHideRadios(sHK="")
	{
		static vAbbrModToFriendlyMod := {"^":"Ctrl", "!":"Alt", "+":"Shift", "#":"Win"}

		if (sHK == A_Blank)
			sHK := this.m_sHotkey

		sAbbrModParse := this.m_sAbbrModParse
		Loop, Parse, sAbbrModParse, |
		{
			sFriendlyMod := vAbbrModToFriendlyMod[A_LoopField]
			if (InStr(sHK, A_LoopField))
			{
				GUIControl, Show, bMod%sFriendlyMod%Left
				GUIControl, Show, bMod%sFriendlyMod%Right
				GUIControl, Show, bMod%sFriendlyMod%Either
			}
			else
			{
				GUIControl, Hide, bMod%sFriendlyMod%Left
				GUIControl, Hide, bMod%sFriendlyMod%Right
				GUIControl, Hide, bMod%sFriendlyMod%Either
			}
		}

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	EscapeSpecialKeys(ByRef sKey)
	{
		if (sKey = "=")
			sKey := "Equals"
		else if (sKey = ";")
			sKey := "SemiColon"
		else if (sKey = "[")
			sKey := "OpenBracket"
		else if (sKey = "sc135")
			sKey := "NumpadDiv"

		return
	}

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ShowDlg
			Purpose: For launching the dialog
		Parameters
			hOwner: Window handle to the owner of this dialog.
			sHKBeingEdited ="":
			sGestureBeingEdited:="" 
			sAppendToTitle="": 
	*/
	ShowDlg(hOwner, bFromEdit, sHKBeingEdited="", sGestureBeingEdited="", sAppendToTitle="")
	{
		global g_vLeap

		SuspendThreads("On")

		GUI, % this.m_sGUI ":Default"
		this.m_hOwner := hOwner
		GUI, +Owner%hOwner%
		WinSet, Disable,, ahk_id %hOwner%

		this.m_bUseEditFunc := bFromEdit
		this.m_sHKBeingEdited := sHKBeingEdited
		this.m_sGestureBeingEdited := sGestureBeingEdited

		this.OnShowDlg()

		if (this.m_sGUI = "HKDlg_")
			GUIControl, Focus, g_vHKDlg_GUICancelBtn

		GUI, Show, x-32768 AutoSize, %sAppendToTitle%
		CenterWndOnOwner(this.m_hDlg, this.m_hOwner)

		this.m_bIsActive := true
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: OnShowDlg()
			Purpose: To update dlg variables with appropriate values
		Parameters
			
	*/
	OnShowDlg()
	{
		global g_vLeap

		SuspendThreads("On")

		if (this.m_sHKBeingEdited != A_Blank)
		{
			sHK := this.TranslateHKForDlg(this.m_sHKBeingEdited, bWin, sLRCtrl, sLRAlt, sLRShift, sLRWin)

			GUIControl,, g_vHKDlg_Hotkey, %sHK%
			if (bWin)
			{
				GUIControl,, g_vHKDlg_WinCheck, 1
				sHK := "#" sHK
			}
			else GUIControl,, g_vHKDlg_WinCheck, 0
		}

		this.CheckRadioBtns(this.m_sHKBeingEdited)
		this.ShowHideRadios(sHK)

		GUIControl,, HotkeyWarnTxt

		if (this.m_bHasLeap)
			GUIControl,, g_vHKDlg_Gesture, % "||" g_vLeap.m_vGesturesIni.GetSections("|", "C") ; Update DDL with new gesture(s)

		if (this.m_sGestureBeingEdited)
			GUIControl, ChooseString, g_vHKDlg_Gesture, % this.m_sGestureBeingEdited

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; Member variables.
	m_sDefaultHotkeyWarnTxt := "* This hotkey is already in use by some other application`nYou may use this hotkey, but unexpected results may occur."
}

class SequenceDlg
{
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
		Author: Verdlin
		Function: __New
			Purpose:
		Parameters
			sAddFunc
			sEditFunc
			sValidateFunc
			iX="0.00"
			iY="0.00"
			iW="0.00"
			iH="0.00"
	*/
	__New(sAddFunc, sEditFunc)
	{
		global

		this.m_sAddFunc := sAddFunc
		this.m_sEditFunc := sEditFunc

		GUI SequenceDlg_:New, -MaximizeBox -MinimizeBox hwndg_hSequenceDlg
		GUI, Add, Text, x15 y5 w10 h13, %A_Space%x
		GUI, Add, Text, xp yp+28 w8 hp, %A_Space%y
		GUI, Add, Text, xp yp+28 w29 hp, %A_Space%width
		GUI, Add, Text, xp yp+28 w33 hp, %A_Space%height
		GUI, Add, Text, x153 y5 w11 hp, `%
		GUI, Add, Text, xp yp+28 wp hp, `%
		GUI, Add, Text, xp yp+28 wp hp, `%
		GUI, Add, Text, xp yp+28 wp hp, `%
		GUI, Add, Edit, x92 y1 w40 h21 Limit5 vg_vEditX
		GUI, Add, Edit, xp yp+28 wp hp Limit5 vg_vEditY
		GUI, Add, Edit, xp yp+28 wp hp Limit5 vg_vEditW
		GUI, Add, Edit, xp yp+28 wp hp Limit5 vg_vEditH
		GUI, Add, Button, x12 yp+33 w154 h23 gSequenceDlg_WindowSet, &Set with Window
		GUI, Add, Button, xp yp+30 w75 hp gSequenceDlg_OK, &OK
		GUI, Add, Button, xp+79 yp wp hp gSequenceDlg_Cancel, &Cancel

		Hotkey, IfWinActive, % "ahk_id" this.m_hDlg
			Hotkey, Enter, SequenceDlg_OK
			Hotkey, NumpadEnter, SequenceDlg_OK

		this.m_iOldX := iX
		this.m_iOldY := iY
		this.m_iOldW := iW
		this.m_iOldH := iH

		this.WindowSetDlg := new WindowSetDlg("SequenceDlg_")

		return this

		SequenceDlg_WindowSet:
		{
			g_vDlgs.SequenceDlg.WindowSetDlg.ShowDlg(g_hSequenceDlg, "SequenceDlg_")
			return
		}

		SequenceDlg_GUIEscape:
		SequenceDlg_GUIClose:
		SequenceDlg_Cancel:
		{
			g_vDlgs.SequenceDlg.GUIClose()
			return
		}

		SequenceDlg_OK:
		{
			g_vDlgs.SequenceDlg.GUIOK()
			return
		}
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: __Get
			Purpose:
		Parameters
			
	*/
	__Get(aName)
	{
		global

		if (aName = "m_hDlg")
			return g_hSequenceDlg

		if (aName = "m_iX")
			return GUIControlGet("", "g_vEditX")
		if (aName = "m_iY")
			return GUIControlGet("", "g_vEditY")
		if (aName = "m_iW")
			return GUIControlGet("", "g_vEditW")
		if (aName = "m_iH")
			return GUIControlGet("", "g_vEditH")

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: Add
			Purpose: To locaize dynamical function calls for Add (note: I tried to override __Call, but I was to dull to get that working properly.)
		Parameters
			vSeq: Object which holds sequence info.
	*/
	Add(vSeq)
	{
		sFunc := this.m_sAddFunc ; Note; I also tried using Func() instead, for some reason, only the first parameter ever gets passed into the function.
		return %sFunc%(vSeq)
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: Edit
			Purpose:
		Parameters
			vSeq: Object which holds sequence info.
	*/
	Edit(vSeq)
	{
		sFunc := this.m_sEditFunc
		return %sFunc%(vSeq)
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GUIOK
			Purpose:
		Parameters
			
	*/
	GUIOK()
	{
		GUI, SequenceDlg_:Default

		if (this.m_iX == A_Blank
			|| this.m_iY == A_Blank
			|| this.m_iW == A_Blank
			|| this.m_iH == A_Blank)
		{
			Msgbox("You must enter in a value for each percentage.")
			return
		}

		; Ensure sequences have two decimal points of precision.
		SetFormat, Float, 5.2

		iX := this.m_iX + 0.0
		iY := this.m_iY + 0.0
		iW := this.m_iW + 0.0
		iH := this.m_iH + 0.0

		vSeq := {m_iX: iX, m_iY: iY, m_iW: iW, m_iH: iH}

		; Restore standard format.
		SetFormat, Integer, d

		if (this.m_bUseEditFunc)
			bSuccess := this.Edit(vSeq)
		else bSuccess := this.Add(vSeq)

		if (bSuccess)
		{
			this.GUIClose()

			; Refresh the preview window.
			gosub Sequence
		}

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function:
			Purpose:
		Parameters
			
	*/
	GUIClose()
	{
		GUI SequenceDlg_: Hide

		WinSet, Enable,, % "ahk_id" this.m_hOwner
		WinActivate, % "ahk_id" this.m_hOwner

		this.m_bIsActive := false
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ShowDlg
			Purpose: To display a dialog to edit sequences.
		Parameters
			hParent
			bFromEdit
			iX="0.00"
			iY="0.00"
			iW="0.00"
			iH="0.00"
	*/
	ShowDlg(hOwner, bFromEdit, iX="", iY="", iW="", iH="")
	{
		global g_vDlgs

		GUI, SequenceDlg_:Default

		this.m_hOwner := hOwner
		this.m_bUseEditFunc := bFromEdit

		this.m_iOldX := iX
		this.m_iOldY := iY
		this.m_iOldW := iW
		this.m_iOldH := iH

		GUIControl,, g_vEditX, % this.m_iOldX
		GUIControl,, g_vEditY, % this.m_iOldY
		GUIControl,, g_vEditW, % this.m_iOldW
		GUIControl,, g_vEditH, % this.m_iOldH

		GUI, % "+Owner" this.m_hOwner
		WinSet, Disable,, % "ahk_id" this.m_hOwner

		GUI, Show, x-32768 AutoSize, Ratio in percent (`%)
		CenterWndOnOwner(this.m_hDlg, this.m_hOwner)

		this.m_bIsActive := true
		return
	}
}

class LeapGestureDlg
{
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: __New
			Purpose: To initialize this dialog that is specific to interfacing with Leap gestures.
		Parameters
			sGUI=""
	*/
	__New(sGUI="")
	{
		global

		this.m_hOwner := hOwner
		this.m_sExistingGesture := sExistingGesture
		this.m_sGUI := sGUI

		if (sGUI == A_Blank)
		{
			GUI, LeapGestureDlg_: New, -MaximizeBox -MinimizeBox hwndg_hLeapGestureDlg
			GUI, +Owner%hOwner%
			WinSet, Disable,, ahk_id %hOwner%
		}
		else GUI %sGUI%:Default

		GUI, Add, Text, w50 h25, Gesture:
		GUI, Add, DropDownList, xp+45 yp-3 w257 gLeapGestureDlg_GestureDDLProc vg_vLeapGestureDlg_Gesture, % "|" g_vLeap.m_vGesturesIni.GetSections("|", "C")
		GUIControl, ChooseString, g_vLeapGestureDlg_Gesture, % this.m_sExistingGesture
		GUI, Add, Button, xp+258 yp-1 w25 hp+2 hwndg_hLeapGestureDlg_LeapGesturesBtn gLeapGestureDlg_LaunchControlCenterDlg
		ILButton(g_hLeapGestureDlg_LeapGesturesBtn, "AutoLeap\Add.ico", 16, 16, 4)

		GUI, Add, Text, w330 r5 vg_vLeapGestureDlg_ErrorTxt Hidden

		if (sGUI == A_Blank)
		{
			; TODO: g_iMSDNStdBtnSpacing*2 or 3
			GUI, Add, Button, x182 yp+30 w%g_iMSDNStdBtnW% h%g_iMSDNStdBtnH% vg_vLeapGestureDlg_OKBtn gLeapGestureDlg_GUIOK, OK
			GUI, Add, Button, % "xp+" g_iMSDNStdBtnW+g_iMSDNStdBtnSpacing " yp wp hp vg_vLeapGestureDlg_GUICancelBtn gLeapGestureDlg_GUIClose", Cancel
		}

		return this

		LeapGestureDlg_GestureDDLProc:
		{
			g_vDlgs.LeapGestureDlg.DDLProc()
			return
		}

		LeapGestureDlg_LaunchControlCenterDlg:
		{
			g_vDlgs.LeapGestureDlg.LaunchControlCenterDlg()
			return
		}

		LeapGestureDlg_GUIOK:
		{
			g_vDlgs.LeapGestureDlg.GUIOK()
			return
		}

		LeapGestureDlg_GUIEscape:
		LeapGestureDlg_GUIClose:
		{
			g_vDlgs.LeapGestureDlg.GUIClose()
			return
		}
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function:
			Purpose:
		Parameters
			
	*/
	__Get(aName)
	{
		global

		if (aName = "m_hDlg")
			return g_hLeapGestureDlg

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ShowLeapGestureDlg
			Purpose: To provide a dialog specific interfacing with Leap gestures.
		Parameters
			hOwner
			sExistingGesture=""
			sGUI=""
	*/
	ShowLeapGestureDlg(hOwner, sExistingGesture="")
	{
		GUI, % this.m_sGUI ":Default"

		this.m_hOwner := hOwner
		GUI, +Owner%hOwner%
		WinSet, Disable,, ahk_id %hOwner%

		GUI, Show, x-32768 AutoSize
		CenterWndOnOwner(this.m_hDlg, this.m_hOwner)

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GUIOK
			Purpose:
		Parameters
			
	*/
	GUIOK()
	{
		GUI, % this.m_sGUI ":Default"

		; TODO: Save settings.
		this.GUIClose()

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: DDLProc
			Purpose:
		Parameters
			
	*/
	DDLProc()
	{
		GUI, % this.m_sGUI ":Default"
		GUIControlGet, sGestureID,, g_vLeapGestureDlg_Gesture

		; Validate that this gesture is not mapped to any other action.
		bIsValid := core_ValidateGesture(sGestureID, (this.m_sExistingGesture != A_Blank), sError)
		if (!bIsValid)
		{
			GUIControl,, g_vLeapGestureDlg_ErrorTxt, %sError%
			GUIControl, Show, g_vLeapGestureDlg_ErrorTxt
			GUIControl, Disable, g_vLeapGestureDlg_OKBtn ; Instead of intruding with a MsgBox prompt, disable the OK button.
		}

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function:
			Purpose:
		Parameters
			
	*/
	GUIClose()
	{
		; Destroy dialog.
		GUI, LeapGestureDlg_:Hide

		; Enable owner.
		WinSet, Enable,, % "ahk_id" this.m_hOwner
		WinActivate, % "ahk_id" this.m_hOwner

		this.m_bIsActive := false
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: LaunchGesturesDlg
			Purpose: To launch the gestures dialog from AutoLeap.ahk
		Parameters
			
	*/
	LaunchControlCenterDlg()
	{
		ShowControlCenterDlg(this.m_hDlg, this.m_sSelGesture)
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
}

class WindowSetDlg
{
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: __New
			Purpose:
		Parameters
			
	*/
		__New(sGUIOwner)
	{
		global

		this.m_sGUIOwner := sGUIOwner

		GUI, WindowSetDlg_:New, +Resize hwndg_hWindowSet
		GUI, Add, Text, x35 y0 w140 vg_vWSText, Set this window at the`ndesired coordinates.`nWhen you are finished,`npress OK.
		GUI, Add, Button, xp y60 w59 h20 vg_vWSOK gWindowSetDlg_GUIClose, &OK
		GUI, Add, Button, xp+59 y60 w59 h20 vg_vWSCancel gWindowSetDlg_Cancel, &Cancel

		return this
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function:
			Purpose:
		Parameters
			
	*/
	__Get(aName)
	{
		global

		if (aName = "m_hDlg")
			return g_hWindowSet

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: ShowWindowSetDlg
			Purpose: To provide a handy window settings dialog. Passes xywh to sFuncCallback
		Parameters
			hOwner: Owner of this dialog
			iX:
			iY:
			iW:
			iH:
	*/
	ShowDlg(hOwner, iX="", iY="", iW="", iH="")
	{
		global

		this.m_hOwner := hOwner

		GUI, % this.m_sGUIOwner ":Default"
		this.m_iOldX := GUIControlGet("", "g_vEditX")
		this.m_iOldY := GUIControlGet("", "g_vEditY")
		this.m_iOldW := GUIControlGet("", "g_vEditW")
		this.m_iOldH := GUIControlGet("", "g_vEditH")

		GUI, WindowSetDlg_:Default
		GUI, +Owner%hOwner%
		WinSet, Disable,, ahk_id %hOwner%

		SuspendThreads("Off") ; Allow HK manipulation of this window.
		GUI, Show, x-32768 AutoSize, Window Placement
		CenterWndOnOwner(this.m_hDlg, this.m_hOwner)
		ResizeWnd("CenterThreeFourths", this.m_hDlg)

		SetTimer, WindowSetDlg_WatchWnd, 100

		this.m_bIsActive := true
		return

		WindowSetDlg_WatchWnd:
		{
			if (g_vDlgs.PrecisionDlg.m_bIsActive)
				g_vDlgs.PrecisionDlg.WindowSetDlg.WatchWnd()
			else if (g_vDlgs.SequenceDlg.m_bIsActive)
				g_vDlgs.SequenceDlg.WindowSetDlg.WatchWnd()

			return
		}

		WindowSetDlg_GUISize:
		{
			Anchor2("WindowSetDlg_:g_vWSText", "xwyh", "0.5, 0, 0.5, 0")
			Anchor2("WindowSetDlg_:g_vWSOK", "xwyh", "0.5, 0, 0.5, 0")
			Anchor2("WindowSetDlg_:g_vWSCancel", "xwyh", "0.5, 0, 0.5, 0")
			return
		}
		WindowSetDlg_Cancel:
		WindowSetDlg_GUIEscape:
		{
			if (g_vDlgs.PrecisionDlg.m_bIsActive)
				g_vDlgs.PrecisionDlg.WindowSetDlg.GUICancel()
			else if (g_vDlgs.SequenceDlg.m_bIsActive)
				g_vDlgs.SequenceDlg.WindowSetDlg.GUICancel()

			return
		}
		WindowSetDlg_GUIClose:
		{
			if (g_vDlgs.PrecisionDlg.m_bIsActive)
				g_vDlgs.PrecisionDlg.WindowSetDlg.GUIClose()
			else if (g_vDlgs.SequenceDlg.m_bIsActive)
				g_vDlgs.SequenceDlg.WindowSetDlg.GUIClose()

			return
		}
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function:
			Purpose:
		Parameters
			
	*/
	GUICancel()
	{
		GUI, % this.m_sGUIOwner ":Default"
		GUIControl,, g_vEditX, % this.m_iOldX
		GUIControl,, g_vEditY, % this.m_iOldY
		GUIControl,, g_vEditW, % this.m_iOldW
		GUIControl,, g_vEditH, % this.m_iOldH

		this.GUIClose()
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: GUIClose
			Purpose:
		Parameters
			
	*/
	GUIClose()
	{
		global g_vDlgs

		WinSet, Enable,, % "ahk_id" this.m_hOwner
		SetTimer, WindowSetDlg_WatchWnd, Off
		GUI, WindowSetDlg_:Hide

		this.m_bIsActive := false
		if (!g_vDlgs.SequenceDlg.m_bIsActive) ; SequenceDlg is a non-hotkey dialog, so allow hotkeys for it.
			SuspendThreads("On")

		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: WindowSetDlg_WatchWnd
			Purpose: To reduce number of global variables.
		Parameters
			
	*/
		WatchWnd()
		{
			global g_DictMonInfo
			GUI, WindowSetDlg_:Default

			WinGetPos, iX, iY, iW, iH, % "ahk_id" this.m_hDlg

			; Specifies whether to give the percentage of the preview window is taking up on the current monitor,
			; or whether to simply return absolute X, Y, W, and H coordinates.
			bUpdateWithWndPct := (this.m_sGUIOwner = "SequenceDlg_")
			if (bUpdateWithWndPct)
			{
				iMon := GetMonitorFromWindow(this.m_hDlg)
				iMonX := g_DictMonInfo[iMon]["Left"]
				iMonY := g_DictMonInfo[iMon]["Top"]
				iMonW := g_DictMonInfo[iMon]["W"]
				iMonH := g_DictMonInfo[iMon]["H"]

				iDestMonX := g_DictMonInfo["PrimaryMonLeft"]
				iDestMonY := g_DictMonInfo["PrimaryMonTop"]
				iDestMonW := g_DictMonInfo["PrimaryMonRight"]
				iDestMonH := g_DictMonInfo["PrimaryMonBottom"]

				; Use resolution difference to scale X and Y.
				iScaledX := iDestMonX + (iX-iMonX) * (iDestMonW/iMonW)
				iScaledY := iDestMonY + (iY-iMonY) * (iDestMonH/iMonH)
				iX := Round((iScaledX * 100) / iMonW, 2)
				iY := Round((iScaledY * 100) / iMonH, 2)

				GetWndPct(iW, iH, this.m_hDlg)
		}

			GUI, % this.m_sGUIOwner ":Default"
			GUIControl,, g_vEditX, %iX%
			GUIControl,, g_vEditY, %iY%
			GUIControl,, g_vEditW, %iW%
			GUIControl,, g_vEditH, %iH%
			return
		}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
}

/*
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
														
				DEPRECATED!			
														
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
*/

; This both Adds and Removes Keys from the DDL.
; I came up with this design after trying four different methods.
; Actually, I stumbled upon this one when I was trying the fourth method,
; and then I realized that this condensed two functions I was using
; (adding and removing) into one.
; Keeping it around because it may be useful in other cases.
HKDlgRepopulateDDL(sDDL, i1, i2, i3)
{
	global asModifiers_c

	GUI HKDlg_: Default
	sHK1 := GUIControlGet("", "vK" i1)
	sHK2 := GUIControlGet("", "vK" i2)
	sHK3 := GUIControlGet("", "vK" i3)

	Loop % asModifiers_c.MaxIndex()
		sKeyList .= asModifiers_c[A_Index] "|"

	if (sHK1 != "None")
		StringReplace, sKeyList, sKeyList, %sHK1%, , All
	if (sHK2 != "None")
		StringReplace, sKeyList, sKeyList, %sHK2%, , All
	if (sHK3 != "None")
		StringReplace, sKeyList, sKeyList, %sHK3%, , All

	StringReplace, sKeyList, sKeyList, ||||, |, All
	StringReplace, sKeyList, sKeyList, |||, |, All
	StringReplace, sKeyList, sKeyList, ||, |, All

	; Remember current entry, and repopulate DDL with sKeyList.
	GUIControlGet, hDDL, Hwnd, %sDDL%
	ControlGet, sCurDDLSel, Choice, ,, % "ahk_id" hDDL

	GUIControl,, %sDDL%, % "|" sKeyList
	GUIControl, ChooseString, %sDDL%, % sCurDDLSel
	return
}