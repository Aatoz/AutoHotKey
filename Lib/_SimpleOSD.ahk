_SimpleOSD(sTextColor="5C5CF0", sBgdColor="202020")
{
	return new SimpleOSD(sTextColor, sBgdColor)
}

class SimpleOSD
{
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	__New(sTextColor="5C5CF0", sBgdColor="202020")
	{
		global

		this.m_sTextColor := sTextColor
		this.m_sBgdColor := sBgdColor

		; With any delay, the OSD sliding looks horrible.
		SetWinDelay, -1

		this.m_bDismiss := false ; Used in SimpleOSD_DismissAfterNMS.
		this.m_iMaxWidth := A_ScreenWidth ; used for clarity, and also ease of changeability.

		GUI SimpleOSD: New, hwndg_hSimpleOSD
		GUI, +AlwaysOnTop -Caption +Owner +LastFound +ToolWindow +E0x20
		WinSet, Transparent, 240

		GUI, Font, % "s15 wnorm c" . this.m_sTextColor ; c0xF52C5F
		GUI, Color, % this.m_sBgdColor

		GUI, Add, Text, x0 y0 hwndg_hSimpleSimpleOSD_MainOutput vg_vSimpleSimpleOSD_MainOutput Wrap Left
		GUI, Add, Text, % "x0 y0 w" this.m_iMaxWidth " r1 vg_vSimpleSimpleOSD_PostDataOutput +Center Hidden" ; Switch out these two text controls for output
		this.m_hFont := Fnt_GetFont(g_hSimpleSimpleOSD_MainOutput)
		this.m_iOneLineOfText := Str_MeasureText("a", this.m_hFont).bottom

		GUI, SimpleOSD:Show, x0 y0 NoActivate
		GUI, SimpleOSD:Hide ; Not using WinMove for sizing since it activates the window

		return this
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	PostMsg(sMsg, iDissmissAfter=3500, hOwner="")
	{
		global
		GUI, SimpleOSD:Default

		; Escape ampersands.
		StringReplace, sMsg, sMsg, &, &&, All

		rect := Str_MeasureTextWrap(sMsg, this.m_iMaxWidth, this.m_hFont)
		this.__New(this.m_sTextColor, this.m_sBgdColor) ; Reset the OSD because it doesn't always stay on top, for some reason.

		GUIControl, Hide, g_vSimpleSimpleOSD_MainOutput
		GUIControl, Show, g_vSimpleSimpleOSD_PostDataOutput
		GUIControl,, g_vSimpleSimpleOSD_PostDataOutput, %sMsg%

		if (hOwner)
		{
			local iW
			WinGetPos,,, iW,, ahk_id %hOwner%
			GUIControl, MoveDraw, g_vSimpleSimpleOSD_PostDataOutput, % "W" iW " H" rect.bottom
			GUI, Show, % "x-9999 y-9999 W" iW " H" rect.bottom " NoActivate"
			CFlyout_New.CenterWndOnOwner(g_hSimpleOSD, hOwner)
		}
		else
		{
			GUIControl, MoveDraw, g_vSimpleSimpleOSD_PostDataOutput, % "W" this.m_iMaxWidth " H" rect.bottom
			GUI, Show, % "W" this.m_iMaxWidth " H" rect.bottom " NoActivate"
		}

		this.DismissAfterNMS(iDissmissAfter)

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	DismissAfterNMS(iNMS)
	{
		global

		this.m_bDismiss := false
		this.m_bOverrideHide := false
		this.m_hOldSimpleOSD := this.m_hSimpleOSD

		SetTimer, SimpleOSD_DismissAfterNMS, %iNMS%
		return

		SimpleOSD_DismissAfterNMS:
		{
			SetTimer, %A_ThisLabel%, Off
			; It seems dubious to support multiple OSDs.
			; The class notifies a message and auto-dismisses it quickly,
			; so it hardly makes sense to display more than one at a time.
			SimpleOSD.Dismiss()
			return
		}
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: SimpleOSD_Dismiss
			Purpose:
		Parameters
			
	*/
	Dismiss()
	{
		WinGetPos,,,, iH, % "ahk_id" this.m_hSimpleOSD
		WAnim_SlideOut("Top", this.m_hSimpleOSD, "SimpleOSD", iH/15, false)
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
}