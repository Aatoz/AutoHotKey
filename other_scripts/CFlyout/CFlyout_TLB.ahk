; TODO: Ideas
	; 1. Transparent ListBox: http://www.autohotkey.com/board/topic/96401-transparent-listbox-help-porting-c-to-ahk/
	; 2. Separate Text control for customizable header (such as displaying the date in time with prominent font and color in Window Spy.ahk)

class CFlyout
{
	/*
	----------------------------------------------------------------------------------------------------------------------------------
	public:
	----------------------------------------------------------------------------------------------------------------------------------
	*/
	; Shows the flyout
	 Show()
	{
		this.EnsureCorrectDefaultGUI()
		GUI, Show

		WinGetPos, iX,,,, % "ahk_id" this.m_hFlyout
		if (iX <= -32768)
			WinMove, % "ahk_id" this.m_hFlyout,, this.m_iX

		this.m_bIsHidden := false
		return
	}

	; Hides the flyout and sets the ListBox selection to 1 (if needed).
	Hide()
	{
		this.EnsureCorrectDefaultGUI()
		GUI, Hide

		this.m_bIsHidden := true

		return
	}

	; Wrapper for OnMessage. All window messages that need monitoring should be sent through this function instead of directly sent to native OnMessage
		; 1.Msgs is a comma-delimited list of Window Messages. All messages are initially directed towards CFlyout_OnMessage.
	; Class-specific functionality, such as WM_LBUTTONDOWN messages, are handled in this function.
		; 2.sCallback is the function name of a callback for CFlyout_OnMessage. sCallback must be a function that takes two parameters: a CFlyout object and a msg.
	OnMessage(msgs, sCallback="")
	{
		static WM_LBUTTONDOWN:=513, WM_KEYDOWN:=256

		Loop, Parse, msgs, `,
		{
			if (A_LoopField = "ArrowDown")
			{
				; TODO: VK_KeyDown?
				Hotkey, IfWinActive, % "ahk_id" this.m_hFlyout
					Hotkey, Down, CFlyout_OnArrowDown
			}
			else if (A_LoopField = "ArrowUp")
			{
				Hotkey, IfWinActive, % "ahk_id" this.m_hFlyout
					Hotkey, Up, CFlyout_OnArrowUp
			}
			else OnMessage(A_LoopField, "CFlyout_OnMessage")

			if (%A_LoopField% == WM_LBUTTONDOWN)
				this.m_bHandleClick := false
		}

		if (this.m_bHandleClick)
			OnMessage(WM_LBUTTONDOWN, "CFlyout_OnMessage")

		this.m_sCallbackFunc := sCallback
		return
	}

	; 1. Currently iW is simply set to m_iW. Sometime in the future, iW will be automatically assigned based on a m_iMaxWidth variable.
	; 2. Sets iH to what CalcHeight() returns.
	GetWidthAndHeight(ByRef riW, ByRef riH)
	{
		; The two lines below ensure that these are out params (as opposed to in/out)
		riH := riW :=

		while (A_Index <= this.m_iMaxRows)
		{
			sTmp := this.m_asItems[A_Index + this.m_iDrawnAtNdx]

			if (A_Index + this.m_iDrawnAtNdx > this.m_asItems.MaxIndex())
				break

			iTmpW := Str_MeasureText(sTmp == A_Blank ? "a" : sTmp, this.m_hFont).right
			if (iTmpW < this.m_iW && iTmpW > riW)
				riW := iTmpW

			; Transparent LB doesn't support 
			;~ Str_Wrap(sTmp == A_Blank ? "a" : sTmp, this.m_iW, this.m_hFont, true, iTmpH)
			riH += this.m_vTLB.ItemHeight
		}

		if (riW == A_Blank)
			iW := this.m_iW
		if (riH == A_Blank)
			;~ Str_Wrap("a", this.m_iW, this.m_hFont, true, riH)
			riH := this.m_vTLB.ItemHeight

		riW += 9
		if (this.m_asItems.MaxIndex() > this.m_iMaxRows) ; Scrollbar is 18px wide
			riW += 18
		riH += 5

		riW := this.m_iW ; TODO: logic for auto-sizing width from wrapper

		return
	}

	; Calculates height of flyout based on the widest string in m_asItems. Height will be no greater than m_iH.
	CalcHeight()
	{
		while (A_Index <= this.m_iMaxRows)
		{
			sTmp := this.m_asItems[A_Index + this.m_iDrawnAtNdx]

			if (A_Index + this.m_iDrawnAtNdx > this.m_asItems.MaxIndex())
				break

			iTmpW := Str_MeasureText(sTmp == A_Blank ? "a" : sTmp, this.m_hFont).right
			if (iTmpW < this.m_iW && iTmpW > riW)
				riW := iTmpW

			; Transparent LB doesn't support 
			;~ Str_Wrap(sTmp == A_Blank ? "a" : sTmp, this.m_iW, this.m_hFont, true, iTmpH)
			riH += this.m_vTLB.ItemHeight
		}

		if (riW == A_Blank)
			iW := this.m_iW
		if (riH == A_Blank)
			;~ Str_Wrap("a", this.m_iW, this.m_hFont, true, riH)
			riH := this.m_vTLB.ItemHeight

		riW += 9
		if (this.m_asItems.MaxIndex() > this.m_iMaxRows) ; Scrollbar is 18px wide
			riW += 18
		riH += 5
		return
	}

	; Calculates height from m_iDrawnAtNdx (topmost item being display) to item number iTo. Used in CFlyoutMenuHandler.
	CalcHeightTo(iTo)
	{
		VarSetCapacity(RECT, 16, 0)
		SendMessage, %LB_GETITEMRECT%, iTo, % &RECT, , % "ahk_id" this.m_hListBox
		return NumGet(RECT, 12, "Int")
		;~ This.ItemHeight := NumGet(RECT, 12, "Int") - NumGet(RECT, 4, "Int")

		while (A_Index <= iTo)
		{
			sTmp := this.m_asItems[A_Index + this.m_iDrawnAtNdx]

			if (A_Index + this.m_iDrawnAtNdx > this.m_asItems.MaxIndex())
				break

			Str_Wrap(sTmp, this.m_iW, this.m_hFont, true, iTmpH)
			iH += iTmpH
		}

		if (iH == A_Blank)
			Str_Wrap("a", this.m_iW, this.m_hFont, true, iH)

		return iH
	}

	; Returns currently selected item in flyout
	GetCurSel()
	{
		ControlGet, sCurSel, Choice, ,, % "ahk_id" this.m_hListBox
		return sCurSel
	}

	; Returns index of currently selected item in flyout
	GetCurSelNdx()
	{
		return this.m_vTLB.CurSel
	}

	; Finds the string and returns the index
	FindString(sString)
	{
		ControlGet, iString, FindString, %sString%,, % "ahk_id" this.m_hListBox
		return iString
	}

	Move(bUp)
	{
		static LB_SETCURSEL:=390

		iSel := bUp ? this.m_vTLB.CurSel - 1: this.m_vTLB.CurSel + 1
		if (iSel > this.m_vTLB.ItemCount - 1) ; Wrap to top
			SendMessage, LB_SETCURSEL, 0, 0, , % "ahk_id" this.m_hListBox
		else if (iSel < 0) ; Wrap to bottom
			SendMessage, LB_SETCURSEL, % this.m_vTLB.ItemCount - 1, 0, , % "ahk_id" this.m_hListBox
		else SendMessage, LB_SETCURSEL, % iSel, 0, , % "ahk_id" this.m_hListBox ; Move Up/Down
		return
	}

	MoveTo(iTo)
	{
		static LB_SETCURSEL:=390
		SendMessage, LB_SETCURSEL, iTo-1, 0,, % "ahk_id" this.m_hListBox
		return
	}

	MovePage(bUp)
	{
		if (bUp)
			ControlSend,,{PgUp}, % "ahk_id" this.m_hListBox
		else ControlSend,,{PgDn}, % "ahk_id" this.m_hListBox

		return
	}

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function:
			Purpose:
		Parameters
			iClickY: Where to click
	*/
	Click(iClickY)
	{
		ControlClick,, % "ahk_id " this.m_hListBox,,,, y%iClickY%
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	Scroll(bUp)
	{
		static WM_VSCROLL:=0x0115
		PostMessage, WM_VSCROLL, % !bUp, 0,, % "ahk_id " this.m_hListBox
		return
	}

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: RemoveItem
			Purpose:
		Parameters
			iItem: Index of item to remove
	*/
	RemoveItem(iItem)
	{
		Control, Delete, %iItem%,, % "ahk_id " this.m_hListBox
		this.m_asItems[iItem].Remove
		this.RedrawControls()
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; Updates flyout with new items specified in aStringList; aStringList is assigned to m_asItems.
	; If aStringList is 0, then the flyout is redrawn using the same m_asItems. 
	; f aStringList is non-zero, then potential changes in the flyout include changes in Height,
	; and changes in X and Y positioning (depending on m_iAnchorAt, m_bDrawBelowAnchor and m_bFollowMouse).
	UpdateFlyout(aStringList = 0)
	{
		this.EnsureCorrectDefaultGUI()

		if (aStringList == 0)
			aStringList := this.m_asItems
		else
		{
			; Set up new cmd list for display.
			;~ Str_ManuallyWrapArray(aStringList, this.m_iW, this.m_hFont)
			this.m_asItems := aStringList

			; List box.
			GUIControl,, m_vLB, % "|" this.GetCmdListForListBox() ; First | replaces all the LB contents.
			GUIControl, Choose, m_vLB, 1 ; Choose the first entry in the list.
		}

		if (this.m_bIsHidden)
			this.Show()

		; Resize GUI controls, if needed.
		this.RedrawControls()

		return
	}

	; GUI interface for editing Flyout_Config.ini. May be callable without initializing any CFlyout object like so, “CFlyout.GUIEditSettings()”
		; 1. hParent is for parentage GUI. If nonzero, then the parent window will be deactivated until the GUI is closed.
		; 2. sGUI is used to determine whether or not GUIEditSettings should be a standalone GUI with its own window
			; or simply added to an existing GUI. i.e. (GUIEditSettings(hGUI1, “1”))
		; 3. bReloadOnExit : if true, Reload will be executed when the GUI is closed.
			; This is useful if you are using multiple flyouts in one script and want them all to be updated with your latest changes.
	GUIEditSettings(hParent=0, sGUI="", bReloadOnExit=false)
	{
		global

		LV_Colors()

		; http://msdn.microsoft.com/en-us/library/windows/desktop/aa511453.aspx#sizing
		local iMSDNStdBtnW := 75
		local iMSDNStdBtnH := 23
		local iMSDNStdBtnSpacing := 6
		;~ GUI, Margin, %iMSDNStdBtnSpacing%, %iMSDNStdBtnSpacing%

		; Load settings from Flyout_config.ini
		if (!this.LoadDefaultSettings(sError))
		{
			Msgbox 8192,, %sError%
			return false
		}

		g_vTmpFlyout := new CFlyout(0, ["This is a preview", "1", "2", "3"])
		g_vConfigIni := class_EasyIni(A_WorkingDir "\Flyout_config.ini")
		g_bReloadOnExit := bReloadOnExit

		if (sGUI == A_Blank)
			GUI GUIFlyoutEdit: New, hwndhFlyoutEdit Resize MinSize, Flyout Settings
		else GUI %sGUI%:Default

		GUI, Add, ListView, xm y5 w450 h250 AltSubmit hwndhLV vvGUIFlyoutEditLV gGUIFlyoutEditLVProc, Option|Value
		LV_Colors.OnMessage()
		LV_Colors.Attach(hLV)

		GUI, Add, Button, % "xp yp+" 250+iMSDNStdBtnSpacing " w450 h" iMSDNStdBtnH " vvGUIFlyoutEditSettings gGUIFlyoutEditSettings", &Edit

		if (sGUI == A_Blank)
		{
			GUI, Add, Button, % "xp+" 450-(iMSDNStdBtnW*2)-iMSDNStdBtnSpacing " yp+" iMSDNStdBtnH+iMSDNStdBtnSpacing " w" iMSDNStdBtnW " hp vvGUIFlyoutEditGUIOK gGUIFlyoutEditGUIOK", &OK
			GUI, Add, Button, % "xp+" iMSDNStdBtnW+iMSDNStdBtnSpacing " yp wp hp vvGUIFlyoutEditGUIClose gGUIFlyoutEditGUIClose", &Cancel
		}

		local key, val, iColorRowNum
		for key, val in this.m_vConfigIni.Flyout
		{
			LV_Add("", key, this.m_vConfigIni.Flyout[key])
			if (key = "FontColor")
				iColorRowNum := LV_GetCount()
		}
		LV_ModifyCol()

		g_hOwner := sGUI == A_Blank ? hParent : hFlyoutEdit
		if (g_hOwner)
		{
			GUI +Owner%g_hOwner%
			WinSet, Disable,, ahk_id %g_hOwner%
		}

		if (sGUI == A_Blank)
		{
			GUI Show, x-32768 AutoSize
			this.CenterWndOnOwner(hFlyoutEdit, g_hOwner)
		}
		else WinActivate, ahk_id %g_hOwner% ; Owner was de-activated through creation of g_vTmpFlyout

		GUIControl, -Redraw, %hLV%
		LV_Colors.Cell(hLV, iColorRowNum, 2, this.m_vConfigIni.Flyout.FontColor)
		GUIControl, +Redraw, %hLV%

		GUIControl, Focus, vGUIFlyoutEditLV
		LV_Modify(1, "Select")
		LV_Modify(1, "Focus")

	; Wait for dialog to be dismissed
	while (sGUI == A_Blank && WinExist("ahk_id" hFlyoutEdit))
	{
		if (g_hOwner && !WinExist("ahk_id" g_hOwner))
			break ; If the owner was closed somehow, then this dialog should also be closed.
		continue
	}

		return

		GUIFlyoutEditLVProc:
		{
			if (A_GUIEvent = "DoubleClick" || A_EventInfo == 113) ; 113 = F2
			{
				gosub GUIFlyoutEditSettings
				return
			}

			return
		}

		GUIFlyoutEditSettings:
		{
			GUI +OwnDialogs

			sCurRowCol1 := LV_GetSelText()
			sCurRowCol2 := LV_GetSelText(2)

			if (sCurRowCol1 = "Background")
			{
				FileSelectFile, sVal
				if (!sVal) ; User cancelled
					return
			}
			else if (sCurRowCol1 = "Font")
			{
				sFontName := SubStr(sCurRowCol2, 1, InStr(sCurRowCol2, ",") - 1)
				sFont := SubStr(sCurRowCol2, InStr(sCurRowCol2, ",") + 1)

				; Basically, we want to hide to color option in this font dialog so as not to confuse users.
				; It is inferior to the actual color picker dlg from Dlg_Color because it does not allow you to
				; choose/define custom colors
				SetTimer, GUIFlyout_HideColorOption, 100
				if (Fnt_ChooseFont(hFlyoutEdit, sFontName, sFont))
				{
					sVal := sFontName ", " sFont
					StringReplace, sVal, sVal, c000000%A_Space%
					LV_Modify(LV_GetSel(), "", sCurRowCol1, sVal)

					g_vConfigIni.Flyout.Font := sVal
					gosub GUIFlyoutUpdateTmpFlyout
					return
				}

				gosub GUIFlyoutUpdateTmpFlyout
				return
			}
			else if (sCurRowCol1 = "FontColor")
			{
				sTmpColor := g_vConfigIni.Flyout.FontColor
				sColor := Dlg_Color(sTmpColor, hFlyoutEdit)
				sVal := RGB(sColor)
				g_vConfigIni.Flyout.FontColor := sVal

				GUIControl, -Redraw, %hLV%
				LV_Colors.Cell(hLV, LV_GetSel(), 2, sVal)
				 GUIControl, +Redraw, %hLV%
			}
			else
			{
				InputBox, sVal,, %sCurRowCol1%`n`n%sAdditional%,,325,175,,,,,%sCurRowCol2%

				if (ErrorLevel)
					return
			}

			LV_Modify(LV_GetSel(), "", sCurRowCol1, sVal)
			g_vConfigIni.Flyout[sCurRowCol1] :=  sVal

			gosub GUIFlyoutUpdateTmpFlyout
			return
		}

		GUIFlyout_HideColorOption:
		{
			IfWinNotActive, Font ahk_class #32770
				return

			Control, Hide,, Static4, Font ahk_class #32770
			Control, Hide,, ComboBox4, Font ahk_class #32770

			ControlGet, bHidden, Visible,, ComboBox4, Font ahk_class #32770
			if (!bHidden)
				SetTimer, GUIFlyout_HideColorOption, Off
			return
		}

		GUIFlyoutUpdateTmpFlyout:
		{
			g_vTmpFlyout:=

			aKeysValsCopy := {}
			for key, val in g_vConfigIni.Flyout
			{
				if (InStr(val, "Expr:"))
					aKeysValsCopy.Insert(key, DynaExpr_EvalToVar(SubStr(val, InStr(val, "Expr:") + 5)))
				else aKeysValsCopy.Insert(key, val)
			}

			g_vTmpFlyout := new CFlyout(0, ["This is a preview", "1", "2", "3"], aKeysValsCopy.ReadOnly, aKeysValsCopy.ShowInTaskbar, aKeysValsCopy.X, aKeysValsCopy.Y, aKeysValsCopy.W, aKeysValsCopy.MaxRows, aKeysValsCopy.AnchorAt, true, aKeysValsCopy.Background, aKeysValsCopy.Font, "c" g_vConfigIni.Flyout.FontColor)
			WinActivate, ahk_id %hFlyoutEdit%
			return
		}

		GUIFlyoutEditGUISize:
		{
			Critical

			if (hFlyoutEdit)
			{
				Anchor2("GUIFlyoutEdit:vGUIFlyoutEditLV", "xwyh", "0, 1, 0, 1")
				Anchor2("GUIFlyoutEdit:vGUIFlyoutEditSettings", "xwyh", "0, 1, 1, 0")
				Anchor2("GUIFlyoutEdit:vGUIFlyoutEditGUIOK", "xwyh", "1, 0, 1, 0")
				Anchor2("GUIFlyoutEdit:vGUIFlyoutEditGUIClose", "xwyh", "1, 0, 1, 0")

				; ControlGetPos because GUIControlGet is not working here
				ControlGetPos, iLVX, iLVY, iLVW, iLVH,, ahk_id %hLV%
				iResize := iLVW / 4
				LV_ModifyCol(1, iResize)
				LV_ModifyCol(2, iLVW - iResize - 5)
			}
			return
		}
		GUIFlyoutEditGUIEscape:
		GUIFlyoutEditGUIOK:
		{
			; Save settings
			g_vConfigIni.Save()
			g_vConfigIni:=
		} ; Fall through
		GUIFlyoutEditGUIClose:
		{
			if (g_hOwner)
				WinSet, Enable,, ahk_id %g_hOwner%

			if (g_bReloadOnExit)
				Reload

			GUI, Destroy
			g_vTmpFlyout :=
			return
		}
	}

	/*
	----------------------------------------------------------------------------------------------------------------------------------
	private:
	----------------------------------------------------------------------------------------------------------------------------------
	*/
	; Note, hParent and asTextToDisplay excluded, any parameter that is set to 0 will instead be set via their
	; corresponding key/value pair in Flyout_config.ini. If a value still cannot be set, creation will likely fail.
		; 1. hParent = 0. If nonzero, must be a valid handle to a window; when set, the CFlyout will become the child of hParent.
		; 2. asTextToDisplay = 0. AHK [] linear array of strings. These will be displayed on the GUI.
			; Each element of the array will be separated by a newline. If any element of the array is too wide,
				; the text will be wrapped accordingly.
		; 3. bReadOnly = 0. When true, the GUI is non-clickable, and no selection box is shown.
		; 4. bShowInTaskbar = 0. Typically used when CFlyout is used like a control instead of a window –
			; you wouldn’t want your “control” showing up in the taskbar. 
		; 5. iX = 0. X coordinate. When iX AND iY are less than -32768, CFlyout will follow your mouse like a Tooltip;
			; it wouldn’t make sense to make CFlyout non-readonly and also set it to follow your mouse, but you can anyway.
			; See DictLookup for an example of how/why you would do this.
		; 6. iY = 0. Y coordinate. Also needs to be set to be to less than -32768 in order for CFlyout to follow the mouse.
		; 7. iW = 0. Width of the Flyout, in pixels. Text will be wrapped based on this number.
		; 8. iMaxRows = 10. Determines the maximum height of the Flyout. Height is dynamically set based on the number
			; of elements in asTextToDisplay. If iMaxRows is set to 10 and there are 11 elements in asTextToDisplay,
			; then the 11th element will not show up on the Flyout; instead, it will can be scrolled down to
			; and will be located beneath the 10th element, naturally.
		; 9. iAnchorAt = -99999. Y Coordinates to “anchor” Flyout GUI to. When set to a number less than -32768,
			; this is effectively telling CFlyout to not anchor to any point. When blank, it loads the setting from CFlyout_Config.ini
		; 10. bDrawBelowAnchor = true. Completely ignored if iAnchorAt < -32768; when true, subsequent Flyout
			; redraws/resizes will place the Top of the Flyout below the specified point; when false,
			; it will place the Bottom of the Flyout above the specified point.
		; 11. sBackground = 0. Background picture for Flyout. If 0 or an invalid file, then the background will be all Black.
		; 12. sFont = 0. Font options in native AHK format sans color. For example, “Arial, s15 Bold”
		; 13. sFontColor = 0. Font color in native AHK format (so it can be hex code or plain color like “Blue”)
	__New(hParent = 0, asTextToDisplay = 0, bReadOnly = "", bShowInTaskbar = "", iX = "", iY = "", iW = "", iMaxRows = 10, iAnchorAt = -99999, bDrawBelowAnchor = true, sBackground = 0, sFont = 0, sFontColor = 0, sTextAlign = "", bAlwaysOnTop = "", bShowOnCreate = true, bExitOnEsc = true)
	{
		global
		local iLocX, iLocY, iLocW, iLocH, iLocScreenH, sLocPreventFocus, sLocShowInTaskbar, sLocNoActivate

		SetWinDelay, -1
		CoordMode, Mouse ; Defaults to Screen

		this.m_hParent := hParent
		if (asTextToDisplay = 0)
			asTextToDisplay := [""]

		; Load settings from Flyout_config.ini
		if (!this.LoadDefaultSettings(sError))
		{
			Msgbox 8192,, %sError%
			return false
		}

		if (iX != A_Blank && iX < -32768 && iY != A_Blank && iY < -32768)
			this.m_bFollowMouse := true
		if (iX != A_Blank)
			this.m_iX := iX
		if (iY != A_Blank)
			this.m_iY := iY
		if (iW != A_Blank)
			this.m_iW := iW
		if (this.m_iMaxRows <= 0 || (iMaxRows > 0 && iMaxRows != 10))
			this.m_iMaxRows := iMaxRows
		if (iAnchorAt != A_Blank || iAnchorAt = -99999)
			this.m_iAnchorAt := iAnchorAt
		if (sBackground)
			this.m_sBackground := sBackground
		if (bReadOnly != A_Blank)
			this.m_bReadOnly := bReadOnly
		if (bShowInTaskbar != A_Blank)
			this.m_bShowInTaskbar:= bShowInTaskbar
		if (bAlwaysOnTop != A_Blank)
			this.m_bAlwaysOnTop := bAlwaysOnTop
		if (sFont)
			this.m_sFont := sFont
		if (sFontColor)
			this.m_sFontColor := sFontColor

		; Naming convention is GUI_FlyoutN. If, for example, 2 CFlyouts already exists, name this flyout GUI_Flyout3
		Loop
		{
			GUI, GUI_Flyout%A_Index%:+LastFoundExist
			IfWinExist
				continue

			iFlyoutNum := A_Index
			break
		}
		this.m_iFlyoutNum := iFlyoutNum
		GUI, GUI_Flyout%iFlyoutNum%: New, +Hwndg_hFlyout, GUI_Flyout%iFlyoutNum%
		this.m_hFlyout := g_hFlyout
		CFlyout.FromHwnd[g_hFlyout] := &this ; for OnMessage handlers

		Hotkey, IfWinActive, ahk_id %g_hFlyout%
		{
			Hotkey, ^C, CFlyout_CopySelected
			if (this.m_bExitOnEsc)
				Hotkey, Esc, CFlyout_GUIEscape
		}

		; Font and color settings
		GUI, Font, % SubStr(this.m_sFont, InStr(this.m_sFont, ",") + 1) " " this.m_sFontColor, % SubStr(this.m_sFont, 1, InStr(this.m_sFont, ",") - 1) ; c000080 ; c83B2F7 ; EEAA99
		GUI, Color, Black ; a black background helps reduce the eye's natural reaction to the blinking effect

		; Add picture
		; Not specifying width and height so that image does not get morphed.
		GUI, Add, Picture, +0x4 AltSubmit X0 Y0 hwndg_hPic, % this.m_sBackground

		; Add ListBox, populate it, then make it transparent
		this.m_asItems := asTextToDisplay
		GUI, Add, ListBox, % "x0 y0 r" (asTextToDisplay.MaxIndex() > iMaxRows ? iMaxRows : asTextToDisplay.MaxIndex()) " Choose1 vm_vLB HWNDg_hListBox", % this.GetCmdListForListBox()
		this.m_hListBox := g_hListBox
		this.m_vTLB := new TransparentListBox(g_hListBox, g_hPic, SubStr(this.m_sFontColor, 2), SubStr(this.m_sFontColor, 2), 0x6AEFF, 80) ; TODO: Custom colors

		this.m_hFont := Fnt_GetFont(this.m_hListBox)
		this.GetWidthAndHeight(iLocW, iLocH)
		GUIControl, MoveDraw, m_vLB, W%iLocW%
		this.RedrawControls()

		; End controls init. Begin GUI init
		this.m_bReadOnly := bReadOnly
		if (this.m_hParent != 0)
		{
			GUI, % "+Owner" this.m_hParent
			if (this.m_bReadOnly)
				WinSet, Disable,, ahk_id %g_hFlyout%
			;~ else WinSet, Disable,, % "ahk_id" this.m_hParent
		}

		iLocX := this.m_iX
		iLocY := this.m_iY
		if (this.m_iAnchorAt >= -32768)
		{
			this.m_bDrawBelowAnchor := bDrawBelowAnchor

			iLocScreenH := GetMonitorRectAt(iLocX, iLocY).bottom
			if (bDrawBelowAnchor)
				iLocY := iLocScreenH - this.m_iAnchorAt
			else iLocY := iLocScreenH - iLocH - this.m_iAnchorAt
		}
		else this.m_bDrawBelowAnchor := false ; if we aren't going to anchor, then this setting is superfluous

		if (this.m_bFollowMouse)
		{
			GetRectForTooltip(iLocX, iLocY, iLocW, iLocH)
			g_hMouseHook := DllCall("SetWindowsHookEx", "int", WH_MOUSE_LL:=14 , "uint", RegisterCallback("CFlyout_MouseProc"), "uint", 0, "uint", 0)
		}

		; See http://www.autohotkey.com/board/topic/21449-how-to-prevent-the-parent-window-from-losing-focus/
		sLocPreventFocus := this.m_bReadOnly ? "+0x40000000 -0x80000000" : ""
		sLocShowInTaskbar := bShowInTaskbar ? "" : "+ToolWindow"
		sLocAlwaysOnTop := this.m_bAlwaysOnTop ? "AlwaysOnTop" : ""
		GUI, +LastFound -Caption %sLocAlwaysOnTop% %sLocPreventFocus% %sLocShowInTaskbar%

		sLocNoActivate := bReadOnly ? "NoActivate" : ""
		if (this.m_asItems.MaxIndex() && bShowOnCreate) ; If we have text to display and should show it on creation, do it now.
			GUI, Show, X%iLocX% Y%iLocY% W%iLocW% H%iLocH% %sLocNoActivate%
		else ; create the GUI but keep it hidden.
		{
			GUI, Show, X-32768 Y%iLocY% W%iLocW% H%iLocH% %sLocNoActivate%
			this.Hide()
			WinMove, % "ahk_id" this.m_hFlyout,, %iLocX%
		}

		return this


		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;;;;;;;;;;;;;;
		CFlyout_GUIEscape:
		{
			Msgbox escape..
			Object(CFlyout.FromHwnd[WinExist(A)]).__Delete()
			return
		}
		;;;;;;;;;;;;;;
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;;;;;;;;;;;;;;
		CFlyout_CopySelected:
		{
			sTmpSel := Object(CFlyout.FromHwnd[g_hFlyout]).GetCurSel()
			if (sTmpSel != A_Blank)
				clipboard := sTmpSel

			sTmpSel :=
			return
		}
		;;;;;;;;;;;;;;
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;;;;;;;;;;;;;;
		CFlyout_OnArrowDown:
		{
			Object(CFlyout.FromHwnd[WinExist(A)]).Move(false)
			return
		}
		;;;;;;;;;;;;;;
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
		;;;;;;;;;;;;;;
		CFlyout_OnArrowUp:
		{
			Object(CFlyout.FromHwnd[WinExist(A)]).Move(true)
			return
		}
		;;;;;;;;;;;;;;
		;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	}

	; Handles safe destruction of all objects CFlyout is responsible for. It is very important to note that,
	; since CFlyout.FromHwnd stores references to CFlyout classes, any object that is assigned a Flyout
	; (i.e. vFlyout := Object(CFlyout.FromHwnd[WinExist(“A”)])) must be released (i.e. vFlyout :=)
	; in order for __Delete to automatically be called upon removal of original Flyout object
	; assigned via vFlyout := new CFlyout(…))
	; Any special destructor handling should go in here.
	__Delete()
	{
		global CFlyout, g_hMouseHook
		this.EnsureCorrectDefaultGUI()

		if (this.m_bFollowMouse)
			DllCall("UnhookWindowsHookEx", "ptr", g_hMouseHook)

		GUI, Destroy
		CFlyout.FromHwnd.Remove(this.m_hFlyout)
		this:=g_hMouseHook:=

		return
	}

	; aName permutations are: GetFlyoutX, GetFlyoutY, GetFlyoutW, GetFlyoutH. These options are wrappers for WinGetPos of the flyout window.
	__Get(aName)
	{
		WinGetPos, iX, iY, iW, iH, % "ahk_id" this.m_hFlyout
		if (aName = "GetFlyoutX")
			return iX
		if (aName = "GetFlyoutY")
			return iY
		if (aName = "GetFlyoutW")
			return iW
		if (aName = "GetFlyoutH")
			return iH

		return
	}

	; Loads settings for flyout from Flyout_Config.ini. If any options are not specified,
	; the default options specified in GetDefaultConfigIni will be used. If any unknown keys are in the inis, then an error is returned.
		; 1. rsError is set to an error message if the function returns false.
	; You can override default settings in Initialize()
	LoadDefaultSettings(ByRef rsError)
	{
		vDefaultConfigIni := class_EasyIni("", this.GetDefaultConfigIni())
		this.m_vConfigIni := class_EasyIni(A_WorkingDir "\Flyout_config.ini")
		; Merge allows new sections/keys to be added without any compatibility issues
		; Invalid keys/sections will be removed since bRemoveNonMatching (by default) is set to true
		this.m_vConfigIni.Merge(vDefaultConfigIni)

		for key, val in this.m_vConfigIni.Flyout
		{
			if (InStr(val, "Expr:"))
				val := DynaExpr_EvalToVar(SubStr(val, InStr(val, "Expr:") + 5))

			if (key = "X")
				this.m_iX := val
			else if (key = "Y")
				this.m_iY := val
			else if (key = "W")
				this.m_iW := val
			;~ else if (key = "H")
				;~ this.m_iH := val
			else if (key = "MaxRows")
				this.m_iMaxRows := val
			;~ else if (key = "MaxWidth")
				;~ this.m_iMaxWidth := val
			else if (key = "AnchorAt")
				this.m_iAnchorAt := val
			else if (key = "DrawBelowAnchor")
				this.m_bDrawBelowAnchor := val
			else if (key = "Background")
				this.m_sBackground := val
			else if (key = "ReadOnly")
				this.m_bReadOnly := val
			else if (key = "ShowInTaskbar")
				this.m_bShowInTaskbar := val
			else if (key = "ExitOnEsc")
				this.m_bExitOnEsc := (val == true)
			else if (key = "AlwaysOnTop")
				this.m_bAlwaysOnTop := val
			else if (key = "Font")
				this.m_sFont := val
			else if (key = "FontColor")
				this.m_sFontColor := "c" val
			else
			{
				rsError := "Error: Missing key/val pair for " key "."
				return false
			}
		}

		return true
	}

	; Redraw any controls that need redrawing
	; Called from UpdateFlyout. To update the flyout with new text, call UpdateFlyout instead.
	RedrawControls()
	{
		this.EnsureCorrectDefaultGUI()

		iWidth := iHeight :=
		; If the cmd list has been updated, then this will use the new dimensions needed for the GUI;
		; otherwise, it uses the dimensions that the GUI is already using.
		this.GetWidthAndHeight(iWidth, iHeight)

		iX := this.GetFlyoutX
		iY := this.GetFlyoutY
		if (iX < -32768 || iX == A_Blank)
			iX := this.m_iX
		if (iY < -32768 || iY == A_Blank)
			iY := this.m_iY

		if (this.m_iAnchorAt >= -32768)
		{
			iScreenH := GetMonitorRectAt(iX, iY).bottom
			if (this.m_bDrawBelowAnchor)
				iY := iScreenH - this.m_iAnchorAt
			else iY := iScreenH - iHeight - this.m_iAnchorAt
		}
		else if (this.m_bFollowMouse)
			GetRectForTooltip(iX, iY, iWidth, iHeight)

		WinMove, % "ahk_id" this.m_hFlyout,, %iX%, %iY%, %iWidth%, %iHeight%

		; Update TLB
		this.m_vTLB.SetRedraw(false)
		WinMove, % "ahk_id" this.m_vTLB.hLB,, 0, 0, iWidth, iHeight
		this.m_vTLB.Update()
		this.m_vTLB.SetRedraw(true)

		return
	}

	GetCmdListForDisplay(iStartAt = 0)
	{
		asCmdListForDisplay := []
		while (A_Index <= this.m_iMaxRows)
		{
			if (iStartAt+A_Index > this.m_asItems.MaxIndex())
				break

			asCmdListForDisplay.Insert(this.m_asItems[iStartAt+A_Index])
		}

		return st_glue(asCmdListForDisplay)
	}

	; Formats m_asItems for display on m_LB control.
	GetCmdListForListBox()
	{
		sCmdListForListBox :=
		Loop, % this.m_asItems.MaxIndex()
		{
			CurElement := this.m_asItems[A_Index + this.m_iDrawnAtNdx]
			if (A_Index == 1)
				sCmdListForListBox := CurElement
			else sCmdListForListBox = %sCmdListForListBox%|%CurElement%
		}
		return sCmdListForListBox
	}

	; Currently unused. The idea is to fill a completely empty line a specified separator
	; such as "-". Then flyout text, mainly in ReadOnly mode, could be made more readable being separated by “-”s.
	; See DictLookup for an example of what I have in mind.
	CalcAndSetSeparator()
	{
		this.m_sSeparator :=
		iMaxChars := Str_GetMaxCharsForFont("-", this.m_iW, this.m_hFont) ; TODO: User set the Separator

		Loop %iMaxChars%
			this.m_sSeparator .= "-"
		return
	}

	; Safety function to ensure that all GUI commands used by the class are directed towards the right GUI.
	EnsureCorrectDefaultGUI()
	{
		iFlyoutNum := this.m_iFlyoutNum
		GUI, GUI_Flyout%iFlyoutNum%:Default
		return
	}

	; Default ini for Flyout_Config.ini. Function is used is used for class_EasyIni object to provide
	; a safe way to push new sections and keys to Flyout_Config.ini without changing any existing settings in Flyout_Config.ini.
	GetDefaultConfigIni()
	{
		return "
			(LTrim
				[Flyout]
				AnchorAt=-99999
				Background=Default.jpg
				Font=Arial, s15
				FontColor=White
				MaxRows=10
				ReadOnly=0
				ShowInTaskbar=0
				X=0
				Y=0
				W=400
				ExitOnEsc=true
			)"
	}

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

	; Member Variables

	; public:
		; [Flyout] in Flyout_config.ini. All may also be set from __New
		m_iX :=
		m_iY :=
		m_iW :=
		m_iMaxRows :=
		m_iAnchorAt :=
		m_bDrawBelowAnchor :=
		m_bReadOnly :=
		m_bShowInTaskbar :=
		m_bAlwaysOnTop :=

		m_sBackground :=

		; Font Dlg
		m_sFont :=
		m_sFontColor :=
		; End Flyout_config.ini section.

	; private:
		m_vConfigIni := {}

		m_bFollowMouse := false ; Set to true when m_iX and m_iY are less than -32768
		static m_iMouseOffset := 16 ; Static pixel offset used to separate mouse pointer from Flyout when m_bFollowMouse is true
		m_sSeparator := ; Not yet interfaced. The idea is to fill a completely empty line a specified separator such as "-"

		m_iDrawnAtNdx := 0 ; 0-based. Used to keep tracking scrolling position. If iMaxRows is set to 10,
			; and 11 elements are in asTextToDisplay, and the user has scrolled to the 11th element,
			; then m_iDrawnAtNdx is set to 1, since we have scrolled past position 1.
		m_bIsHidden := ; True when Hide() is called. False when Show() is called.

		; Handles
		m_hFlyout := ; Handle to main GUI
		m_hListBox :=
		m_hFont := ; Handle to logical font for Text control
		m_hParent := ; Handle to parent assigned from hParent in __New

		; Control IDs
		m_vLB :=
		m_vSelector :=

		m_iFlyoutNum := ; Needed to multiple CFlyouts
		m_asItems := [] ; Formatted for Text control display purposes

		; OnMessage callback
		m_sCallbackFunc := ; Function name for optional OnMessage callbacks
		m_bHandleClick := true ; Internally handle clicks by moving selection.
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Message handler for all messages specified through CFlyout.OnMessage.
;;;;;;;;;;;;;; Class-specific functionality, such as WM_LBUTTONDOWN messages, are handled in this function.
CFlyout_OnMessage(wParam, lParam, msg, hWnd)
{
	global g_hFlyout
	Critical
	static s_iUseThisToAvoidWeirdBug := 100
	static WM_LBUTTONDOWN:=513

	;~ SetFormat, Float,, H

	if (CFlyout.FromHwnd.HasKey(hWnd))
		vFlyout := Object(CFlyout.FromHwnd[hWnd])
	else
	{
		while (A_Index < s_iUseThisToAvoidWeirdBug && !IsObject(vFlyout))
			vFlyout := Object(CFlyout.FromHwnd[hWnd - A_Index])
	}
	if (!IsObject(vFlyout))
		vFlyout := Object(CFlyout.FromHwnd[g_hFlyout])

	; Click is handled natively now.
	;~ if (msg == WM_LBUTTONDOWN && vFlyout.m_bHandleClick)
	;~ {
		;~ ; The reason for return is twofold. Not only should you disallow interaction with a read-only "control,"
		;~ ; but also the options that are set because of read-only cause WinGetPos to retrieve the parent (or if there is no parent, then the script's main hwnd) window coordinates
		;~ if (vFlyout.m_bReadOnly)
			;~ return

		;~ CoordMode, Mouse, Relative
		;~ MouseGetPos,, iMouseY
		;~ vFlyout.Click(iMouseY)
	;~ }

	if (IsFunc(vFlyout.m_sCallbackFunc))
		bRet := Func(vFlyout.m_sCallbackFunc).(vFlyout, msg)

	vFlyout :=
	return bRet
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Callback specified in CFlyout.__New when this.m_bFollowMouse is true.
CFlyout_MouseProc(nCode, wParam, lParam, msg)
{
	Critical, 5000
	global g_hMouseHook, g_hFlyout

	vFlyout := Object(CFlyout.FromHwnd[g_hFlyout])
	vFlyout.RedrawControls()

	vFlyout:=
	return DllCall("CallNextHookEx", "uint", g_hMouseHook, "int", nCode, "uint", wParam, "uint", lParam)
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Called only when m_bFollowMouse is true. A reliable function to keep the flyout off of the mouse by 16 pixels,
	;;;;;;;;;;;;;;; like how Tooltip works. It also keeps the flyout rect from spanning two or more monitors.
	;;;;;;;;;;;;;; riWndX is the desired X coordinate. It will always be incremented by 16 pixels. It will further be adjusted only if needed.
	;;;;;;;;;;;;;; riWndY is the desired Y coordinate. It will always be incremented by 16 pixels. It will further be adjusted only if needed.
	;;;;;;;;;;;;;; iWndW is the width of the flyout. WinGetPos is not called to retrieve the width instead because,
	;;;;;;;;;;;;;;; when this function is called, the flyout may (in the future) be set to a different width than the current width.
	;;;;;;;;;;;;;;iWndH is the width of the flyout. WinGetPos is not called to retrieve the height instead because, when this function is called,
	;;;;;;;;;;;;;; the flyout may be set to a different height than the current height.
GetRectForTooltip(ByRef riWndX, ByRef riWndY, iWndW, iWndH)
{
	CoordMode, Mouse ; Defaults to Screen
	MouseGetPos, iX, iY
	rect := GetMonitorRectAt(iX, iY)
	MonMouseIsOnLeft := rect.left
	MonMouseIsOnRight := rect.right
	MonMouseIsOnBottom := rect.bottom
	MonMouseIsOnTop := rect.top

	iX += 16
	iY += 16

	riWndX := iX
	riWndY := iY

	bCheck := true
	bWidthExceedsMonSpace := riWndX + iWndW > MonMouseIsOnRight
	if (bWidthExceedsMonSpace && iY - 16 >= MonMouseIsOnBottom - iWndH)
		riWndX := MonMouseIsOnRight - iWndW
	else if (bWidthExceedsMonSpace)
	{
		riWndX := MonMouseIsOnRight - iWndW
		bCheck := false
	}

	if (riWndY + iWndH > MonMouseIsOnBottom)
		riWndY := MonMouseIsOnBottom - iWndH

	if (bCheck && (iX - 16 >= riWndX && (riWndY - 16 <= MonMouseIsOnBottom)))
		riWndX := iX - iWndW - 16

	;~ Tooltip % "MonLeft:`t`t"MonMouseIsOnLeft "`nMonRight:`t`t" MonMouseIsOnRight "`nMonBot:`t`t`t" MonMouseIsOnBottom "`nMonTop:`t`t" MonMouseIsOnTop "`nriWndX:`t`t`t" riWndX "`nriWndY:`t`t`t" riWndY "`niWndW:`t`t`t" iWndW "`niWndH:`t`t`t" iWndH "`nbCheck:`t`t`t" bCheck

	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
/*
===============================================================================
Function:   wp_GetMonitorAt (Modified by Verdlin to return monitor rect)
    Get the index of the monitor containing the specified x and y coordinates.

Parameters:
    x,y - Coordinates
    default - Default monitor
  
Returns:
   array of monitor coordinates

Author(s):
    Original - Lexikos - http://www.autohotkey.com/forum/topic21703.html
===============================================================================
*/
GetMonitorRectAt(x, y, default=1)
{
	SysGet, m, MonitorCount
	; Iterate through all monitors.
	Loop, %m%
	{ ; Check if the window is on this monitor.
		SysGet, Mon%A_Index%, MonitorWorkArea, %A_Index%
		if (x >= Mon%A_Index%Left && x <= Mon%A_Index%Right && y >= Mon%A_Index%Top && y <= Mon%A_Index%Bottom)
			return {left: Mon%A_Index%Left, right: Mon%A_Index%Right, top: Mon%A_Index%Top, bottom: Mon%A_Index%Bottom}
	}

	return {left: Mon%default%Left, right: Mon%default%Right, top: Mon%default%Top, bottom: Mon%default%Bottom}
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; My (Verdlin) modification of Titan?s/Polythene?s anchor function: https://raw.github.com/polyethene/AutoHotkey-Scripts/master/Anchor.ahk
;;;;;;;;;;;;;; Using this one instead of Attach or Titan’s/Polythene’s Anchor v4 because this function,
;;;;;;;;;;;;;; although the parameter syntax is downright atrocious, actually works in Windows 7 and 8.
Anchor2(ctrl, a, d = false) {
static pos
sGUI := SubStr(ctrl, 1, InStr(ctrl, ":")-1)
GUI, %sGUI%:Default
ctrl := SubStr(ctrl, InStr(ctrl, ":")+1)
sig = `n%ctrl%=

If (d = 1){
draw = Draw
d=1,1,1,1
}Else If (d = 0)
d=1,1,1,1
StringSplit, q, d, `,

If !InStr(pos, sig) {
GUIControlGet, p, Pos, %ctrl%
pos := pos . sig . px - A_GUIWidth * q1 . "/" . pw - A_GUIWidth * q2 . "/"
. py - A_GUIHeight * q3 . "/" . ph - A_GUIHeight * q4 . "/"
}
StringTrimLeft, p, pos, InStr(pos, sig) - 1 + StrLen(sig)
StringSplit, p, p, /

s = xwyh
Loop, Parse, s
If InStr(a, A_LoopField) {
If A_Index < 3
e := p%A_Index% + A_GUIWidth * q%A_Index%
Else e := p%A_Index% + A_GUIHeight * q%A_Index%
d%A_LoopField% := e
m = %m%%A_LoopField%%e%
}
GUIControlGet, i, hwnd, %ctrl%
ControlGetPos, cx, cy, cw, ch, , ahk_id %i%

DllCall("SetWindowPos", "UInt", i, "Int", 0, "Int", dx, "Int", dy, "Int", InStr(a, "w") ? dw : cw, "Int", InStr(a, "h") ? dh : ch, "Int", 4)
DllCall("RedrawWindow", "UInt", i, "UInt", 0, "UInt", 0, "UInt", 0x0101) ; RDW_UPDATENOW | RDW_INVALIDATE
return
}

;~ Anchor2(hCtrl, sSpecs, d = false)
;~ {
	;~ static pos
	;~ sig := "`n" hCtrl "="

	;~ Loop, Parse, sSpecs, %A_Space%
	;~ {
		;~ sXYWH := SubStr(A_LoopField, 1, 1)
		;~ q%sXYWH% := SubStr(A_LoopField, 2)
	;~ }

	;~ If !InStr(pos, sig) {
	;~ ControlGetPos, px, py, pw, ph,, ahk_id %hCtrl%
	;~ pos := pos . sig . px - A_GUIWidth * (qx == A_Blank ? 1 : qx) . "/" . py - A_GUIHeight * (qy == A_Blank ? 1 : qy) . "/"
		;~ . pw - A_GUIWidth * (qw == A_Blank ? 1 : qw) . "/" . ph - A_GUIHeight * (qh == A_Blank ? 1 : qh) . "/"
	;~ }

	;~ StringTrimLeft, p, pos, InStr(pos, sig) - 1 + StrLen(sig)
	;~ StringSplit, p, p, /

	;~ if (qx != A_Blank)
		;~ dx := p1 + A_GUIWidth * qx
	;~ if (qy != A_Blank)
		;~ dy := p2 + A_GUIWidth * qy
	;~ if (qw != A_Blank)
		;~ dw := p3 + A_GUIHeight * qw
	;~ if (qh != A_Blank)
		;~ dh := p4 + A_GUIHeight * qh

	;~ ControlGetPos, cx, cy, cw, ch,, ahk_id %hCtrl%

	;~ DllCall("SetWindowPos", "UInt", hCtrl, "Int", 0, "Int", dx, "Int", dy, "Int", dw ? dw : cw, "Int", dh ? dh : ch, "Int", 4)
	;~ DllCall("RedrawWindow", "UInt", hCtrl, "UInt", 0, "UInt", 0, "UInt", 0x0101) ; RDW_UPDATENOW | RDW_INVALIDATE
	;~ return
;~ }
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Sets the default GUI and ListView for use with GUI commands
LV_SetDefault(sGUI, sLV)
{
	GUI, %sGUI%:Default
	GUI, ListView, %sLV%
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Wrapper to return the selected item number in a ListView
LV_GetSel()
{
	return LV_GetNext(0, "Focused") == 0 ? 1 : LV_GetNext(0, "Focused")
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; Wrapper to return the selected item in a ListView as text
LV_GetSelText(iCol=1)
{
	LV_GetText(sCurSel, LV_GetSel(), iCol)
	StringReplace, sCurSel, sCurSel, `r, , All ; Sometimes, characters are retrieved with a carriage-return.
	return sCurSel
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#Include <class_TransparentListBox>