;;;;;;;;;;;;;;
; Title: 	AddSDWtoRegistry.ahk	
; AutoHotkey Version: 1.0.47
; Language:     English
; Platform:     Win9x/NT
; Author:       DAT 07-02-2009
;
; Apply registry changes to add new context menu item 'Send To Dialog Window'

SendMode Input 

;;;;;;;;;;;;;;;;;;;;;;;;;
; User input may be required here:
; The next line should show the location of the main script, 'SendToDialogWindow.ahk'.
; If yours is located somewhere other than 'C:\AutoHotkey Scripts\'  you'll need to 
; edit the line. 
;
PathToScript = C:\AutoHotkey Scripts\SendToDialogWindow.ahk
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
WaitFor = 30 ; seconds
ResultMsg = Will wait %WaitFor%s for user input
Delay := (WaitFor*1000)
SetTimer , ButtonCancel , %Delay%
Gosub , GuiSetup

GuiEscape:		; User pressed escape.
GuiClose:		; User closed the window.
ButtonCancel:	; User clicked Cancel button.
gui , Destroy
ExitApp

ButtonGo:
SetTimer , ButtonCancel , off
Gui , Submit ; stores gui selection
gui , Destroy
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;  !!!! Caution: The next section alters the registry, which is	!!!!
;  !!!!	potentially harmful. Don't alter anything in RegWrite	!!!! 
;  !!!! or RegDelete unless you know what you're doing.			!!!! 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
If (var1 = 1)
{
	RegWrite , REG_SZ, HKEY_CLASSES_ROOT, Folder\shell\Send to Dialog Window ,, Send to Dialog Window
	RegWrite , REG_SZ, HKEY_CLASSES_ROOT, Folder\shell\Send to Dialog Window\Command ,, "C:\Program Files\AutoHotkey\AutoHotkey.exe" "%PathToScript%" "`%1"

	ResultMsg = Registry key added - waiting %WaitFor%s for more input
    SoundBeep, 800, 25  
    SoundBeep, 1200,  25  
	SetTimer , ButtonCancel , %Delay%
	Gosub , GuiSetup
}
If (var2 = 1)
{
	RegDelete , HKEY_CLASSES_ROOT, Folder\shell\Send to Dialog Window
	ResultMsg = Registry key removed - waiting %WaitFor%s for more input
    SoundBeep, 1200,  25  
    SoundBeep, 800,  25  
	SetTimer , ButtonCancel , %Delay%
	Gosub , GuiSetup
}
SetTimer , ButtonCancel , %Delay%

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;  Set up the GUI
;
GuiSetup:
Gui, Font, S10 CDefault , Verdana
	Gui, Add, Radio, x56 y132w320 h20  checked0 vvar1,  Add registry key
	Gui, Add, Radio, x56 y172 w320 h20 vvar2 , Remove registry key
Gui, Add, Button, x96 y222 w100 h30 Default, Cancel
Gui, Add, Button, x216 y222 w100 h30 , Go
Gui, Add, Text, x16 y22 w360  +Left, Will add or remove a new registry key to put 'Send to Dialog Window' in the context menu of folders.`n`nSelect which you want to do and then click 'Go'.  To escape with no action click 'Cancel'.
Gui, Add, Text, x16 y272 w360  +Center, %ResultMsg%
Gui, Show, x318 y368 h316 w400, 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;