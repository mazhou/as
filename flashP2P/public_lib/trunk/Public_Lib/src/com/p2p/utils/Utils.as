package com.p2p.utils
{
	public class Utils
	{
		public function Utils()
		{}
		
		public function get40SizeUUID():String
		{
			var uuid:String =  getTime().toString(16)
			while(uuid.length<40){
				uuid += (Math.random()*10000000).toString(16);
			}
			uuid =uuid.substr(0,40);
			return uuid;
		}
		
		private function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
	}
}