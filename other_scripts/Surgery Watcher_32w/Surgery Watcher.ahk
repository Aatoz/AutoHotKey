#Persistent
#SingleInstance Force
SetWorkingDir, %A_ScriptDir%

; For speed...
SetBatchLines, -1
SetWinDelay, -1
Process, Priority,, H

FileInstalls()
InitTray()

; Testing environment.
if (false)
{
	InitGlobals(false)
	InitGUI()

	RunUnitTests()
	ObjTree(g_vMetrics, "Done: g_vMetrics Expanded")

	Tooltip
	Msgbox Press ok to exit
	SurgeryWatcher_Exit()
	return
}

InitGlobals()
InitGUI()

#Include %A_ScriptDir%\AutoLeap\AutoLeap.ahk
#Include %A_ScriptDir%\Catalog.ahk

return

LeapMsgHandler(sMsg, ByRef rLeapData, ByRef rasGestures, ByRef rsOutput)
{
	; Important: Ensure this format is retained each time we do calculations.
	SetFormat, FloatFast, 0.15

	global g_vMetrics, g_vCatalog, g_vUnitsInfo, g_sUnits
		; Raw data.
		, g_vRawDataCSV, g_vColLabelToNum, g_iCSVRow
		; Helper vars for fields.
		, g_iHands_c, g_s3DParse_c, g_sLeapSecsParse_c
	static s_bIsFirstCallWithData := true
		; Time information relevant to each hand.
		, s_vTimeInfo := {Hand1:{TimeStartOffset:0, TotalTimeVisible:0, TimeSinceLastCall:0}
			, Hand2:{}, Header:{}} ; Hand2 and Header should be identical to Hand1, not explicitly settings vars to reduce cloning.

	; Metrics needed:
		; 1. Total path distance travelled. - Done.
		; 2. Speed. - Done.
		; 3. Acceleration. - Difference in velocity between two frames. Units are: m/s2.
		; 4. Motion smoothness. - Difference in acceleration between two frames. Units are: m/s3.
		; 5. Average distance between hands. - Done. Using PalmDiff[XYZ]_US
			; which C++ compares hand1 stable vs. Hand2.

	; If no hands are present, there is no data to process.
	if (sMsg = "Post" || !rLeapData.HasKey("Hand1"))
		return

	; Time start, time visible, time since last call.
	SetTimeInfo(s_bIsFirstCallWithData, rLeapData, s_vTimeInfo)

	; Populate the CSV as we go.
	g_iCSVRow++

	g_vRawDataCSV[g_vColLabelToNum["H1 TimeStamp (ms)"], g_iCSVRow] := s_vTimeInfo.Hand1.TotalTimeVisible
	g_vRawDataCSV[g_vColLabelToNum["H2 TimeStamp (ms)"], g_iCSVRow] := s_vTimeInfo.Hand2.TotalTimeVisible

	g_iUnitConversionFactor := g_vUnitsInfo[g_sUnits].FromMM
/*
------------------------------------------------------------
-----------LOOP OVER ALL CATALOG FIELDS-----------
------------------------------------------------------------
*/

	iHandsLoop := (rLeapData.HasKey("Hand2") ? 2 : 1)
	asGUIOutput := ["", "", ""]
	aFieldsToRecall := {}
	for sFieldID, aFieldInfo in g_vCatalog
	{
		iFieldLoop := A_Index
		sIndent := "---"
		aFieldInfo_Copy := ObjClone(aFieldInfo)

		sUnits := aFieldInfo_Copy.Units
		StringReplace, sUnits, sUnits, $(g_sUnits), %g_sUnits%, All
		aFieldInfo_Copy.Units := sUnits

		if (aFieldInfo_Copy.LeapSec = "Header")
			iHandsLoop := 1

		Loop, %iHandsLoop%
		{
			iHand := A_Index
			; Hand1 and Hand2 have identical column names, but we need UIDs for g_vColLabelToNum,
			sRawDataColPrefix := "H" A_Index " "
			sGUIOutput :=

			iGUIOutputNdx := iHand
			if (aFieldInfo_Copy.LeapSec = "Header")
			{
				; No UID needed for hand differences.
				sRawDataColPrefix :=
				iGUIOutputNdx := 3
			}

			if (aFieldInfo.LeapSec = "Hand")
				aFieldInfo_Copy.LeapSec := aFieldInfo.LeapSec . iHand
			if (aFieldInfo.MetricSec = "Hand")
				aFieldInfo_Copy.MetricSec := aFieldInfo.MetricSec . iHand

			if (aFieldInfo_Copy.StoreAs = "TimeWeighted")
			{
				AddTimeWgtVar(rLeapData, aFieldInfo_Copy
					, s_vTimeInfo[aFieldInfo_Copy.LeapSec].TimeSinceLastCall
					, s_vTimeInfo[aFieldInfo_Copy.LeapSec].TotalTimeVisible
					, sRawDataColPrefix, sIndent, sGUIOutput)
			}
			else if (aFieldInfo_Copy.StoreAs = "ValFromMetrics")
			{
				AddVarFromMetricsDiff(rLeapData, aFieldInfo_Copy
					, s_vTimeInfo[aFieldInfo_Copy.LeapSec].TimeSinceLastCall
					, s_vTimeInfo[aFieldInfo_Copy.LeapSec].TotalTimeVisible
					, sRawDataColPrefix, sIndent, sGUIOutput)
			}
			else if (aFieldInfo_Copy.StoreAs = "RawInc")
				AddRawVar(rLeapData, aFieldInfo_Copy, sRawDataColPrefix, sIndent, sGUIOutput)
			else FatalErrorMsg("Invalid data storage type encountered: " . aFieldInfo_Copy.StoreAs)

			; Store values so that the next call can reference these values as "Prev" vals.
			; If we updated the vals now, subsequent fields would not be referencing actual previous vals.
			aFieldsToRecall[aFieldInfo_Copy.MetricSec, sFieldID, "MetricKey"] := aFieldInfo_Copy.MetricKey
			aFieldsToRecall[aFieldInfo_Copy.MetricSec, sFieldID, "LeapKey"] := aFieldInfo_Copy.LeapKey

			asGUIOutput[iGUIOutputNdx] .= sGUIOutput
		}
	}

	SurgeryWatcher_OutputToGUI("Metrics for hand 1`n" . asGUIOutput.1
		. "`nMetrics for hand 2`n" . asGUIOutput.2 . "`nMetrics between hands`n" . asGUIOutput.3)

	; Now loop over data to store previous values.
	for sec, vField in aFieldsToRecall
		for sFieldID, aFieldInfo in vField
		{
			g_vMetrics[sec, aFieldInfo.MetricKey "_Prev"] := g_vMetrics[sec, aFieldInfo.MetricKey]
			g_vMetrics[sec, aFieldInfo.LeapKey "_Prev"] := rLeapData[sec, aFieldInfo.LeapKey]

			; For calculating averages from differences in metrics.
			if (g_vCatalog[sFieldID].HasKey("MetricKeyForCurVal"))
				g_vMetrics[sec, g_vCatalog[sFieldID, "MetricKeyForCurVal"] "_Prev"] := g_vMetrics[sec, g_vCatalog[sFieldID, "MetricKeyForCurVal"]]
		}

	s_bIsFirstCallWithData := false
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: SetTimeInfo
		Purpose: Set up palm info object that helps us with time
	Parameters
		bIsFirstCallWithData
		rLeapData
		rvTimeInfo
*/
SetTimeInfo(bIsFirstCallWithData, ByRef rLeapData, ByRef rvTimeInfo)
{
	global g_sLeapSecsParse_c
	static s_iTotalTimeVisible := 0

	if (bIsFirstCallWithData)
	{
		TimeSinceLastCall() ; Begin counter.
		iTimeSinceLastCall := 0.001 ; If 0, first metrics are all 0.
	}
	else
	{
		iTimeSinceLastCall := TimeSinceLastCall()
		if (iTimeSinceLastCall == 0)
			iTimeSinceLastCall := 0.001
	}

	s_iTotalTimeVisible += iTimeSinceLastCall
	Loop, Parse, g_sLeapSecsParse_c, |
	{
		rvTimeInfo[A_LoopField].TotalTimeVisible := s_iTotalTimeVisible
		rvTimeInfo[A_LoopField].TimeSinceLastCall := iTimeSinceLastCall
	}

	; Perform some sanity checks for our time-weighted vars.
	if (rvTimeInfo.Hand1.TimeSinceLastCall < 0)
		FatalErrorMsg("Error: There is an issue with calculating the time since the last frame " rvTimeInfo.Hand1.TimeSinceLastCall)
	if (s_iTotalTimeVisible == 0)
		FatalErrorMsg("Error: There is an issue with the time-weighting denominator.")
	else if (rvTimeInfo.Hand1.TimeSinceLastCall > s_iTotalTimeVisible)
		FatalErrorMsg("Error: There is an issue with the time-weighting numerator.")


	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: AddRawVar
		Purpose: For adding variables that simply need incrementing.
	Parameters
		rLeapData
		raFieldInfo: Field info from g_vCatalog
		sRawDataColPrefix: Hand1 and Hand2 have identical column names, but we need UIDs for g_vColLabelToNum,
			This string should be "H1 " or "H2 "
		sIndent: Indentation for labels (needed for rsDataForGUI)
		rsDataForGUI: Visual string data outputted to GUI
*/
AddRawVar(ByRef rLeapData, ByRef raFieldInfo, sRawDataColPrefix, sIndent, ByRef rsDataForGUI)
{
	global

	IncVarInMetrics(rLeapData, raFieldInfo, iVar)

	; Log this information.
	rsDataForGUI .= sIndent . raFieldInfo.Label ": " Round(iVar * g_iUnitConversionFactor) " " raFieldInfo.Units "`n"
	g_vRawDataCSV[g_vColLabelToNum[sRawDataColPrefix . raFieldInfo.Label], g_iCSVRow] := iVar

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: IncVarInMetrics
		Purpose: To locaize logic of adding metrics to our metrics db.
	Parameters
		rLeapData
		raFieldInfo: Field info from g_vCatalog
		riVar="": Passed out var retrieved from rLeapData
*/
IncVarInMetrics(ByRef rLeapData, ByRef raFieldInfo, ByRef riVar="")
{
	global
	riVar := 0

	; Validate all sections and keys.
	ValidateLeapAndMetricSecsAndKeys(rLeapData, raFieldInfo)

	local iLeapVar := rLeapData[raFieldInfo.LeapSec][raFieldInfo.LeapKey]

	if (iLeapVar != A_Blank)
	{
		if (raFieldInfo.UseAbsVal)
			iLeapVar := abs(iLeapVar)

		g_vMetrics[raFieldInfo.MetricSec, raFieldInfo.MetricKey] += iLeapVar
	}

	riVar := g_vMetrics[raFieldInfo.MetricSec, raFieldInfo.MetricKey]

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: AddVarFromMetricsDiff
		Purpose: For add variables that are calculated from difference in various metrics stored in g_vMetrics.
	Parameters
		rLeapData
		raFieldInfo: Field info from g_vCatalog
		iNum: Numerator
		iDenom: Denominator
		sRawDataColPrefix: Hand1 and Hand2 have identical column names, but we need UIDs for g_vColLabelToNum,
			This string should be "H1 " or "H2 "
		sIndent: Indentation for labels (needed for rsDataForGUI)
		rsDataForGUI: Visual string data outputted to GUI
*/
AddVarFromMetricsDiff(ByRef rLeapData, ByRef raFieldInfo, iNum, iDenom, sRawDataColPrefix, sIndent, ByRef rsDataForGUI)
{
	global

	CalcVarFromMetricsDiff(rLeapData, raFieldInfo, iNum, iDenom, iCurLeapDiff, iMetricDiff)

	; Log this information.
	rsDataForGUI .= sIndent . raFieldInfo.Label ": " Round(iCurLeapDiff * g_iUnitConversionFactor) " " raFieldInfo.Units "`n"
	g_vRawDataCSV[g_vColLabelToNum[sRawDataColPrefix . raFieldInfo.Label], g_iCSVRow] := iCurLeapDiff

	rsDataForGUI .= sIndent . raFieldInfo.AvgLabel ": " Round(iMetricDiff * g_iUnitConversionFactor) " " raFieldInfo.Units "`n"
	g_vRawDataCSV[g_vColLabelToNum[sRawDataColPrefix . raFieldInfo.AvgLabel], g_iCSVRow] := iMetricDiff

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: CalcVarFromMetricsDiff
		Purpose: To calculate a var from metrics based upon information in raFieldInfo
	Parameters
		rLeapData
		raFieldInfo: Field info from g_vCatalog.
		iTimeMultiplier_Num: To multiply numerator by
		iTotalTime_Denom
		riCurDiff: Difference between current val at current frame and "current" val at last frame.
		riAvgDiff: Difference between metric val at current frame and val at last frame.
*/
CalcVarFromMetricsDiff(ByRef rLeapData, ByRef raFieldInfo, iTimeMultiplier_Num, iTotalTime_Denom, ByRef riCurDiff, ByRef riAvgDiff)
{
	global g_vMetrics
	riCurDiff := riAvgDiff := 0

	; Validate all sections and keys.
	ValidateLeapAndMetricSecsAndKeys(rLeapData, raFieldInfo)

	if (raFieldInfo.MetricKey = "WgtAvgAcceleration" . raFieldInfo.Dim)
	{
		iCurMetric := abs(rLeapData[raFieldInfo.LeapSec, raFieldInfo.LeapKey])
		iPrevMetric := abs(g_vMetrics[raFieldInfo.MetricSec, raFieldInfo.LeapKey "_Prev"])
	}
	else
	{
		iCurMetric := g_vMetrics[raFieldInfo.MetricSec, raFieldInfo.CurMetricKeyForDiff]
		iPrevMetric := g_vMetrics[raFieldInfo.MetricSec, raFieldInfo.CurMetricKeyForDiff "_Prev"]
	}

	if (iCurMetric == A_Blank)
		riCurDiff := A_Blank
	else riCurDiff := (iCurMetric - iPrevMetric)
	; We must store current values for other metrics differences that need to reference this field.
	; Acceleration needing Velocity, for example.
	g_vMetrics[raFieldInfo.MetricSec, raFieldInfo.MetricKeyForCurVal] := riCurDiff

	; Time-wgt current val of metric to get weighted average.
	TimeWgtVarInMetrics(riCurDiff, raFieldInfo, iTimeMultiplier_Num, iTotalTime_Denom, riAvgDiff)

	return
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function:
		Purpose: AddTimeWgtVar
			Note: Function assumes you want to time weight a far coming out of rLeapData
	Parameters
		rLeapData
		raFieldInfo: Field info from g_vCatalog
		iNum: Numerator
		iDenom: Denominator
		sRawDataColPrefix: Hand1 and Hand2 have identical column names, but we need UIDs for g_vColLabelToNum,
			This string should be "H1 " or "H2 "
		sIndent: Indentation for labels (needed for rsDataForGUI)
		rsDataForGUI: Visual string data outputted to GUI
*/
AddTimeWgtVar(ByRef rLeapData, ByRef raFieldInfo, iNum, iDenom, sRawDataColPrefix, sIndent, ByRef rsDataForGUI)
{
	global

	; Validate all sections and keys.
	ValidateLeapAndMetricSecsAndKeys(rLeapData, raFieldInfo)

	iVar := rLeapData[raFieldInfo.LeapSec, raFieldInfo.LeapKey]
	TimeWgtVarInMetrics(iVar, raFieldInfo, iNum, iDenom, iTimeWgtVar)

	; Log this information.
	iCurVal := rLeapData[raFieldInfo.LeapSec][raFieldInfo.LeapKey]
	if (raFieldInfo.UseAbsVal)
		iCurVal := Abs(iCurVal)
	rsDataForGUI .= sIndent . raFieldInfo.Label ": " Round(iCurVal * g_iUnitConversionFactor) " " raFieldInfo.Units "`n"
	g_vRawDataCSV[g_vColLabelToNum[sRawDataColPrefix . raFieldInfo.Label], g_iCSVRow] := iCurVal

	rsDataForGUI .= sIndent . raFieldInfo.AvgLabel ": " Round(iTimeWgtVar * g_iUnitConversionFactor) " " raFieldInfo.Units "`n"
	g_vRawDataCSV[g_vColLabelToNum[sRawDataColPrefix . raFieldInfo.AvgLabel], g_iCSVRow] := iTimeWgtVar

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: TimeWgtVarInMetrics
		Purpose: Handles general logic for time-weighting a variable tracking in our Leap procedures.
	Parameters
		iRawVar: Var to time-weight
		raFieldInfo: Field info from g_vCatalog
		iTimeMultiplier_Num: To multiply numerator by
		iTotalTime_Denom: Denom
		riVar="": Time-weighted var
*/
TimeWgtVarInMetrics(iRawVar, ByRef raFieldInfo, iTimeMultiplier_Num, iTotalTime_Denom, ByRef riVar="")
{
	global
	riVar := 0

	if (iRawVar == A_Blank)
		iRawVar := 0
	else if (raFieldInfo.UseAbsVal)
		iRawVar := abs(iRawVar)

	; Set the current, unweighted var in metrics.
	; Time-weight var numerator only
	if (g_vMetrics[raFieldInfo.MetricSec, raFieldInfo.MetricKey] == A_Blank)
		g_vMetrics[raFieldInfo.MetricSec, raFieldInfo.MetricKey] := (iRawVar * iTimeMultiplier_Num)
	else g_vMetrics[raFieldInfo.MetricSec, raFieldInfo.MetricKey] += (iRawVar * iTimeMultiplier_Num)
	; The denominator should be used by callers when the total is actually needed.
	riVar := g_vMetrics[raFieldInfo.MetricSec, raFieldInfo.MetricKey] / iTotalTime_Denom

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: ValidateLeapAndMetricSecsAndKeys
		Purpose: Effectively catches bugs in script if we try to use invalid sections or keys for data storage.
	Parameters
		rLeapData
		raFieldInfo: Field info from g_vCatalog
*/
ValidateLeapAndMetricSecsAndKeys(ByRef rLeapData, ByRef raFieldInfo)
{
	global g_vMetrics

	; It's ok if Hand1 is present but Hand2 is not; in those cases, we just use 0.
	; Key must be present in header OR Hand1. If sLeapSec is Hand2, that is ok because keys are identical between both hands.
	; MetricSec and Metric key must always exist.
	bMetricHasSec := g_vMetrics.HasKey(raFieldInfo.MetricSec)
	bMetricHasKey := g_vMetrics[raFieldInfo.MetricSec].HasKey(raFieldInfo.MetricKey)
	if (!(rLeapData.Header.HasKey(raFieldInfo.LeapKey) || (rLeapData.HasKey("Hand1")
			&& rLeapData["Hand1"].HasKey(raFieldInfo.LeapKey))))
	{
		FatalErrorMsg("Error: Program is trying to retrieve data using invalid sections or keys.`n`nLeap data section:`t" 
			. raFieldInfo.LeapSec "(" rLeapData.Header.HasKey(raFieldInfo.LeapKey) "-" rLeapData.HasKey("Hand1") "-" 
			. rLeapData["Hand1"].HasKey(raFieldInfo.LeapKey) ")`nLeap data key:`t" raFieldInfo.LeapKey 
			. "(" rLeapData[raFieldInfo.LeapSec].HasKey(raFieldInfo.LeapKey) ")`nMetric data section:`t" 
			. raFieldInfo.MetricSec "(" bMetricHasSec ")`nMetric data key:`t" raFieldInfo.MetricKey "(" bMetricHasKey ")`n"
			. rLeapData.GetKeys("Header"))
	}

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: InitGUI
		Purpose: Set up the main GUI
	Parameters
		
*/
InitGUI()
{
	global

	GUI, SurgeryWatcher_:New, hwndg_hSurgeryWatcher MinSize Resize, %g_sName%

	; ---Menus---

	; File
	Menu, SurgeryWatcher_FileMenu, Add, E&xport...`tCtrl + Shift + E, SurgeryWatcher_Export
	Menu, SurgeryWatcher_FileMenu, Icon, E&xport...`tCtrl + Shift + E, AutoLeap\Save As.ico,, 16
	Menu, SurgeryWatcher_FileMenu, Add, E&xit`tAlt + F4, SurgeryWatcher_GUIClose
	Menu, SurgeryWatcher_FileMenu, Icon, E&xit`tAlt + F4, AutoLeap\Exit.ico,, 16

	; Edit
	Menu, SurgeryWatcher_EditMenu, Add, &Record`tCtrl + R, SurgeryWatcher_RecordOrStop
	Menu, SurgeryWatcher_EditMenu, Icon, &Record`tCtrl + R, Record.ico,, 16

	; View
	for sec, aData in g_vUnitsInfo
	{
		aData.Menu .= "`tAlt + " A_Index
		Menu, SurgeryWatcher_ViewMenu, Add, % aData.Menu, SurgeryWatcher_UnitChange
	}
	Menu, SurgeryWatcher_ViewMenu, Check, % g_vUnitsInfo.mm.Menu ; Check Millimeters.
	g_sUnits := "mm"

	; Calculations
	Menu, SurgeryWatcher_HelpMenu, Add, &Calculations, SurgeryWatcher_Calcs
	Menu, SurgeryWatcher_HelpMenu, Icon, &Calculations, AutoLeap\Info.ico,, 16
	; About
	Menu, SurgeryWatcher_HelpMenu, Add, &About, SurgeryWatcher_ReadMe
	Menu, SurgeryWatcher_HelpMenu, Icon, &About, AutoLeap\Info.ico,, 16

	Menu, SurgeryWatcher_MainMenu, Add, &File, :SurgeryWatcher_FileMenu
	Menu, SurgeryWatcher_MainMenu, Add, &Edit, :SurgeryWatcher_EditMenu
	Menu, SurgeryWatcher_MainMenu, Add, &View, :SurgeryWatcher_ViewMenu
	Menu, SurgeryWatcher_MainMenu, Add, &Help, :SurgeryWatcher_HelpMenu

	GUI, Menu, SurgeryWatcher_MainMenu

	; ---Layout---

	GUI, Font, s12
	GUI, Add, Edit, x5 w450 h400 vg_vSurgeryWatcher_Output ReadOnly
	GUI, Font, s10
	; Record/Stop.
	GUI, Add, Button, % "x5 yp+" 400+g_iMSDNStdBtnSpacing " w80 h26 hwndg_hRecordBtn vg_vRecordBtn gSurgeryWatcher_RecordOrStop", &Start
	ILButton(g_hRecordBtn, "Record.ico", 24, 24, 0)
	GUI, Add, Text, % "X" 225-g_iMSDNStdBtnW + 6 " YP+" g_iMSDNStdBtnSpacing/2 " W220 H" g_iMSDNStdBtnH " vg_vImportantCopyright", % g_sName " " A_Year
	GUI, Add, Button, % "XP+" 225 " Yp-" g_iMSDNStdBtnSpacing/2 " W" g_iMSDNStdBtnW " HP vg_vExitBtn gSurgeryWatcher_Exit", E&xit

	GUIControl, Focus, g_vRecordBtn
	GUI, Show

	return

	SurgeryWatcher_UnitChange:
	{
		; Check one item, uncheck all others.
		for sec, aData in g_vUnitsInfo
		{
			if (A_ThisMenuItem = aData.Menu)
			{
				g_sUnits := sec
				Menu, SurgeryWatcher_ViewMenu, Check, % aData.Menu
			}
			else Menu, SurgeryWatcher_ViewMenu, Uncheck, % aData.Menu
		}

		return
	}

	SurgeryWatcher_RecordOrStop:
	{
		g_bIsRecording := !g_bIsRecording

		if (g_bIsRecording)
		{
			if (!g_vMetrics.IsEmpty() && !g_bMetricsDataWasExported)
			{
				MsgBox, 8228, Start Recording?, If you start recording`, all data from previous simulation will be removed.
				IfMsgBox Yes
				{
					InitGlobals(false) ; No need to re-init Leap.
					SurgeryWatcher_OutputToGUI("")
				}
				else
				{
					g_bIsRecording := false
					return
				}
			}

			GUIControl,, g_vRecordBtn, &Stop
			ILButton(g_hRecordBtn, "Stop.ico", 24, 24, 0)
			Menu, SurgeryWatcher_EditMenu, Rename, &Record`tCtrl + R, Stop &Recording`tCtrl + R
			Menu, SurgeryWatcher_EditMenu, Icon, Stop &Recording`tCtrl + R, Record.ico,, 16

		Loop 3
		{
			SurgeryWatcher_OutputToGUI("Tracking will begin in " 3-A_Index+1 "...")
			Sleep 1000
		}

			g_vLeap.SetTrackState(true)
		}
		else
		{
			GUIControl,, g_vRecordBtn, &Start
			ILButton(g_hRecordBtn, "Record.ico", 24, 24, 0)
			Menu, SurgeryWatcher_EditMenu, Rename, Stop &Recording`tCtrl + R, &Record`tCtrl + R
			Menu, SurgeryWatcher_EditMenu, Icon, &Record`tCtrl + R, Record.ico,, 16
			g_vLeap.SetTrackState(false)
			g_bMetricsDataWasExported := false
		}

		return
	}

	SurgeryWatcher_Export:
	{
		SetFormat, FloatFast, 0.15
		FileDelete, Export.csv

		aRows := []
		; Sections are columns.
		for sec, aData in g_vMetrics
		{
			bMakeHeaders := (A_Index == 2)
			bIsOtherRow := (sec = "Other")

			; Keys are row headings.
			; values are cells.
			sRow := sec
			for k, v in aData
			{
				if (InStr(k, "_Prev"))
					continue

				if (bIsOtherRow)
					sOtherRowHeaders .= "," k
				else if (bMakeHeaders)
					sHeaders .= (sHeaders == A_Blank ? k : "," k)

				if (bIsOtherRow)
					sDataForBothRows .= "," v
				else sRow .= "," v
			}
			if (!bIsOtherRow)
				aRows.Insert(sRow)
		}

		sHeaders .= sOtherRowHeaders
		aRows.1 .= sDataForBothRows
		aRows.2 .= sDataForBothRows

		; H1,H2,H3,...
		FileAppend, `,%sHeaders%, Export.csv

		for i, v in aRows
		{
			; Row,V1,V2,V3,...
			FileAppend, `n%v%, Export.csv ; Initial comma because rows are like headers.
		}

		Run, %A_WorkingDir%,, UseErrorLevel
		g_bMetricsDataWasExported := true
		return
	}

	SurgeryWatcher_ReadMe:
	{
		g_vLeap.m_vDlgs.ShowInfoDlg(GetReadMeFile(), g_hSurgeryWatcher, 700)
		return
	}

	SurgeryWatcher_Calcs:
	{
		g_vLeap.m_vDlgs.ShowInfoDlg(GetLegendFile(), g_hSurgeryWatcher)
		return
	}

	SurgeryWatcher_GUISize:
	{
		Anchor2("SurgeryWatcher_:g_vSurgeryWatcher_Output", "xwyh", "0, 1, 0, 1")
		Anchor2("SurgeryWatcher_:g_vRecordBtn", "xwyh", "0, 0, 1, 0")
		Anchor2("SurgeryWatcher_:g_vImportantCopyright", "xwyh", "0.5, 0, 1, 0")
		Anchor2("SurgeryWatcher_:g_vExitBtn", "xwyh", "1, 0, 1, 0")

		return
	}

	SurgeryWatcher_GUIClose:
		GUI, SurgeryWatcher_:Destroy
	Reload:
	SurgeryWatcher_Exit:
	{
		SurgeryWatcher_Exit()
		return
	}
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: SurgeryWatcher_Exit
		Purpose: To exit gracefully.
	Parameters
		
*/
SurgeryWatcher_Exit()
{
	global
	g_vLeap.OSD_PostMsg("Data is being logged...")

	SetFormat, FloatFast, 0.15
	SurgeryWatcher_OutputToGUI("Exporting raw data (This may take a *long* time)...")
	g_vRawDataCSV.Save()

	GUI, SurgeryWatcher_:Destroy
	g_vLeap.m_bInit := true ; Since I have so much trouble getting this to freaking delete.
	g_vLeap.__Delete()

	ExitApp
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: SurgeryWatcher_OutputToGUI
		Purpose: To localize logic of displaying information on the GUI.
	Parameters
		s: String to output
*/
SurgeryWatcher_OutputToGUI(s)
{
	GUI, SurgeryWatcher_:Default
	GUIControl,, g_vSurgeryWatcher_Output, %s%
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: FileInstalls
		Purpose: Houses all FIleInstalls
	Parameters
		None
*/
FileInstalls()
{
	; For AutoHotkey.exe
	FileInstall, msvcr100.dll, msvcr100.dll
	FileInstall, msvcp100.dll, msvcp100.dll
	; For Leap_Forwarder_32.exe
	FileCreateDir, AutoLeap
	FileInstall, AutoLeap\msvcr120.dll, AutoLeap\msvcr120.dll
	FileInstall, AutoLeap\msvcp120.dll, AutoLeap\msvcp120.dll

	FileInstall, Eye.ico, Eye.ico
	FileInstall, Record.ico, Record.ico
	FileInstall, Stop.ico, Stop.ico
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: InitTray
		Purpose: To initialize the tray icon appropriately.
	Parameters
		
*/
InitTray()
{
	; Tray icon
	Menu, TRAY, Icon, Eye.ico,, 1

	Menu, TRAY, NoStandard
	Menu, TRAY, MainWindow ; For compiled scripts
	Menu, TRAY, Add, E&xit, SurgeryWatcher_Exit
	Menu, TRAY, Click, 1
	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: InitGlobals
		Purpose:
	Parameters
		bInitLeap=true; I need it to be false for unit tests.
*/
InitGlobals(bInitLeap=true)
{
	global

	g_sName := "Surgery Watcher " chr(169)

	; http://msdn.microsoft.com/en-us/library/windows/desktop/aa511453.aspx#sizing
	g_iMSDNStdBtnW := 75
	g_iMSDNStdBtnH := 23
	g_iMSDNStdBtnSpacing := 6

	g_iHands_c := 2
	; For parsing loops within hands loop.
	g_s3DParse_c := "X|Y|Z"
	g_sLeapSecsParse_c := "Hand1|Hand2|Header"

	; Leap Forwarder.
	local sMetrics := "
	(LTrim
		[Other]
		WgtAvgDistFromHandsX=0
		WgtAvgDistFromHandsY=0
		WgtAvgDistFromHandsZ=0

		[Hand1]
		DistanceTraveledX=0
		DistanceTraveledY=0
		DistanceTraveledZ=0
		WgtAvgSpeedX=0
		WgtAvgSpeedY=0
		WgtAvgSpeedZ=0
		WgtAvgAccelerationX=0
		WgtAvgAccelerationY=0
		WgtAvgAccelerationZ=0
		WgtAvgMotionSmoothnessX=0
		WgtAvgMotionSmoothnessY=0
		WgtAvgMotionSmoothnessZ=0

		[Hand2]
		; To avoid cloning, data is copied from Hand1.
	)"

	g_vMetrics := class_EasyIni("Metrics", sMetrics)
	g_vMetrics.Hand2 := ObjClone(g_vMetrics.Hand1)
	g_bMetricsDataWasExported := true ; because there's nothing to export when we first start.

	FileDelete, RawData.csv
	g_vRawDataCSV := class_EasyCSV("RawData", "", true) ; has headers = true.
	g_iCSVRow := 0

	local sUnitsInfo := "
	(LTrim
		[m]
		Menu=&Meters (m)
		FromMM=0.001

		[cm]
		Menu=&Centimeters (cm)
		FromMM=0.1

		[mm]
		Menu=Mi&llimeters (mm)
		FromMM=1

		[in]
		Menu=&Inches (in)
		FromMM=0.03937008

		[ft]
		Menu=&Feet (ft)
		FromMM=0.00328084
	)"
	g_vUnitsInfo := class_EasyIni("", sUnitsInfo)
	g_iUnitConversionFactor := 1

	; Loads g_vCatalog.
	LoadCatalog()

	g_vColLabelToNum := {}

	g_vColLabelToNum["H1 TimeStamp (ms)"] := g_vRawDataCSV.AddCol("H1 TimeStamp (ms)", sError)
	g_vColLabelToNum["H2 TimeStamp (ms)"] := g_vRawDataCSV.AddCol("H2 TimeStamp (ms)", sError)

	for sField, aFieldInfo in g_vCatalog
		Loop %g_iHands_c%
		{
			if (aFieldInfo.LeapSec = "Header" && A_Index == 2)
				continue ; We only need to add columns for these fileds once.

			sLabel := "H" A_Index " " aFieldInfo.Label
			sAvgLabel := "H" A_Index " " aFieldInfo.AvgLabel
			if (aFieldInfo.LeapSec = "Header")
			{
				sLabel := aFieldInfo.Label
				sAvgLabel := aFieldInfo.AvgLabel
			}

			; Not worth the trouble to calculate motion smoothness.
			if (sField != ("Motion Smoothness" . aFieldInfo.Dim))
				g_vColLabelToNum[sLabel] := g_vRawDataCSV.AddCol(sLabel, sError)
			; Averaging fields store current and averages.
			if (aFieldInfo.StoreAs = "TimeWeighted" || aFieldInfo.StoreAs = "ValFromMetrics")
				g_vColLabelToNum[sAvgLabel] := g_vRawDataCSV.AddCol(sAvgLabel, sError)

			if (sError)
				FatalErrorMsg(sError)
		}

	if (bInitLeap)
	{
		g_vLeap := new AutoLeap("LeapMsgHandler")
		g_vLeap.m_vProcessor.m_bIgnoreGestures := true
		g_vLeap.SetTrackState(false)
	}

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: RunUnitTests
		Purpose: To ensure our calculations are valid.
	Parameters
		
*/
RunUnitTests()
{
	global g_s3DParse_c, g_iHands_c
	sLeapData := "
	(LTrim
		[Header]
		hWnd=0x0
		DataType=Update
		PalmDiffX_US=100
		PalmDiffY_US=100
		PalmDiffZ_US=100

		[Hand1]
		PalmX=0
		PalmY=0
		PalmZ=0
		VelocityX=100
		VelocityY=100
		VelocityZ=100
		PalmDeltaX_US=100
		PalmDeltaY_US=100
		PalmDeltaZ_US=100
		TimeVisible=1
		Roll=0
		Pitch=0
		Yaw=0

		[Hand2]
		PalmX=0
		PalmY=0
		PalmZ=0
		VelocityX=100
		VelocityY=100
		VelocityZ=100
		PalmDeltaX_US=100
		PalmDeltaY_US=100
		PalmDeltaZ_US=100
		TimeVisible=1
		Roll=0
		Pitch=0
		Yaw=0
	)"
	vLeapData := class_EasyIni("", sLeapData)

	Loop %g_iHands_c%
	{
		iHand := A_Index
		for k, v in vLeapData["Hand" iHand]
			vLeapData["Hand" iHand, k] := 100
	}
	vLeapData.Hand1.TimeVisible := vLeapData.Hand2.TimeVisible := 0

	LeapMsgHandler("", vLeapData, [], s)
	Tooltip 1
	Sleep 1000

	Loop %g_iHands_c%
	{
		iHand := A_Index
		for k, v in vLeapData["Hand" iHand]
			vLeapData["Hand" iHand, k] := 150
	}
	Loop, Parse, g_s3DParse_c, |
		vLeapData.Header["PalmDiff" A_LoopField] := 150
	vLeapData.Hand1.TimeVisible := vLeapData.Hand2.TimeVisible := 1001

	LeapMsgHandler("", vLeapData, [], s)
	Tooltip 2
	Sleep 1000

	Loop %g_iHands_c%
	{
		iHand := A_Index
		for k, v in vLeapData["Hand" iHand]
			vLeapData["Hand" iHand, k] := 200
	}
	Loop, Parse, g_s3DParse_c, |
		vLeapData.Header["PalmDiff" A_LoopField] := 200

	vLeapData.Hand1.TimeVisible := vLeapData.Hand2.TimeVisible := 2001
	Loop 15
	{
		LeapMsgHandler("", vLeapData, [], s)
		Tooltip % 2 + A_Index
		Sleep 250

		Loop %g_iHands_c%
		{
			Random, iInc, 50, 500
			iHand := A_Index
			for k, v in vLeapData["Hand" iHand]
			{
				if (k = "TimeVisible")
					continue

				vLeapData["Hand" iHand, k] := iInc
			}
		}
		Random, iInc, 50, 500
		Loop, Parse, g_s3DParse_c, |
			vLeapData.Header["PalmDiff" A_LoopField] := iInc

		Random, iTime, 0.1, 0.3
		vLeapData.Hand1.TimeVisible := vLeapData.Hand2.TimeVisible += iTime
	}

	return
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: FatalErrorMsg
		Purpose: It's nice to append some data to a fatal error MsgBox and then quit.
	Parameters
		sError: Error to display.
*/
FatalErrorMsg(sError)
{
	global g_vLeap, g_vRawDataCSV
	Msgbox 8192,, %sError%`n`nPlease contact aatozb@gmail.com in order to fix this.`n`nThe program will exit after this message is dismissed.

	g_vLeap.OSD_PostMsg("Data is being logged...")
	g_vRawDataCSV.Save("RawData_From Latest Crash.csv")
	g_vLeap.OSD_PostMsg("Data has been saved. The application will now exit.")
	Sleep 1500

	return SurgeryWatcher_Exit()
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: GetReadMeFile
		Purpose:
	Parameters
		
*/
GetReadMeFile()
{
	global

	return "
	(
License: <a href=""http://creativecommons.org/licenses/by-nc-nd/4.0/legalcode"">Attribution-NonCommercial-NoDerivatives 4.0 International</a>
	Copyright " g_sName " " A_Year " Noah Graydon
	All rights reserved

Version: %VERSION%

Credits (This links to an external website; web content is not rated or monitored)
	AutoHotkey
		<a href=""http://www.autohotkey.com/forum/profile.php?mode=viewprofile&u=6056"">tinku99 @ AutoHotkey</a>
		<a href=""http://www.autohotkey.com/forum/profile.php?mode=viewprofile&u=9238"">HotKeyIt @ AutoHotkey</a>
		<a href=""http://www.autohotkey.com/forum/profile.php?mode=viewprofile&u=3754"">Lexikos @ AutoHotkey</a>
		<a href=""http://www.autohotkey.com/forum/profile.php?mode=viewprofile&u=47646"">Amnesiac @ AutoHotkey</a>
		<a href=""http://www.autohotkey.net/~HotKeyIt/AutoHotkey/files/AutoHotkey-txt.html"">HotkeyIt @ AutoHotkey_H</a>
		<a href=""http://www.autohotkey.com/board/topic/90972-string-things-common-text-and-array-functions/"">Tidbit: String Things library</a>
		<a href=""http://www.autohotkey.com/board/topic/37147-ilbutton-image-buttons-with-text-states-alignment/"">tkoi: ILButton.ahk</a>
		<a href=""https://raw.github.com/polyethene/AutoHotkey-Scripts/master/Anchor.ahk"">Polythene: Anchor.ahk</a>
		<a href=""http://www.autohotkey.com/board/topic/94458-msgbox-replacement-monolog-non-modal-transparent-message-box-cornernotify/"">RobertCollier4: CornerNotify (with some minor modifictions by me)</a>
		<a href=""http://www.autohotkey.com/board/topic/90481-library-fnt-v05-preview-do-stuff-with-fonts/"">Jballi: Fnt.ahk</a>

	Visual
		<a href=""http://mebaze.com"">Mebaze</a> for ""Bunch of Bluish"" icons
		<a href=""https://www.iconfinder.com/krasnoyarsk"">Aha-Soft</a> for ""Free Blue Buttons"" icons
		<a href=""http://mazenl77.deviantart.com/"">MazeNL77</a> for ""I Like Buttons"" icons
	Other
		<a href=""https://www.leapmotion.com/"">" g_vLeap.m_sLeapTM " Motion</a>

	Special Thanks
		Lexikos and Chris Mallet for AutoHotkey.
		HotkeyIt for his amazing work with AutoHotkey_H, and also his helpful answers to my many questions in the AutoHotkey forum.

	If you see your work and you are not credited, this is not deliberate. Notify me and I will credit you ASAP.
	)"
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/*
	Author: Verdlin
	Function: GetLegendFile
		Purpose:
	Parameters
		
*/
GetLegendFile()
{
	global

	return "
	(

Hand1 and Hand2: Which hand is which?
	The " g_vLeap.m_sLeapMC " cannot necessarily distinguish the left hand from the right (although it likely will in the future). Therefore, metrics are given as ""Hand1"" and ""Hand2."" Hand1 is the first hand detected, Hand2 is the second.

Distance Traveled
	Difference between palm position for two points in time.

Speed/Velocity
	This is not calculated by " g_sName ". Rather, it is received directly from the " g_vLeap.m_sLeapMC "; therefore, " g_sName " is not responsible if hand-calculated speed (based on the Distance Traveled and time elapsed between frames) is different than the reported speed.

Average Speed
	Time-weighted average Speed.

Average Acceleration
	Difference between Average Speed for two points in time.

Average Motion Smoothness
	Difference between Average Acceleration for two points in time.

Average Distance Between Hands
	Values are calculated as the difference between Hand1 and Hand2. A positive Y metric indicates Hand1 is higher than Hand2; conversely, a negative Y metric indicates Hand1 is lower than Hand2.

	)"

}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

/*
-----------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------DEPENDENCIES---------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------
*/

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;; My (Verdlin) modification of Titan?s/Polythene?s anchor function: https://raw.github.com/polyethene/AutoHotkey-Scripts/master/Anchor.ahk
;;;;;;;;;;;;;; Using this one instead of Attach or Titan’s/Polythene’s Anchor v4 because this function,
;;;;;;;;;;;;;; although the parameter syntax is downright atrocious, actually works in Windows 7 and 8.
Anchor2(ctrl, a, d = false)
{
	static pos
	sGUI := SubStr(ctrl, 1, InStr(ctrl, ":")-1)
	GUI, %sGUI%:Default
	ctrl := SubStr(ctrl, InStr(ctrl, ":")+1)
	sig = `n%ctrl%=

	If (d = 1){
	draw = Draw
	d=1,1,1,1
	}Else If (d = 0)
	d=1,1,1,1
	StringSplit, q, d, `,

	If !InStr(pos, sig) {
	GUIControlGet, p, Pos, %ctrl%
	pos := pos . sig . px - A_GUIWidth * q1 . "/" . pw - A_GUIWidth * q2 . "/"
	. py - A_GUIHeight * q3 . "/" . ph - A_GUIHeight * q4 . "/"
	}
	StringTrimLeft, p, pos, InStr(pos, sig) - 1 + StrLen(sig)
	StringSplit, p, p, /

	s = xwyh
	Loop, Parse, s
	If InStr(a, A_LoopField) {
	If A_Index < 3
	e := p%A_Index% + A_GUIWidth * q%A_Index%
	Else e := p%A_Index% + A_GUIHeight * q%A_Index%
	d%A_LoopField% := e
	m = %m%%A_LoopField%%e%
	}
	GUIControlGet, i, hwnd, %ctrl%
	ControlGetPos, cx, cy, cw, ch, , ahk_id %i%

	DllCall("SetWindowPos", "UInt", i, "Int", 0, "Int", dx, "Int", dy, "Int", InStr(a, "w") ? dw : cw, "Int", InStr(a, "h") ? dh : ch, "Int", 4)
	DllCall("RedrawWindow", "UInt", i, "UInt", 0, "UInt", 0, "UInt", 0x0101) ; RDW_UPDATENOW | RDW_INVALIDATE
	return
}

/*
timeSinceLastCall ( http://ahkscript.org/boards/viewtopic.php?f=6&t=537 )
   Return the amount of time, in milliseconds, that has passed since you last called this function.

   id    = You may use different ID's to store different timesets. ID should be 1 and above (not 0 or negative) or a string.
   reset = If reset is 1 and id is 0, all ID's are cleared. Otherwise if reset is 1, that specific id is cleared.

   * NOTE:
   The first call is usually blank.

example:
   out:=timeSinceLastCall()
   sleep, 500
   out:=timeSinceLastCall()
output:  500
*/
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