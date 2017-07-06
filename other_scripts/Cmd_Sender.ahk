DetectHiddenWindows, On

; Process command line first.
Loop %0% ; for each parameter
{
	sParm := %A_Index%
	break
}

SendMessageToExe(sParm)
Msgbox done.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin and http://l.autohotkey.net/docs/commands/OnMessage.htm
	Function: SendMessageToExe
		Purpose: To send messages to AutoLeap.exe
	Parameters
		StringToSend: ByRef saves a little memory in this case.
*/
SendMessageToExe(ByRef StringToSend)
{
	DetectHiddenWindows, On

	VarSetCapacity(CopyDataStruct, 3*A_PtrSize, 0)
	SizeInBytes := (StrLen(StringToSend) + 1) * (A_IsUnicode ? 2 : 1)
	NumPut(SizeInBytes, CopyDataStruct, A_PtrSize)
	NumPut(&StringToSend, CopyDataStruct, 2*A_PtrSize)

	SendMessage, 0x4a, 0, &CopyDataStruct,, % "ahk_id" WinExist("Deerchase Command")
	bRet := ErrorLevel

	return bRet
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;