BIN_ToTxt(string)
{
	autotrim, off
	loop
	{
		var=128
		ascii=0
		StringRight, byte, string, 8 
		if byte=
		break
		StringTrimRight, string, string, 8 
		Loop, parse, byte 
		{
			if a_loopfield = 1
			ascii+=%var%
			var/=2
		}
		transform, text, Chr, %ascii%
		alltext=%text%%alltext%
	}
	autotrim, on
	return alltext
}

BIN_FromTxt(string)
{
	Loop, parse, string
	{
		var=128
		Transform, tobin, Asc, %A_LoopField%
		loop, 8
		{
			oldtobin=%tobin%
			tobin:=tobin-var
			transform, isnegative, Log, %tobin%
			value=1
			if isnegative=
			{
			tobin=%oldtobin%
			value=0
			}
			var/=2
			allvalues=%allvalues%%value% 
		}
	}
	return allvalues
}