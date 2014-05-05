LoadCatalog()
{
	global g_s3DParse_c

/*
	Legend
		CloneTo: Used to dynamically clone sections
		3D: Used to dynamically rename first sec to %sec%X, and then clone for Y and Z
		m_bCloned: Used to indicate we have cloned/renamed this sec.
			Hungarian notation is used to clarify that this is only used for the loading process.
		LastAvgVal: Used in LeapMsgHandler(). Stored each time we iterate through a field so that
			fields that need to calculate difference may do so.
			We don't need LastCurVal because that will be present in the Leap engine??

	Remember:
		* We can't use Leap keys as secs because of items like Acceleration.
		* Roll is first because, due to dynamic creating of sections, it gets placed first anyway.
			If we did not explicitly make it first, then pitch and yaw would be at the bottom.

	Need to add
		1. MotionSmoothness
*/

	sCatalog := "
		(LTrim
			[Roll]
			Label=Current |A_ThisSec|
			AvgLabel=Average |A_ThisSec|
			StoreAs=TimeWeighted
			Units=°
			UseAbsVal=0
			LeapSec=Hand
			LeapKey=|A_ThisSec|
			MetricSec=Hand
			MetricKey=WgtAvg|A_ThisSec|
			3D=0
			CloneTo=Pitch|Yaw
			m_bCloned=0
			LastVal=

			[DistanceTraveled]
			Label=Distance traveled |A_ThisDim|
			AvgLabel=
			StoreAs=Raw
			Units=|g_sUnits|
			UseAbsVal=1
			LeapSec=Hand
			LeapKey=Trans|A_ThisDim|
			MetricSec=Hand
			MetricKey=|A_ThisSec|
			3D=1
			Dim= ; X,Y, or Z
			m_bCloned=0

			[Speed]
			Label=Current speed |A_ThisDim|
			AvgLabel=Average speed |A_ThisDim|
			StoreAs=TimeWeighted
			Units=|g_sUnits|/s
			UseAbsVal=0
			LeapSec=Hand
			LeapKey=Velocity|A_ThisDim|
			MetricSec=Hand
			MetricKey=WgtAvg|A_ThisSec|
			3D=1
			Dim=
			m_bCloned=0

			[Acceleration]
			Label=Current acceleration |A_ThisDim|
			AvgLabel=Average acceleration |A_ThisDim|
			StoreAs=ValFromMetrics
			Units=|g_sUnits|/s2
			LeapSec=Hand
			LeapKey=Velocity|A_ThisDim|
			MetricSec=Hand
			MetricKey=WgtAvg|A_ThisSec|
			3D=1
			Dim=
			m_bCloned=0

			[Distance between hands]
			Label=Current distance between hands |A_ThisDim|
			AvgLabel=Average distance between hands |A_ThisDim|
			StoreAs=TimeWeighted
			Units=|g_sUnits|
			UseAbsVal=1
			LeapSec=Header
			LeapKey=PalmDiff|A_ThisDim|
			MetricSec=Other
			MetricKey=WgtAvgDistFromHands|A_ThisDim|
			3D=1

		)"

	FileDelete, Catalog.ini
	global g_vCatalog := class_EasyIni("Catalog", sCatalog)

	; Note: we cannot safely change data while also iterating through it,
	; so we must store this information and change it afterwards.
	aDataChanges := []

	; Resolve |A_ThisSec|
	for sec, aData in g_vCatalog
	{
		; 3D=1
		if (aData.3D && !aData.m_bCloned)
		{
			; Store data for making appropriate sections.
			Loop, Parse, g_s3DParse_c, |
			{
				aDataChanges.Insert({m_sFunc: "", m_sOldSec: sec
					, m_sNewSec: sec . A_LoopField, m_sDim: A_LoopField, m_sError: ""})

				iDataCnt := aDataChanges.MaxIndex()
				if (A_Index == 1)
				{
					sSourceSecForCopying := aDataChanges[iDataCnt].m_sNewSec
					aDataChanges[iDataCnt].m_sFunc := "RenameSection"
				}
				else
				{
					aDataChanges[iDataCnt].m_sFunc := "AddSection"
					aDataChanges[iDataCnt].m_sSourceSecForCopying := sSourceSecForCopying
				}
			}
		}
		; CloneTo=...
		if (aData.CloneTo)
		{
			sCloneToList := aData.CloneTo
			Loop, Parse, sCloneToList, |
				aDataChanges.Insert({ m_sFunc: "AddSection", m_sOldSec: sec
					, m_sNewSec: A_LoopField, m_sDim: A_LoopField
					, m_sSourceSecForCopying: sec, m_sError: "" })
		}
	}

	for iNdx, vDataChange in aDataChanges
	{
		; Not sure how to dynamically call class methods explicitly, so just matching on strings.
		if (vDataChange.m_sFunc = "RenameSection")
			bSuceeded := g_vCatalog.RenameSection(vDataChange.m_sOldSec, vDataChange.m_sNewSec, vDataChange.m_sError)
		else if (vDataChange.m_sFunc = "AddSection")
		{
			; Add the section.
			bSuceeded := g_vCatalog.AddSection(vDataChange.m_sNewSec, "", "", vDataChange.m_sError)
			; Now copy over keys/vals from appropriate sections.
			g_vCatalog[vDataChange.m_sNewSec] := ObjClone(g_vCatalog[vDataChange.m_sSourceSecForCopying])
		}
		aNewData := g_vCatalog[vDataChange.m_sNewSec]

		if (!bSuceeded)
			FatalErrorMsg("Error: Catalog load failed.`n`n" vDataChange.m_sError)

		; Remove key used to help clone...
		g_vCatalog.DeleteKey(vDataChange.m_sNewSec, "CloneTo")
		; And indicate we have sucessfully clonged.
		aNewData.m_bCloned := 1
		; If this was a 3D field, add add the Dim key for dynamical variable references.
		if (aNewData.3D)
			aNewData.Dim := vDataChange.m_sDim
	}

	; Note: Given the nature of resolving dynamic variables, this loop must always come last!
	for sec, aData in g_vCatalog
	{
		for k, v in aData
		{
			if (InStr(v, "|A_ThisSec|"))
			{
				StringReplace, v, v, |A_ThisSec|, %sec%, All
				g_vCatalog[sec][k] := v
			}
			if (InStr(v, "|A_ThisDim|"))
			{
				StringReplace, v, v, |A_ThisDim|, % aData.Dim, All
				g_vCatalog[sec][k] := v
			}
		}
	}

	g_vCatalog.Save()

	return
}