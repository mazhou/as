package analysisURL
{
	
	import analysisURL.AnalysisEvent;
	
	import com.p2p.utils.Base64;
	import com.p2p.utils.json.JSONDOC;
	import com.p2p.utils.sha1Encrypt;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.utils.Timer;
	
	
	public class LetvAnalysisURL extends EventDispatcher
	{		
		protected var _startloadG3:Number;
		protected var _letvVODInfo:Object;	
		protected var _letvVODInfoLoader:URLLoader;		
		protected var _G3URLArray:Array;    //保存G3地址的数组，便于在访问失败时选择其他地址
		
		//protected var _myTimer:Timer;//超时计时器,10秒钟超时
		
		public function LetvAnalysisURL()
		{			
		}
		public function start(str:String):void
		{			
			clear();
			
			_G3URLArray = new Array();
//			str = "http://g3.letv.cn/28/24/68/letv-uts/1289903-AVC-514481-AAC-124402-246247-20386466-dc4a6b1e89946853cdcc2e5aeec4392b-1355296253105.flv?b=662&mmsid=2101170&tm=1359432662&key=7bc0bd2d910a13255331bc91aa36daa7&format=1&tag=letv&sign=letv&expect=3&rateid=1000"
			str = "http://g3.letv.cn/19/53/82/letv-uts/684508-AVC-537889-AAC-31586-6767257-498020185-c2ce9304df17ddcfe16adb8b7199dc67-1350293248246.flv?b=588&mmsid=1944433&tm=1359357666&key=6ba67d4178663dbd414afdcffdb5ebaa&format=1&tag=letv&sign=letv&expect=3&rateid=1000"
			trace("str = "+str);
			var strg3url:String = str.replace("g3.letv.com","g3.letv.cn");
			
			var obj:Object=new Object();
			obj = getCheckURL(strg3url);	  //获取groupName,checkXML地址；
			
			_letvVODInfo       = new Object();					
			_letvVODInfo.group = obj.group;   //将groupName
			_letvVODInfo.check = obj.check;   //将checkXML地址保存
			_letvVODInfo.retry = 0;	          //初始化尝试连接次数
			
			creatG3URLArray(strg3url);        //获得3个G3地址，存入_G3URLArray数组
			
			//------------测试输出-----------------
			trace("strg3url = "+strg3url);
			for(var i:int = 0 ; i<_G3URLArray.length ; i++)
			{
				trace("_G3URLArray["+i+"] = "+_G3URLArray[i]);
			}
			//-------------------------------------
			startLetvVODInfoLoader();			
		}
		public function clear():void
		{
			clearLetvVODInfoLoader();
			_startloadG3 = 0;
			_letvVODInfo = null;
			_G3URLArray  = null ;
			_letvVODInfoLoader = null;			
		}
		protected function creatG3URLArray(str:String):void
		{
			_G3URLArray = new Array();
			
			str	= changeG3URL(str);           //转换成可以返回3个CDN地址的G3
			
			_G3URLArray.push(str);            //将第一个G3地址存入数组
			
			var replaceReg:RegExp = /(^)http:\/\/([\w-]+\.)+[\w-]+/i;	
			
			str = str.replace(replaceReg,"http://g3.letv.com");
			
			_G3URLArray.push(str);            //将第二个G3地址存入数组
			
			var servers:Array = ["http://220.181.117.15","http://220.181.117.16","http://220.181.117.27","http://123.125.89.141","http://123.125.89.142","http://123.125.89.143"];
			
			str = str.replace(replaceReg,servers[Math.floor(Math.random() * servers.length)]);
			
			_G3URLArray.push(str);            //将第三个G3地址存入数组
			
		}
		
		protected function startLetvVODInfoLoader():void
		{
			_startloadG3 = getTime();      //取开始加载的时间；	
			
			clearLetvVODInfoLoader();
			
			_letvVODInfoLoader=new URLLoader();
			_letvVODInfoLoader.addEventListener(Event.COMPLETE,letvVODInfoLoader_COMPLETE);
			_letvVODInfoLoader.addEventListener(IOErrorEvent.IO_ERROR,letvVODInfoLoader_ERROR);
			_letvVODInfoLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR,letvVODInfoLoader_ERROR);			
				
			_letvVODInfoLoader.load(new URLRequest(_G3URLArray[_letvVODInfo.retry]));
		}
		
		protected function clearLetvVODInfoLoader():void
		{			
			
			if (_letvVODInfoLoader)
			{
				try
				{				
					_letvVODInfoLoader.close();
					
				}catch(err:Error)
				{
				}
				
				_letvVODInfoLoader.removeEventListener(Event.COMPLETE,letvVODInfoLoader_COMPLETE);
				_letvVODInfoLoader.removeEventListener(IOErrorEvent.IO_ERROR,letvVODInfoLoader_ERROR);
				_letvVODInfoLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,letvVODInfoLoader_ERROR);
				_letvVODInfoLoader = null;
				
			}			
			
		}
		
		protected function letvVODInfoLoader_COMPLETE(evt:Event):void
		{					
			try
			{	
				var obj:Object = JSONDOC.decode(String(_letvVODInfoLoader.data));				
				
			}catch(e:Error)
			{
				letvVODInfoLoader_ERROR("dataError");				
				return;
			}					
			
			if(!obj.geo)
			{
				letvVODInfoLoader_ERROR("dataError");				
				return;
			}else
			{
				var arr:Array = String(obj.geo).split(".");
				if(arr.length != 4)
				{
					letvVODInfoLoader_ERROR("dataError");				
					return;
				}
			}
			
			var flvURLArray:Array  = new Array();                // 由于通过g3地址需要返回多个flv地址保证容错播放，所以将地址保存到_flvURL数组中
			var flvNodeArray:Array = new Array();                // 存放cdn node id
			
			for(var i:int = 0 ; i<obj.nodelist.length ; i++)
			{				
				flvURLArray.push(obj.nodelist[i].location);
				//----------测试

				
				flvNodeArray.push(obj.nodelist[i].gone);				
			}		

			//flvURLArray.push("http://123.125.89.45/16/46/77/letv-uts/813824-AVC-254879-AAC-47088-2705264-107337129-cabdfecf76a9a6bab7902aa4f89900e0-1352490655701.letv?crypt=288f5781aa7f2e150&b=800&gn=706&nc=3&bf=15&p2p=1&video_type=flv&check=1&tm=1353940200&key=6d9f816f744f3f82947174214ec901ca&lgn=letv&proxy=2071812438&cipi=168448203");
			//flvURLArray.push("http://123.125.89.45/16/46/77/letv-uts/813824-AVC-254879-AAC-47088-2705264-107337129-cabdfecf76a9a6bab7902aa4f89900e0-1352490655701.letv?crypt=288f5781aa7f2e150&b=800&gn=706&nc=3&bf=15&p2p=1&video_type=flv&check=1&tm=1353940200&key=6d9f816f744f3f82947174214ec901ca&lgn=letv&proxy=2071812438&cipi=168448203");
			//flvURLArray.push("http://123.125.89.86/16/46/77/letv-uts/813824-AVC-254879-AAC-47088-2705264-107337129-cabdfecf76a9a6bab7902aa4f89900e0-1352490655701.letv?crypt=50718c43aa7f2e150&b=800&gn=103&nc=3&bf=15&p2p=1&video_type=flv&check=1&tm=1353940200&key=6d9f816f744f3f82947174214ec901ca&lgn=letv&proxy=2071812397&cipi=168448203");
			//flvURLArray.push("http://123.125.89.86/16/46/77/letv-uts/813824-AVC-254879-AAC-47088-2705264-107337129-cabdfecf76a9a6bab7902aa4f89900e0-1352490655701.letv?crypt=50718c43aa7f2e150&b=800&gn=103&nc=3&bf=15&p2p=1&video_type=flv&check=1&tm=1353940200&key=6d9f816f744f3f82947174214ec901ca&lgn=letv&proxy=2071812397&cipi=168448203&rstart=11534336&rend=13893631");
			

//			flvURLArray.push("http://119.167.147.75/19/24/107/letv-uts/813818-AVC-538078-AAC-46798-2705519-205319026-c88510ef0374d8034129deafa350d997-1352492180355.flv?crypt=7b90990baa7f2e151&b=607&gn=730&nc=3&bf=20&p2p=1&video_type=flv&check=0&tm=1353574800&key=2fd3545d83e463c9935a55049a467dc8&retry=0&tag=letv&sign=letv&rateid=1000&code=434");
//			flvURLArray.push("http://119.167.147.75/19/24/107/letv-uts/813818-AVC-538078-AAC-46798-2705519-205319026-c88510ef0374d8034129deafa350d997-1352492180355.flv?crypt=7b90990baa7f2e151&b=607&gn=730&nc=3&bf=20&p2p=0&video_type=flv&check=0&tm=1353574800&key=2fd3545d83e463c9935a55049a467dc8&retry=0&tag=letv&sign=letv&rateid=1000&code=434");
//			flvURLArray.push("http://119.167.147.75/19/24/107/letv-uts/813818-AVC-538078-AAC-46798-2705519-205319026-c88510ef0374d8034129deafa350d997-1352492180355.flv?crypt=7b90990baa7f2e151&b=607&gn=730&nc=3&bf=20&p2p=9&video_type=flv&check=0&tm=1353574800&key=2fd3545d83e463c9935a55049a467dc8&retry=0&tag=letv&sign=letv&rateid=1000&code=434");


			//flvURLArray.push("http://123.125.89.87/17/25/33/letv-uts/893132-AVC-254739-AAC-31586-2328298-86959879-262f62f5a1ff90130713f82d6be4422c-1353891996821.letv?crypt=79fdba73aa7f2e174&b=800&gn=103&nc=3&bf=17&p2p=1&video_type=flv&check=1&tm=1353940200&key=b9e8cd2fb9834d962fda73c3a4a6726e&lgn=letv&proxy=2071812384&cipi=168448203&rstart=8126464&rend=10354687");
			//flvURLArray.push("http://123.125.89.32/17/25/33/letv-uts/893132-AVC-254739-AAC-31586-2328298-86959879-262f62f5a1ff90130713f82d6be4422c-1353891996821.letv?crypt=6bfa7911aa7f2e150&b=800&gn=706&nc=3&bf=15&p2p=1&video_type=flv&check=1&tm=1353940200&key=b9e8cd2fb9834d962fda73c3a4a6726e&lgn=letv&proxy=2071812439&cipi=168448203&rstart=8126464&rend=10354687");
			
			/*flvURLArray.push("http://119.167.147.75/19/24/107/letv-uts/813818-AVC-538078-AAC-46798-2705519-205319026-c88510ef0374d8034129deafa350d997-1352492180355.flv?crypt=7b90990baa7f2e151&b=607&gn=730&nc=3&bf=20&p2p=9&video_type=flv&check=0&tm=1353574800&key=2fd3545d83e463c9935a55049a467dc8&retry=0&tag=letv&sign=letv&rateid=1000&code=434");
			*/
			var object:Object = new Object();                   //用于保存发送统计用的内容：
			object.error = 0;                                    //0表示成功获取
			object.url   = _G3URLArray[_letvVODInfo.retry];      //成功访问的G3url
			object.utime = getTime()-_startloadG3 ;              //访问耗时
			object.retry = _letvVODInfo.retry+1;                 //尝试次数			
			object.res   = "-";                                  //目前先使用“-”表示	
			
			object.flvURL  = flvURLArray.concat();
			object.flvNode = flvNodeArray.concat();
			
			object.groupName = _letvVODInfo.group;
			object.checkURL  = _letvVODInfo.check;
			//----------测试
		    //object.checkURL  = "http://webchecksum.letv.com/19/24/107/letv-uts/813818-AVC-538078-AAC-46798-2705519-205319026-c88510ef0374d8034129deafa350d997-1352492180355.xml";

			//0907
			object.geo   = obj.geo;                              //运营商信息
			trace("geo    = "+obj.geo);
			
			dispatchG3SuccessEvent(object);
			
		}		
		
		protected function letvVODInfoLoader_ERROR(evt:*=null):void
		{			
			var obj:Object = new Object();
			
			obj.allG3Failed = 0;                                   //0：还有没尝试过的g3地址    1：所有g3地址都已尝试过了			
			obj.url = _G3URLArray[_letvVODInfo.retry];     //此时连接的G3 url
			
			_letvVODInfo.retry++;
			
			if( _G3URLArray[_letvVODInfo.retry] == undefined )
			{
				//  如果所有g3都已尝试过，则从第一个g3连接
				obj.allG3Failed    = 1;
				_letvVODInfo.retry = 0;						
			}			
				
			obj.utime  = getTime()-_startloadG3 ;    //连接耗时
			obj.res    = "-";                        //目前暂时使用“-”			
			obj.retry  = _letvVODInfo.retry;         //尝试连接的次数
			
			if(evt is IOErrorEvent)
			{		
				obj.error = 400;                    //网络连接错误				
					
			}else if(evt is TimerEvent)
			{				
				obj.error = 401;                    //超时错误				
				
			}else if(evt is SecurityErrorEvent)
			{				
				obj.error = 402;                    //跨域错误				
				
			}else if(evt is String)
			{				
				obj.error = 403;                    //数据错误				
				
			}else
			{				
				obj.error = 999;                    //其他错误				
			}
			//			
			startLetvVODInfoLoader();	             //重新加载
			//
			dispatchG3FailedEvent(obj);
			
		}
		protected function dispatchG3FailedEvent(obj:Object):void
		{
			obj.code = "URLAnalysisFailed";
			
			dispatchEvent(new AnalysisEvent(AnalysisEvent.ERROR,obj));
			
		}
		protected function dispatchG3SuccessEvent(obj:Object):void
		{
			obj.code = "URLAnalysisSuccess";		
			
			dispatchEvent(new AnalysisEvent(AnalysisEvent.STATUS,obj));
		}
		/** 
		 * 将原有g3地址转为可返回3个flv地址的g3 
		 */
		private function changeG3URL(str:String):String
		{			
			var str1:String = "";
			var arr:Array   = new Array();
			
			arr = str.split("expect=");
			
			var i:int = arr[1].indexOf("&"); //判断数组大小！
			if(i != -1)
			{
				str1 = String(arr[1]).substring(i);
				
			}
			var str2:String = arr[0] + "expect=3"+str1;
			
			return str2;
		}
		//---------------返回checkXML地址和经过SHA1加密的groupID----------------------------
		private function getCheckURL(dispatchURL:String):Object
		{			
			/*
			例： 利用原来的G3地址  http://g3.letv.com/10/13/13/2101360458.0.flv?format=1&expect=1&b=445" 转换成	
			                      
			    checkSum地址  :   http://webchecksum.letv.com/10/13/13/2101360458.0.xml			
			    groupID       :   /10/13/13/2101360458.0.flv 经SHA1算法转化后生成的字符串
			*/
			var obj:Object=new Object();
			
			var startIndex:Number = dispatchURL.indexOf("/",7);  //从 "http://" 之后开始查找第一个"/"
			var endIndex:Number = dispatchURL.indexOf("?",7);    //查找到 "？" 之前的所有字符串
			
			var path:String = dispatchURL.slice(startIndex,endIndex);
			
			var enc:sha1Encrypt = new sha1Encrypt(true);
			var strSHA1:String = sha1Encrypt.encrypt(path);
			
			obj.group = strSHA1; //生成组ID，是经过strSHA1加密的字符串
			
			var arr:Array = path.split("flv") ;
			obj.check = String("http://webchecksum.letv.com"+arr[0]+"xml");			
			
			return obj;
		}		
		//-------------------------------------------------------------------------		
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}