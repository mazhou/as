package {
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.events.NetStatusEvent;
	import flash.events.TimerEvent;
	import flash.net.NetStream;
	import flash.net.SharedObject;
	import flash.net.URLRequest;
	import flash.net.sendToURL;
	import flash.system.Capabilities;
	import flash.utils.Timer;
	//import com.letv.player.p2p.events.P2PNetStreamEvent;
	
	public class StatisticManager
	{
		/*播放主要环节时间序列图:
		1.播放器加载(播放器加载动作由播放页JS方式上报);
		2.播放初始化(playerInit)
		3.获取广告位置
		4.获取广告地址配置xml
		5.下载广告物料
		6.广告曝光过程
		7.获取CDN地址
		(1)开始获取CDN(playerStartCDN)
		(2)成功获取CDN(playerCDN)
		(3)获取CDN失败(playerFailCDN)
		8.首次视频文件下载
		9.视频播放过程
		(1)视频开始播放(playerStartPlay)
		(2)视频心跳
		(3)视频缓冲
		10.播放结束*/
		
		private var _netstream:*;
		private var _heartbeatTimer:Timer;
		private var _time:int= 1000*10//1000*3*60;//
		//private var _time:int=1000*5;
		private var _heartbeatNum:int=0;//心跳次数
		private var _bufferNum:int=0;//缓冲次数
		private var _startbufferTime:int=0;//开始缓冲计时
		private var _stopbufferTime:int=0;//缓冲结束计时
		private var _realbufferTime:int=0;//缓冲花费时间
		private var _allbufferTime:int=0;//缓冲总费时
		private var _heartBuffer:int=0;//心跳期间缓冲上报时间
		private var _bufferArr:Array=[];
		private var _bufferArrLength:int=0;
		private var _startpauseTime:int=0;//开始暂停计时
		private var _stoppauseTime:int=0;//暂停结束计时
		private var _realpauseTime:int=0;//暂停花费时间
		private var _allpauseTime:int=0;//暂停总费时
		private var _startPause:Boolean=false;//开始暂停
		private var _heartPause:int=0//心跳期间暂停上报时间
		private var _pauseArr:Array=[];
		private var _pauseArrLength:int=0;
		private var _startdispatchTime:int=0;//开始调度计时
		private var _completedispatchTime:int=0;//完成调度计时
		private var _startCDNTime:int=0;//开始连接CDN计时;
		private var _completeCDNTime:int=0;//完成CDN连接计时
		private var _bufferReady:Boolean=false;
		private var _seekReady:Boolean=false;
		private var _pauseReady:Boolean=false;
		private var _obj:Object;
		private var ch:String;//渠道号
		private var cid:String;//频道id号
		private var uuid:String;//播放器生成的一次播放的唯一标识
		private var uname:String;//用户名
		private var vid:String;//视频标识
		private var ksp:String;//播放协议0:http,1:p2p,2:rtmp
		private var node:String;//CDN节点node值
		private var videorate:String//文件视频的码率
		private var location:String//调度信息中的location值
		private var split:String;//视频分片数量
		private var def:String;//清晰度0：标清；1：高清；3：超清
		private var size:String;//缓冲区下载文件大小
		private var stime:String;//片头时长
		private var etime:String;//片尾时长
		private var bp:String;//是否断点续传
		private var mmsid:String;//视频媒资ID
		private var p2ptime:Number=0//规定时间内p2p下载耗费时间
		private var p2psize:uint=0//规定时间内下载p2p大小 
		private var peer:int=0//规定时间内chunk来源邻居数 
		private var chunknum:uint=0//总chunk数
		private var alltime:Number=0//规定时间内总下载耗费时间
		private var httpsize:uint=0//规定时间内http下载大小 
		private var speednum:int=0;
		
		private var logUrl:String="http://dc.letv.com/";
		//private var logUrl:String="http://stat.client.letv.com/stat.php?t=FLASHP2P&";
		//private var logUrl:String="http://10.10.80.58/stat.php?t=FLASHP2P&";
		public function StatisticManager()
		{
			
		}
		public function reset(netstream:NetStream):void{
			heartbeatStop();
			_netstream=netstream;
			_netstream.addEventListener("streamStatus",netStatusHandle);
			_netstream.addEventListener("p2pStatus",netStatusHandle);
			
		}
		//播放器初始化
		public function playerInit(obj:Object):void
		{
			_obj=obj;
			ch=String(_obj.ch);//渠道号
			cid=String(_obj.cid);//频道id号
			uuid=GuidUtil.create();
			uname=String(_obj.uname);//用户名
			var os:String="FLASH_"+Capabilities.version;//平台环境，标识flash或其他.例如 Flash_WIN 10,0,12,36
			var ver:String=String(_obj.ver);//终端（或播放器）版本。例如 INS_1.1.2
			var ref:String=String(_obj.ref);//播放页地址
			var auto:String=String(_obj.auto);//是否启用自动播放 0表示没有启用自动播放;1表示启用自动播放
			var ru:String=String(_obj.ru);//播放器来源 
			var initVideorate:String=String(_obj.videorate);//文件视频的码率 页面获取
			var ftype:String=String(_obj.ftype);//文件类型 页面获取
			var did:String=sharedID();
			var uid:String=String(_obj.uid);//Passport唯一用户号 页面获取
			//lz
			//sendToURL(new URLRequest(logUrl+"vq/int?os="+os+"&ver="+ver+"&ref="+ref+"&auto="+auto+"&ch="+ch+"&ru="+ru+"&error=0&utime=0&scrn=0&videorate="+initVideorate+"&ftype="+ftype+"&cid="+cid+"&uuid="+uuid+"&r="+Math.random()+"&uname="+uname+"&retry=1&did="+did+"&uid="+uid));
		}
		//播放器全屏
		public function playerFullScreen():void
		{
			//lz
			//sendToURL(new URLRequest(logUrl+"vq/action?act=2&ontime=0&ct=0&sp=0&uuid="+uuid+"&r="+Math.random()+"&ch="+ch+"&uname="+uname+"&Section=0"));
		}
		
		//播放器调度
		private function playerDispatch(obj:Object):void
		{
			var error:String=String(obj.error);//错误代码错误,0表示成功 。。400：网络错误；401：超时；402：跨域；403：数据解析失败；999：其他
			var utime:String=String(obj.utime);
			var retry:String=String(obj.retry);//尝试次数 首次时使用1, 第2次使用2;（最多3次）
			var res:String=String(obj.res);//调度返回值
			var location:String=String(obj.url);//调度信息中的location值
			//trace(utime,"=",_completedispatchTime,"-",_startdispatchTime)
			//lz
			//sendToURL(new URLRequest(logUrl+"vq/gslb?error="+error+"&utime="+utime+"&retry"+retry+"&res="+res+"&location="+UrlMultiEncode.urlencodeGBK(location)+"&uuid="+uuid+"&r="+Math.random()+"&ch="+ch+"&uname="+uname));
		}
		
		private function netStatusHandle(event:Object):void
		{
			var code:String=event.info.code;
			switch (code)
			{
				case "Stream.Play.Start" :
					playerStart(event.info);
					break;
				case "Stream.Play.Stop" :
					playerStop();
					break;
				case "Stream.Buffer.Empty" :
					if(_bufferReady)
					{
						_bufferReady=false;
						_startbufferTime=getTime();
					}
					break;
				case "Stream.Buffer.Full" :
					if(_bufferReady)
					{
						_stopbufferTime=getTime();
						if(_startbufferTime!=0)
						{
							_realbufferTime=_stopbufferTime-_startbufferTime-_heartBuffer;
							if(_realbufferTime>2000)
							{
								_bufferArr.push(_realbufferTime);
								playerBuffer();
							}
						}
					}
					_bufferReady=true;
					return;
					break;
				case "Stream.Pause.Notify":
					_pauseReady=false;
					_startPause=true;
					_startpauseTime=getTime();
					break;
				case "Stream.Unpause.Notify":
					_pauseReady=true;
					_stoppauseTime=getTime();
					_realpauseTime=_stoppauseTime-_startpauseTime-_heartPause;
					_pauseArr.push(_realpauseTime);
					break;
				case "Stream.Seek.Complete":
					playerGrag();
					break;
				case "Stream.Play.Failed" :
					playerStart(event.info);
					break;
				case "P2P.LoadG3URL.Failed":
					playerDispatch(event.info)
					break;
				case "P2P.LoadG3URL.Success":
					playerDispatch(event.info)
					/*for(var i:String in event.info)
					{
						trace(i,"=",event.info[i])
					}*/
					break;
			}
		}
		
		//播放器缓冲
		private function playerBuffer():void
		{
			//trace("正在缓冲。。")
			_bufferNum++;
			//lz			
			//sendToURL(new URLRequest(logUrl+"vq/action?act=1&ontime=0&ct="+_bufferNum+"&sp=0&uuid="+uuid+"&r="+Math.random()+"&ch="+ch+"&uname="+uname+"&Section=0"));
		}
		
		//播放开始
		private function playerStart(obj:Object):void
		{
			var error:int=obj.error;
			var retry:int=obj.retry;
			var ksp:int=obj.ksp;
			var node:int=obj.node;
			var location:String=obj.url;
			var utime:Number=obj.utime;
			//lz			
			//sendToURL(new URLRequest(logUrl+"vq/play?error="+error+"&retry"+retry+"&utime="+utime+"&ksp="+ksp+"&scrn=0&node="+node+"&videorate="+videorate+"&location="+UrlMultiEncode.urlencodeGBK(location)+"&cid="+cid+"&vid="+vid+"&split="+split+"&ontime=0&ch="+ch+"&uuid="+uuid+"&r="+Math.random()+"&uname="+uname+"&def="+def+"&size="+size+"&btime=0&stime="+stime+"&etime="+etime+"&bp="+bp+"&mmsid="+mmsid));
			heartbeatInit();
		}
		//播放器拖拽
		public function playerGrag():void
		{
			//lz			
			//sendToURL(new URLRequest(logUrl+"vq/action?act=3&ontime=0&ct=0&sp=0&uuid="+uuid+"&r="+Math.random()+"&ch="+ch+"&uname="+uname+"&Section=0"));
		}
		//心跳提交======lsize,ltime,lnode(上传不上报)
		private function heartbeatInit():void
		{
			if(_heartbeatTimer)
			{
				_heartbeatTimer.reset();
				_heartbeatNum=0;
				_bufferNum=0;
			}
			_heartbeatTimer=new Timer(_time);
			_heartbeatTimer.addEventListener(TimerEvent.TIMER,heartbeatOntimer);
			_heartbeatTimer.start();
		}
		
		private function heartbeatOntimer(event:TimerEvent):void
		{
			staticDate();
			
			_heartbeatNum++;
			//缓冲
			if(_bufferReady==false)
			{
				_stopbufferTime=getTime();
				if(_startbufferTime!=0)
				{
					_realbufferTime=_stopbufferTime-_startbufferTime;
					if(_realbufferTime>20)
					{
						_bufferArr.push(_realbufferTime);
						_bufferArrLength=_bufferArr.length
						for(var b:int=0;b<_bufferArrLength;b++)
						{
							_allbufferTime+=_bufferArr[b];
						}
						
						var bufferLastArr:Array=_bufferArr.slice(_bufferArrLength-1,_bufferArrLength);
						_heartBuffer=bufferLastArr.toString();
					}
				}
				
			}else
			{
				for(var f:int=0;f<_bufferArr.length;f++)
				{
					_allbufferTime+=_bufferArr[f];
				}
			}
			
			//暂停
			if(_pauseReady==false&&_startPause)
			{
				_stoppauseTime=getTime();
				_realpauseTime=_stoppauseTime-_startpauseTime;
				_pauseArr.push(_realpauseTime);
				_pauseArrLength=_pauseArr.length
				for(var u:int=0;u<_pauseArrLength;u++)
				{
					_allpauseTime+=_pauseArr[u];
				}
				
				var pauseLastArr:Array=_pauseArr.slice(_pauseArr.length-1,_pauseArr.length);
				_heartPause=pauseLastArr.toString();
				
				if(_allpauseTime>_time)
				{
					_allpauseTime=_time;
				}
			}else
			{
				for(var p:int=0;p<_pauseArrLength;p++)
				{
					_allpauseTime+=_pauseArr[p];
				}
			}
			
			
			
			if(speednum==0)
			{
				speednum=-1;
			}
			
			//上报
			//lz			
			//sendToURL(new URLRequest(logUrl+"vq/action?act=0&ontime=0&ct="+_heartbeatNum+"&sp="+speednum+"&uuid="+uuid+"&r="+Math.random()+"&ch="+ch+"&uname="+uname+"&Section=0&utime="+Math.round(_time/(1000*60))+"&ptime="+_allpauseTime+"&btime="+_allbufferTime+"&ksp="+ksp+"&stime="+alltime+"&dsize="+p2psize+"&dtime="+p2ptime+"&dnode="+peer+"&httpsize="+httpsize));
			//trace(        "心跳 = "+logUrl+"vq/action?act=0&ontime=0&ct="+_heartbeatNum+"&sp="+speednum+"&uuid="+uuid+"&r="+Math.random()+"&ch="+ch+"&uname="+uname+"&Section=0&utime="+Math.round(_time/(1000*60))+"&ptime="+_allpauseTime+"&btime="+_allbufferTime+"&ksp="+ksp+"&stime="+alltime+"&dsize="+p2psize+"&dtime="+p2ptime+"&dnode="+peer+"&httpsize="+httpsize)
			//清零
			//缓冲
			_bufferArr=[];
			_allbufferTime=0;
			//暂停
			_pauseArr=[];
			_allpauseTime=0;
			
		}
		//心跳关闭
		private function heartbeatStop():void
		{
			if(_heartbeatTimer)
			{
				
				_heartbeatTimer.stop();
			
			}
			_heartbeatNum=0;
			_bufferNum=0;
			_startbufferTime=0;
			_stopbufferTime=0;
			_realbufferTime=0;
			_allbufferTime=0;
			_heartBuffer=0;
			_bufferArrLength=0;
			_startpauseTime=0;
			_stoppauseTime=0;
			_realpauseTime=0;
			_allpauseTime=0;
			_startPause=false;
			_heartPause=0;
			_pauseArrLength=0;
			_bufferReady=false;
			_seekReady=false;
			 _pauseReady=false;
			 p2ptime=0;
			 p2psize=0;
			 peer=0;
			 chunknum=0;
			 alltime=0;
			 httpsize=0;
		}
		//播放器结束
		
		private function playerStop():void
		{
			//最后一次上报在LetvP2PVodProvide中执行
			//staticDate();
			//lz
			/*
			sendToURL(new URLRequest(logUrl+"vq/end?uuid="+uuid+"&r="+Math.random()+"&ch="+ch+"&uname="+uname+"&utime=3&ptime="+_allpauseTime+"&btime="+_allbufferTime+"&ksp="+ksp+"&stime="+_allpauseTime+"&dsize="+p2psize+"&dtime="+p2ptime+"&dnode="+peer+"&lsize=+$13&ltime=$14&lnode=$15"));
			sendToURL(new URLRequest(logUrl+"vq/action?act=0&ontime=0&ct="+_heartbeatNum+"&sp="+speednum+"&uuid="+uuid+"&r="+Math.random()+"&ch="+ch+"&uname="+uname+"&Section=0&utime="+_time/(1000*60)+"&ptime="+_allpauseTime+"&btime="+_allbufferTime+"&ksp="+ksp+"&stime="+alltime+"&dsize="+p2psize+"&dtime="+p2ptime+"&dnode="+peer+"&httpsize="+httpsize));
			*/
			heartbeatStop();
			
		}
		
		private function staticDate():void
		{
			/*var obj:Object=_netstream.getStatisticData();
			p2ptime=obj.p2ptime;
			p2psize=obj.p2psize;
			peer=obj.peer; 
			chunknum=obj.chunknum;
			alltime=obj.alltime;
			httpsize=obj.httpsize;
			speednum=obj.speednum;*/
		}
		
		private function sharedID():String
		{
			var _clientidDefault:XML=<root><clientid>{GuidUtil.create()}</clientid></root>;
			var _clientidShared:SharedObject=SharedObject.getLocal("letv_player_config_clientid","/");
			if(_clientidShared.size!=0)
			{
				var _clientidConfig:XML=XML(_clientidShared.data.config);
			}
			else
			{
				_clientidConfig=_clientidDefault.copy();
				_clientidShared.data.config=_clientidConfig;
				_clientidShared.flush();
			}
			return String(_clientidConfig.clientid[0]);
		}
		private function getTime():Number {
			return Math.floor((new Date()).time);
		}
	}
}