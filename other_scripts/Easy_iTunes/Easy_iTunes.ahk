#SingleInstance Force
SetWinDelay, -1
SetWorkingDir, %A_ScriptDir%

g_vITunes := ComObjCreate("iTunes.Application")

try ; Attempts to execute code.
	ComObjConnect(g_vITunes, "iTunesListener_")
catch sError ; Handles the first error/exception raised by the block above.
{
	MsgBox Error: Unable to connect to iTunes event handlers.`nThis can happen if iTunes isn't running or is still starting up.
	ExitApp
}

; Be careful, "iTunes U" and "90’s Music" are weird. That is NOT a whitespace or tab in the name. I don't know WHAT it is, actually!.
g_vPlaylistWhitelist := {"Library":"Library", "Music":"Music", "Home Videos":"Home Videos", "Podcasts":"Podcasts", "Music Videos":"Music Videos", "Movies":"Movies", "TV Shows":"TV Shows", "iTunes U":"iTunes U", "Books":"Books", "PDFs":"PDFs", "Audiobooks":"Audiobooks", "Purchased":"Purchased", "Genius":"Genius", "90’s Music":"90’s Music", "Classical Music":"Classical Music", "My Top Rated":"My Top Rated", "Recently Added":"Recently Added", "Recently Played":"Recently Played", "Top 25 Most Played":"Top 25 Most Played"}

/*
TODO:
	CFlyout-like GUI. Left hand past is track list while right pane is album artwork. Interface in QL potentially.
		See g_vITunes.CurrentPlaylist().Tracks().Count
	Add seek by N amount (determined by hotkey and seek variable value set by a different hotkey which does an InputBox)
	Option to add currently playing track to playlist
*/

return

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: GetPlaylists
		Purpose:
	Parameters
		
*/
GetPlaylists()
{
	global g_vITunes, g_vPlaylistWhitelist
	objLibrary := g_vITunes.Sources.Item(1)

	aPlaylists := ["Playlists", ""]
	Loop % objLibrary.Playlists.Count
	{
		vPlaylist := objLibrary.Playlists.Item(A_Index)
		; This also works: vPlaylist := objLibrary.Playlists.ItemByName(sRow)
		if (g_vPlaylistWhitelist.HasKey(vPlaylist.Name))
			continue

		aPlaylists.Insert(vPlaylist.Name)
	}

	return aPlaylists
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

GetTracksInPlaylist(vPlaylist="")
{
	global g_vITunes

	if (!vPlaylist)
		vPlaylist := g_vITunes.CurrentPlaylist()

	aTracks := []
	Loop % vPlaylist.Tracks().Count
	{
		vTrack := vPlaylist.Tracks().Item(A_Index)
		aTracks.Insert(vTrack.Name)
	}

	return aTracks
}

#+A::
{
	iTunesOSD().PostMsg(GetSongName(), GetAlbumArt())
	return
}

#+P::
{
	; CFlyout interface scratchpad
	aPlaylists := GetPlaylists()
	aPlaylists.1 .= " (" aPlaylists.MaxIndex() ")"
	aTracks := GetTracksInPlaylist()

	g_vPlaylists := new CFlyout(0, aPlaylists, false, false, -1920, 0, 350, 15, -99999, false, 0, "Consolas, s12")
	g_vPlaylists.OnMessage(WM_LBUTTONUP:=514 "," WM_LBUTTONDOWN:=513 ",ArrowUp,ArrowDown", "PlaylistFlyout_Proc")
	g_vPlaylists.MoveTo(2)

	objLibrary := g_vITunes.Sources.Item(1)
	vPlaylist := objLibrary.Playlists.Item(2)
	vTrack := vPlaylist.Tracks().Item(1)

	g_vTracks := new CFlyout(0, aTracks, false, false, -1920+g_vPlaylists.GetFlyoutW, 0, 350, 15, -99999, false, GetAlbumArt(vTrack.Artwork), "Consolas, s12")
	g_vTracks.OnMessage(WM_LBUTTONUP:=514 "," WM_LBUTTONDOWN:=513 ",ArrowUp,ArrowDown", "TrackFlyout_Proc")

	Hotkey, IfWinActive, % "ahk_id" g_vPlaylists.m_hFlyout
		Hotkey, Left, Flyout_OnLeftArrow
		Hotkey, Right, Flyout_OnRightArrow
	Hotkey, IfWinActive, % "ahk_id" g_vTracks.m_hFlyout
		Hotkey, Left, Flyout_OnLeftArrow
		Hotkey, Right, Flyout_OnRightArrow

	return

	GUI, New, hwndg_hTmp Resize MinSize, Playlists Browser
	GUI, -AlwaysOnTop

	GUI, Add, ListView, hwndg_hLV vg_vLV w524 r20, Playlist
	Loop % aPlaylists.MaxIndex()
		LV_Add("", aPlaylists[A_Index])
	GUI, Add, Button, xp y385 w75 h23 hwndhLVDeleteProc gLVDeleteProc, &Delete
	GUI, Add, Button, xp+85 yp w75 h23 gGUIReload, &Reload
	GUI, Add, Button, x460 yp w75 h23 hwndhOKNext vg_vOK gGUIOK, &OK

	GUI, Show, AutoSize

	return

	LVDeleteProc:
	{
		objLibrary := g_vITunes.Sources.Item(1)

		iRow := 0
		Loop
		{
			iRow := LV_GetNext(iRow)  ; Resume the search at the row after that found by the previous iteration.
			if (!iRow)
				break
			LV_GetText(sRow, iRow)
			StringReplace, sRow, sRow, `r, , All ; Sometimes, characters are retrieved with a carriage-return.

			vPlaylist := objLibrary.Playlists.ItemByName(sRow)
			vPlaylist.Delete()
			LV_Delete(iRow)
		}

		return
	}

	GUIOK:
		GUI, Destroy
		return

	GUIReload:
		Reload
		return
}

PlaylistFlyout_Proc(vFlyout, sMsg)
{
	global g_vITunes, g_vTracks

	vPlaylist := g_vITunes.Sources.Item(1).Playlists.ItemByName(vFlyout.GetCurSel())
	aTracks := GetTracksInPlaylist(vPlaylist)

	; TODO: For background picture, use artwork from first track
	vTrack := vPlaylist.Tracks().Item(1)
	g_vTracks.EnsureCorrectDefaultGUI()
	GUIControl,, g_vPic, % GetAlbumArt(vTrack.Artwork)

	g_vTracks.UpdateFlyout(aTracks)
	WinActivate, % "ahk_id" g_vTracks.m_hFlyout

	return
}

TrackFlyout_Proc(vFlyout, sMsg)
{
	global g_vITunes

	return
}

Flyout_OnLeftArrow:
{
	hActive := WinExist("A")
	if (hActive = g_vPlaylists.m_hFlyout)
	{
		g_vPlaylists :=
		g_vTracks :=
	}
	else if (hActive = g_vTracks.m_hFlyout)
		WinActivate, % "ahk_id" g_vPlaylists.m_hFlyout

	return
}

Flyout_OnRightArrow:
{
	hActive := WinExist("A")
	if (hActive = g_vPlaylists.m_hFlyout)
	{
		WinActivate, % "ahk_id" g_vTracks.m_hFlyout
	}
	else if (hActive = g_vTracks.m_hFlyout)
		Msgbox % "TODO: Play " g_vTracks.GetCurSel() " from " g_vPlaylists.GetCurSel() " playlist"

	return
}

#+S::
{
	Seek()
	return
}

#+~::
{
	Rewind()
	return
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: iTunesListener_OnPlayerPlayEvent
		Purpose:
	Parameters
		vTrack
*/
iTunesListener_OnPlayerPlayEvent(vTrack)
{
	iTunesOSD().PostMsg(vTrack.Name "`nby " vTrack.Artist, GetAlbumArt())
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: iTunesListener_OnPlayerStopEvent
		Purpose:
	Parameters
		vTrack
*/
;~ iTunesListener_OnPlayerStopEvent(vTrack)
;~ {
	;~ global s_sLastSong
	;~ s_sLastSong := ""
	;~ return
;~ }
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: GetAlbumArt
		Purpose: To save the album artwork of the currently playing song into sOutputFile saved in A_ScriptDir.
	Parameters
		vArtworkCol: Artwork collection COM object. If blank, the current artwork for the current track is used.
		sFilePrefix: Specifies prefix for artwork file names.
*/
GetAlbumArt(vArtworkCol="", sFilePrefix="")
{
	global g_vITunes

	Loop, %A_ScriptDir%\Artwork*.*, 0
		FileDelete, %A_LoopFileFullPath%

	if (!vArtworkCol)
		vArtworkCol := g_vITunes.CurrentTrack.Artwork

	if (!sFilePrefix)
		sFilePrefix := "Artwork"

	if (!IsObject(vArtworkCol))
		return "Unable to find artwork collection."

	Loop, % vArtworkCol.Count
	{
		vArtwork := vArtworkCol.Item(A_Index)

		if (vArtwork.Format = 1)
			strExtension := "bmp"
		else if (vArtwork.Format = 2)
			strExtension := "jpg"
		else if (vArtwork.Format = 4)
			strExtension := "gif"
		else if (vArtwork.Format = 5)
			strExtension := "png"
		else
			strExtension := ""

		; Sometimes the JPGs don't come through the GUI. This is a hack that fixes the problem (thus far anyhow)-- Verdlin: 12/8/15.
		if (strExtension == "jpg")
			strExtension := "bmp"

		vArtwork.SaveArtworkToFile(A_ScriptDir "\" sFilePrefix . A_Index "." strExtension)
		if (A_Index == 1)
			sArtwork := A_ScriptDir "\" sFilePrefix . A_Index "." strExtension
	}

	return sArtwork
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: GetSongName
		Purpose: To return the name of the currently playing song
	Parameters
*/
GetSongName()
{
	global g_vITunes
	return g_vITunes.CurrentTrack.Name "`nby " g_vITunes.CurrentTrack.Artist
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: Seek
		Purpose: To seek by iSec
	Parameters
		
*/
Seek(iSec=10)
{
	global g_vITunes
	g_vITunes.PlayerPosition += iSec
	; TODO: Display in main OSD instead
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: Seek
		Purpose: To seek by iSec
	Parameters
		
*/
Rewind(iSec=10)
{
	global g_vITunes
	g_vITunes.PlayerPosition -= iSec
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Label: OnExit
		Purpose: Cleanup
*/
OnExit:
{
	if (IsObject(g_vITunes))
		ComObjConnect(g_vITunes) ; Disconnect

	ObjRelease(g_vITunes)
	g_vITunes := ""

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

iTunesOSD()
{
	return new iTunesOSD()
}

class iTunesOSD
{
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	__New()
	{
		global

		; With any delay, the OSD sliding looks horrible.
		SetWinDelay, -1

		this.m_bDismiss := false ; Used in iTunesOSD_DismissAfterNMS.
		this.m_iMaxWidth := 350 ; used for clarity and ease of changeability.
		this.m_iArtworkH := 350 ; used for clarity and ease of changeability.

		GUI iTunesOSD: New, hwndg_hiTunesOSD
		this.m_hiTunesOSD := g_hiTunesOSD

		GUI, +AlwaysOnTop -Caption +Owner +LastFound +ToolWindow +E0x20
		WinSet, Transparent, 240
		GUI, Color, 202020
		GUI, Font, s12 c5C5CF0 wnorm ; c0xF52C5F

		GUI, Add, Text, x0 y0 hwndg_hiTunesOSD_MainOutput vg_vITunesOSD_MainOutput Wrap Left
		GUI, Add, Text, % "x0 y0 w" this.m_iMaxWidth " r1 vg_vITunesOSD_PostDataOutput +Center Hidden" ; Switch out these two text controls for output
		this.m_hFont := Fnt_GetFont(g_hiTunesOSD_MainOutput)
		this.m_iOneLineOfText := Str_MeasureText("a", this.m_hFont).bottom

		; iTunes Artwork is always 500x500, I think ;) -- Verdlin: 12/7/15.
		GUIControlGet, iPos, Pos, g_vITunesOSD_PostDataOutput
		GUI, Add, Picture, % "x0 y" iPosH " h" this.m_iArtworkH " w" this.m_iMaxWidth " vg_vITunesOSD_Artwork"

		return this
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	PostMsg(sMsg, sPathToArt, iDissmissAfter=3500)
	{
		global
		GUI, iTunesOSD:Default

		rect := Str_MeasureTextWrap(sMsg, this.m_iMaxWidth, this.m_hFont)
		this.__New() ; Reset the OSD because it doesn't always stay on top, for some reason.

		GUIControl, Hide, g_vITunesOSD_MainOutput
		GUIControl, Show, g_vITunesOSD_PostDataOutput
		GUIControl, MoveDraw, g_vITunesOSD_PostDataOutput, % "W" this.m_iMaxWidth " H" rect.bottom
		StringReplace, sMsg, sMsg, &, &&, All ; Escape ampersands so they aren't underlined.
		GUIControl,, g_vITunesOSD_PostDataOutput, %sMsg%
		GUIControl, Move, g_vITunesOSD_Artwork, % "y" rect.bottom " w" this.m_iMaxWidth " h" this.m_iArtworkH
		GUIControl,, g_vITunesOSD_Artwork, %sPathToArt%

		iNewH := this.m_iArtworkH + rect.bottom
		iX := -this.m_iMaxWidth
		GUI, Show, % "x" iX " y" A_ScreenHeight-iNewH " w" this.m_iMaxWidth " h" iNewH " NoActivate"
		this.DismissAfterNMS(iDissmissAfter)

		return
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;
	DismissAfterNMS(iNMS)
	{
		global

		this.m_bDismiss := false
		this.m_bOverrideHide := false
		this.m_hOldiTunesOSD := this.m_hITunesOSD

		SetTimer, iTunesOSD_DismissAfterNMS, %iNMS%
		return

		iTunesOSD_DismissAfterNMS:
		{
			SetTimer, %A_ThisLabel%, Off
			; It seems dubious to support multiple OSDs.
			; The class notifies a message and auto-dismisses it quickly,
			; so it hardly makes sense to display more than one at a time.
			iTunesOSD.Dismiss()
			return
		}
	}
	;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	/*
		Author: Verdlin
		Function: iTunesOSD_Dismiss
			Purpose:
		Parameters
			
	*/
	Dismiss()
	{
		global g_hiTunesOSD

		WinGetPos,,,, iH, % "ahk_id" g_hiTunesOSD
		;~ WAnim_SlideOut("Bottom", g_hiTunesOSD, "iTunesOSD", iH/25, false)
		WAnim_FadeViewInOut(g_hiTunesOSD, 10, false, "iTunesOSD", false)
		return
	}
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
}

;#Include %A_ScriptDir%\CFlyout.ahk
#Include %A_ScriptDir%\CFlyout_TLB.ahk