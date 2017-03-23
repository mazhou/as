package
{
	public class ClientObject_HLS2 extends Object
	{
		public var client:Object;
		//由P2PNetStream的onMetaData回调函数
		public var metaDataCallBackFun:Function;
		public function ClientObject_HLS2()
		{
			super();
		}
		public function onMetaData(obj:Object):void 
		{
			trace(this,"onMetaData")
			for(var param:String in obj)
			{
				trace(this,param+"<>"+obj[param]);
			}
		}
		public function onCuePoint(obj:Object):void {
			trace(this,"onCuePoint")
		}
		public function onImageData(obj:Object):void {
			trace(this,"onImageData")
		}
		public function onPlayStatus(obj:Object):void 
		{
			trace(this,"onPlayStatus");
			for(var param:String in obj)
			{
				trace(this,param+"<>"+obj[param]);
			}
		}
		public function onSeekPoint(obj:Object):void {
			trace(this,"onSeekPoint")
		}
		public function onTextData(obj:Object):void {
			trace(this,"onTextData")
		}
		public function onXMPData(obj:Object):void {
			trace(this,"onXMPData")
		}
		public function onBWDone(...args):void {
			
		}
	}
}