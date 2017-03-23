package com.p2p.data
{
	import com.p2p.data.vo.LiveVodConfig;

	public class LIVE_TIME
	{
		private static var _liveTime:Number=0;
		private static var _lastLocationTime:Number=0;
		private static var _offTime:Number=0;
		/**
		 * @param _liveTime 参数是秒
		 */		
		public static function SetLiveTime(_liveTime:Number):void{
			LIVE_TIME._liveTime=_liveTime;
			_lastLocationTime=getTime();
		}
		/**
		 * 依据客户端时间返回直播点时间
		 * @param _liveTime 返回的时间是秒
		 */	
		public static function GetLiveTime():Number{
			return Math.floor(LIVE_TIME._liveTime+(getTime()-_lastLocationTime)/1000);
		}
		/**
		 * 依据客户端时间返回伪直播点时间
		 * @param _liveTime 返回的时间是秒
		 */	
		public static function GetLiveOffTime():Number{
			return Math.floor(LIVE_TIME._liveTime+(getTime()-_lastLocationTime)/1000+LiveVodConfig.TIME_OFF+_offTime);
		}
		/**依据一分钟最小的块做调整*/
		public static function OffLiveTime(offTime:Number):void{
			_offTime=offTime+5;
		}
		
		private static function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}