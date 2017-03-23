package com.p2p.dataManager
{
	import com.p2p.data.vo.PlayData;
	
	import flash.utils.ByteArray;

	public class VodDataManager /*implements IDispatcher*/
	{
		public var isDebug:Boolean=true;
		
		public function VodDataManager()
		{
		}
		public function  readByte():PlayData{return null}
		public function  bytesLoaded():uint{return 0;}
		public function  bytesTotal():uint{return 0;}
		public function minDESCTimestamp():Number{
			return (new Date).time;
		}
	}
}