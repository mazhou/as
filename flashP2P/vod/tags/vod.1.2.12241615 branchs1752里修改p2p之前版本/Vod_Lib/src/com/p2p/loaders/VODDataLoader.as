package com.p2p.loaders
{
	/*
	此类负责注册从 http p2p 下载数据对象的注册以及进行相应管理
	*/
	//import com.mzStudio.mzStudioDebug.MZDebugger;
	import com.p2p.data.Chunk;
	import com.p2p.data.Chunks;
	import com.p2p.events.HttpLoaderEvent;
	import com.p2p.events.MetaDataLoaderEvent;
	import com.p2p.events.P2PEvent;
	import com.p2p.events.P2PLoaderEvent;
	import com.p2p.loaders.MetaDataLoader;
	import com.p2p.managers.DataManager;
	
	import flash.events.EventDispatcher;

	public class VODDataLoader extends EventDispatcher
	{
		protected var _videoInfo:Object;//存储flv url,rtmfp地址，组名称
		protected var _httpObject:Object = new Object();//存储多个http请求链路

		public function VODDataLoader(obj:Object)
		{
			_videoInfo = obj;
		}
		//		
		public function httpLoadData(idx:uint, n:int, url:String):Boolean
		{
			//MZDebugger.trace(this,"httpLoadData"+idx);
			var httpLoader:HttpLoader = new HttpLoader(_videoInfo.clip_interval);
			httpLoader.setReady(String(url),uint(_videoInfo.filesize),uint(_videoInfo.chunksnumber));
			_httpObject[idx] = httpLoader;
			_httpObject[idx].addEventListener(HttpLoaderEvent.HTTP_GOT_PROGRESS,httpLoaderProgress);
			_httpObject[idx].addEventListener(HttpLoaderEvent.HTTP_GOT_COMPLETE,httpLoaderComplete);
			_httpObject[idx].addEventListener(P2PEvent.ERROR,loaderError);
			var bRet:Boolean = _httpObject[idx].loadData(idx,n);
			//
			if (!bRet)
			{
				clearHttpLoader(idx);
			}
			//
			return bRet;
			
		}
		/*
		返回正在执行http下载的对象
		*/
		public function gethttpObject():Object
		{
			for each(var i:Object in _httpObject)
			{
				return i;
			}
			   
			return null;
		}
		/*
		返回正在执行http下载的任务数量（链路数量）
		*/
		public function gethttpObjectCount():uint
		{
			var n:uint = 0;
			for(var i:String in _httpObject)
			{
				n++;
			}
			return n;
		}
		public function clear():void
		{
			for(var i:String in _httpObject)
			{
				clearHttpLoader(uint(i));
			}
			//
			_videoInfo = null;
		}
		public function GetHttpChunks(idx:uint):HttpLoader
		{
			return _httpObject[idx];
		}
		public function clearHttpLoader(idx:uint):void
		{
			if(null != _httpObject[idx])
			{
				//trace("_httpObject["+idx+"]"+httpObject[idx])
				_httpObject[idx].removeEventListener(HttpLoaderEvent.HTTP_GOT_PROGRESS,httpLoaderProgress);
				_httpObject[idx].removeEventListener(HttpLoaderEvent.HTTP_GOT_COMPLETE,httpLoaderComplete);
				_httpObject[idx].removeEventListener(P2PEvent.ERROR,loaderError);
				_httpObject[idx].clear();
				delete _httpObject[idx];
				//trace("_httpObject["+idx+"]"+httpObject[idx])
			}
			
		}
		protected function httpLoaderProgress(e:HttpLoaderEvent):void
		{
			dispatchEvent(e as HttpLoaderEvent);
		}
		protected function httpLoaderComplete(e:HttpLoaderEvent):void
		{			
			dispatchEvent(e as HttpLoaderEvent);			
		}
		protected function loaderError(e:P2PEvent):void
		{
			dispatchEvent(e as P2PEvent);
		}
	}
}