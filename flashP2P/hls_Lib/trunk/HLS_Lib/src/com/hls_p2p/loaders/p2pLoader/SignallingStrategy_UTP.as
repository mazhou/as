package com.hls_p2p.loaders.p2pLoader
{
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.InitData;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.DataManager;
	import com.p2p.utils.console;
	import com.p2p.utils.console;
	import com.hls_p2p.statistics.Statistic;
	
	import flash.events.AsyncErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.NetStream;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.Timer;
	public class SignallingStrategy_UTP
	{
		public var isDebug:Boolean = true;
		private var handshakeIsOk:Boolean = false;
		public var utp_pipe:UTP_Pipe;
		public var XNetStream:NetStream = null;
		protected var dataManager:DataManager = null;
		
		protected var p2pLoader:UTP_Loader		= null;
		
		protected var remoteBirthTime:Number 			= -1;	
		//对方的播放类型，vod live
		protected var remotePlayType:String  			= "";
		protected var remoteClientType:String 			= "UTP";
		
		protected var remotePNList:Array;
		protected var remoteTNList:Array;
		protected var remoteCDNTaskPieceList:Array;
		
		public var requestArr:Array 					= new Array;
		protected var beginTime:Number 					= 0;
		
		private var _peerHartBeatTimer:Timer;
		
		public var isReceivedData:Boolean = false;
		
		private var _isRemoteWantPeerList:Boolean = false;
		
		private var _isThisWantPeerList:Boolean = false;
		
		public function get remoteID():String
		{
			return utp_pipe.remoteID;
		}
		
		public function get groupID():String
		{
			return utp_pipe.groupID;
		}
		
		public function get canRecieved():Boolean
		{
			return utp_pipe.canRecieved;
		}
		
		public function set canRecieved(value:Boolean):void
		{
			utp_pipe.canRecieved = value;
		}
		
		public function get canSend():Boolean
		{
			return utp_pipe.canSend;
		}
		
		public function set canSend(value:Boolean):void
		{
			utp_pipe.canSend = value;
		}
		
		public function resetHartBeatTimer(nStep:int):void
		{			
			if (_peerHartBeatTimer && !_peerHartBeatTimer.running)
			{
				_peerHartBeatTimer.delay =nStep;//TEST//3*1000 //
				_peerHartBeatTimer.repeatCount = 1;
				_peerHartBeatTimer.reset();
				_peerHartBeatTimer.start();
			}
		}
		
		public function SignallingStrategy_UTP(utp_pipe:UTP_Pipe,p2pLoader:UTP_Loader,dataManager:DataManager)
		{
			switch( utp_pipe.termid )
			{
				case "0":
					this.remoteClientType = ""
					break;
				case "1":
					this.remoteClientType = "PC"
					break;
				case "2":
					this.remoteClientType = "MP"
					break;
				case "3":
					this.remoteClientType = "BOX"
					break;
				case "4":
					this.remoteClientType = "TV"
					break;
			}
			
			
			this.utp_pipe				= utp_pipe;
			this.p2pLoader	 			= p2pLoader;
			this.dataManager 			= dataManager;
			
			utp_pipe.dataSuccess		= dataSuccess;
			utp_pipe.connectSuccess 	= sendHandshake;
			beginTime = getTime();
			_peerHartBeatTimer = new Timer(3*1000, 1);
			_peerHartBeatTimer.addEventListener(TimerEvent.TIMER, peerHartBeatTimer );
		}
		
		public function isActivePeer():Boolean
		{
			if( getTime()-beginTime > 9*1000 )
			{
				return false;
			}
			return true;
		}
		
		private function peerHartBeatTimer(event:* = null):void
		{
			HartBeatTimer(true);
		}
		
		private var peerGap:Number = 0;
		private function HartBeatTimer(isHeart:Boolean=false):void
		{	
			if (isHeart && (getTime() - peerGap < 1000))
			{
				return;
			}
			
			if (utp_pipe.canSend)
			{
				sendHartBeat();
				peerGap = getTime();
			}
		}
		
		public function isDead():Boolean
		{
			return (Math.floor((new Date()).time) - beginTime) > (3*60*1000);
		}
		
		private function sendHartBeat():void
		{
			//send bitmap
			if(handshakeIsOk)
			{
				var temp_byteArray:ByteArray = new ByteArray();
				temp_byteArray.writeByte(3);//Bitfield type:sequential_rw_range_bitfield = 3
				temp_byteArray.writeUnsignedInt(0);//字节数
				console.log(this,"send require bitmap:code:21");
				utp_pipe.sendData(21,temp_byteArray);
			}
		}
		
		public function sendHandshake():void
		{
			//数据
			var bodyObj:Object = {	
				"peerID":LiveVodConfig.uuid,//this.utp_pipe.remoteID,//"1b7edd42d7532ea9fb74bf037c43045c1342fdb0",
				"resourceID":LiveVodConfig.resourceID,
				"handshakeType":1,
				"peerVersion":671,//目前写死，随着utp部门升级而更改
				"IP":0,
				"Port":0,
				"appID":0,
				"protocolVersion":5,//目前写死，随着utp部门升级而更改
				"magicValue":4660,//0x1234
				"protocolFlags":0,
				"upLoadFlags":0,
				"timestamp":244374314,//(new Date()).time,
				"reserved2":0,
				"reserved3":0,
				"reserved4":0
			}
			//结构体
			var handInfoMap:Array = [	
				{"name":"peerID"},
				{"name":"resourceID"},
				{"name":"timestamp"},
				{"name":"peerVersion"},
				{"name":"magicValue"},
				{"name":"protocolVersion"},
				{"name":"protocolFlags"},
				{"name":"handshakeType"},
				{"name":"IP"},
				{"name":"Port"},
				{"name":"upLoadFlags"},
				{"name":"appID"},
				{"name":"reserved2"},
				{"name":"reserved3"},
				{"name":"reserved4"}];
			
			var temp_byteArray:ByteArray = new ByteArray();
			temp_byteArray.endian = Endian.BIG_ENDIAN;
			for(var i:int=0 ; i<handInfoMap.length ; i++)
			{				
				
				switch(handInfoMap[i].name)
				{
					case "peerID":
					case "resourceID":
						for (var j:Number = 0; j < bodyObj[handInfoMap[i].name].length / 2; j++)
						{
							var thisNumber:int = parseInt(bodyObj[handInfoMap[i].name].substr(j * 2, 2), 16);
							temp_byteArray.writeByte(thisNumber);
						}
						break;
					case "timestamp":
						temp_byteArray.writeUnsignedInt(bodyObj[handInfoMap[i].name]);
						break;
					case "peerVersion":
						temp_byteArray.writeShort(bodyObj[handInfoMap[i].name]);
						break;
					case "magicValue":
						temp_byteArray.writeShort(bodyObj[handInfoMap[i].name]);
						break;
					case "protocolVersion":
						temp_byteArray.writeShort(bodyObj[handInfoMap[i].name]);
						break;
					case "protocolFlags":
						temp_byteArray.writeShort(bodyObj[handInfoMap[i].name]);
						break;
					case "handshakeType":
						temp_byteArray.writeByte(bodyObj[handInfoMap[i].name]);
						break;
					case "IP":
						temp_byteArray.writeUnsignedInt(bodyObj[handInfoMap[i].name]);
						break;
					case "Port":
						temp_byteArray.writeShort(bodyObj[handInfoMap[i].name]);
						break;
					case "upLoadFlags":
					case "appID":
					case "reserved2":
					case "reserved3":
					case "reserved4":
						if(bodyObj.protocolVersion >= 2)
						{
							temp_byteArray.writeUnsignedInt(bodyObj[handInfoMap[i].name]);
						}
						break;
				}		
			}
			console.log(this,"sendData shake code:20");
			utp_pipe.sendData(20,temp_byteArray);
		}
		
		public function dataSuccess(receive_byteArray:ByteArray):void
		{
			beginTime = getTime();
			var type:uint = receive_byteArray.readByte();
			console.log(this,"recieve type:"+type);
			switch (type)
			{
				case 20:
					analysisHandInfo(receive_byteArray);//握手
					break;
				case 21:
					analysisBitField(receive_byteArray);//bitmap
					break;
				case 22:
					analysisRequest(receive_byteArray);//require data
					break;
				case 23:
					analysisReceiveData(receive_byteArray);//data
					break;
				default:
					trace(type)
					break
			}
		}
		private function analysisHandInfo(receive_byteArray:ByteArray):void
		{
//			var obj:Object = new Object();
//			obj.peerID = toHexString(receive_byteArray,20);
//			obj.resourceID = toHexString(receive_byteArray,20);
//			obj.timestamp = receive_byteArray.readUnsignedInt();
//			obj.peerVersion = receive_byteArray.readShort();
//			obj.magicValue = receive_byteArray.readShort();
//			obj.protocolVersion = receive_byteArray.readShort();
//			obj.protocolFlags = receive_byteArray.readShort();
//			obj.handshakeType = receive_byteArray.readByte();
//			obj.IP = receive_byteArray.readUnsignedInt();
//			obj.Port = receive_byteArray.readShort();
//			if(receive_byteArray.bytesAvailable>0)
//			{
//				obj.upLoadFlags = receive_byteArray.readUnsignedInt();
//				obj.appID = receive_byteArray.readUnsignedInt();
//				obj.reserved2 = receive_byteArray.readUnsignedInt();
//				obj.reserved3 = receive_byteArray.readUnsignedInt();
//				obj.reserved4 = receive_byteArray.readUnsignedInt();
//			}

			handshakeIsOk = true;
		}
		private function analysisBitField(receive_byteArray:ByteArray):void
		{
			var obj:Object = new Object();
			var type:uint = receive_byteArray.readByte();
			
			if( type != 3 ){
				console.log(this,"analysisBitField type:"+type);
			}
			
			switch (type)
			{
				case 0:
//					trace("sequential_bitfield");
					break;
				case 1:
//					trace("discrete_bitfield");
//					while(receive_byteArray.bytesAvailable > 0)
//					{
//						trace(receive_byteArray.readByte());
//					}
					break;
				case 2:
//					trace("sequential_range_bitfield");
					break;
				case 3:
//					trace("sequential_rw_range_bitfield");
					var p:int = 0;
					if(receive_byteArray.bytesAvailable > 4){
						var size:uint = receive_byteArray.readUnsignedInt();
						remotePNList = new Array();
						while(receive_byteArray.bytesAvailable >= 10)
						{
							var startHigh:uint = receive_byteArray.readUnsignedInt();
							var startLow:uint = receive_byteArray.readUnsignedInt();
							var start:Number = (startLow * (1 << 32)) + startHigh;
							var length:uint = receive_byteArray.readShort();
							
							console.log(this,"start == "+start+", len == "+length);
							
							remotePNList.push({"start":start,"end":(start+length-1)});
						}
					}
					
					break;
			}
			
			if( true == LiveVodConfig.ifCanP2PDownload 
				&& requestArr.length == 0)
			{
				var piece:Piece = getTask(remoteTNList,remotePNList) as Piece;
				if(piece)
				{
					requestArr.push(piece);
					sendDataRequest(piece);
				}
			}
		}
		private function analysisReceiveData(receive_byteArray:ByteArray):void
		{
			var obj:Object = new Object();
			var pieceIDHigh:uint = receive_byteArray.readUnsignedInt();
			var pieceIDLow:uint = receive_byteArray.readUnsignedInt();
			var pieceID:Number = (pieceIDLow * (1 << 32)) + pieceIDHigh;
			obj.pieceID = pieceID;
			obj.pieceSize = receive_byteArray.readUnsignedInt();//Piece大小
			obj.pieceOffset = receive_byteArray.readUnsignedInt();//Offset
			obj.bufferSize = receive_byteArray.readUnsignedInt();//缓存区大小
			console.log(this,"ReceiveData pieceID"+obj.pieceID+" pieceSize"+obj.pieceSize+" bufferSize:"+obj.bufferSize);
			obj.data = new ByteArray();
			obj.data.position = 0;
			receive_byteArray.readBytes(obj.data,0,obj.bufferSize);
//			var debugStr:String = "";
//			var change:int=0;
//			var value:String = '';
//			while((obj.data as ByteArray).bytesAvailable>0)
//			{
//				value = (obj.data as ByteArray)[(obj.data as ByteArray).position].toString(16)
//				debugStr += value.length == 1?("0"+value+" "):(value+" ");
//				(obj.data as ByteArray).position++;
//				change++;
//				if(change==16)
//				{
//					change = 0;
//					debugStr += "\n"
//				}
//			}
//			console.log(this,"recieveData:\n"+debugStr);
//			trace("recieveData:"+debugStr);
//			trace("objectLength:"+obj.data.length+" vlb:"+obj.data.bytesAvailable);
			(obj.data as ByteArray).position = 0;
			dealRemoteSendData(obj);
			return;
		}
		
		protected function dealRemoteSendData(obj:Object):void
		{
			var tmpPiece:Piece;
			if(obj.pieceID && (requestArr[0] as Piece).pieceKey == obj.pieceID )
			{
				tmpPiece =  dataManager.getPiece(
					{
						"groupID":this.groupID,
						"type":(requestArr[0] as Piece).type,
						"pieceKey":(requestArr[0] as Piece).pieceKey
					}
				);
				
				if( tmpPiece )
				{
					//trace("dealRemoteSendData key = "+tmpPiece.pieceKey);
					if( false == tmpPiece.isChecked )
					{
						//trace("dealRemoteSendData success ");
						isReceivedData = true;
						tmpPiece.protocol = "utp";
						tmpPiece.setStream((obj.data as ByteArray),utp_pipe.remoteID,this.remoteClientType);
					}
					else
					{
						//trace("dealRemoteSendData P2PRepeatLoad ");
						Statistic.getInstance().P2PRepeatLoad(tmpPiece.pieceKey,tmpPiece.from);
					}
					var idx:int = requestArr.indexOf(tmpPiece);
					if ( -1 != idx)
					{
						requestArr.splice(idx, 1);
					}
				}
			}
			tmpPiece = null;
		}
		
		protected function getTask(TNArray:Array,PNArray:Array):Object
		{
			if(null == TNArray && null == PNArray )
			{
				return null;
			}
			var obj:Object = new Object;
			obj.groupID		= this.groupID;
			obj.TNrange		= TNArray;
			obj.PNrange		= PNArray;
			obj.remoteID	= utp_pipe.remoteID;
			
			var callBackObj:Object = dataManager.getP2PTask(obj);
			obj = null;
			return callBackObj;
		}
		private function sendDataRequest(piece:Piece):void
		{
			var peiceRequestValue:Object = {	
				"sizeOfRequests":1,//请求的数目
				"pieceId":piece.pieceKey,//请求的piece的索引
				"pieceOffset":0,//该 piece起始值
				"pieceLength":piece.size//该piece的长度
			}
			var peiceRequestMap:Array = [
				{"name":"sizeOfRequests"},
				{"name":"pieceId"},
				{"name":"pieceOffset"},
				{"name":"pieceLength"}];
			
			
			var temp_byteArray:ByteArray = new ByteArray();
			temp_byteArray.endian = Endian.BIG_ENDIAN;
			for(var i:int=0 ; i<peiceRequestMap.length ; i++)
			{
				switch(peiceRequestMap[i].name)
				{
					case "sizeOfRequests":
						temp_byteArray.writeByte(int(peiceRequestValue[peiceRequestMap[i].name]));
						break;
					case "pieceId":
						var pieceId:Number = Number(peiceRequestValue[peiceRequestMap[i].name]);
						temp_byteArray.writeUnsignedInt(pieceId & 0xffffffff00000000);
						temp_byteArray.writeUnsignedInt(pieceId & 0x00000000ffffffff);
						
						break;
					case "pieceOffset":
						temp_byteArray.writeUnsignedInt(int(peiceRequestValue[peiceRequestMap[i].name]));
						break;
					case "pieceLength":
						temp_byteArray.writeUnsignedInt(int( peiceRequestValue[peiceRequestMap[i].name] ));
						break;
				}
			}
			console.log(this,"send require data:code:22");
			utp_pipe.sendData(22,temp_byteArray);
		}
		
		private function analysisRequest(receive_byteArray:ByteArray):void
		{
			console.log(this,"analysis romote Request")
		}
		
		private function toHexString(bytes:ByteArray, length:int):String
		{
			var result:String = new String();
			while(length-- > 0){
				var v:int = bytes.readByte() & 0xff;
				if(v < 0x10){
					result += "0"
				}
				result += v.toString(16);
			}
			return result;
		}
		
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		
		public function clear():void
		{
			
		}
	}
}