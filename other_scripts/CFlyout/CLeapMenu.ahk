class CLeapMenu
{
	__New(ByRef rFlyoutMenuHandler_c, ByRef rLeap_c)
	{
		If (!Gdip_Startup())
		{
			MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
			return
		}

		; Remember: assigning an object in this way internally results in a new pointer to the objects memory.
		; This class keep a "const" pointer to the origian memory because
		; it needs to keep up with the menu handler object but should not modify it.
		this.m_rMH_c := rFlyoutMenuHandler_c
		this.m_rLeap_c := rLeap_c

		; References m_rMH_c.
		this.CircleGUI_Init()

		return this
	}

	MenuProc(ByRef rLeapData)
	{
		static s_iLastFocRow := 0, s_iHoveringFor := 0, s_iHoverLimit := 1000

		if (this.m_bCircleHidden)
			this.ShowCircle()

		iVelocityXFactor := this.m_rLeap_c.CalcVelocityFactor(abs(rLeapData.Finger1.VelocityX), 40)
		iVelocityYFactor := this.m_rLeap_c.CalcVelocityFactor(abs(rLeapData.Finger1.VelocityY), 60)

	; Don't move too sluggishly.
	bSmallXDelta := abs(rLeapData.Finger1.DeltaX) < 0.25
	bSmallYDelta := abs(rLeapData.Finger1.DeltaY) < 0.25
	if (bSmallXDelta)
		iVelocityXFactor := 1
	if (bSmallYDelta)
		iVelocityYFactor := 1

		WinGetPos, iX, iY,,, % "ahk_id" this.m_hCircleGUI
		; Avoid shaky movement.
		if (bSmallXDelta)
			iNewX := iX
		else iNewX := iX + (rLeapData.Finger1.DeltaX*iVelocityXFactor)
		; Avoid shaky movement.
		if (bSmallYDelta)
			iNewY := iY
		else iNewY := iY - (rLeapData.Finger1.DeltaY*iVelocityYFactor)

		this.MoveCircle(iNewX, iNewY)

		iFocRow := this.m_rMH_c.GetRowFromPos(this.m_hCircleGUI, iFlyoutUnderCircle, bIsUnderTopmost)
		iLastCall := this.TimeSinceLastCall()

		if (iFocRow == s_iLastFocRow)
		{
			; Inc hovering time.
			s_iHoveringFor += iLastCall

			; When we reach the hover limit, submit/escape/whatever.
			if (s_iHoveringFor >= s_iHoverLimit)
			{
				if (iFlyoutUnderCircle == -1) ; exit all menus...
				{
					; ... but give a little grace period.
					if (s_iHoveringFor >= (s_iHoverLimit * 2))
					{
						this.EndMenuProc(s_iHoveringFor)
						return
					}
				}
				else ; submit selection under appropriate menu.
				{
					; If we are hovering over the previous menu and we are also hovering over what is already selected, do nothing.
					vPrevMenu := this.m_rMH_c.GetMenu_Ref(this.m_rMH_c.m_iNumMenus - 1)
					if (iFlyoutUnderCircle == vPrevMenu.m_iFlyoutNum && iFocRow == vPrevMenu.GetCurSelNdx()+1)
					{
						s_iHoveringFor := 0
						return
					}

					; Exit to the hovered menu, if needed.
					while (this.m_rMH_c.m_iNumMenus > iFlyoutUnderCircle)
						this.m_rMH_c.ExitTopmost()
					; Now launch the menu item focused.
					this.m_rMH_c.Submit(iFocRow, bMainMenuExist)

					if (!bMainMenuExist)
					{
						this.EndMenuProc(s_iHoveringFor)
						return
					}

					s_iHoveringFor := 0
				}
			}
		}
		else s_iHoveringFor := 0

		s_iLastFocRow := iFocRow
		return
	}

	__Get(aName)
	{
		global

		if (aName = "m_hCircleGUI")
			return g_hCircleGUI

		WinGetPos, iX, iY, iW, iH, ahk_id %g_hCircleGUI%
		if (aName = "m_iCircleX")
			return iX
		if (aName = "m_iCircleY")
			return iY
		if (aName = "m_iCircleW")
			return iW
		if (aName = "m_iCircleH")
			return iH

		return
	}

	EndMenuProc(ByRef rs_iHoveringFor)
	{
		this.m_rMH_c.ExitAllMenus()
		this.HideCircle()
		rs_iHoveringFor := 0
		return
	}

	CircleGUI_Init()
	{
		global

		; Make circle exactly the height of one row.
		this.m_iCircleRad := this.m_rMH_c.m_iDefH

		; Create a layered window (+E0x80000) that is always on top (+AlwaysOnTop), has no taskbar entry or caption
		GUI, CircleGUI_: +Hwndg_hCircleGUI LastFound OwnDialogs Owner AlwaysOnTop -Caption E0x80000

		; Create a gdi bitmap with width and height of the work area
		hbm := CreateDIBSection(this.m_iCircleRad, this.m_iCircleRad)

		; Get a device context compatible with the screen
		hdc := CreateCompatibleDC()

		; Select the bitmap into the device context
		obm := SelectObject(hdc, hbm)

		; Get a pointer to the graphics of the bitmap, for use with drawing functions
		G := Gdip_GraphicsFromHDC(hdc)

		; Set the smoothing mode to antialias = 4 to make shapes appear smother (only used for vector drawing and filling)
		Gdip_SetSmoothingMode(G, 4)

		; Get a random colour for the background and foreground of hatch style used to fill the ellipse,
		; as well as random brush style, x and y coordinates and width/height
		; 0 = 0x00000000 and 4294967295 = 0xffffffff as the latest version of ahk has broken Random function that dont use floating point values
		;~ Random, RandBackColour, 0, 4294967295.0
		;~ Random, RandForeColour, 0, 4294967295.0
		;~ Random, RandBrush, 0, 53

		RandBackColour := 654800120.00
		RandForeColour := 3290788387.00
		RandBrush := 7
		RandElipseWidth := 38
		RandElipseHeight := 38

		; Create the random brush
		pBrush := Gdip_BrushCreateHatch(RandBackColour, RandForeColour, RandBrush)

		; Fill the graphics of the bitmap with an ellipse using the brush created
		Gdip_FillEllipse(G, pBrush, RandElipsexPos, RandElipseyPos, RandElipseWidth, RandElipseHeight)

		; Update the specified window
		UpdateLayeredWindow(g_hCircleGUI, hdc, (A_ScreenWidth-this.m_iCircleRad)/2, (A_ScreenHeight-this.m_iCircleRad)/2, this.m_iCircleRad, this.m_iCircleRad)

		; Delete the brush as it is no longer needed and wastes memory
		Gdip_DeleteBrush(pBrush)

		return

		CircleGUI_GUIClose:
		{
			; I don't like disallowing an exit, but
			; if the class is working correctly, the circle will be hidden when it needs to be.
			return
		}
	}

	MoveCircle(iX, iY, iW="", iH="")
	{
		WndMove(iX, iY, "", "", this.m_hCircleGUI, true, false) ; TODO: Un-link dependency on Windows Master.ahk
		GUI, CircleGUI_:+AlwaysOnTop ; Causes a flash, but this is a necessary evil because new CFlyouts will be on top otherwise.
		return
	}

	ShowCircle()
	{
		GUI, CircleGUI_: Show, % "X0 Y0 W" this.m_iCircleRad " H" this.m_iCircleRad
		GUI, CircleGUI_:+AlwaysOnTop
		this.m_bCircleHidden := false
		return
	}

	HideCircle()
	{
		GUI, CircleGUI_: Hide
		this.m_bCircleHidden := true
		return
	}

	TimeSinceLastCall(id=1, reset=0)
	{
		static arr:=array()
		if (reset=1)
		{
			((id=0) ? arr:=[] : (arr[id, 0]:=arr[id, 1]:="", arr[id, 2]:=0))
			return
		}
		arr[id, 2]:=!arr[id, 2]
		arr[id, arr[id, 2]]:=A_TickCount
		return abs(arr[id,1]-arr[id,0])
	}

	m_bCircleHidden := true ; We initialize it with it hidden.
	m_iCircleRad := 38
	m_rMH_c :=
}

#Include %A_ScriptDir%\CFlyoutMenuHandler.ahk