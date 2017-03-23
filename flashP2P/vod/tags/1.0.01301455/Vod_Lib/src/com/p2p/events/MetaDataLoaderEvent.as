package com.p2p.events
{
	import flash.events.Event;	
	
	public class MetaDataLoaderEvent extends P2PEvent
	{
		public static const LOAD_METADATA_STATUS:String = "MetaDataLoaderStatus";
		public static const LOAD_METADATA_SUCCESS:String = "MetaDataLoaderEvent.Success";
		public static const LOAD_METADATA_SECURITY_ERROR:String = "MetaDataLoaderEvent.SecurityError";
		public static const LOAD_METADATA_I0_ERROR:String = "MetaDataLoaderEvent.IOError";
		public static const LOAD_METADATA_PARSE_ERROR:String = "MetaDataLoaderEvent.ParseError";
		public static const NEED_CDN_BYTES_SUCCESS:String = "NeedCDNBytesSuccess";
		public function MetaDataLoaderEvent(type:String,info:Object,bubbles:Boolean=false,cancelable:Boolean=false)
		{
			super(type,info,bubbles,cancelable);
		}
		public override function clone():Event
		{
			return new MetaDataLoaderEvent(type,info,bubbles,cancelable);
		}
		public override function toString():String
		{
			return formatToString("MetaDataLoaderEvent","info","type","bubbles","cancelable");
		}
	}
}