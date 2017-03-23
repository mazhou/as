package com.p2p.data.vo
{
	public class LiveVodConfig
	{
		//PLAY***********************************************************************************************
		/**内核版本号*/
		public static const VERSION:String = "liv.1.2.08011133";
		/**P2P协议版本号*/
		public static const P2P_AGREEMENT_VERSION:String = "1.0";
		/**点播设置，内存最大字节*/
		//public static var MEMORY_SIZE:uint= 80*1024*1024;
		public static var MEMORY_SIZE:uint= 300*1024*1024;
		/**直播用，内存存放的时间，800(800*1024b/8字节)码流约50分钟*/
		public static var MEMORY_TIME:uint=50;
		/**每个片的字节，128k字节*/
		public static var CLIP_INTERVAL:uint = 128*1024;
		/**伪直播偏移时间*/
		public static var TIME_OFF:Number=-60*3;
		/**当前播放的类型*/
		public static const LIVE:String="LIVE";
		public static const VOD:String="VOD";
		public static var TYPE:String=LIVE;
		
		public static function SET_MEMORY_TIME():void
		{
			MEMORY_TIME = Math.ceil((MEMORY_SIZE/(DATARATE/8*1024))/60);
		}
		
		//DATAMANAGE***********************************************************************************************
		/**播放码率*/
		public static var DATARATE:Number=800;
		/**播放码率的倍数，暂定为1.5倍*/
		public static var RATE_MULTIPLE:Number=1.5;
		/**紧急区加载的区间，通过块的格林尼治时间相差换算，误差在一个块之间*/
		public static var DAT_BUFFER_TIME:Number=30;
		/**是否有领先的资格*/
		public static var ISLEAD:int=1;
		/**是否为服务器确认的领先资格*/
		public static var IS_REAL_LEAD:Boolean=false;
		/**领先者个名字*/
		public static var NAME_OF_LEADER:String="";
		
		//DESC***********************************************************************************************
		/**desc在内存缓存的时间，暂定2小时,单位秒*/
		//public static var DESC_TIME:Number=10*60;
		public static var DESC_TIME:Number=40*60;
		/**desc重复加载次数（总的次数=DESC_RPEAT_LOAD_COUNT*加载地址的个数）*/
		public static var DESC_RPEAT_LOAD_COUNT:int=3;
		
		//DAT***********************************************************************************************
		/**dat重复加载次数(总的次数=DAT_RPEAT_LOAD_COUNT*加载地址的个数) */
		public static var DAT_RPEAT_LOAD_COUNT:int=3;
		/**隔断时间，观察是否有数据下载，如果没有认为是网络错误，暂定间隔时间为2000豪秒*/
		public static var DAT_CHECK_INTERVAL:Number=2000;
				
		
		//P2P***********************************************************************************************
		/**在p2p使用中，可以修改的本地名称*/
		public static var MY_NAME:String;
		/**连接失败的节点在失败列表中的保存时间*/
		public static var badPeerTime:Number = 30*1000;
		
		public static function CLEAR():void
		{
			LiveVodConfig.MEMORY_SIZE   = 300*1024*1024;
			LiveVodConfig.MEMORY_TIME   = 50;
			LiveVodConfig.CLIP_INTERVAL = 128*1024;
			LiveVodConfig.TIME_OFF = -60*3;
			
			LiveVodConfig.TYPE     = LIVE;
			
			/**播放码率*/
			LiveVodConfig.DATARATE        = 800;
			LiveVodConfig.RATE_MULTIPLE   = 1.5;
			LiveVodConfig.DAT_BUFFER_TIME = 30;
			LiveVodConfig.ISLEAD          = 1;
			LiveVodConfig.IS_REAL_LEAD    = false;
			LiveVodConfig.NAME_OF_LEADER  = "";
			
			LiveVodConfig.DESC_TIME             = 40*60;
			LiveVodConfig.DESC_RPEAT_LOAD_COUNT = 3;
			
			LiveVodConfig.DAT_RPEAT_LOAD_COUNT = 3;
			LiveVodConfig.DAT_CHECK_INTERVAL   = 2000;
			
			LiveVodConfig.MY_NAME     = null;
			LiveVodConfig.badPeerTime = 30*1000;
		}		
	}
}