package com.p2p_live.loaders
{
	import com.mzStudio.component.load.AssetLoader;
	import com.mzStudio.event.EventExtensions;
	import com.mzStudio.event.EventWithData;
	import com.mzStudio.mzStudioDebug.MZDebugger;
	import com.p2p_live.data.DescTaskList;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.TimerEvent;
	import flash.utils.Timer;

	public class DescLoader extends EventDispatcher
	{
		public function setStartTime(shiftTime:Number):void
		{
			
			if(liveURL==""||liveShiftURL==""||playTime==0){
				throw new Error("no pay value liveURL||liveShiftURL||playTime"+this);
				return;
			}
			this.shiftTime=shiftTime;
			reset();
			loadAsset();
			MZDebugger.trace(this,{"key":"DESC","value":"重新计时"});
		}
		
		protected function reset():void{
			loadType=LIVESHIFT;
			
			if(liveLoadTimer==null){
				liveLoadTimer=new Timer(DESC_FETCH_INTERVAL);
				liveLoadTimer.addEventListener(TimerEvent.TIMER,liveDESCLaod)
			}
			
			loadDepleteTime=0;
			minClipTime=int.MAX_VALUE;
			maxClipTime=0;
		}
		
		protected function liveDESCLaod(evt:TimerEvent=null):void{
			liveLoadTimer.delay=DESC_FETCH_INTERVAL;
			loadAsset();
		}
		/**
		 * 每次加载完调用该方法，判断是那种类型加载
		 * @param countTime 下载后累计的时长
		 */
		protected function loadAsset(countTime:Number=0):void{
//			trace("shiftTime--:"+shiftTime);
			if( loadType==LIVESHIFT){
				getTime=(new Date()).time;
				if(loadDepleteTime==0){
					loadDepleteTime=getTime;
				}else{
					loadDepleteTime=getTime-loadDepleteTime;
					//trace("countTime:"+countTime,"loadDepleteTime:"+loadDepleteTime);
					shiftTime=shiftTime+int((countTime-loadDepleteTime)/1000);
					loadDepleteTime=getTime;
				}
				if(shiftTime>-10){
					loadType=LIVE
				}
			}
			trace("shiftTime2--:"+shiftTime);
			assetLoader=new AssetLoader();
			assetLoader.addEventListener(Event.COMPLETE,completeHandler);
			assetLoader.addEventListener(ErrorEvent.ERROR,errorHandler);
			
			if(loadType==LIVE){
				liveLoadTimer.reset();
				liveLoadTimer.start();
				assetLoader.load(liveURL,DESC_FETCH_TIMEOUT/1000);
				MZDebugger.trace(this,{"key":"DESC","value":"请求的直播地址是"+liveURL});
			}else if( loadType==LIVESHIFT){
				assetLoader.load(liveShiftURL+shiftTime+"&rdm="+Math.random(),DESC_FETCH_TIMEOUT/1000);
				if(liveLoadTimer.running){
					liveLoadTimer.stop();
				}
				MZDebugger.trace(this,{"key":"DESC","value":"请求的时移地址是"+liveShiftURL+shiftTime+"&rdm="+Math.random()})
			}
		}
		private var getTime:Number;
		protected function completeHandler(evt:EventExtensions):void
		{
			
			var dugString:String="";
			try{
				/*MZDebugger.*/trace(/*THIS,{"KEY":"DESC","VALUE":(*/evt.data/*)}*/)
				var xml:XML=new XML(evt.data);
				var elemet:XML;
				var elemetHead:XML;
				var reg:RegExp=/\/(\d+)_(\d+)_(\d+)/;
				var countNum:Number=0;
				var temCreate:Number=0;
				var temDuration:Number=0;
				var min:Number=int.MAX_VALUE;
				
				var headReg:RegExp=/(\d+)\./;
				var temHead:String="";
				var str:String="";
				var tempArr:Array;
				for each(elemetHead  in xml.header){
					if(headReg.test(elemetHead.@name)){
						temHead+=elemetHead.@name.match(headReg)[1]+"~_~";
					}
				}
				var obj:Object=new Object();
				for each(elemet in xml.clip){
					str=elemet.@name;
					if(reg.test(str)){
						if(str.match(reg).length==4){
							temCreate=Number(str.match(reg)[1]);
							temDuration=Number(str.match(reg)[2]);
							if(maxClipTime==0 && minClipTime==int.MAX_VALUE){
								if(temCreate<minClipTime){
									min=minClipTime=temCreate;
								}
								if(temCreate>maxClipTime){
									maxClipTime=temCreate;
								}
								//可以扩展到添加tasklist
								countNum+=temDuration;
								dugString+=elemet.@name+"~_~"+str.match(reg)[1]+"~_~"+str.match(reg)[2]+"~_~"+str.match(reg)[3]+"~_~"+elemet.@checksum+"\n";
								
								//trace("第一次"+minClipTime,maxClipTime,temDuration,countNum);
							}else{
								if(temCreate<min){
									min=temCreate;
								}
								if(temCreate>maxClipTime){
									maxClipTime=temCreate;
									countNum+=temDuration;
									dugString+=elemet.@name+"~_~"+str.match(reg)[1]+"~_~"+str.match(reg)[2]+"~_~"+str.match(reg)[3]+"~_~"+elemet.@checksum+"\n";
									//trace("max第n次"+minClipTime,maxClipTime,temDuration,countNum);
									continue;
								}
								
								if(temCreate<minClipTime){
									minClipTime=temCreate;
									countNum+=temDuration;
									dugString+=elemet.@name+"~_~"+str.match(reg)[1]+"~_~"+str.match(reg)[2]+"~_~"+str.match(reg)[3]+"~_~"+elemet.@checksum+"\n";
									//trace("min第n次"+minClipTime,maxClipTime,temDuration,countNum);
								}
							}
						}
					}
				}
				
				MZDebugger.trace(this,{"key":"DESC","value":"minClipTime:"+minClipTime+" min:"+min+
					" maxClipTime:"+maxClipTime+" temDuration:"+temDuration+" countNum"+countNum})
//				trace("max第n次"+minClipTime,min,maxClipTime,temDuration,countNum);
			}catch(err:Error){
				trace(this+"数据解析错误"+err.getStackTrace());
			}
			//如果请求没有改变，将前30秒
			if(countNum==0){
				//没有新数据
//				countNum=30000;
			}
			
			if(dugString!=""&&temHead!=""){
				DescTaskList.getInstance().addDesc({"header":temHead,"clip":dugString});
				//如果不引入DescTaskList可用事件模式
				//EventWithData.getInstance().doAction(DESCDATA,false,false,{"header":temHead,"clip":dugString});
				MZDebugger.trace(this,{"key":"DESC","value":"Head:"+temHead+"\nclip:"+dugString});
			}
			if(loadType==LIVE){return;};
			//下一次时移时间=(1357875358+59/2+60)-(本地时间+偏差时间）即本次区间（最小的数据+中间值+1分钟）-(本地时间+偏差时间）
			//绝对时间是 int((min*1000+countNum/2+60000)/1000);
			shiftTime=int((min*1000+countNum/2+60000-((new Date).time+serverOffTime))/1000);
			//加载的区间超过30分钟，每隔3分钟启动加载
			if(maxClipTime-playTime>30*60){
				//没有测试
				liveLoadTimer.delay=3*60*1000;
				trace("时间距播放器位置超过了30分钟")
				MZDebugger.trace(this,{"key":"DESC","value":"时间距播放器位置超过了30分钟"});
			}else{
				loadAsset();
			}
		}
		
		private function errorHandler(evt:ErrorEvent):void
		{
			
			//切换cdn
			if(evt.text==AssetLoader.TIME_UP){
			
			}else if(evt.text==AssetLoader.IO_ERROR){
			
			}else if(evt.text==AssetLoader.SECURITY_ERROR){
				
			}
		}
		
		public const DESCDATA:String="DESCDATA";
		
		//请求直播地址
		public var liveURL:String="";
		//请求时移地址
		public var liveShiftURL:String="";
		
		//播放器播放的数据的创建时间单位秒1358218492
		public var playTime:Number=0;
		
		//服务器与本地时间差值,单位豪秒
		public var serverOffTime:Number=0;
		
		//当前加载的类型
		protected var loadType:String=LIVESHIFT;
		
		protected const LIVE:String="live";
		protected const LIVESHIFT:String="liveShift";
		
		//时移每次加载时间
		protected var shiftTime:Number=0;
		
		//加载视频信息起始时间
		protected var minClipTime:Number=int.MAX_VALUE;
		
		//加载视频信息的结束时加
		protected var maxClipTime:Number=0;
		
		//请求耗时
		protected var loadDepleteTime:Number=0;
		
		//资源加载器
		protected var assetLoader:AssetLoader=null;
		
		//直播时加载器
		protected var liveLoadTimer:Timer=null;
		
		//直播间隔
		protected const DESC_FETCH_INTERVAL:uint = 3000; 
		//请求超时
		protected const DESC_FETCH_TIMEOUT:uint = 6000;
		
	}
}