package com.mzStudio.util
{
	public class DateFormat
	{
		public function returnDateFormat(date:Date):String
		{
			return "["+
//				date.fullYear+"-"+date.month+"-"+date.day+
//				" "+
				date.getHours()+":"+date.getMinutes()+":"+date.getSeconds()+"."+date.milliseconds+"]";
			
		}
	}
}