package com.hls_p2p.data.vo
{
	import com.hls_p2p.statistics.Statistic;
	
	public class LiveVodConfig
	{

		/**点播设置，内存最大字节*/
		//public static var MEMORY_SIZE:uint			= 300*1024*1024;
//		public static var MEMORY_SIZE:uint			= 300*1024*1024;
//		public static function set MEMORY_SIZE(value:uint):void
//		{
//		}
		public static function get MEMORY_SIZE():uint
		{
			if( TYPE == VOD )
			{
				return 	300*1024*1024;
			}
			return 	30*1024*1024;
		}
		
		/**直播用，内存存放的时间，800(800*1024b/8字节)码流约50分钟*/
		public static var MEMORY_TIME:uint			= 50;
		
		/**每个片的字节，128k字节*/
		public static var CLIP_INTERVAL:uint 		= 188*1024;//128*1024;
		
		/** live_vod_piecesize*/
		public static var CLIP_LIVEVOD_PERSIZE:uint = 188*1024;
		/**伪直播偏移时间*/
		public static var TIME_OFF:Number			= 60*1;
		
		public static function GET_VERSION():String
		{
			if(LiveVodConfig.TYPE == LiveVodConfig.VOD)
			{
				return LiveVodConfig.VOD_VERSION;
			}
			else
			{
				return LiveVodConfig.LIVE_VERSION;
			}
		}
		public static function GET_AGREEMENT_VERSION():String
		{
			if(LiveVodConfig.TYPE == LiveVodConfig.VOD)
			{
				return LiveVodConfig.P2P_AGREEMENT_VOD_VERSION;
			}
			else
			{
				return LiveVodConfig.P2P_AGREEMENT_LIVE_VERSION;
			}
		}
		
		public static function SET_MEMORY_TIME():void
		{
			if(LiveVodConfig.TYPE == LiveVodConfig.VOD)
			{
				MEMORY_TIME = Math.ceil((MEMORY_SIZE/(DATARATE/8*1024))/60);
			}			
		}
		
		public static var ADD_DATA_TIME:Number 	= -1;
		public static var PLAY_TIME:Number 		= -1;

		/**点播总时长*/
		public static var DURATION:Number 		= -1;
		
		public static var TOTAL_TS:Number    	= 0;
		public static var TOTAL_PIECE:Number 	= 0;
		public static var LAST_TS_ID:Number  	= 0;
		
		private static var _NEAREST_WANT_ID:Number = -1;
		public static function set NEAREST_WANT_ID(num:Number):void
		{
			_NEAREST_WANT_ID = num;
			Statistic.getInstance().NEAREST_WANT_ID();
		}
		public static function get NEAREST_WANT_ID():Number
		{
			return _NEAREST_WANT_ID
		}
		//TTT
		public static var G_SEEKPOS:Number		 = 0;
		public static var M3U8LASTBLOCKID:Number = 0;
		
		//DATAMANAGE***********************************************************************************************
		/**播放码率*/
		public static var DATARATE:Number			= 800;
		/**播放码率的倍数，暂定为1.5倍*/
		public static var RATE_MULTIPLE:Number		= 1.5;
		/**紧急区加载的区间，通过块的格林尼治时间相差换算，误差在一个块之间*/
		public static var DAT_BUFFER_TIME:Number	= 10;//30;//60*10;//7;
		
		//DESC***********************************************************************************************
		/**desc在内存缓存的时间，暂定2小时,单位秒*/
		public static var DESC_TIME:Number			= 40*60;
		/**desc重复加载次数（总的次数=DESC_RPEAT_LOAD_COUNT*加载地址的个数）*/
		public static var DESC_RPEAT_LOAD_COUNT:int	= 3;
		/**每次请求DESC的时移时间*/
		public static function set M3U8_MAXTIME(num:Number):void
		{
			_M3U8_MAXTIME = num;
			Statistic.getInstance().M3U8_MaxTime();
		}
		public static function get M3U8_MAXTIME():Number
		{
			return _M3U8_MAXTIME;
		}
		private static var _M3U8_MAXTIME:Number 	= -1;
		//DAT***********************************************************************************************
		/**dat重复加载次数(总的次数=DAT_RPEAT_LOAD_COUNT*加载地址的个数) */
		public static var DAT_RPEAT_LOAD_COUNT:int	= 3;
		/**隔断时间，观察是否有数据下载，如果没有认为是网络错误，暂定间隔时间为2000豪秒*/
		public static var DAT_CHECK_INTERVAL:Number	= 2000;
		/**随机CDN下载数据的概率*/
		public static var DAT_LOAD_RATE:Number		= 0.1//0.3;
		
		//NETSTREAM*****************************************************************************************
		/**缓存时，暂停最大的时间，如果超过这个时间直接seek，单位时间是秒（原来是90秒）*/
		public static var Buffer_Count_Time:Number	= 60;
		/**播放不超过这个缓冲值，超过将不再喂数据*/
		public static var BufferTimeLimit:Number	= 20;
		/**开始运行的时间*/
		public static var BirthTime:Number			= 0;
		
		//P2P***********************************************************************************************
		/**在p2p使用中，可以修改的本地名称*/
		public static var MY_NAME:String;
		/**连接失败的节点在失败列表中的保存时间*/
		public static var badPeerTime:Number 		= 2*60*1000;
		/**最大连接节点数*/
		public static var MAX_PEERS:Number 			= 9;
		/**是否允许p2p下载*/
		public static var ifCanP2PDownload:Boolean = true;//false//
		/**是否允许p2p上传*/
		public static var ifCanP2PUpload:Boolean   = true;//false//
		/**是否允许紧急区之外的CDN下载任务可以被取消*/
		//public static var ifCanResetCDNTask:Boolean = true;
		
		public static function CLEAR():void
		{
//			LiveVodConfig.MEMORY_SIZE   		= 300*1024*1024;
			
			LiveVodConfig.TYPE    		 		= LiveVodConfig.LIVE;
			
			LiveVodConfig.ADD_DATA_TIME  		= -1;
			LiveVodConfig.PLAY_TIME 			= -1;
			LiveVodConfig._NEAREST_WANT_ID 	    = 0;
			
			LiveVodConfig.Buffer_Count_Time		= 60;
			LiveVodConfig.BufferTimeLimit		= 20;
			LiveVodConfig.BirthTime				= 0;
			
			/**播放码率*/
			LiveVodConfig.DATARATE        		= 800;
			LiveVodConfig.RATE_MULTIPLE   		= 1.5;
			
			LiveVodConfig.DESC_RPEAT_LOAD_COUNT = 3;
			LiveVodConfig._M3U8_MAXTIME 		= -1;
			
			LiveVodConfig.DAT_RPEAT_LOAD_COUNT 	= 3;
			LiveVodConfig.DAT_CHECK_INTERVAL   	= 2000;
			
			LiveVodConfig.MY_NAME       		= "";
			LiveVodConfig.badPeerTime   		= 30*1000;
			LiveVodConfig.DAT_LOAD_RATE 		= 0.1;
			
			LiveVodConfig.TOTAL_TS    			= 0;
			LiveVodConfig.TOTAL_PIECE 			= 0;
			LiveVodConfig.LAST_TS_ID  			= 0;

			LiveVodConfig.ifCanP2PDownload 		= true;
			LiveVodConfig.ifCanP2PUpload    	= true;

			//LiveVodConfig.ifCanResetCDNTask		= true;
			
			LiveVodConfig.TERMID  				= "";	//终端类型
			LiveVodConfig.PLATID  				= "";	//平台ID
			LiveVodConfig.SPLATID 				= "";  //子平台ID
		}
		//statistics************************************************************************************
		public static const CLIENT_TYPE:String 	= "PC";//"BOX";//"MP";//"TV";////////
		public static var TERMID:String 		= "";		//终端类型
		public static var PLATID:String 		= "";		//平台ID
		public static var SPLATID:String 		= "";	//子平台ID
		//PLAY***********************************************************************************************
		/**内核版本号*/
		private static const VOD_VERSION:String  = "vod.3.0.12131321";
		private static const LIVE_VERSION:String = "liv.3.0.12190002_7P_30M";
		
		/**当前播放的类型*/
		public static const LIVE:String			 = "LIVE";
		public static const VOD:String			 = "VOD";
		public static var TYPE:String=LIVE;//VOD;
		
		/**P2P协议版本号 */
		private static const P2P_AGREEMENT_VOD_VERSION:String  = "1.3m3u8_12111859";//"1.3m3u8_11151520";//"1.3m3u8_11051326";//0909122->加removeHaveData功能
		private static const P2P_AGREEMENT_LIVE_VERSION:String = "1.3m3u8_12111859";//"1.3m3u8_11151520";//"1.3m3u8_11251830";//"1.3m3u8_11051326";
	}
}