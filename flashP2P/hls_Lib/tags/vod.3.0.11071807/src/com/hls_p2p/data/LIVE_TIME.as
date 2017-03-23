package com.hls_p2p.data
{
	import com.hls_p2p.data.vo.LiveVodConfig;

	public class LIVE_TIME
	{
		private static var _liveTime:Number				= 0;
		private static var _lastLocationTime:Number		= 0;
		private static var _offTime:Number				= 0;
		private static var _baseTime:Number				= 0;
		private static var _lastBaseLocationT:Number	= 0;
		
		private static var _pauseTime:Number			= 0;
		private static var _isPause:Boolean				= false;
		
		
		public static function get isPause():Boolean
		{
			return _isPause;
		}

		public static function set isPause(value:Boolean):void
		{
			if(value)
			{
				_pauseTime=GetBaseTime();
				SetBaseTime(_pauseTime);
			}
			
			_isPause = value;
			
			if(!_isPause)
			{
				_lastBaseLocationT = getTime();
			}
		}

		/**
		 * @param _liveTime 参数是秒
		 */		
		public static function SetLiveTime(_liveTime:Number):void
		{
			LIVE_TIME._liveTime=_liveTime;
			_lastLocationTime=getTime();
		}
		/**
		 * 依据客户端时间返回直播点时间
		 * @param _liveTime 返回的时间是秒
		 */	
		public static function GetLiveTime():Number
		{			
			return Math.floor(LIVE_TIME._liveTime+(getTime()-_lastLocationTime)/1000);
		}
		/**
		 * 依据客户端时间返回伪直播点时间
		 * @param _liveTime 返回的时间是秒
		 */	
		public static function GetLiveOffTime():Number{
			return Math.floor(LIVE_TIME._liveTime+(getTime()-_lastLocationTime)/1000-LiveVodConfig.TIME_OFF+_offTime);
		}
		/**依据一分钟最小的块做调整*/
		public static function OffLiveTime(offTime:Number):void
		{
			_offTime=offTime+5;
		}
		
		/**
		 *seek或play设置时间 
		 * @param offTime
		 */		
		public static function SetBaseTime(offTime:Number):void
		{
			_baseTime=offTime;
			_lastBaseLocationT=getTime();
		}
		
		/**
		 * 依据客户端时间返回seek点本地时间
		 * @param _liveTime 返回的时间是秒
		 */	
		public static function GetBaseTime():Number
		{
			if(_isPause)
			{
				_lastBaseLocationT = getTime();
				return _baseTime;
			}
			return Math.floor(_baseTime+(getTime()-_lastBaseLocationT)/1000);
		}
		
		public static function CLEAR():void
		{
			_liveTime 			= 0;
			_lastLocationTime 	= 0;
			_offTime 			= 0;
			_baseTime 			= 0;
			_lastBaseLocationT 	= 0;
			
			_isPause 			= false;
			_pauseTime 			= 0;
		}

		private static function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}