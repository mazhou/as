package com.mzStudio.mzStudioDebug
{
	import flash.utils.ByteArray;
	internal class MZDebuggerData
	{
		private var _id:String;
		private var _data:Object;
		public function MZDebuggerData(id:String, data:Object)
		{
			_id = id;
			_data = data;
		}
		public function get id():String{
			return _id;
		}
		public function get data():Object {
			return _data;
		}
		public function get bytes():ByteArray
		{
			var bytesId:ByteArray = new ByteArray();
			var bytesData:ByteArray = new ByteArray();
			
			bytesId.writeObject(_id);
			bytesData.writeObject(_data);
			
			var item:ByteArray = new ByteArray();
			item.writeUnsignedInt(bytesId.length);
			item.writeBytes(bytesId);
			item.writeUnsignedInt(bytesData.length);
			item.writeBytes(bytesData);
			item.position = 0;
			
			bytesId = null;
			bytesData = null;
			
			return item;
		}
		public function set bytes(value:ByteArray):void
		{
			var bytesId:ByteArray = new ByteArray();
			var bytesData:ByteArray = new ByteArray();
			
			try {
				value.readBytes(bytesId, 0, value.readUnsignedInt());
				value.readBytes(bytesData, 0, value.readUnsignedInt());
				
				_id = bytesId.readObject() as String;
				_data = bytesData.readObject() as Object;
			} catch (e:Error) {
				_id = null;
				_data = null;
			}
			
			bytesId = null;
			bytesData = null;
		}
		public static function read(bytes:ByteArray):MZDebuggerData
		{
			var item:MZDebuggerData = new MZDebuggerData(null, null);
			item.bytes = bytes;
			return item;
		}
	}
}