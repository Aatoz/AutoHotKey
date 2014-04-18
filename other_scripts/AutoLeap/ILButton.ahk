/*
Title: ILButton
Version: 1.1
Author: tkoi <http://www.autohotkey.net/~tkoi>
License: GNU GPLv3 <http://www.opensource.org/licenses/gpl-3.0.html>

Function: ILButton()
    Creates an imagelist and associates it with a button.
Parameters:
    hBtn   - handle to a buttton
    images - a pipe delimited list of images in form "file:zeroBasedIndex"
               - file must be of type exe, dll, ico, cur, ani, or bmp
               - there are six states: normal, hot (hover), pressed, disabled, defaulted (focused), and stylushot
                   - ex. "normal.ico:0|hot.ico:0|pressed.ico:0|disabled.ico:0|defaulted.ico:0|stylushot.ico:0"
               - if only one image is specified, it will be used for all the button's states
               - if fewer than six images are specified, nothing is drawn for the states without images
               - omit "file" to use the last file specified
                   - ex. "states.dll:0|:1|:2|:3|:4|:5"
               - omitting an index is the same as specifying 0
               - note: within vista's aero theme, a defaulted (focused) button fades between images 5 and 6
    cx     - width of the image in pixels
    cy     - height of the image in pixels
    align  - an integer between 0 and 4, inclusive. 0: left, 1: right, 2: top, 3: bottom, 4: center
    margin - a comma-delimited list of four integers in form "left,top,right,bottom"

Notes:
    A 24-byte static variable is created for each IL button
    Tested on Vista Ultimate 32-bit SP1 and XP Pro 32-bit SP2.

Changes:
  v1.1
    Updated the function to use the assume-static feature introduced in AHK version 1.0.48
*/

ILButton(hBtn, images, cx=16, cy=16, align=4, margin="1,1,1,1") {
	static
	static i = 0
	local himl, v0, v1, v2, v3, ext, hbmp, hicon
	i ++

	himl := DllCall("ImageList_Create", "Int",cx, "Int",cy, "UInt",0x20, "Int",1, "Int",5, "UPtr")
	Loop, Parse, images, |
		{
		StringSplit, v, A_LoopField, :
		if not v1
			v1 := v3
		v3 := v1
		SplitPath, v1, , , ext
		if (ext = "bmp") {
			hbmp := DllCall("LoadImage", "UInt",0, "Str",v1, "UInt",0, "UInt",cx, "UInt",cy, "UInt",0x10, "UPtr")
			DllCall("ImageList_Add", "Ptr",himl, "Ptr",hbmp, "Ptr",0)
			DllCall("DeleteObject", "Ptr", hbmp)
			}
		else {
			DllCall("PrivateExtractIcons", "Str",v1, "Int",v2, "Int",cx, "Int",cy, "PtrP",hicon, "UInt",0, "UInt",1, "UInt",0)
			DllCall("ImageList_AddIcon", "Ptr",himl, "Ptr",hicon)
			DllCall("DestroyIcon", "Ptr", hicon)
			}
		}
	; Create a BUTTON_IMAGELIST structure
	VarSetCapacity(struct%i%, A_PtrSize + (5 * 4) + (A_PtrSize - 4), 0)
	NumPut(himl, struct%i%, 0, "Ptr")
	Loop, Parse, margin, `,
		NumPut(A_LoopField, struct%i%, A_PtrSize + ((A_Index - 1) * 4), "Int")
	NumPut(align, struct%i%, A_PtrSize + (4 * 4), "UInt")
	; BCM_FIRST := 0x1600, BCM_SETIMAGELIST := BCM_FIRST + 0x2
	PostMessage, 0x1602, 0, &struct%i%, , ahk_id %hBtn%
	Sleep 1 ; workaround for a redrawing problem on WinXP
	}