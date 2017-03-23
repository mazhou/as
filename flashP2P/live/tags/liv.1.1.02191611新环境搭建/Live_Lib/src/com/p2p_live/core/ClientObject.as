package com.p2p_live.core{
	import com.mzStudio.mzStudioDebug.MZDebugger;

	public class ClientObject extends Object
	{
		//由播放器定义的NetStream的回调对象
		public var client:Object;
		//由P2PNetStream的onMetaData回调函数
		public var metaDataCallBackFun:Function;
		public function ClientObject()
		{
			super();
		}
		public function onMetaData(obj:Object):void 
		{
			var debugMsg:String="";
			for(var i:* in obj){
				debugMsg+=i+":"+obj[i]+"\n"
			}
			MZDebugger.trace(this,{"key":"VEDIO","value":debugMsg});
			trace("解析后onMetaData:"+debugMsg+":"+(new Date).time)
			if(metaDataCallBackFun!=null)
			{
				metaDataCallBackFun.call(null,obj);
			}
			if(client)
			{
				try
				{
					client.onMetaData.call(null,obj);
				}
				catch(e:Error)
				{
					throw e;
				}
			}
		}
		public function onCuePoint(obj:Object):void {
			if(client)
			{
				try
				{
					client.onCuePoint.call(null,obj);
				}
				catch(e:Error)
				{
					throw e;
				}
			}
		}
		public function onImageData(obj:Object):void {
			if(client)
			{
				try
				{
					client.onImageData.call(null,obj);
				}
				catch(e:Error)
				{
					throw e;
				}
			}
		}
		public function onPlayStatus(obj:Object):void 
		{
			if(client)
			{
				try
				{
					client.onPlayStatus.call(null,obj);
				}
				catch(e:Error)
				{
					throw e;
				}
			}
		}
		public function onSeekPoint(obj:Object):void {
			if(client)
			{
				try
				{
					client.onSeekPoint.call(null,obj);
				}
				catch(e:Error)
				{
					throw e;
				}
			}
		}
		public function onTextData(obj:Object):void {
			if(client)
			{
				try
				{
					client.onTextData.call(null,obj);
				}
				catch(e:Error)
				{
					throw e;
				}
			}
		}
		public function onXMPData(obj:Object):void {
			if(client)
			{
				try
				{
					client.onXMPData.call(null,obj);
				}
				catch(e:Error)
				{
					throw e;
				}
			}
		}
		public function onBWDone(...args):void {
			if(client)
			{
				try
				{
					client.onBWDone.call(null,args);
				}
				catch(e:Error)
				{
					throw e;
				}
			}
		}
	}
}