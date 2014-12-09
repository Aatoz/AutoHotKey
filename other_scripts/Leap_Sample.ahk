#SingleInstance Force
#Persistent
SetWinDelay, -1

/*

This type of INI file would be generated either from your GUI, or the AutoLeap GUI
It should be noted that AutoLeap GUI *only* Add/Modifies Sections and the Gesture key within each section
This means that, with however you choose to interface your scripts with this API,
	it is safe for you to actually modify Gestures.ini in conjunction with your script
	(just as long as you don't mess with the section names or the Gesture keys).
That is why, in Gestures.ini, there is actually an Action key in each section.
	The Action key would presumably come from some exterior GUI that inserts
	the Action keys into the ini based on one specific gesture.
The method in this script interprets each Action value as a function,
	and it dynamically calls that function in LeapSample_MsgHandler.
If it is not clear what I mean by this, then see how I interface the ini with this script
	in LeapSample_MsgHandler.

*/

FileDelete, Gestures.ini
FileAppend,
(
[Snap to Left]
Gesture=Swipe Left
Func=SnapWnd
[Snap to Right]
Gesture=Swipe Right
Func=SnapWnd
[Snap to Center]
Gesture=Circle Left
Func=SnapWnd
[Snap to Top Left]
Gesture=Swipe Up, Swipe Left
Func=SnapWnd
[Snap to Top Right]
Gesture=Swipe Up, Swipe Right
Func=SnapWnd
[Snap to Bottom Left]
Gesture=Swipe Down, Swipe Left
Func=SnapWnd
[Snap to Bottom Right]
Gesture=Swipe Down, Swipe Right
Func=SnapWnd
[Toggle Maximize]
Gesture=Swipe Up
Func=MaximizeWindow
[Minimize/Restore]
Gesture=Swipe Down
Func=MinimizeWindow
[Confirm]
Gesture=Keytap
Func=OnKeyTap
[Move Window]
Gesture=Swipe Left, Swipe Right
Func=MoveWindow
InteractiveGesture=true
), Gestures.ini

; The AutoLeap object takes ownership of Leap functions, and leap messages are forwarded to LeapSample_MsgHandler
g_vLeap := new AutoLeap("LeapMsgHandler", "Gestures.ini")
g_vLeapMsgProcessor := {}

Msgbox Welcome! This script has mapped some basic gestures to window functions. For example, a swipe to the left will take the current window and snap it to the left corner of this monitor.`n`nFollowing this message, those gestures will appear in the Gestures Control Center. Take a few moments to get familiarized with the gestures and then exit the dialog -- don't worry you'll receive further instructions after you exit the dialog.

g_vLeap.ShowControlCenterDlg() ; So you can see how the GUI module looks

Msgbox Great! Now perform these gestures and watch as the magic of the Leap Motion Controller becomes a reality!

return


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
1. sMsg will be "Record" or "Post"
2. rasGestures is an array of gestures -- one gesture per element
3. rsOutput is a string that, if set, will be displayed on the OSD for one second

* When sMsg = "Record" this means that gestures are still being daisy-chained together.
* When sMsg = "Post" this means that gestures recording has stopped.
		This happens when no fingers/tools are detected by the Leap API
*/
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
LeapMsgHandler(sMsg, ByRef rLeapData, ByRef rasGestures, ByRef rsOutput)
{
	global g_vLeap, g_vLeapMsgProcessor
	static s_iPalm1ID := rLeapData.Hand1.ID, s_iPalm2ID := rLeapData.Hand2.ID

	g_vLeapMsgProcessor.m_bHand1HasReset := s_iPalm1ID != rLeapData.Hand1.ID
	g_vLeapMsgProcessor.m_bHand2HasReset := s_iPalm2ID != rLeapData.Hand2.ID
	s_iPalm1ID := rLeapData.Hand1.ID
	s_iPalm2ID := rLeapData.Hand2.ID

	bIsDataPost := (sMsg = "Post")

	; The below checks allows the hand(s) to go completely out of view without us ending the gesture.
	if (g_vLeapMsgProcessor.m_bUseTriggerGesture)
	{
		bIsMakingFist := g_vLeap.IsMakingFist(rLeapData)
		if (!bIsMakingFist || g_vLeapMsgProcessor.m_bHand1HasReset)
		{
			g_vLeapMsgProcessor.m_iFistStart := 0
			g_vLeapMsgProcessor.m_iTimeWithFist := 0
			TimeSinceLastCall(A_ThisFunc, 2)
		}

		if (bIsMakingFist) ; If we have been making a fist for the past second, bail out.
		{
			g_vLeapMsgProcessor.m_iTimeWithFist += TimeSinceLastCall(A_ThisFunc)
			g_vLeapMsgProcessor.m_bFistMadeDuringThreshold := g_vLeapMsgProcessor.m_iTimeWithFist > 1000
		}
	}
	; End fist-checking.

	; Leap_ functions stop getting called when making a fist for 1 or more seconds.
	bActionHasStarted := g_vLeapMsgProcessor.m_bActionHasStarted
	bCallbackCanStop := g_vLeapMsgProcessor.m_bCallbackCanStop
	bCallbackWillStop := g_vLeapMsgProcessor.m_bCallbackWillStop

	if (!bCallbackWillStop && bActionHasStarted && bCallbackCanStop
		|| (bCallbackWillStop && g_vLeapMsgProcessor.m_bCallerHasFinished))
	{
		; Let the user know that and what we stopped tracking.
		g_vLeap.OSD_PostMsg("Stop " g_vLeapMsgProcessor.m_sTriggerAction)

		ResetLeapMsgProcessor()
		
}
	else if (sMsg = "Forward" && g_vLeapMsgProcessor.m_bUseTriggerGesture)
	{
		g_vLeapMsgProcessor.m_hTriggerGestureFunc.(rLeapData, rasGestures)

		; We have to start before we stop.
		if (!g_vLeapMsgProcessor.m_bActionHasStarted)
			g_vLeapMsgProcessor.m_bActionHasStarted := g_vLeapMsgProcessor.m_bCallbackCanStop

		if (g_vLeap.IsMakingFist(rLeapData) && g_vLeapMsgProcessor.m_bFistMadeDuringThreshold)
			g_vLeapMsgProcessor.m_bCallbackCanStop := true
	}

	sGesture := st_glue(rasGestures, ", ")
	if (sGesture == "")
		return

	for sec, aData in g_vLeap.m_vGesturesIni
	{
		if (sGesture = aData.Gesture)
		{
			bGestureExists := true
			break
		}
	}

	if (!bGestureExists)
		return

	if (bIsDataPost)
	{
		if (aData.InteractiveGesture)
			SetLeapMsgCallback(sec, aData)
		else if (IsFunc(aData.Func))
			Func(aData.Func).(rLeapData, rasGestures)

		rsOutput := sec
	}

	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: ResetLeapMsgProcessor
		Purpose: To reset the Leap message processor.
	Parameters
		None
*/
ResetLeapMsgProcessor()
{
	global g_vLeap, g_vLeapMsgProcessor

	for k, v in g_vLeapMsgProcessor
		g_vLeapMsgProcessor[k] := 0 ; false for bools, and 0 for ints because you can't ++ A_Blank

	g_vLeap.m_vProcessor.m_bIgnoreGestures := false ; Start showing gestures on the OSD again.
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: SetLeapMsgCallback
		Purpose: When a chain of gestures is mapped to a Leap_* function, we must set up the appropriate vars here.
	Parameters
		sActionName: Identifer of action
		aData: Keys/vals data
*/
SetLeapMsgCallback(sActionName, aData)
{
	global g_vLeap, g_vLeapMsgProcessor

	if (g_vLeapMsgProcessor.m_hTriggerGestureFunc := Func(aData.Func))
	{
		g_vLeapMsgProcessor.m_bUseTriggerGesture := true
		g_vLeapMsgProcessor.m_bCallbackWillStop := (aData.CallbackWillStop = "true")
		g_vLeapMsgProcessor.m_bGestureUsesPinch := (aData.UsesPinch = "true")
		g_vLeap.m_vProcessor.m_bIgnoreGestures := true ; Reduces noise and saves precious time in ProcessAutoLeapData.
		g_vLeapMsgProcessor.m_sTriggerAction := sActionName

		g_vLeapMsgProcessor.m_bFistMadeDuringThreshold := false
		TimeSinceLastCall(2, true) ; Reset
		g_vLeapMsgProcessor.m_iFistStart := 0
	}

	return
}
;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
MaximizeWindow(ByRef rLeapData, ByRef rasGestures)
{
	hWnd := WinExist("A")

	WinGet, MinMaxState, MinMax, ahk_id %hWnd%
	WinActivate

	; #1
	if (MinMaxState = -1)
		WinRestore, ahk_id %hWnd%
	; #2
	else if (MinMaxState = 1)
		WinRestore, ahk_id %hWnd%
	; #3
	else if (MinMaxState = 0)
		WinMaximize, ahk_id %hWnd%
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
MinimizeWindow(ByRef rLeapData, ByRef rasGestures)
{
	; Use Win-Split Logic:
	; 1. If the window is minimized, maximize it.
	; 2. If the window is maximized, set it to it's default, non-maximized position
	; 3. If the window is neither minimzed or maximized, minimze it.
	hWnd := WinExist("A")

	WinGet, MinMaxState, MinMax, ahk_id %hWnd%
	; Note: This should be much easier when I incorporate window properties.

	; #1
	if (MinMaxState = -1)
		WinRestore, ahk_id %hWnd%
	; #2
	else if (MinMaxState = 1)
		WinRestore, ahk_id %hWnd%
	; #3
	else if (MinMaxState = 0)
		WinMinimize, ahk_id %hWnd%

	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
OnKeyTap(ByRef rLeapData, ByRef rasGestures)
{
	SendInput {Enter}
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
SnapWnd(ByRef rLeapData, ByRef rasGestures)
{
	hWnd := WinExist("A")
	WinGetPos, iWndX, iWndY, iWndW, iWndH, ahk_id %hWnd%

	sDir := st_glue(rasGestures, ", ")

	if (sDir = "Swipe Left")
		iX := 0
	else if (sDir = "Swipe Right")
		iX := A_ScreenWidth - iWndW
	else if (sDir = "Circle Left")
		iX := A_ScreenWidth*0.5 - iWndW*0.5, iY := A_ScreenHeight*0.5 - iWndH*0.5
	else if (sDir = "Swipe Down, Swipe Left")
		iX := 0, iY := A_ScreenHeight - iWndH
	else if (sDir = "Swipe Down, Swipe Right")
		iX := A_ScreenWidth - iWndW, iY := A_ScreenHeight - iWndH
	else if (sDir = "Swipe Up, Swipe Left")
		iX := 0, iY := 0
	else if (sDir = "Swipe Up, Swipe Right")
		iX := A_ScreenWidth - iWndW, iY := 0

	WinMove, ahk_id %hWnd%,, %iX%, %iY%
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: MoveWindow
		Purpose: To move a window in real-time based upon a single-hand's palm position
	Parameters
		rLeapData
		rasGestures
		hWnd="A"
*/
MoveWindow(ByRef rLeapData, ByRef rasGestures, hWnd="A")
{
	global g_vLeap

	MakeValidHwnd(hWnd)

	; Tracking gets iffy at these points, and currently the interaction box class does not help with this problem.
	; TODO: Use Data confidence factor in v2.0
	if (rLeapData.Hand1.PalmX > 290 || || rLeapData.Hand1.PalmX < -270 || rLeapData.Hand1.PalmY > 505)
		return

	; Take into account the velocity.
	iVelocityX := abs(rLeapData.Hand1.VelocityX)
	iVelocityY := abs(rLeapData.Hand1.VelocityY)

	iVelocityXFactor := g_vLeap.CalcVelocityFactor(iVelocityX, 75)
	iVelocityYFactor := g_vLeap.CalcVelocityFactor(iVelocityY, 75)

/*
	Take into account the monitor the window is on
		1. When the window width is greater than 50% of the monitor's width, move the window's X less; otherwise, move it more.
		2. When the window height is greater than 50% of the monitor's height, move the window's Y less; otherwise, move it more.
*/
	GetWndPct(iWPct, iHPct, hWnd)

	iMonXFactor := (100-iWPct)/100
	iMonYFactor := (100-iHPct)/100

	if (iWPct < 49.99)
		iMonXFactor += 1
	if (iHPct < 49.99)
		iMonYFactor += 1

	; Get palm X and Y movement.
	g_vLeap.GetPalmDelta(rLeapData, iPalmXDelta, iPalmYDelta)
	iPalmXDelta *= -1 ; Movement should be reversed, in this particular case.

	WinGetPos, iCurX, iCurY, iW, iH, ahk_id %hWnd%

	; TODO: When skeletal tracking becomes available, we may be able to enable this or something like it.
	;~ bMoveAlongXOnly := (rLeapData.HasKey("Hand2") && rLeapData.HasKey("Finger8"))
	;~ bMoveAlongYOnly := (rLeapData.HasKey("Hand2") && rLeapData.HasKey("Finger7") && !rLeapData.HasKey("Finger8"))

	iNewX := iCurX
	iNewY := iCurY
	; Strip out noise from humanity's generable inability to stabilize their palms.
	if (abs(iPalmXDelta) > 0.35)
		iNewX := iCurX + (iPalmXDelta*(iVelocityXFactor+iMonXFactor))
	if (abs(iPalmYDelta) > 0.35)
		iNewY := iCurY + (iPalmYDelta*(iVelocityYFactor+iMonYFactor))

	if (iNewX < 0)
		iNewX := 0
	if (iNewX + iW > A_ScreenWidth)
		iNewX := A_ScreenWidth - iW
	if (iNewY < 0)
		iNewY := 0
	if (iNewY + iH > A_ScreenHeight)
		iNewY := A_ScreenHeight - iH

	WinMove, ahk_id %hWnd%,, iNewX, iNewY

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

GetWndPct(ByRef riWPct, ByRef riHPct, hWnd = "A")
{
	WinGetPos, iX, iY, iW, iH, ahk_id %hWnd%

	riWPct := Round((iW * 100) / A_ScreenWidth, 2)
	riHPct := Round((iH * 100) / A_ScreenHeight, 2)

	return
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: MakeValidHwnd
		Purpose: hWnd="A" is passed around in many functions. They all need to validate the hWnd when it is *not* valid.
			That logic happens here.
	Parameters
		hWnd
*/
MakeValidHwnd(ByRef rhWnd)
{
	if (rhWnd = "A" || !rhWnd)
		rhWnd := WinExist("A")
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

#Include AutoLeap\AutoLeap.ahk