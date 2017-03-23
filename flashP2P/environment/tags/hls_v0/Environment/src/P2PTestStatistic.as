package 
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.TimerEvent;
	import flash.net.NetStream;
	import flash.utils.Timer;
	
	import lee.managers.RectManager;
	
	/**
	 * 计算http下载，p2p下载，分享的平均速度，瞬时速度，数据块大小
	 * */
	public class P2PTestStatistic extends EventDispatcher
	{
		protected var _netstream:NetStream;
		protected var _timeNum:Number=3000;//时间
		protected var _timer:Timer;
		
		protected var _httpdownloadTime:int=0;
		protected var _p2pdownloadTime:int=0;
		protected var _httpNum:int=0;
		protected var _p2pNum:int=0;
		protected var _httpDownLoadSize:Number = 0;//http下载数据总量
		protected var _httpShunShiSize:Number = 0;//http瞬时下载数据
		protected var _httpShunshiSpeed:Number = 0;//http瞬时下载速度
		protected var _httpDownLoadSpeed:Number = 0;//http下载速度

		protected var _p2pDownLoadSize:Number = 0;//p2p下载数据总量
		protected var _p2pShunShiSize:Number = 0;//p2p瞬时下载数据
		protected var _p2pShunshiSpeed:Number = 0;//p2p瞬时下载速度
		protected var _p2pDownLoadSpeed:Number = 0;//p2p下载速度

		protected var _p2pDownLoadRate:Number = 0;//分享率


		public var isShowSpeed:Boolean = true;

		public function P2PTestStatistic()
		{
		}
		/**
		 * 初始化
		* */
		public function init(netstream:NetStream):void
		{
			_netstream = netstream;
			RectManager.p2pTestStatistic = this;

			_netstream.addEventListener("streamStatus",netstatusHandle);
			_netstream.addEventListener("p2pLocalStatus",netstatusHandle);

			_timer = new Timer(_timeNum);
			_timer.addEventListener(TimerEvent.TIMER,onTimer);
			_timer.start();
		}
		/**
		 * 计时器停止
		* */
		public function stop():void
		{
			if (_timer)
			{
				_timer.stop();
			}
			clear();
		}

		private function start():void
		{
			if (_timer)
			{
				_timer.reset();
				_timer.start();
			}
		}

		private function netstatusHandle(event:Object):void
		{
			var code:String = String(event.info.code);
			switch (code)
			{
				case "Stream.Play.Start" :
					start();
					break;
				case "Stream.Play.Stop" :
					stop();
					break;
				case "P2P.HttpGetChunk.Success" :
					_httpDownLoadSize +=  event.info.size;
					_httpShunShiSize +=  event.info.size;
					break;
				case "P2P.P2PGetChunk.Success" :
					_p2pDownLoadSize +=  event.info.size;
					_p2pShunShiSize +=  event.info.size;
					break;
			}
		}
		private function onTimer(event:TimerEvent):void
		{
			if (! isShowSpeed)
			{
				return;
			}
			//http下载
			
			if(_httpShunshiSpeed!=0)
			{
				_httpNum++;
			}
			if(_httpDownLoadSize!=0)
			{
				if(_httpNum!=0)
				{
					_httpdownloadTime=(_httpNum*_timeNum)/1000;
					_httpDownLoadSpeed=(_httpDownLoadSize/1024)/_httpdownloadTime;
				}
				
				_httpShunshiSpeed=(_httpShunShiSize/1024)/(_timeNum/1000);
			}
			
			
			//P2P下载
			if(_p2pShunShiSize!=0)
			{
				_p2pNum++;
			}
			if(_p2pDownLoadSize!=0)
			{
				if(_p2pNum!=0)
				{
					_p2pdownloadTime=(_p2pNum*_timeNum)/1000;
					_p2pDownLoadSpeed=_p2pDownLoadSize/1024/_p2pdownloadTime;
				}
				_p2pShunshiSpeed=(_p2pShunShiSize/1024)/(_timeNum/1000);
			}
			
			//下载率
			_p2pDownLoadRate = int((_p2pDownLoadSize / (_p2pDownLoadSize + _httpDownLoadSize))*100);
            
			var obj:Object=new Object();
			/*
			obj.bufferTime = :
			case "bufferLength":
			case "time":*/
			obj.P2PRate = _p2pDownLoadRate;
			obj.P2PSpeed = getNum(_p2pShunshiSpeed);
			obj.avgSpeed = getNum( _httpDownLoadSpeed);
			
			obj.txt = ">>>>>HTTP下载---------" + "\n" + "数据量:" + _httpDownLoadSize / 1024 / 1024 + " MB" + "\n" + "平均速度:" +getNum( _httpDownLoadSpeed) + " KB/s" + "\n" + "速度:" + getNum(_httpShunshiSpeed) + " KB/s" + "\n" + "\n" + "-------->p2p下载---------" + "\n" + "数据量:" + _p2pDownLoadSize / 1024 / 1024 + " MB" + "\n" + "平均速度:" + getNum(_p2pDownLoadSpeed) + " KB/s" + "\n" + "速度:" + getNum(_p2pShunshiSpeed) + " KB/s" + "\n" + "\n"  + "p2p下载率：" + _p2pDownLoadRate + " %" + "\n";
			
			this.dispatchEvent(new P2PTestStatisticEvent(P2PTestStatisticEvent.P2P_TEST_STATISTIC_TIMER,obj));
            
			
			
			_httpShunShiSize = 0;
			_p2pShunShiSize = 0;
		}

		private function getNum(num:Number):String
		{
			var str:String="";
			if(num==0)
			{
				return "0";
			}else
			{
				str=num.toFixed(2);
				if(str=="0.00")
				{
					str="0.01"
				}
				return str;
			}
		}

		private function clear():void
		{
			_httpDownLoadSize = 0;
			_httpShunShiSize = 0;
			_httpShunshiSpeed = 0;
			_httpDownLoadSpeed = 0;

			_p2pDownLoadSize = 0;
			_p2pShunShiSize = 0;
			_p2pShunshiSpeed = 0;
			_p2pDownLoadSpeed = 0;

			_p2pDownLoadRate = 0;
		}

	}
}