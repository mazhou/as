package com.p2p.data.vo
{
	public class VodConfig
	{
		/**内核版本号*/
		public static var VERSION:String = "vod.1.2.01161421";
		/**协议版本号*/
		public static const P2P_AGREEMENT_VERSION:String = "1_2_01131500";
		/**点播设置，内存最大字节*/
		//public static var MEMORY_SIZE:uint= 80*1024*1024;
		//public static var MEMORY_SIZE:uint= 300*1024*1024;
		/**直播用，内存存放的时间，800(800*1024b/8字节)码流约50分钟*/
		//public static var MEMORY_TIME:uint = 50*60;
		/**
		 * _adTime保存播放器播放广告的剩余时间，该值随时钟递减，
		 * 只有当_adTime大于5秒时开启P2P优先加载的策略
		 * 单位：毫秒
		 * */
		private static var _adRemainingTime:Number = -1;
		private static var _locationADTime:Number = 0;
		public static function setAdRemainingTime(adTime:Number):void
		{
			_adRemainingTime = adTime;
			_locationADTime=(new Date).time;
		}
		/**
		 * 判断是否支持在播放广告时开启P2P加载
		 * 当存在广告剩余时间变量并且广告剩余时间大于 5秒 时才开启P2P优先加载
		 * */
		public static function getAdRemainingTime():Number
		{
			/*if((new Date).time-_locationADTime >= _adRemainingTime-5*1000)
			{
				return 0;
			}*/
			return (_adRemainingTime-((new Date).time-_locationADTime))/1000;
		}
		/***/
		public static function ifHasSendAdTime():Boolean
		{
			if( _adRemainingTime > -1 )
			{
				return true;
			}
			return false;
		}
	}
}