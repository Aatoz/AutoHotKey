#SingleInstance Force
#Persistent

/*

This type of INI file would be generated either from your GUI, or the CLeapModule GUI
It should be noted that CLeapModule GUI *only* Add/Modifies Sections and the Gesture key within each section
This means that, with however you choose to interface your scripts with this API,
	it is safe for you to actually modify Gestures.ini in conjunction with your script
	(just as long as you don't mess with the section names or the Gesture keys).
That is why, in Gestures.ini, there is actually an Action key in each section.
	The Action key would presumably come from some exterior GUI that inserst
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
Action=SnapWnd
[Snap to Right]
Gesture=Swipe Right
Action=SnapWnd
[Snap to Center]
Gesture=Circle Left
Action=SnapWnd
[Snap to Top Left]
Gesture=Swipe Up, Swipe Left
Action=SnapWnd
[Snap to Top Right]
Gesture=Swipe Up, Swipe Right
Action=SnapWnd
[Snap to Bottom Left]
Gesture=Swipe Down, Swipe Left
Action=SnapWnd
[Snap to Bottom Right]
Gesture=Swipe Down, Swipe Right
Action=SnapWnd
[Toggle Maximize]
Gesture=Swipe Up
Action=MaximizeWindow
[Minimize/Restore]
Gesture=Swipe Down
Action=MinimizeWindow
[Confirm]
Gesture=Keytap
Action=OnKeytap
), Gestures.ini

; The CLeapModule object takes ownership of Leap functions, and leap messages are forwarded to LeapSample_MsgHandler
g_vLeap := new CLeapModule("Gestures.ini", Func("LeapSample_MsgHandler"))
g_vLeap.ShowSettingsDlg() ; So you can see how the GUI module looks
return

#^R::Reload

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
1. sMsg will be "Record" or "Post"
2. asGestures is an array of gestures -- one gesture per element
3. rsOutput is a string that, if set, will be displayed on the OSD for one second

* When sMsg = "Record" this means that gestures are still being daisy-chained together.
* When sMsg = "Post" this means that gestures recording has stopped.
		This happens when no fingers/tools are detected by the Leap API
*/
LeapSample_MsgHandler(sMsg, asGestures, ByRef rsOutput)
{
	global g_vLeap
	rsOutput :=

	if (sMsg = "Post")
	{
		sGestures := st_glue(asGestures, ",")
		for sGestureName, aData in g_vLeap.m_vGesturesIni
		{
			if (sGestures = aData.Gesture)
			{
				if (hFunc := Func(aData.Action))
					hFunc.(sGestures)

				; Gesture action will be briefly displayed on OSD
				rsOutput := sGestureName
				break
			}
		}
	}
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
MaximizeWindow(a="")
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
MinimizeWindow(a="")
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
OnKeytap(a="")
{
	SendInput {Enter}
	return
}
;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;
SnapWnd(sDir)
{
	hWnd := WinExist("A")
	WinGetPos, iWndX, iWndY, iWndW, iWndH, ahk_id %hWnd%

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

#Include AutoLeap\CLeapModule.ahk