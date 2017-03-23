package com.p2p_live.loaders
{
	import com.mzStudio.mzStudioDebug.MZDebugger;
	import com.p2p_live.data.Block;
	import com.p2p_live.data.BlockList;
	import com.p2p_live.data.Chunk;
	import com.p2p_live.data.Chunks;
	import com.p2p_live.data.Piece;
	import com.p2p_live.data.TaskList;
	import com.p2p_live.data.TaskListBlock;
	import com.p2p_live.events.*;
	import com.p2p_live.managers.DataManager;
	import com.p2p.utils.CRC32;
	
	import flash.errors.EOFError;
	import flash.errors.IOError;
	import flash.events.*;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.setTimeout;
	
	public class HttpLiveDataLoader extends EventDispatcher 
	{
		private const HTTP_BUFFER_CLIP_NUM:uint = 2; //2表示在播放点之后还允许加载一个block
		private const HTTP_BUFFER_SEEK_CLIP_NUM:int = 3;//3表示在播放点之后还允许加载两个个block
		public static const HTTP_CLIENT_TIMEOUT:String = "time out";
		protected var _descLoader:HttpLiveDescLoader;
		protected var _descSeekLoader:HttpLiveSeekDescLoader;	
				
		protected var _headerDataObj:Object;
		protected var _httpClient:URLStream;
		protected var _httpClientTimer:Timer;
		protected var _downloadingTask:uint;
		//protected var _perDownloadingTask:uint;
		protected var _errorTask:int = -1;
		protected var _errorTaskCounts:int = 0;
		protected var _errorDESCCounts:int = 0;
		protected var _isHttpDownloading:Boolean;
		protected var _dataManager:DataManager;
		protected var _headerDownloaded:Boolean=false;
		protected var _headerSent:Boolean = false;
		/**
		 * _taskList包含两类任务地址，一类是数据片段dat文件地址，
		 * 另一类是包含header地址的数组
		 */		
		protected var _taskList:TaskList;
		/**
		 * _videoInfo保存播放文件desc的路径信息及相关
		 * _videoInfo.url  desc的完整路径，供直播时使用
		 * _videoInfo.path 当发生时移时，保存不发生变化的路径部分
		 * _videoInfo.loadingDate 当发生时移时，保存已经 加载 的dat文件路径 年与日时分钟 部分
		 * _videoInfo.serverCurtime 服务器当前时间
		 * _videoInfo.offsetTime    本地时间与服务器时间的差值
		 * _videoInfo.abTime        时移的绝对时间
		 */		
		protected var _videoInfo:Object;		
		protected var _p2pLoader:P2PLoader;		
		protected var _isSeek:Boolean;			
		
		protected var _CDNIndex:int = 0;     //保存正在使用的cdn数组的索引	
		
		/**
		 * _nextIndex保存预加载desc文件时的索引值，用来在所加载desc文件没有及时更新时重新加载
		*/
		protected var _nextIndex:uint;
			
		protected var _startDelayTime:Number = 0; //时移时，两次预加载之间的时间差值,用来抵消各种导致播放延误造成的误差
				
		protected var _isTrueLiveType:Boolean = true;
		
		protected var _falseLiveTime:Number = 0;
		
		protected var _nextMinuteTime:Number = 0;//时移时，保存预加载下一分钟的相对时间
		
		protected var _newComingMinuteNum:int = 1;//时移时，保存预加载的分钟数，用来限制预加载的范围
		
		protected var _newComingMinuteNumMax:int = 40;//时移时，保存预加载的分钟数，用来限制预加载的范围
		
		protected var _startRunTime:int = 0;          //开始运行的时间(秒),后期将考虑用P2PNetStream中的_startRunTime替代
		
		protected var _perDownloadSize:Number = -1;   //用于保存上一次_httpClient下载的文件字节大小，从而判断是否有数据在下载
		protected var _nowDownloadSize:Number = 0;   //用于保存本次_httpClient下载的文件字节大小，从而判断是否有数据在下载
		/**
		 * 
		 * @param videoInfo    Object,直播需要的参数
		 * @param dataManager    DataManager类的对象
		 * 
		 */		
		public function HttpLiveDataLoader(videoInfo:Object,dataManager:DataManager)
		{		
			init(videoInfo,dataManager);
		}	
		public function start():void
		{	
			//var url:String = getCDNURL();
			
			if(_isTrueLiveType)
			{
				//trace("直播请求地址_falseLiveTime  "+_falseLiveTime);
				//MZDebugger.trace(this,{"key":"INIT","value":"\n HttpLiveDataLoader _isTrueLiveType = "+_isTrueLiveType});
				_descLoader.start(_videoInfo.url[_CDNIndex]);
			}
			else
			{
				//trace("伪直播请求地址_falseLiveTime  "+_falseLiveTime);
				//MZDebugger.trace(this,{"key":"INIT","value":"\n HttpLiveDataLoader _isTrueLiveType = "+_isTrueLiveType});
				var obj:Object = new Object();
				if(_startRunTime != 0)
				{
					obj.abTime = _videoInfo.serverCurtime+(Math.round(getTime()/1000)-_startRunTime)-_falseLiveTime;
				}
				else
				{
					obj.abTime = _videoInfo.serverCurtime-_falseLiveTime;
				}
				
				obj.time = -1*_falseLiveTime;				
				startSeek(obj)
			}
			
		}
		/*protected function getCDNURL():String
		{
			var url:String = _videoInfo.url[_CDNIndex];
			if(!_isTrueLiveType)
			{
				url = _videoInfo["path"][_CDNIndex] + -1*_falseLiveTime;
			}
			return url;
		}*/
		protected function init(videoInfo:Object,dataManager:DataManager):void
		{
			clear();
			
			_videoInfo      = new Object();
			_videoInfo.url  = videoInfo.url;
			_videoInfo.path = videoInfo.path;
			_videoInfo.geo  = videoInfo.geo;
			_videoInfo.groupName     = videoInfo.groupName;
			_videoInfo.serverCurtime = Number(videoInfo.serverCurtime);
			_videoInfo.serverStartTime  = Number(videoInfo.serverStartTime);
			_videoInfo.serverOffsetTime = Number(videoInfo.serverOffsetTime);
			
			_isTrueLiveType = videoInfo.isTrueLiveType;
			
			if(!videoInfo.isTrueLiveType)
			{
				_falseLiveTime = videoInfo.falseLiveTime;
			}
			
			_dataManager = dataManager;			
			// 创建加载dat文件
			_httpClient = new URLStream();
			//_httpClient.addEventListener(Event.OPEN,downloadOpenHandler)
			_httpClient.addEventListener(Event.COMPLETE, downloadCompleteHandler);
			_httpClient.addEventListener(ProgressEvent.PROGRESS, downloadProgressHandler);
			_httpClient.addEventListener(IOErrorEvent.IO_ERROR, downloadIOErrorHandler);			
			_httpClient.addEventListener(SecurityErrorEvent.SECURITY_ERROR, downloadSecurityErrorHandler);			
			
			//计时器 ，加载超时，重新切换cdn
			if(!_httpClientTimer){
				_httpClientTimer=new Timer(3*1000);
				_httpClientTimer.addEventListener(TimerEvent.TIMER,httpClientTimerHandler);
			}
			
			//创建p2p
			_p2pLoader=new P2PLoader(dataManager,_videoInfo.geo);	
			_p2pLoader.addEventListener(P2PLoaderEvent.STATUS,dispatchEvent);	
			_p2pLoader.startLoadP2P(_videoInfo.groupName);
			//直播desc加载
			_descLoader = new HttpLiveDescLoader();				
			_descLoader.addEventListener(HttpLiveEvent.LOAD_DATA_STATUS,httpLiveDescLoad_STATUS);						
			//时移desc加载
			_descSeekLoader = new HttpLiveSeekDescLoader(_videoInfo.path);	
			_descSeekLoader.addEventListener(HttpLiveEvent.LOAD_DATA_STATUS,httpLiveDescLoad_STATUS);
		}
		
		private function httpClientTimerHandler(evt:TimerEvent=null):void
		{
			trace("_nowDownloadSize = "+_nowDownloadSize);
			trace("_downloadingTask = "+_downloadingTask);
			if(_nowDownloadSize != _perDownloadSize)
			{
				_perDownloadSize = _nowDownloadSize;
			}
			else
			{
				dispatchLoadTaskError(HTTP_CLIENT_TIMEOUT);				
			}			
		}
		public function checkData(data:ByteArray,index:uint):Boolean
		{
			var crc32:CRC32 = new CRC32();
			crc32.update(data);
			var obj:Object = _taskList.blockObj;
			if(obj.hasOwnProperty(index))
			{	
				return obj[index].checksum == crc32.getValue();
			}
			return false;
		}
		
		public function removeChunkIndex(curIndex:uint):void
		{
			var obj:Object = _taskList.blockObj;
			for(var task:String in obj)
			{
				if(uint(task) < curIndex)
				{
					delete obj[task];
				}				
			}
		}
		
		public function removeWantData(bl:Block):void
		{
			for(var i:int=0 ; i<bl.pieces.length ; i++)
			{
				if(bl.pieces[i].iLoadType == 2)
				{
					bl.pieces[i].iLoadType = 1;
					//_p2pLoader.removeWantData(String(bl.id+bl.pieces[i].id));
				}				
			}			
		}		
		public function removeHaveData(index:uint):void
		{
			_p2pLoader.removeHaveData(index,index);
		}
		public function nextChunkIndex(curIndex:uint):uint
		{
			var nextIndex:uint = _taskList.getNextTaskID(curIndex);	
			
			if(nextIndex == curIndex)
			{
				//当前已无最新的数据块
				return curIndex;
			}
			
			//判断预加载时移desc
			preloadSeekDesc(nextIndex);
			
			var headerChanged:Boolean = needChangeHeader(nextIndex);
			if(headerChanged)
			{
				return 0;
			}
			return nextIndex;
		}
		
		private function needChangeHeader(nextIndex:uint):Boolean
		{
			for(var i:String in _headerDataObj)
			{
				/**当需要换header且已经下载了该header时*/
				if(nextIndex >= uint(i))
				{
					var info:Object = new Object();
					info.code = HttpLiveEvent.CHANGE_METADATA;
					dispatchEvent(new HttpLiveEvent(HttpLiveEvent.LOAD_DATA_STATUS,info));
					
					info.code = HttpLiveEvent.LOAD_HEADER_SUCCESS;	
					info.startTime = nextIndex;
					info.data = _headerDataObj[i];
					dispatchEvent(new HttpLiveEvent(HttpLiveEvent.LOAD_DATA_STATUS,info));					
					delete _headerDataObj[i];
					
					return true;
				}
			}	
			for(var j:int=0 ; j<_taskList.headerArr.length ; j++)
			{
				/**当需要换header但该header还没有被下载时*/
				if(nextIndex == uint(_taskList.headerArr[j]))
				{
					return true;
				}
			}
			return false;
		}
		
		private function preloadSeekDesc(nextIndex:uint):void
		{
			/** 
			 * 当时移时，分析是否已经是该分钟片段的第一块数据或发生时移读取的第一块数据，
			 * 如果是则开始加载下一分钟的desc文件
			 */			
			if(_isSeek)
			{
				var taskBlock:TaskListBlock = _taskList.blockObj[nextIndex];
				if(taskBlock && taskBlock.needNextMinDesc && _nextIndex != nextIndex)
				{				
					_nextIndex = nextIndex;
					
					if(_newComingMinuteNum>=_newComingMinuteNumMax)
					{						
						if(_videoInfo["loadingDate"] < -60)
						{
							_newComingMinuteNum--;
						    preloadSeekDescTest();
						}						
					}
					//_descSeekLoader.start(_CDNIndex,newComingDescShiftTime());
				}				
			}
		}
		
		public function goonHttp(playID:uint):void
		{
			assignHttpTask();
		}
		
		public function get httpDownloadingTask():uint
		{
			return _downloadingTask;
		}
		
		public function clear():void
		{
			_videoInfo = null;	
			_startRunTime = 0;
			if(_descLoader)
			{
				_descLoader.clear();
				_descLoader.removeEventListener(HttpLiveEvent.LOAD_DATA_STATUS,httpLiveDescLoad_STATUS);
				_descLoader = null;
			}
			if(_descSeekLoader)
			{
				_descSeekLoader.clear();
				_descSeekLoader.removeEventListener(HttpLiveEvent.LOAD_DATA_STATUS,httpLiveDescLoad_STATUS);
				_descSeekLoader = null;	
			}
			if(_httpClient)
			{
				if(_httpClient.connected)
				{
					try
					{
						_httpClient.close();					
					}
					catch(ex:IOError)
					{
						trace("_httpClient close error");
					}	
				}	
				//_httpClient.removeEventListener(Event.OPEN,downloadOpenHandler);
				_httpClient.removeEventListener(Event.COMPLETE,downloadCompleteHandler);	
				_httpClient.removeEventListener(ProgressEvent.PROGRESS, downloadProgressHandler);
				_httpClient.removeEventListener(IOErrorEvent.IO_ERROR,downloadIOErrorHandler);			
				_httpClient.removeEventListener(SecurityErrorEvent.SECURITY_ERROR,downloadSecurityErrorHandler);				
				_httpClient = null;
				_httpClientTimer.stop()
				_httpClientTimer.removeEventListener(TimerEvent.TIMER,httpClientTimerHandler);
				_httpClientTimer=null;
			}
			if(_p2pLoader)
			{
				_p2pLoader.removeEventListener(P2PLoaderEvent.STATUS,dispatchEvent);
				_p2pLoader.clear();
				_p2pLoader = null;
			}
			reset();
		}
		/*
		private function downloadOpenHandler(evt:Event=null):void{
			//停止时间 从新计时
			_httpClientTimer.stop();
		}
		*/
		private function reset():void
		{
			_headerSent = false;			
			_isSeek     = false;
			_nextIndex  = 0;
			_downloadingTask = 0;
			//_perDownloadingTask = 0;
			_errorTask  = -1;
			_errorTaskCounts = 0;
			_errorDESCCounts = 0;
			_startDelayTime  = 0;
			_isHttpDownloading = false;			
			_headerDownloaded  = false;	
			_nextMinuteTime = 0;
			_newComingMinuteNum = 1;
			_perDownloadSize = -1;
			_nowDownloadSize = 0;
						
			if(_descLoader){
				_descLoader.close();
			}			
			
			if(_httpClient && _httpClient.connected)
			{
				try
				{
					_httpClient.close();
				}
				catch(e:ErrorEvent)
				{
					trace("_httpClient close error");
				}				
			}
			
			if(_descSeekLoader)
			{
				_descSeekLoader.close();
			}
			_headerDataObj = new Object();
			if(_taskList)
			{
				_taskList.clear();
			}
			_taskList = new TaskList();
		}
		
		public function startSeek(obj:Object):void
		{
			reset();
			
			if(obj.backToLive)
			{
				//先判断该进度是否可由时移改为直播
				start();
				return;
			}	
			
			seekInit(obj);			
		}
		private function seekInit(obj:Object):void
		{
			_isSeek = true;			
			
			if(_dataManager && _dataManager.blockList)
			{
				_dataManager.blockList.clearNeedData();				
			}
			
			_videoInfo["abTime"] = obj.abTime;
			_videoInfo["loadingDate"] = obj.time;
			
			var url:String = _videoInfo["path"][_CDNIndex] + _videoInfo["loadingDate"];
			
			_startDelayTime = getTime();
			_descSeekLoader.start(_CDNIndex,obj.time);	
			//
			var info:Object = new Object();
			info.code = HttpLiveEvent.CHANGE_METADATA;
			dispatchEvent(new HttpLiveEvent(HttpLiveEvent.LOAD_DATA_STATUS,info));
		}
		private function httpLiveDescLoad_STATUS(event:HttpLiveEvent):void
		{
			switch(event.info.code)
			{
				case HttpLiveEvent.LOAD_DESC_SUCCESS:
					
					MZDebugger.trace(this,{"key":"OTHER","value":"\n LOAD_DESC_SUCCESS "});
					
					var newTaskList:Object = parseDesc(event.info.descXml as XML);
					if(newTaskList != null )
					{	
						if(!_isSeek)
						{
							syncTask(newTaskList);
						}
						else
						{
							syncSeekTask(newTaskList);							
						}
						_errorDESCCounts = 0;
						assignHttpTask();						
					}
					dispatchEvent(event);
					break;
				case HttpLiveEvent.LOAD_DESC_IO_ERROR:					
				case HttpLiveEvent.LOAD_DESC_PARSE_ERROR:					
				case HttpLiveEvent.LOAD_DESC_SECURITY_ERROR:
					if(_errorDESCCounts>=6)
					{
						if(_downloadingTask>0)
						{
							//当xml加载失败时判断dat是否从未加载过，如果未加载过则将失败信息上报
							dispatchEvent(event);
						}						
						_errorDESCCounts=0;
					}
					else
					{
						_errorDESCCounts++;
					}
					/**更换cdn地址*/
					_CDNIndex = nextCDNIndex(_CDNIndex);
					break;
				/*case HttpLiveEvent.LOAD_DESC_NOT_EXIST:
					if(_isSeek)
					{
						trace("--------------HttpLiveEvent.LOAD_DESC_NOT_EXIST---------------");
						_descSeekLoader.start(_CDNIndex);
					}else
					{
						dispatchEvent(event);
					}
					break;*/
			}
		}
		
		private function assignHttpTask():void
		{	
			//is downloading?			
			if(_isHttpDownloading)
			{				
				return;	
			}
			//find the next task
			var nextTaskID:uint = 0;
			var taskListObj:Object = _taskList.blockObj;
			for( var strTaskID:String in taskListObj)
			{				
				var taskID:uint = uint( strTaskID );
				if(taskID >= _downloadingTask 
					&& (nextTaskID == 0 || taskID < nextTaskID) //nextTaskID == 0第一次进入循环；taskID < nextTaskID每次取最小值
					&& (_dataManager.blockList.getBlock(taskID) != null && !_dataManager.blockList.getBlock(taskID).isAllDataAssign))
				{
					nextTaskID = taskID;
				}
			}
			//是否需要下载header		
			var url:String = needLoadHeader(nextTaskID);			
			if(url){
				_headerDownloaded = false;
			}else{
				//是否需要下载clip
				url = needLoadClip(nextTaskID);
			}
			
			if(url){
				//开始计时
				_httpClientTimer.reset();
				_httpClientTimer.start();
				trace("加载数据流地址："+url);
				_httpClient.load(new URLRequest(url));
				_isHttpDownloading = true;	
			}
			
		}
		
		private function needLoadHeader(nextTaskID:uint):String
		{
			var url:String;
			//MZDebugger.trace(this,{"key":"INIT","value":"\n 判断下载 HEADER "});
			for(var i:int=0 ; i<_taskList.headerArr.length ; i++)
			{
				var headerIndex:uint = uint(String(_taskList.headerArr[i]).split(".")[0]);
				
				if((headerIndex <= nextTaskID || nextTaskID == 0) //nextTaskID == 0 是在seek时，遇到了已经下载过的数据时发生的
					&& headerIndex > _downloadingTask)
				{
					_downloadingTask = String(_taskList.headerArr[i]).split(".")[0];
					url = _videoInfo.url[_CDNIndex].replace("desc.xml",String(_taskList.headerArr[i]));
					//MZDebugger.trace(this,{"key":"INIT","value":"\n 开始下载 HEADER "+url});
					return url+"&r="+getTime();			
				}
			}
			return null;
		}
		
		private function needLoadClip(nextTaskID:uint):String
		{
			//no task to assign
			if(nextTaskID == 0 || /*!_p2pLoader.isLeader() &&  */nextTaskID != 0 && limit(nextTaskID))
			{
				return null;
			}	
			//stop p2p downloading------------
			var bl:Block = _dataManager.blockList.getBlock(nextTaskID);
			if(bl != null && !bl.isAllDataAssign)
			{				
				removeWantData(bl);
			}
			
			_downloadingTask = nextTaskID;
			
			var taskBlock:TaskListBlock = _taskList.blockObj[_downloadingTask];
			
			if(bl != null)
			{
				bl.begin = getTime();
				bl.from = "http";
			}
			else
			{				
				var block:Block = new Block();
				block.needDataList = _dataManager.blockList.NeedData;
				block.from  = "http";			
				block.begin = getTime();							
				block.end   = 0;
				block.creatTime = Number(_downloadingTask);
				block.duration = taskBlock.duration;
				block.checksum = taskBlock.checksum;
				block.id       = _downloadingTask;
				block.size     = taskBlock.size;
				_dataManager.blockList.addBlock(block);
			}
			
			var url:String = _videoInfo.url[_CDNIndex].replace("desc.xml",taskBlock.name);
			return url+"&r="+getTime();
		}
		
		private function limit(taskID:uint):Boolean
		{
			var compArr:Array  = [];
			var nextIndex:uint = 0;
			var taskBlockObj:Object = _taskList.blockObj;
			
			for(var i:String in taskBlockObj)
			{
				if(i != "header"){
					compArr.push(uint(i));
				}				
			}
			var arr:Array = compArr.sort();
			var index:int = arr.indexOf(_dataManager.playHead);
			var indexTask:uint = arr.indexOf(taskID);
			//trace(index);
			//trace(indexTask);
			if(!_isSeek)
			{
				if(indexTask == -1 || index == -1 || indexTask - index < HTTP_BUFFER_CLIP_NUM)
				{
					return false;
				}
			}
			else
			{				
				if(indexTask == -1 || index == -1 || indexTask - index < HTTP_BUFFER_SEEK_CLIP_NUM)
				{
					return false;
				}
			}			
						
			return true;			
		}
		
		private function syncSeekTask(newTaskList:Object):void
		{
			trace("时移添加任务");
			if(newTaskList.hasOwnProperty("header"))
			{							
				for(var i:String in newTaskList["header"])
				{
					if(_taskList.headerArr.indexOf(newTaskList["header"][i]) == -1)
					{
						_taskList.headerArr.push(newTaskList["header"][i]);
						trace("添加header："+i+":"+newTaskList["header"][i]);
					}
				}
				
				/*if(!_taskList.hasOwnProperty("header")){
					_taskList["header"] = new Array();	
				}
				for(var i:String in newTaskList["header"]){
					if(_taskList["header"].indexOf(newTaskList["header"][i]) == -1){
						_taskList["header"].push(newTaskList["header"][i]);
					}
				}*/
			}
			
			for(var task:String in newTaskList)
			{
				if(task == "header")
				{
					continue;
				}
				
				if(!_taskList.blockObj[task])
				{						
					/**
					 * 
					此处进行tasklist的任务添加，
					如果是seek之后第一次分配tasklist任务，则进行判断，将包含seek
					时间点的task及之后的task存入tasklist，以此保证当执行完seek时，
					从包含seek的时间点的数据块开始播放。
					
					_videoInfo["abTime"]只有seek后第一次分配任务时才作为判断的条件，
					当第一次分配任务结束时将清除。
					 
					seek之后每分钟的第一块数据块添加needNextMinDesc = true属性
					当读到此任务时用needNextMinDesc=true来判断开始预加载下一分钟的desc文件
					*/
					if(!_videoInfo["abTime"])
					{
						if(newTaskList[task]["needNextMinDesc"])
						{
							syncSeekAddTask(task,newTaskList[task],true);
						}
						else
						{
							syncSeekAddTask(task,newTaskList[task]);
						}						
					}
					else
					{
						trace("时移第一次访问");
						if( uint(task) < _videoInfo.abTime )
						{
							if( _videoInfo.abTime*1000 <= (uint(task)*1000 + uint(newTaskList[task]["duration"])) )
							{
								//syncSeekAddTask(task,newTaskList[task],true);
								syncSeekAddTask(task,newTaskList[task]);
							}
						}
						else
						{
							syncSeekAddTask(task,newTaskList[task]);
						}
					}										
				}
			}
			if(_videoInfo["abTime"])
			{
				delete _videoInfo["abTime"];
			}
			preloadSeekDescTest();
		}
		private function preloadSeekDescTest():void
		{
			/** 
			 * 当时移时，判断当前已经下载了足够的数据维持播放，且预加载的desc数据在允许范围之内（40分钟）才开始预加载下一分钟的desc文件
			 */		
			if( /*!limit(_downloadingTask) && */_newComingMinuteNum <= _newComingMinuteNumMax)
			{
				_descSeekLoader.start(_CDNIndex,newComingDescShiftTime());
			}
						
		}
		/**
		 * 参数
		 * first:是否可以预加载下一分钟片段的标记，此标记目前添加给seek之后的第一块读取的数据和每个分钟片段的第一块数据
		 * 添加到请求地址，如果是时移后的第一块数据则不用添加此标记
		 * */
		private function syncSeekAddTask(task:String,taskObj:Object,needNextMinDesc:Boolean=false):void
		{
			_taskList.blockObj[task] = taskObj;
			if(needNextMinDesc)
			{
				_taskList.blockObj[task]["needNextMinDesc"] = true;
			}
			if(_dataManager.blockList.getBlock(uint(task)) == null
				|| !_dataManager.blockList.getBlock(uint(task)).isAllDataAssign )
			{
				addP2PBlock(uint(task),"p2p");	
			}
		}
		
		private function syncTask(newTaskList:Object):void
		{			
			//start p2p-download the new coming task
			var lastTask:uint = lastTask();
			
			var taskBlockObj:Object = _taskList.blockObj;
			var debugAddData:String="";
			for(var name:String in newTaskList)
			{						
				if(name!="header")
				{
					trace("添加clip：创建时间： "+name+"添加数据前最大的数据："+lastTask)
					if(!taskBlockObj[name] && uint(name) > lastTask)
					{
						taskBlockObj[name] = newTaskList[name];
						addP2PBlock(uint(name),"p2p");
						debugAddData+="添加clip"+name+" ";
						//addP2PChunk(_taskList[name]["name"]);
					}
											
				}else{
					for(var j:int=0 ; j< newTaskList["header"].length ; j++)
					{
						
						if(_taskList.headerArr.indexOf(newTaskList["header"][j]) == -1)
						{
							_taskList.headerArr.push(newTaskList["header"][j]);
							debugAddData+="添加header"+":"+newTaskList["header"][j]+" ";
						}
						
						/*if(!_taskList["header"]){
							_taskList["header"] = new Array();
						}
						if(_taskList["header"].indexOf(newTaskList["header"][j]) == -1){
							_taskList["header"].push(newTaskList["header"][j]);
						}*/
					}					
				}
				//MZDebugger.trace(this,{"key":"DESC","value":debugAddData})
				trace("debugAddData:\n"+debugAddData);
			}
		}
		//review
		public function addP2PBlock(index:uint,from:String):void
		{
			var taskBlock:TaskListBlock = _taskList.blockObj[index];
			if(taskBlock)
			{
				trace("blockList分配空间："+index+" from:"+from);
				var bl:Block = new Block();	
				bl.needDataList = _dataManager.blockList.NeedData;
				bl.from  = from;
				bl.id    = index;
				bl.size	 = taskBlock.size;
				bl.begin = getTime();							
				bl.end   = 0;
				bl.duration = taskBlock.duration;
				bl.checksum = taskBlock.checksum;
				bl.creatTime = Number(index);			
				
				_dataManager.blockList.addBlock(bl);
			}
			/*if(_dataManager.isJoinNetGroup)
			{
				_p2pLoader.addWantData(index,index);
			}*/
		}
		
		private function lastTask():uint
		{
			var lastTask:uint = 0;
			var taskBlockObj:Object = _taskList.blockObj;
			for(var name:String in taskBlockObj)
			{
				if(uint(name) > lastTask)
				{
					lastTask = uint(name);
				}		
			}
			return lastTask;
		}
		
		private function firstTask():uint
		{
			var firstTask:uint = uint.MAX_VALUE;
			var taskBlockObj:Object = _taskList.blockObj;
			for(var name:String in taskBlockObj)
			{
				if(uint(name) < firstTask)
				{
					firstTask = uint(name);
				}		
			}
			return firstTask;
		}
		
		private function parseDesc(descXml:XML):Object
		{
			if(descXml.elements("*").length() <= 0)
			{
				return null;
			}
			try
			{			
				var taskListObj:Object = new Object();
				var theFirst:uint = 0;
				var debugAddData:String="";
				for each (var clipObj:XML in descXml.clip)
				{					
					var name:String = clipObj.@name;	
					var nameArray:Array = name.split("/");
					if(nameArray.length <= 0)
					{
						continue;
					}
					nameArray = String(nameArray[nameArray.length - 1]).split(".");
					nameArray = String(nameArray[0]).split("_");
					if(nameArray.length <= 0)
					{
						continue;
					}
					var clip:TaskListBlock = new TaskListBlock();
					clip.name     = name;
					clip.checksum = uint(clipObj.@checksum);
					clip.duration = Number(String(nameArray[1]).split("_"));
					clip.size     = Number(String(nameArray[2]).split("_"));
					taskListObj[uint(nameArray[0])] = clip;
					debugAddData+="name"+clip.name+" checksum:"+clipObj.@checksum+" duration:"+clip.duration+" size:"+clip.size+"\n";
					//					
					if(_isSeek)
					{
						/*当seek时，选出本次下载分钟片段内的第一个数据块*/
						if(theFirst == 0 || theFirst > uint(nameArray[0]))
						{
							theFirst = uint(nameArray[0]);
						}
					}
				}
				
				if(_isSeek && theFirst != 0 && taskListObj[theFirst])
				{
					taskListObj[theFirst].needNextMinDesc = true;
				}
				//
				var header:Array = new Array();
				var i:int = 0;
				while(descXml.header[i])
				{
					header[i] = String(descXml.header[i].@name);
					i++;
				}
				taskListObj["header"] = header;
				//
				//MZDebugger.trace(this,{"key":"DESC","value":debugAddData})
				//trace("debugAddData2:\n"+debugAddData);
				return taskListObj;
			}
			catch(ex:Error)
			{
				//TODO...
				var info:Object = new Object();
				info.code = HttpLiveEvent.LOAD_DESC_PARSE_ERROR;
				var event:HttpLiveEvent = new HttpLiveEvent(HttpLiveEvent.LOAD_DATA_STATUS,info);
				dispatchEvent(event);				
			}
			return null;
		}
		private function downloadProgressHandler(e:ProgressEvent):void
		{
			_nowDownloadSize = e.bytesLoaded;
		}
		private function downloadCompleteHandler(event:Event):void 
		{	
			var info:Object = new Object();
			info.from = "http";
			_isHttpDownloading = false;
			var e:HttpLiveEvent = new HttpLiveEvent(HttpLiveEvent.LOAD_DATA_STATUS,info);			
			//is header
			if(!_headerDownloaded && !_headerDataObj.hasOwnProperty(_downloadingTask))
			{
				_headerDownloaded = true;		
				var data:ByteArray = new ByteArray();
				_httpClient.readBytes(data);
				//MZDebugger.trace(this,{"key":"INIT","value":"\n 头文件成功下载 ！！！_headerSent = "+_headerSent});
				if(!_headerSent)
				{
					info.code = HttpLiveEvent.LOAD_HEADER_SUCCESS;
					info.data = data;					
									
					dispatchEvent(e);
					_headerSent = true;	
					//MZDebugger.trace(this,{"key":"INIT","value":"\n 发送头文件 _headerSent = "+_headerSent});
				}
				else
				{
					_headerDataObj[_downloadingTask] = data;
				}
				if(_startRunTime == 0)
				{
					_startRunTime = Math.round(getTime()/1000);
				}
				assignHttpTask();
				return;
			}
			
			//is clip	
			if(_httpClient.bytesAvailable>0)
			{
				_errorTask = -1;
				_errorTaskCounts = 0;
				info.size = _httpClient.bytesAvailable;
				info.data = new ByteArray();
				_httpClient.readBytes(info.data);			
				info.code = HttpLiveEvent.LOAD_CLIP_SUCCESS;
				info.id = _downloadingTask;
				dispatchEvent(e);
				//assign a new http task	
				
				_httpClientTimer.reset();
				
				assignHttpTask();
			}
			else
			{
				downloadIOErrorHandler();
			}
			
		}
		
		private function downloadIOErrorHandler(event:IOErrorEvent=null):void
		{
			if(!_headerDownloaded)
			{
				dispatchLoadTaskError(HttpLiveEvent.LOAD_HEADER_IO_ERROR);
			}else
			{
				dispatchLoadTaskError(HttpLiveEvent.LOAD_CLIP_IO_ERROR);
			}
		}
		
		private function downloadSecurityErrorHandler(event:SecurityErrorEvent):void
		{
			if(!_headerDownloaded)
			{
				dispatchLoadTaskError(HttpLiveEvent.LOAD_HEADER_SECURITY_ERROR);
			}else
			{
				dispatchLoadTaskError(HttpLiveEvent.LOAD_CLIP_SECURITY_ERROR);
			}
		}
		private function dispatchLoadTaskError(err:String):void
		{   
			_errorTaskCounts++;
			if(err != HTTP_CLIENT_TIMEOUT)
			{
				_isHttpDownloading = false;	
			}			
			if(_errorTask == _downloadingTask )
			{						
				if(_errorTaskCounts >= 3*_videoInfo.url.length)
				{					
					var info:Object = new Object();			
					info.code = err;
					info.id   = _downloadingTask;
					info.allCDNFailed = 1;
					info.from = "http";
					var e:HttpLiveEvent = new HttpLiveEvent(HttpLiveEvent.LOAD_DATA_STATUS,info);
					dispatchEvent(e);	
					
					_errorTaskCounts = 0;
					_errorTask = -1;					
				}				
			}
			else
			{
				_errorTask = _downloadingTask;
			}
			/**更换cdn地址*/
			_CDNIndex = nextCDNIndex(_CDNIndex);
			
			assignHttpTask();
		}
		
		private function nextCDNIndex(index:int):int
		{			
			if(_videoInfo && _videoInfo.url && _videoInfo.url as Array)
			{
				index++;
				if(index >= _videoInfo.url.length)
				{
					index = 0;
				}
				return index;
			}
			return index;
		}
		/*
		private function newComingDesc(offset:Boolean=false):String
		{	
			trace("_startDelayTime1 = "+_startDelayTime);
			var shiftTime:Number = 60 - Math.round((getTime() - _startDelayTime) / 1000);
			_videoInfo["loadingDate"] = _videoInfo["loadingDate"] + shiftTime;
			var url:String = _videoInfo.path[_CDNIndex] + _videoInfo["loadingDate"];
			_startDelayTime = getTime();
			return url;
		}
		*/
		
		/**
		 * 加载下一分钟的xml数据，当时移的时间与服务器当前时间之差小于10秒时，_videoInfo["loadingDate"]=-10 
		 * @return 
		 * 
		 */		
		private function newComingDescShiftTime():Number
		{				
			var nextMinuteTime:Number = 60 - Math.round((getTime() - _startDelayTime) / 1000);
			_videoInfo["loadingDate"] = _videoInfo["loadingDate"] + nextMinuteTime;	
			
			if(_videoInfo["loadingDate"] < -10)
			{				
				_newComingMinuteNum++ ;
			}
			else
			{
				_videoInfo["loadingDate"] = -10;
			}
			_startDelayTime = getTime();
			return _videoInfo["loadingDate"];
			
		}
		
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		} 
	}
}