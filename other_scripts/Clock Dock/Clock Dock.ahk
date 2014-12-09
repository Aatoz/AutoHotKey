#SingleInstance Force
#Persistent

; This is a cool clock OSD which uses CFlyout

; Idea, use AutoLeap Std OSD for notifications, but make it distinctly different from AutoLeap

g_hDesktop := WinExist("ahk_class Progman")

g_vFlyout := new CFlyout(g_hDesktop, [A_MM "/" A_DD "/" A_YYYY, A_DDDD, A_Hour ":" A_Min ":" A_Sec], false, true)

g_vFlyout.Show()

return

#Include CFlyout.ahk