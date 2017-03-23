package com.mzStudio.mzStudioDebug
{
	public interface IMZDebug
	{
		function set address(value:String):void;
		function get connected():Boolean;
		function processQueue():void;
		function send(id:String, data:Object, direct:Boolean = false):void;
		function connect():void;
	}
}