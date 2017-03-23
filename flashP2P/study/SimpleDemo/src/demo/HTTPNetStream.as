package demo
{
	import at.matthew.httpstreaming.*;
	
	import flash.events.TimerEvent;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	import flash.utils.Timer;
	
	import net.httpstreaming.flv.FLVHeader;
	import net.httpstreaming.flv.FLVParser;
	import net.httpstreaming.flv.FLVTag;
	import net.httpstreaming.flv.FLVTagAudio;
	import net.httpstreaming.flv.FLVTagScriptDataMode;
	import net.httpstreaming.flv.FLVTagScriptDataObject;
	import net.httpstreaming.flv.FLVTagVideo;

	public class HTTPNetStream extends NetStream
	{
		private var _mainTimer:Timer = null;
		private var _state:String = "";
		public static const END_SEQUENCE:String = "endSequence";
		public static const RESET_BEGIN:String = "resetBegin";
		public static const RESET_SEEK:String = "resetSeek";
		private var _fileHandler:HTTPStreamingMP2TSFileHandler = null;
		private var _flvParser:FLVParser = null;
		private var _flvParserProcessed:uint;
		private var b0:ByteArray;
		private var b1:ByteArray; //= new TS_1() as ByteArray;
		private var b2:ByteArray; //= new TS_2() as ByteArray;
		private var streamId:int=0;
		public function HTTPNetStream(connection:NetConnection, peerID:String="connectToFMS")
		{
			super(connection, peerID);
			_mainTimer = new Timer(25); 
			_mainTimer.addEventListener(TimerEvent.TIMER, onMainTimer);	
			
			
			b0 = new TS_0() as ByteArray;
			b1 = new TS_1() as ByteArray;
			b2 = new TS_2() as ByteArray;
		}
		override public function seek(offset:Number):void
		{
			streamId=Math.floor(3*Math.random());
			trace()
		}
		override public function play(...args):void 
		{
			super.play(null);
			var header:FLVHeader = new FLVHeader();
			var headerBytes:ByteArray = new ByteArray();
			header.write(headerBytes);
			this["appendBytes"](headerBytes);
			
			notifyTotalDuration(800);
			
			_fileHandler = new HTTPStreamingMP2TSFileHandler();
			
			resetSeekHandler();
			setState("play");
			_mainTimer.start();
			
		}
		private var byte1:ByteArray=null;
		private function getBytesFromTS():IDataInput
		{
			if(byte1==null)
			{
				byte1 = new ByteArray();
				b0.readBytes(byte1);
				byte1.position=0;
			}
			return byte1;
		}
		private function addData():void
		{
			var bytes:ByteArray = null;
			var input:IDataInput = null;
			var keepProcessing:Boolean = true;
			
			input =  getBytesFromTS();
			if (input != null && input.bytesAvailable>0)
			{
				this._fileHandler.beginProcessFile();
				bytes=_fileHandler.processFileSegment(input);
				if(bytes!=null /*&& bytes.bytesAvailable>0*/)
				{
					if(bytes.length>0)
					{
						trace(this,"bytes0:"+bytes[0])
					}
					processAndAppend(bytes);
				}
			}
			if(this.bufferLength>3)
			{
				keepProcessing=false;
			}
		}
		private function processAndAppend(inBytes:ByteArray):uint
		{
			var bytes:ByteArray;
			var processed:uint = 0;
			inBytes.position = 0;	
			_flvParser.parse(inBytes, true, onTag);	
			bytes = new ByteArray();
			_flvParser.flush(bytes);
			_flvParser = null;	
			_flvParser = new FLVParser(false);
			
			if (true)
			{
//				if(bytes){
//					var str:String="";
//					for(var i:int=0;i<bytes.length;i++)
//					{
//						if(i>15){break;}
//						str+=bytes[i].toString(16)+" ";
//					}
//					trace(this,"bytes>"+str);
//				}
				attemptAppendBytes(bytes);
			}
			
			return processed;
		}
		private function onTag(tag:FLVTag):Boolean
		{
			var bytes:ByteArray = new ByteArray();
			tag.write(bytes);
			_flvParserProcessed += bytes.length;
			attemptAppendBytes(bytes);
			return true;
		}
		private function doConsumeAllScriptDataTags(timestamp:uint):void
		{
			_flvParserProcessed += consumeAllScriptDataTags(timestamp);
		}
		private function consumeAllScriptDataTags(timestamp:Number):int
		{
			trace(this,"consumeAllScriptDataTags:"+timestamp);
			var processed:int = 0;
			var index:int = 0;
			var bytes:ByteArray = null;
			var tag:FLVTagScriptDataObject = null;
			return processed;
		}
		private function attemptAppendBytes(bytes:ByteArray):void
		{
			this["appendBytes"](bytes);
		}
		private function setState(value:String):void
		{
			_state = value;
		}
		private function notifyTotalDuration(duration:Number):void
		{
			var sdo:FLVTagScriptDataObject = new FLVTagScriptDataObject();
			var metaInfo:Object = new Object();
			metaInfo.duration = duration;
			metaInfo.abc = "123";
			sdo.objects = ["onMetaData", metaInfo];
			if (client)
			{
				var methodName:* = sdo.objects[0];
				var methodParameters:* = sdo.objects[1];
				if (client.hasOwnProperty(methodName))
				{
					client[methodName](methodParameters);
				}
			}
		}
		
		private function onMainTimer(timerEvent:TimerEvent):void
		{
			switch(_state)
			{
				case "play":
					addData();
					break;
			}
		}
		
		private function resetSeekHandler():void
		{
			_flvParser = null;
			_flvParser = new FLVParser(false);
			b0.position=0;
			b1.position=0;
			b2.position=0;
			this._fileHandler.beginProcessFile();
			this["appendBytesAction"](RESET_SEEK);
		}
		
		private function resetBeginHandler():void
		{
			this["appendBytesAction"](RESET_BEGIN);
		}
		
		private function resetEndHandler():void
		{
			this["appendBytesAction"](END_SEQUENCE);
		}
		
		[Embed("0.ts",mimeType="application/octet-stream")]
		private const TS_0:Class;
		[Embed("1.ts",mimeType="application/octet-stream")]
		private const TS_1:Class;
		[Embed("2.ts",mimeType="application/octet-stream")]
		private const TS_2:Class;
		
	}
}