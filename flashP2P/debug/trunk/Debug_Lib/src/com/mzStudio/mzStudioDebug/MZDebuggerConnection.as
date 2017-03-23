
package com.mzStudio.mzStudioDebug
{
	
	internal class MZDebuggerConnection
	{
		
		internal static function getInstance() : MZDebuggerConnection {
			if ( instance == null ) instance = new MZDebuggerConnection(new SingleTon() );
			return instance as MZDebuggerConnection;
		}
		
		public function initialize():void
		{
		}
		
		public  function set address(value:String):void {
			connector.address = value;
		}
		
		public  function get connected():Boolean {
			return connector.connected;
		}
		
		
		public  function processQueue():void {
			connector.processQueue();
		}
		
		public  function send(id:String, data:Object, direct:Boolean = false):void {
			connector.send(id, data, direct);
		}
		
		public function connect():void {
			connector.connect();
		}
		public function MZDebuggerConnection(singleTon:SingleTon=null){if(singleTon==null)throw Error("SingleTon,do not call structure method");};
		private static var instance:MZDebuggerConnection;
		// Connector class
		private  var connector:IMZDebug=new MZDebuggerConnectionDefault;
	}
}
class SingleTon{}