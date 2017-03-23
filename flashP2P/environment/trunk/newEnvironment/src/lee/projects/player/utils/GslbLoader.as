package lee.projects.player.utils
{
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.external.ExternalInterface;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.system.Capabilities;
	import flash.utils.clearTimeout;
	import flash.utils.getTimer;
	import flash.utils.setTimeout;

	public class GslbLoader extends EventDispatcher
	{
		private var _initPlayer:Boolean=false;
		private var _descFile:String = "desc.xml";//直播描述文件名
		private var _url:String;
		private var _md5:String;
		private var _gslbURL:String;
		private var _cdnType:String;
		private var _cdnURL:String;
		private var _cdnURL_bak:String;
		private var _ext:String;
		private var _scheme:String;
		private var _uip:String;
		private var _must:String;
		private var _ever:String;
		private var _thirdcdn:String;
		///////////////////
		private var _curTime:Number;//服务器当前时间
		private var _diffTime:Number=0;//服务器和本地时间偏差
		private var _cdndir:String;//文件路径，优先级高于dir
		private var _dir:String;//文件路径
		private var _bUpdateShiftTime:Boolean = false;
		private var _p2p:String="0";//p2p是否能播放
		private var _http:String="1";//http是否能播放
		private var _rtmp:String="0";//rtmp是否能播放
		private var _hls:String="0";//是否m3ub模式
		private var _startTime:Number=0;//视频开始时间
		private var _endTime:Number=0;//视频结束时间
		private var _shiftTime:Number=0;//进度条可拖动的范围
		private var _videoDuration:Number=-1;
		//private var _bShift:Boolean=false;
		private var _clipMaxLen:uint=5;
		
		private var _gslbLoaderTimeOut:Number=3000;//加载超时时间
		private var _gslbRetry:Number=2;//每次重试次数
		private var _nextgslbTime:Number=5;//下次请求gslb的时间间隔
		private var _startLoadGslb:Boolean=false;//是否已经加载gslb
		private var _loadSuccess:Boolean=false;//是否加载成功
		private var _reload:Boolean=false;//是否重新加载gslb状态
		private var _gslbTimeoutID:uint=0;
		private var _gtime:Number=0;//定时参数
		private var _desc:String;//运行商信息
		private var _remote:String;//客户端ip
		
		//////测试模式新增参数
		private var _usetype:String;
		private var _vartype:String;//播放视频类型
		private var _dest_ip:String;//播放视频的地址
		
		private var _type:String="HTTP_MODE_TYPE";
		
		private var _gslbLoader:URLLoader;//调度加载对象
		private var _flashVars:Object;//Flashvar参数对象
		private var _geo:String;
		private var _live_rate:String="";///新增加统计带宽的参数
		private var _groupName:String;
		private var _liveppct:Number=0.2;
		private var _livesftime:Number=0;
		private var _key:String;
		private var _info:Object;
		private var _loadContinueTime:int=0;
		private var _gslbErrorTimeLen:Number=180000;
		private var _sptime:Number=0;//定义节目开始时间
		private var _eptime:Number=0;//定义节目结束时间
		private var _gone:Array=new Array;
		private var _sign:String="live_web";
		private var _keyModel:LiveKey=LiveKey.getInstance();
		private var _setTimeOutId:uint=0;
		private var _mustm3u8:String="0";
		private var _vtype:String="";
		private var _cdnArr:Array;
		private var _termid:String;
		private var _platid:String;
		private var _splatid:String;
		private var _musttype:String="0";
		private var _token:String = "";
		private var _pay:String = "0";
		public static var _instance:GslbLoader;
		
		public function GslbLoader()
		{
		}

		public function get remote():String
		{
			return _remote;
		}

		public function get desc():String
		{
			return _desc;
		}

		public static function getInstance():GslbLoader
		{
			if(!_instance)
			{
				_instance=new GslbLoader();
			}
			return _instance;
		}
		public function init(o:Object):void
		{
			_loadContinueTime=getTimer();
			_info=o;
			_url=o.url;
			_md5=o.streamid;
			_gslbURL = o.gslbUrl;
			_cdnType = o.cdn;
			_cdnURL = o.url;
			_ext=o.ext;
			_scheme=o.scheme;
			_uip=o.uip;
			_must=o.must;
			_ever=o.ever;
			_usetype=o.usetype;
			_vartype=o.type;
			_dest_ip=o.dest_ip;
			_dir=o.path;
			_sptime=o.sptime;
			_eptime=o.eptime;
			_sign=o.from;
			_musttype=o.musttype;
			_token=o.token;
			_pay = o.pay;
			if(_sign.indexOf("letv_ltv")>-1)
			{
				_sign=_sign.replace("letv_ltv","live");
			}
//			if(o.gslbObj)
//			{
//				_gslbLoaderTimeOut=o.gslbObj["timeout"];
//				_gslbRetry=o.gslbObj["retry"];
//				_gslbErrorTimeLen=o.gslbObj["errortime"];
//			}
			var obj:Object={streamid:o.streamid,serverurl:o.furl,usetime:o.ftime};
			initKey(obj);
		}
		public function initKey(value:Object):void
		{
			_keyModel.init(value);
			_keyModel.addEventListener(Event.COMPLETE,overHandler);
		}
		public function clear():void
		{
			sendLog(this+"clear",1);
			_startLoadGslb=true;
			_loadSuccess=false;
			_cdnArr=new Array;
			stop();
		}
		public function reload():void
		{
			_loadContinueTime=getTimer();
			_reload=true;
			_keyModel.reFreshTime();
			loadgslb();
		}
		public function load():void
		{
			sendLog(this+"获取服务器时间！",1);
			//loadgslb();
			var flag:Boolean=false;
			if(_usetype=="alpha")
			{
				flag=true;
			}
			_keyModel.load(flag);
		}
		private function overHandler(evt:Event):void
		{
			/**加载结束，可以求情gslb了**/
			sendLog(this+"获取服务器时间结束，加载gslb！tm="+_keyModel.tm+",key="+_keyModel.key,1);
			loadgslb();
		}
		private function loadgslb():void
		{
			clear();
			if(_usetype=="alpha")
			{
				_curTime = (int)((new Date()).time/1000);
				if(_vartype=="rtmp")
				{
					_cdnURL="rtmp://"+_dest_ip+"/"+_dir;
				}
				else if(_vartype=="leflv")
				{
					_cdnURL="http://"+_dest_ip+"/"+_dir+"/desc.xml?tag=live";				
				}
				type=_cdnURL;
				_startLoadGslb=false;
				_loadSuccess=true;
				var obj:Object={
					"type":"complete",
					"utime":"0",
					"error":"0",
					"retry":"0",
					"res":"-",
					"location":_cdnURL
				};
				_cdnArr.push(_cdnURL);
				dispatchEvent(new Event(Event.COMPLETE));
				return;
			}
			_groupName=_gslbURL
			///补充参数
			_groupName+="gslb?stream_id="+_md5;
			_groupName+="&tag=live";
			_groupName+="&ext="+_ext;
			_groupName+="&sign="+_sign;
			_groupName+="&format=2";
			_groupName+="&expect=2";
			_groupName+="&scheme="+_scheme;
			_groupName+="&termid=1";
			_groupName+="&pay="+_pay;
			_groupName+="&ostype="+encodeURI(Capabilities.os);
			_groupName+="&hwtype=un";
			_groupName+="&platid=10&splatid=1001&playid=1";
			if(_uip)
			{
				_groupName+="&uip="+_uip;
			}
			if(_must)
			{
				_groupName+="&must="+_must;
			}
			if(_ever)
			{
				_groupName+="&ever="+_ever;
			}
			if(_keyModel.tm)
			{
				_groupName+="&tm="+_keyModel.tm;
			}
			if(_token&&_token!=null)
			{
				_groupName+="&token="+_token;
			}
			if(_keyModel.key)
			{
				_groupName+="&key="+_keyModel.key;
			}
			sendLog(this+"加载gslb，地址："+_groupName,1);
			_gtime=getTimer();
			_gslbLoader = new URLLoader();
			_gslbLoader.addEventListener(Event.COMPLETE,_gslbLoader_COMPLETE);
			_gslbLoader.addEventListener(ErrorEvent.ERROR,_gslbLoader_ERROR);
			_gslbLoader.load(new URLRequest(_groupName));
		}
		private function _gslbLoader_COMPLETE(event:Event):void
		{
			var xml:XML;
			//sendLog("data="+event.target.data);
			try
			{
				xml=XML(event.target.data);
			}
			catch(e:Error)
			{
				_gslbLoader_ERROR();
				return;
			}
			if(xml==null)
			{
				_gslbLoader_ERROR();
				return;
			}
			//返回错误码
			if(xml.hasOwnProperty("status"))
			{
				if(String(xml.status) == "400")
				{
					if(_ext == "xml")
					{
						_ext = "m3u8";
					}
					else
					{
						_ext = "xml";
					}
					_gslbLoader_ERROR();
					return;
				}
			}
			_loadContinueTime=getTimer();
			_loadSuccess=true;
			_startLoadGslb=false;
			clearTimeout(_gslbTimeoutID);
			sendLog(this+"加载gslb成功！"+_cdnType,1);
			var listUrl:Array;
			var listUrl2:Array;
//			if(xml.hasOwnProperty("location"))
//			{
//				if(_cdnType == "letv")
//				{
//					_cdnURL = xml.location;
//					_cdnURL_bak = null;
//				}
//				_cdnArr.push(_cdnURL);
//			}else{

				if(_cdnType == "letv")
				{
					for(var i:int=0;i<xml.nodelist.node.length();i++)
					{
//						var obj:Object = {};
//						obj.loaction = ;
//						for(var i:* in
						_cdnArr.push(xml.nodelist.node[i].text());
						_gone.push(xml.nodelist.node[i].@gone);
					}
				}
//			}
			if(xml.hasOwnProperty("desc"))
			{
				_desc =xml.desc;
			}
			if(xml.hasOwnProperty("remote"))
			{
				_remote = xml.remote;
			}
			if(xml.hasOwnProperty("termid"))
			{
				_termid=xml.termid;
			}
			if(xml.hasOwnProperty("platid"))
			{
				_platid=xml.platid;
			}
			if(xml.hasOwnProperty("splatid"))
			{
				_splatid=xml.splatid;
			}
			if(xml.hasOwnProperty("geo"))
			{
				_geo=xml.geo;
			}
			if(xml.hasOwnProperty("liveppct"))
			{
				_liveppct=Number(xml.liveppct);
			}
			if(xml.hasOwnProperty("livesftime"))
			{
				_livesftime=Number(xml.livesftime);
			}
			if(xml.hasOwnProperty("livep2p"))
			{
				_p2p=xml.livep2p;
			}
			if(xml.hasOwnProperty("liveflv"))
			{
				_http=xml.liveflv;
			}
			if(xml.hasOwnProperty("livertmp"))
			{
				_rtmp=xml.livertmp;
			}
//			if(xml.hasOwnProperty("livehls"))
//			{
//				_hls=xml.livehls;
//			}
			if(xml.hasOwnProperty("mustm3u8"))
			{
				_mustm3u8=xml.mustm3u8;
			}
			//_mustm3u8="1";
			if(mustm3u8&&_ext!="m3u8"&&_musttype!="flv")
			{
				//重新请求能获得m3u8地址
				_ext="m3u8";
				loadgslb();
				return;
			}
			if(_cdnArr[0])
			{
				type=_cdnArr[0];
				listUrl = _cdnArr[0].split("?");
				if(listUrl.length >0)
				{
					listUrl2 = listUrl[0].split("/");
					if(listUrl2.length > 0)
					{
						_descFile = listUrl2[listUrl2.length -1];
					}
				}
			}
			_curTime = (int)((new Date()).time/1000);//毫秒转化为秒 
			if(!isNaN(xml.curtime) && xml.curtime != 0)
			{
				_curTime = xml.curtime;
				_diffTime=(int)(_curTime-(new Date()).time/1000);
			}
			if(!isNaN(xml.starttime) && xml.starttime != 0)
			{
				_startTime = Number(xml.starttime);
			}
			else
			{
				_startTime = 0;
			}
			if(!isNaN(xml.endtime))
			{
				_endTime = Number(xml.endtime);
			}
			else
			{
				_endTime = -1;
			}
			if(xml.hasOwnProperty("timeshift"))
			{
				_shiftTime =Number(xml.timeshift);
			}
			if(_sptime>0)
			{
				_startTime=Math.round(_sptime/1000);
				_shiftTime=_startTime;
			}
			if(_eptime>0)
			{
				_endTime=Math.round(_eptime/1000);
			}
			if(_endTime>0)
			{
				_videoDuration=_endTime-_startTime;
				if(_videoDuration<0)
				{
					_videoDuration=0;
				}
			}
			_dir = xml.dir;
			_cdndir=xml.cdnpath;
			if(xml.hasOwnProperty("cdnpath")&&_cdndir!="")
			{
				sendLog("cdndir="+_cdndir+"|启用cdndir");
				_dir=_cdndir;
			}
			/*测试使用*/
			if(_info&&_info.useVersion=="alpha")
			{
				createTestTime();
			}
			//////检查当前请求的数据是否合理
			var _dataUse:Boolean=false;
			if(type=="HTTP_MODE_TYPE")
			{
				if(http||p2p)
				{
					_dataUse=true;
				}
				else
				{
					_scheme="rtmp";
				}
			}
			if(type=="RTMP_MODE_TYPE")
			{
				if(rtmp)
				{
					_dataUse=true;
				}
				else
				{
					_scheme="http";
				}
			}
			if(!_dataUse)
			{
				sendLog(this+"数据不可用，需要重新请求！type="+type+",http="+http+",p2p="+p2p+",data="+xml,4);
				clearTimeout(_gslbTimeoutID);
				if(!rtmp&&!http)
				{
					_gslbTimeoutID=setTimeout(load,_nextgslbTime*1000);
				}
				else
				{
					loadgslb();
				}
				//LetvStatistics.getInstance().sendAll({"type":"gslb",utime:(getTimer()-_gtime),"error":500,"retry":_gslbLoader.retry,"res":"-","location":"-"});
				return;
			}
			var obj:Object={
				"type":"complete",
				"utime":(getTimer()-_gtime),
				"error":"0",
				"retry":"1",
				"res":"-",
				"location":_cdnURL,
				"servertime":_keyModel.time
			};
			dispatchEvent(new Event(Event.COMPLETE));
		}
		private function _gslbLoader_ERROR(event:Event=null):void
		{
			sendLog(this+"_gslbLoader_ERROR");
			_startLoadGslb=false;
			//重新请求gslb
			clearTimeout(_gslbTimeoutID);
		}
		private function stop():void
		{
			sendLog(this+"stop");
			if(_gslbLoader)
			{
				_gslbLoader.removeEventListener(Event.COMPLETE,_gslbLoader_COMPLETE);
				_gslbLoader.removeEventListener(ErrorEvent.ERROR,_gslbLoader_ERROR);
				try
				{
					_gslbLoader.close();
				}
				catch(e:Error)
				{
					sendLog("_urlStream.close()错误");
				}
				_gslbLoader=null;
			}
		}
		private function createTestTime():void
		{
			_videoDuration=60*60;
			_endTime=int(new Date().time/1000)-30*60;
			_shiftTime = _endTime-_videoDuration;
		}
		public function get cdnURL():String
		{
			var url:String;
			//sendLog("_urlStream.close()错误"+_cdnArr+"|"+_cdnArr.length,1);
			if(_cdnArr&&_cdnArr.length>0)
			{
				url=_cdnArr[0];
			}
			return url;
		}
		public function set cdnURL(s:String):void
		{
			if(_cdnArr)
			{
				_cdnArr[0]=s;
			}
		}
		public function set cdnURL_bak(s:String):void
		{
			if(_cdnArr)
			{
				_cdnArr[1]=s;
			}
		}
		public function get cdnURL_bak():String
		{
			var url:String;
			if(_cdnArr&&_cdnArr.length>1)
			{
				url=_cdnArr[1];
			}
			return url;
		}
		public function get termid():String
		{
			return _termid;
		}
		public function get platid():String
		{
			return _platid;
		}
		public function get splatid():String
		{
			return _splatid;
		}
		public function get cdnArr():Array
		{
			return _cdnArr;
		}
		public function get thirdcdn():String
		{
			return _thirdcdn;
		}
		public function get dir():String
		{
			return _dir;
		}
		public function get shiftTime():Number
		{
			return _shiftTime;
		}
		public function get cdnType():String
		{
			return _cdnType;
		}
		public function set cdnType(s:String):void
		{
			_cdnType=s;
		}
//		public function get bshift():Boolean
//		{
//			return _bShift;
//		}
		public function get gslbSuceess():Boolean
		{
			return _loadSuccess;
		}
		
		public function get curTime():Number
		{
			return int(new Date().time/1000)+diffTime;
		}
		public function set type(s:String):void
		{
			if(s == null)return;
			if(s.indexOf("http://")>-1)
			{
				_type="HTTP_MODE_TYPE";
			}
			else if(s.indexOf("rtmp://")>-1)
			{
				_type="RTMP_MODE_TYPE";
			}
			if(s.indexOf(".m3u8")>-1)
			{
				_vtype="m3u8";
			}
			else
			{
				_vtype="flv";
			}
		}
		public function get type():String
		{
			return _type;
		}
		public function get p2p():Boolean
		{
			if(_p2p=="1")
			{
				return true;
			}
			return false;
		}
		public function get hls():Boolean
		{
			if(_hls=="1")
			{
				return true;
			}
			return false;
		}
		public function get mustm3u8():Boolean
		{
			if(_mustm3u8=="1"&&(_musttype=="0"||_musttype=="m3u8"))
			{
				return true;
			}
			return false;
		}
		public function get http():Boolean
		{
			if(_http=="1")
			{
				return true;
			}
			return false;
		}
		public function get rtmp():Boolean
		{
			if(_rtmp=="1")
			{
				return true;
			}
			return false;
		}
		public function set must(m:String):void
		{
			_must=m;
		}
		public function get must():String
		{
			return _must;
		}
		public function set ever(e:String):void
		{
			_ever=e;
		}
		public function get ever():String
		{
			return _ever;
		}
		public function get diffTime():Number
		{
			return _diffTime;
		}
		public function get startTime():Number
		{
			return _startTime;
		}
		public function get endTime():Number
		{
			return _endTime;
		}
		public function get serverTime():Number
		{
			return _curTime;
		}
		public function get descFile():String
		{
			return _descFile;
		}
		public function get clipMaxLen():uint
		{
			return _clipMaxLen;
		}
		public function get streamid():String
		{
			return _md5;
		}
		public function get videoDuration():Number
		{
			return _videoDuration;
		}
		public function get geo():String
		{
			return _geo;
		}
		public function get livesftime():Number
		{
			return _livesftime;
		}
		public function get liveppct():Number
		{
			return _liveppct;
		}
		public function get gone():Array
		{
			return _gone;
		}
		public function get gslb():String
		{
			return _groupName;
		}
		public function get vtype():String
		{
			return _vtype;
		}
		public function get groupName():String
		{
//			var reg:RegExp=/.*\/(.*)\/desc\.xml.*/;
//			var tarr:Array=reg.exec(_cdnURL);
//			var str:String="";
//			if(tarr.length>1)
//			{
//				str=tarr[1];
//			}
			return _md5;//_groupName+str;
		}
		protected function sendLog(msg:*,num:int=0):void
		{
			ExternalInterface.call("console.log",msg);
		}
	}
}