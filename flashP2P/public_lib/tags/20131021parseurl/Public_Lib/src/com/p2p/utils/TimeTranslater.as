package com.p2p.utils
{
	public class TimeTranslater
	{
		/**获取绝对时间所对应的小时和分钟的相对值{hour:Number,min:Number}*/
		public static function getHourMinObj(id:Number):Object
		{
			var obj:Object = new Object();
			//var date:Date  = new Date(id*1000);
			/*obj.year = date.fullYear;
			obj.date = date.date;
			obj.hor  = date.hours;
			obj.min  = date.minutes;*/
			//obj.hour = Math.floor(id/3600);
			//obj.min  = date.minutes;
			obj.minutes =Math.floor(id/60);//obj.hour + obj.min;
			return obj;
		}
		
		/**参数单位是秒*/
		public static function getTime(dateTime:Number):String{
			var date:Date=new Date(dateTime*1000);
			return date.getHours()+":"+date.getMinutes()+":"+date.getSeconds()+"."+date.milliseconds;
		}
	}
}