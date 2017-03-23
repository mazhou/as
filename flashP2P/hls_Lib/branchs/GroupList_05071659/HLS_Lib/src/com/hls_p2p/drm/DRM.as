package com.hls_p2p.drm
{
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	public class DRM
	{
		
		public function getKey():String
		{
			var key:String = "";
			return key;
		}
		
		public function submitKey():void
		{
			
		}
		
		public function decryptSream( input:ByteArray ):ByteArray
		{
			var bytes:ByteArray = new ByteArray;
			input.position = 0;
			while (input.bytesAvailable > 187) 
			{
				if(input.readByte() != 0x47)
				{
					continue;
				}
				break;
			}
			var byteArray:ByteArray = new ByteArray();
			byteArray.writeBytes(input,input.position-1);
			return byteArray;
		}
		
		public function close():void
		{
			
		}
		
	}
}