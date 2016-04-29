#SingleInstance Force
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.


_DragDrop() ; Init stb lib.

Loop 2
{
	if (A_Index == 1)
		sTitle := "Drag n Drop with GUIDropFiles"
	else sTitle := "Drag n Drop NO GUIDropFiles"

	GUI, DragDrop%A_Index%_:New, +Hwndg_hSample%A_Index%, %sTitle%

	; Typically you would want this if statement below, but I don't want to screw up the sample.
	;~ if (DragDrop.ShouldUseDD())
	g_vDD%A_Index% := new DragDrop("SimulateDragNDrop" A_Index, g_hSample%A_Index%)

	iW := 300
	iH := 135
	iX := Floor((A_ScreenWidth - iW) / 2)
	iY := Floor((A_ScreenHeight - iH) / 2) + (A_Index == 2 ? iH+38 : 0)

	GUI, Add, Edit, x0 y0 w%iW% h100 ReadOnly vg_vDDEdit%A_Index%, Drag and Drop a file onto me!
	GUI, Add, Button, xp y100 wp h30 gDragDrop_GUICloseAll, E&xit everything
	; Generated using SmartGUI Creator for SciTE
	GUI, Show, x%iX% y%iY% w%iW% h%iH%
}

return

SimulateDragNDrop1(vDDContents)
{
	GUI, DragDrop1_:Default

	for vItem in vDDContents
		sContents .= (sContents ? "`n" : "") . vItem.Path

	if (sContents)
		GUIControl,, g_vDDEdit1, %sContents%

	return
}

SimulateDragNDrop2(vDDContents)
{
	GUI, DragDrop2_:Default

	for vItem in vDDContents
		sContents .= (sContents ? "`n" : "") . vItem.Path

	if (sContents)
		GUIControl,, g_vDDEdit2, %sContents%

	return
}

DragDrop1_GUIDropFiles:
{
	; So you can see the difference between GUI 1 and GUI 2.
	; GUI 1 gets a nice + selection icon but GUI 2 gets a No/X icon
	return
}

DragDrop_GUICloseAll:
DragDrop1_GUIEscape:
DragDrop1_GUIClose:
DragDrop2_GUIEscape:
DragDrop2_GUIClose:
	g_vDD1 :=
	g_vDD2 :=
	ExitApp