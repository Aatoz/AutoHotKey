_MonInfo()
{
	global g_vMonInfo := {}
	global g_aMapOrganizedMonToSysMonNdx := []

	SysGet, iVirtualScreenLeft, 76
	SysGet, iVirtualScreenTop, 77
	SysGet, iVirtualScreenRight, 78
	SysGet, iVirtualScreenBottom, 79

	g_vMonInfo.Insert("VirtualScreenLeft", iVirtualScreenLeft)
	g_vMonInfo.Insert("VirtualScreenTop", iVirtualScreenTop)
	g_vMonInfo.Insert("VirtualScreenRight", iVirtualScreenRight)
	g_vMonInfo.Insert("VirtualScreenBottom", iVirtualScreenBottom)

	SysGet, iMonCnt, MonitorCount

	SysGet, iPrimaryMon, MonitorPrimary
	SysGet, iPrimaryMon, Monitor, %iPrimaryMon%

	g_vMonInfo.Insert("Primary", {Left: iPrimaryMonLeft, Right: iPrimaryMonRight
		, Top: iPrimaryMonTop, Bottom: iPrimaryMonBottom
		, W:Abs(iPrimaryMonLeft - iPrimaryMonRight) , H:Abs(iPrimaryMonTop - iPrimaryMonBottom)
		, Ndx: iPrimaryMon})

	aDictMonInfo := []
	Loop, %iMonCnt%
	{
		vDictMonInfo := {}

		SysGet, Mon, MonitorWorkArea, %A_Index%

		vDictMonInfo.Insert("Left", MonLeft)
		vDictMonInfo.Insert("Right", MonRight)
		vDictMonInfo.Insert("Top", MonTop)
		vDictMonInfo.Insert("Bottom", MonBottom)
		vDictMonInfo.Insert("W", Abs(MonRight-MonLeft))
		vDictMonInfo.Insert("H", Abs(MonTop-MonBottom))
		vDictMonInfo.Insert("Ndx", A_Index)
		aDictMonInfo.Insert(vDictMonInfo)
	}

	Loop % aDictMonInfo.MaxIndex()
	{
		iBottomLeftMon := GetBottomLeftMon(aDictMonInfo)
		if (iBottomLeftMon == 0)
		{
			Msgbox 8192,, "An error occured when trying to calibrate monitor positions"
			return
		}

		g_aMapOrganizedMonToSysMonNdx.Insert(aDictMonInfo[iBottomLeftMon]["Ndx"])
		g_vMonInfo.Insert(ObjClone(aDictMonInfo[iBottomLeftMon]))

		; Until I can figure out a better way to do this, set coordinates
		; to blank so that we won't return the same monitor.
		; Not the most efficient method, but this algorithm is confusing.
		aDictMonInfo[iBottomLeftMon]["Left"] := ""
		aDictMonInfo[iBottomLeftMon]["Bottom"] := ""
	}

	return
}

GetBottomLeftMon(aDictMonInfo)
{
	a:= []
	Loop % aDictMonInfo.MaxIndex()
		a.Insert(aDictMonInfo[A_Index]["Bottom"])

	; Find bottom monitors first...
	iBottom := max(a*) ; As monitors get lower, their bottoms increase *snickers*
	Loop % aDictMonInfo.MaxIndex()
	{
		if (aDictMonInfo[A_Index]["Bottom"] == iBottom)
			sBottomList .= sBottomList == A_Blank ? A_Index : "|" A_Index
	}

	; and, of those bottom monitors, the leftmost monitor.
	a := []
	Loop, Parse, sBottomList, |
		a.Insert(aDictMonInfo[A_LoopField]["Left"])
	iLeft := min(a*)

	Loop, Parse, sBottomList, |
	{
		; Assume that there is only one leftmost monitor in the list of bottom monitors
		if (aDictMonInfo[A_LoopField]["Left"] == iLeft && aDictMonInfo[A_LoopField]["Bottom"] == iBottom)
			return A_LoopField
	}
	return 0
}