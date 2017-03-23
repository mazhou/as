package com.mzStudio.mzStudioDebug
{
	import flash.display.DisplayObject;
	import flash.events.EventDispatcher;

	public class MZDebugger extends EventDispatcher
	{
		public static function getInstance() : MZDebugger {
			if ( instance == null ) instance = new MZDebugger(new SingleTon() );
			return instance as MZDebugger;
		}
		
		public function initialize(address:String = "127.0.0.1"):void
		{
			
			if (!_initialized) {
				_initialized = true;
				
				// Start our engines
//				MZDebuggerCore.getInstance().base;
				MZDebuggerCore.getInstance().initialize();
				MZDebuggerConnection.getInstance().initialize();
				MZDebuggerConnection.getInstance().address = address;
				MZDebuggerConnection.getInstance().connect();
				
				// Start the sampler
				// try{
				// var SampleClass:* = getDefinitionByName("flash.sampler::Sample");
				// if (SampleClass != null) {
				// MonsterDebuggerSampler.initialize();
				// }
				// } catch (e:Error) {}
				
			}
		}
		public static function trace(caller:*, object:*, person:String = "",  color:uint = 0x000000):void
		{
			getInstance().trace(caller,object,person,color);
		}
		
		public static function customTrace(caller:*, key:String,value:*, color:uint = 0xffffff):void
		{
			if(!key||key==""||!value||value=="")return;
			getInstance().customTrace(caller,key,value,color);
		}
		
		public static function rectTrace( object:*):void{
			getInstance().rectTrace(object);
		}
		public function customTrace(caller:*, key:String,value:*,  color:uint = 0xffffff):void
		{
			if (!_initialized) {
				initialize();
			}
//			if (_initialized && _enabled) {
			if (_initialized &&isEnable) {
				MZDebuggerCore.getInstance().customTrace(caller, key,value, color);
			}
		}
		public function rectTrace( object:*):void
		{
			if (!_initialized) {
				initialize();
			}
//			if (_initialized && _enabled) {
			if (_initialized && isEnable) {
				MZDebuggerCore.getInstance().rectTrace(object);
			}
		}
		public function trace(caller:*, object:*, person:String = "",  color:uint = 0x000000):void
		{
			
			if (!_initialized) {
				initialize();
			}
//			if (_initialized && _enabled) {
			if (_initialized && isEnable) {	
				MZDebuggerCore.getInstance().trace(caller, object, person, color);
			}
		}
		/**后续计划记录日志功能*/
		public function log(caller:*, object:*, person:String = "",  color:uint = 0x000000):void
		{	
			if (_initialized) {
				
			}
		}
		/**后续抓图用*/
		public  function snapshot(caller:*, object:DisplayObject, person:String = ""):void
		{
//			if (_initialized && _enabled) {
			if (_initialized && isEnable) {
//				MZDebuggerCore.getInstance().snapshot(caller, object, person, label);
			}
		}
		
//		public function get enabled():Boolean {
//			return _enabled;
//		}
		
//		public function set enabled(value:Boolean):void {
//			_enabled = value;
//		}
		
		public function clear():void
		{
//			if (_initialized && _enabled) {
			if (_initialized && isEnable) {
				MZDebuggerCore.getInstance().clear();
			}
		}
		public function MZDebugger(singleTon:SingleTon=null):void{if(singleTon==null)throw Error("SingleTon,do not call structure method")};
		private static var instance:MZDebugger;
		internal static var isEnable:Boolean =true;
//		private  var _enabled:Boolean = true;
		
		private  var _initialized:Boolean = false;
		public const VERSION:Number = 3.02;
	}
}
class SingleTon{}