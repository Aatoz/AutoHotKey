#Persistent
OnExit,UnHook
If !HookFunction("user32.dll", "MessageBoxExW", MyMessageBoxExW:=RegisterCallback("MessageBoxExW","",5), hMessageBoxExW)
  MsgBox Function could not be hooked
Return

UnHook:
UnHookFunction("user32.dll", "MessageBoxExW", hMessageBoxExW)
ExitApp


MessageBoxExW(hwnd,lpText,lpCaption,uType,uId){
  global MyMessageBoxExW,hMessageBoxExW
  title:=StrGet(lpCaption,"UTF-16")
  text:=StrGet(lpText,"UTF-16")
  UnHookFunction("user32.dll", "MessageBoxExW", hMessageBoxExW)
  ret:=DllCall("MessageBoxExW","PTR",hwnd,"Str",text "`n`nYour MessageBoxExW has been hooked!","Str",title,"UInt",uType,"Short",uId)
  HookFunction("user32.dll", "MessageBoxExW", MyMessageBoxExW, hMessageBoxExW)
  return ret
}


HookFunction(lpModule, lpFuncName, lpFunction, ByRef lpBackup){
  static MEM_FREE:=65536,MEM_COMMIT:=4096,MEM_RESERVE:=8192,PAGE_EXECUTE_READWRITE:=64,MEM_DECOMMIT:=16384
  
  hProcess:=DllCall("GetCurrentProcess","PTR")    ,   hModule := DllCall("GetModuleHandle","Str",lpModule,"PTR")
  ; Get module and function address
	hFunc := DllCall("GetProcAddress","PTR",hModule,"AStr", lpFuncName,"PTR")
  
  ; Create jmp to use
	jmp:=Struct("Byte[6]",[0xe9,0x00,0x00,0x00,0x00,0xc3])
  
  VarSetCapacity(lpBackup,6) ; make sure we have enough memory allocated
  ; Backup current jmp
	DllCall("ReadProcessMemory","PTR",hProcess,"PTR", hFunc, "PTR", &lpBackup,"UInt", 6,"PTR", 0)

  ; Set addres in jmp
	NumPut((lpFunction - hFunc - 5) & 0xFFFFFFFF ,jmp[]+1,"Uint")
  
  ; allocate memory for jmp
  If !hMem:=DllCall("VirtualAlloc","PTR",0,"Uint",6,"Uint",MEM_COMMIT|MEM_RESERVE,"Uint",PAGE_EXECUTE_READWRITE)
    Return
  
  ;	copy new jmp
  DllCall("RtlMoveMemory","PTR",hMem,"PTR", jmp[],"PTR", 6) 
  
  ; overwrite jmp
	if !DllCall("WriteProcessMemory","PTR",hProcess,"PTR", hFunc,"PTR", hMem,"Uint", 6,"UInt", 0){
    DllCall("VirtualFree","PTR",hMem,"Uint",6,"Uint",MEM_FREE|MEM_DECOMMIT)
    return
  }
  DllCall("VirtualFree","PTR",hMem,"Uint",6,"Uint",MEM_FREE|MEM_DECOMMIT)
	return hFunc
}

UnHookFunction(lpModule, lpFuncName, ByRef lpBackup){
  static MEM_FREE:=65536,MEM_COMMIT:=4096,MEM_RESERVE:=8192,PAGE_EXECUTE_READWRITE:=64
	hFunc := DllCall("GetProcAddress","PTR",DllCall("GetModuleHandle","Str",lpModule,"PTR"),"AStr", lpFuncName,"PTR")
  ; allocate memory for backup jmp
  If !hMem:=DllCall("VirtualAlloc","PTR",0,"Uint",6,"Uint",MEM_COMMIT|MEM_RESERVE,"Uint",PAGE_EXECUTE_READWRITE)
    Return
  DllCall("RtlMoveMemory","PTR",hMem,"PTR", &lpBackup,"PTR", 6) 
  
  ret :=DllCall("WriteProcessMemory","PTR",DllCall("GetCurrentProcess","PTR"),"PTR", hFunc,"PTR", hMem,"Uint", 6,"PTR", 0)
  DllCall("VirtualFree","PTR",hMem,"Uint",6,"Uint",MEM_FREE|MEM_DECOMMIT)
  
	return FALSE
}