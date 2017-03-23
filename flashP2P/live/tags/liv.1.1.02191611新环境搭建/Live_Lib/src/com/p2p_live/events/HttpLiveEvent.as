package com.p2p_live.events
{
	import flash.events.Event;

	public class HttpLiveEvent extends P2PEvent
	{
		public static const LOAD_DATA_STATUS:String = "HttpLiveStatus";
		
		public static const LOAD_DESC_SUCCESS:String = "HttpLiveEvent.Desc.Success";
		public static const LOAD_DESC_IO_ERROR:String = "HttpLiveEvent.Desc.IOError";
		public static const LOAD_DESC_NOT_EXIST:String = "HttpLiveEvent.Desc.NotExist";
		public static const LOAD_DESC_PARSE_ERROR:String = "HttpLiveEvent.Desc.ParseError";
		public static const LOAD_DESC_SECURITY_ERROR:String = "HttpLiveEvent.Desc.SecurityError";
		
		public static const LOAD_HEADER_SUCCESS:String = "HttpLiveEvent.Header.Success";
		public static const LOAD_HEADER_IO_ERROR:String = "HttpLiveEvent.Header.IOError";
		public static const LOAD_HEADER_SECURITY_ERROR:String = "HttpLiveEvent.Header.SecurityError";
		
		public static const LOAD_CLIP_SUCCESS:String = "HttpLiveEvent.Clip.Success";
		public static const LOAD_CLIP_IO_ERROR:String = "HttpLiveEvent.Clip.IOError";
		public static const LOAD_CLIP_SECURITY_ERROR:String = "HttpLiveEvent.Clip.SecurityError";
		
		public static const CHANGE_METADATA:String = "ChangeMetaData";
		
		public function HttpLiveEvent(type:String,info:Object,bubbles:Boolean=false,cancelable:Boolean=false)
		{
			super(type,info,bubbles,cancelable);
		}
		public override function clone():Event
		{
			return new HttpLiveEvent(type,info,bubbles,cancelable);
		}
		public override function toString():String
		{
			return formatToString("HttpLiveEvent","info","type","bubbles","cancelable");
		}
	}
}