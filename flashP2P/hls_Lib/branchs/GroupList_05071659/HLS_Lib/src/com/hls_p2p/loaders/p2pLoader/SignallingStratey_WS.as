package com.hls_p2p.loaders.p2pLoader
{
	import com.hls_p2p.data.Piece;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dataManager.DataManager;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.console;
	
	import flash.events.TimerEvent;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.Timer;

	public class SignallingStratey_WS
	{
		public var isDebug:Boolean = false;
		
		protected var remotePlayType:String  			= "";
		protected var remoteClientType:String 			= "WS";
		
		protected var remotePNList:Array;
		protected var remoteTNList:Array;
		protected var remoteCDNTaskPieceList:Array;
		protected var readySendDataList:Array = null;
		
		protected var ws_pipe:WS_Pipe;
		protected var p2pLoader:WebSocket_Loader;
		protected var dataManager:DataManager;
		
		public var requestArr:Array 					= new Array;
		protected var beginTime:Number = 0;
		
		public var isReceivedData:Boolean = false;
		
		private var _isRemoteWantPeerList:Boolean = false;
		
		private var _isThisWantPeerList:Boolean = false;
		
		
		private var handshakeIsOk:Boolean = false;
		private var _peerHartBeatTimer:Timer;
		
		public function SignallingStratey_WS(ws_pipe:WS_Pipe,socketLoader:WebSocket_Loader,dataManager:DataManager)
		{
			switch(ws_pipe.termid )
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
			this.ws_pipe				= ws_pipe;
			this.p2pLoader	 			= socketLoader;
			this.dataManager 			= dataManager;
			
			ws_pipe.dataSuccess		= dataSuccess;
			ws_pipe.connectSuccess 	= sendHandshake;
			beginTime = getTime();
			
			_peerHartBeatTimer = new Timer(1000);
			_peerHartBeatTimer.addEventListener(TimerEvent.TIMER, peerHartBeatTimer );
			_peerHartBeatTimer.start();
		}
		protected function getTime():Number 
		{
			return Math.floor((new Date()).time);
		}
		public function sendHandshake(value:String):void
		{
			//数据
			if(value == null)
			{	
				return;
			}
			handshakeIsOk = true;//握手成功
			var lines:Array = value.split(/\r?\n/);
			var responseLine:String;
			while (lines.length > 0) {
				responseLine = lines.shift();
				var header:Object = parseHTTPHeader(responseLine);
				if(header == null)
				{
					continue;
				}
				var lcName:String= header.name.toLocaleLowerCase();;
				var lcValue:String= header.value.toLocaleLowerCase();
				switch(lcName)
				{
					case "x-mtep-client-id":
						break;
					case "x-mtep-client-module":
						break;
					case "x-mtep-client-version":
						break;
					case "x-mtep-protocol-version":
						break;
					case "x-mtep-business-tags":
						break;
					case "x-mtep-os-platform":
						break;
					case "x-mtep-hardware-platform":
						break;
				}
			}
		}
		
		
		private function handleSendWebSocketData():void 
		{
			if (ws_pipe&&ws_pipe.canSend)
			{
				var byteArray:ByteArray = new ByteArray();
				byteArray.endian=Endian.BIG_ENDIAN;
				var sendDataSct:Array = [
					{"sequence_4":0},//0
					{"rangeCount_4":0},//1
					{"rangeItems":[
						[{"type_2":123},{"start_8":234},{"end_4":345}]
					]},//2
					{"requestCount_4":0},//3
					{"requestItems":[
						[{"type_2":0},{"start_8":1411033199},{"cks_4":57473}]
					]},//4
					{"responseCount_4":0},//5
					{"responseItems":[
						[{"type_2":0},{"start_8":1411033199},{"streamLength_4":57473},{"stream_d":new ByteArray()}]
					]},//6
					{"peerCount_4":1},//连接节点数//7
					{"peerItems":[
						[{"head_4":0},{"URL_utf":"ws://202.103.4.52:34567/*****"}]
					]}//8
				];
				var rangeItems:Array=[];
				var tempList:Array;
				if( true == LiveVodConfig.ifCanP2PUpload )
				{
					tempList	= this.dataManager.getTNRange(this.groupID);
					var start:Number;
					var end:Number;
					if(tempList != null)
					{
						for(var i:int=0;i<tempList.length;i++)
						{
							start=tempList[i]['start'];
							end =tempList[i]['end'];
							rangeItems.push([{"type_2":0},{"start_8":start},{"end_4":(end-start+1)}]);
						}
					}
					
					tempList	= this.dataManager.getPNRange(this.groupID);
					if(tempList != null)
					{
						for(i=0;i<tempList.length;i++)
						{
							start=tempList[i]['start'];
							end =tempList[i]['end'];
							rangeItems.push([{"type_2":1},{"start_8":start},{"end_4":(end-start+1)}]);
						}
					}
				}
				sendDataSct[2]["rangeItems"]=rangeItems;
				//
				var requestItems:Array=[];
				var type:int = 0;
				//trace("LiveVodConfig.ifCanP2PDownload="+LiveVodConfig.ifCanP2PDownload);
				if(requestArr == null)
				{
					requestArr = [];
				}
				if( true == LiveVodConfig.ifCanP2PDownload 
					&&requestArr.length == 0)
				{
					var piece:Piece = getTask(this.remoteTNList,this.remotePNList) as Piece;
					if(null != piece)
					{
						//trace("============new piece=========");
						requestArr.push(piece);
						if(piece.type =="PN")
						{
							type =1;
						}
						requestItems.push([{"type_2":type},{"start_8":piece.pieceKey},{"cks_4":piece.checkSum}]);
					}
				}
				sendDataSct[4]["requestItems"]=requestItems;
				var responseItems:Array=[];
				type=0;
				if(readySendDataList && readySendDataList.length>0)
				{
					for(i=0;i<readySendDataList.length;i++)
					{
						if(readySendDataList[i]['type']=="PN")
						{
							type = 1;
						}
						responseItems.push([{"type_2":type},{"start_8":readySendDataList[i]['key']},{"streamLength_4":readySendDataList[i]['data'].length},{"stream_d":readySendDataList[i]['data']}]);
						//trace("stream_len=-----------"+readySendDataList[i]['data'].length);
					}
					readySendDataList 	= null;//new Array();
				}
				sendDataSct[6]["responseItems"]=responseItems;
				//trace("response:"+sendDataSct[6]["responseItems"].length);
				//trace("================"+sendDataSct["responseItems"].length);
				var peerItems:Array=[];
				/*是否向节点索取节点列表*/		
				tempList = p2pLoader.getSuccessPeerList(remoteID);
				for(i=0;i<tempList.length;i++)
				{
					peerItems.push([{"head_4":i},{"URL_utf":tempList[i]}]);
				}
				if(!LiveVodConfig.IS_SHARE_PEERS)
				{
					return;
				}
				sendDataSct[8]["peerItems"]=peerItems;
			
				sendDataSct[1].rangeCount_4 = sendDataSct[2].rangeItems.length;
				sendDataSct[3].requestCount_4 = sendDataSct[4].requestItems.length;
				sendDataSct[5].responseCount_4 = sendDataSct[6].responseItems.length;
				for( var p:int = 0; p < sendDataSct[6].responseItems.length;p++ )
				{
					sendDataSct[6].responseItems[p][2].streamLength_4 = sendDataSct[6].responseItems[p][3].stream_d.length;
				}
				sendDataSct[7].peerCount_4 = sendDataSct[8].peerItems.length;
				for( var pp:int = 0; pp < sendDataSct[8].peerItems.length;pp++ )
				{
					sendDataSct[8].peerItems[pp][0].head_4 = sendDataSct[8].peerItems[pp][1].URL_utf.length;
				}
				outPutP2PState(sendDataSct);
				parseData(sendDataSct,byteArray);
				//trace(">>>"+toHexString(byteArray));
				ws_pipe.sendData("sendBytes",byteArray);
				//解析发送的数据＝＝＝＝
				//dataSuccess(byteArray);
				return;
			}
		}
		private function convertToBit(size:String,data:*,byteArray:ByteArray):void
		{
			switch(size)
			{
				case "2":
					byteArray.writeShort( data );
					break;
				case "4":
					byteArray.writeUnsignedInt( data );
					break;
				case "8":
					byteArray.writeUnsignedInt( Math.floor(data/0x100000000) );
					byteArray.writeUnsignedInt( Math.floor(data%0x100000000) );
					break;
				case "utf":
					byteArray.writeUTFBytes(data);
					break;
				case "d":
					//trace(">>>"+toHexString(data));
					byteArray.writeBytes(data);
					break;
			}
		}
				
		private function convertToValue(size:String,byteArray:ByteArray,position:uint=0,len:uint=0 ):*
		{
			switch(size)
			{
				case "2":
					byteArray.position = position;
					var value_s:uint =byteArray.readShort();
					return value_s;
					break;
				case "4":
					byteArray.position = position;
					var value_u:uint = byteArray.readUnsignedInt();
					return value_u;
					break;
				case "8":
					byteArray.position = position;
					var high:uint = byteArray.readUnsignedInt();
					var low:uint = byteArray.readUnsignedInt();
					var value_n:Number = (high * 0x100000000) + low;
					return value_n;
					break;
				case "utf":
					byteArray.position = position;
					var str:String = byteArray.readUTFBytes(len);
					return str;
					break;
				case "d":
					byteArray.position = position;
					var bytes:ByteArray = new ByteArray();
					byteArray.readBytes(bytes,0,len);
					return bytes;
					break;
			}
			return 0;
		}
		
		
		
		private function parseData(obj:*,byteArray:ByteArray):void
		{
			if(obj is Array)
			{
				for(var i:int = 0; i < obj.length; i++)
				{
					if (obj[i] is Array)
					{
						parseData(obj[i],byteArray);
					}else if(obj[i]  is Object)
					{
						parseData(obj[i],byteArray);
					}
				}
			}else if(obj is Object)
			{
				for( var element:String in obj )
				{
					var size:String = element.split("_")[1];
					if(size)
					{
						//trace("cvr:",element,size,obj[element])
						convertToBit( size,obj[element],byteArray );
					}
					if(!size && obj[element])
					{
						parseData( obj[element] ,byteArray);
					}
				}
			}
		}
		private function parseRecieveData(value:ByteArray):void
		{
			var position:uint = 0;
			var sequnce:uint = convertToValue('4',value,position);//sequnce
			position += 4;
			trace(">>>","sequnce:"+sequnce)
			var rangeCount:uint = convertToValue('4',value,position);//sequnce
			position += 4;

			/////
			remoteTNList = [];
			remotePNList = [];
			for( var oi:uint = 0; oi < rangeCount;oi++){
				var type:uint = convertToValue('2',value,position);//sequnce
				position += 2;
				var start:Number = convertToValue('8',value,position);//sequnce
				position += 8;
				var end:Number = convertToValue('4',value,position);//sequnce
				position += 4;
				if(0==type)
				{
					remoteTNList.push({"start":start,"end":(start+end-1)});
				}
				else
				{
					remotePNList.push({"start":start,"end":(start+end-1)});
				}
			}
			//trace("TN="+JSON.stringify(remoteTNList));
			//trace("PN="+JSON.stringify(remotePNList));
			var reqCount:uint = convertToValue('4',value,position);//sequnce
			position += 4;
			var sendArr:Array = [];
			for( var i:uint = 0; i < reqCount;i++){
				var type2:uint = convertToValue('2',value,position);//sequnce
				position += 2;
				var pid:Number = convertToValue('8',value,position);//sequnce
				position += 8;
				var sck:Number = convertToValue('4',value,position);//sequnce
				position += 4;
				if(type2==0)
				{
					sendArr.push({"type":"TN","groupId":groupID,"key":pid,'sck':sck});
				}
				else
				{
					sendArr.push({"type":"PN","groupId":groupID,"key":pid,'sck':sck});
				}
//				//trace(
//					"reqCount:"+reqCount
//					,"type2:"+type2
//					,"pid:"+pid
//					,"sck:"+sck
//				);
			}
			if(sendArr.length>0)
			{
				readySendDataList = getData(sendArr);
			}
			var respCount:uint = convertToValue('4',value,position);//sequnce
			position += 4;
			var len:uint = (requestArr?requestArr.length:1);
			for( var ii:uint = 0; ii < respCount&&ii<len;ii++){
				var type3:uint = convertToValue('2',value,position);//sequnce
				position += 2;
				var pid2:Number = convertToValue('8',value,position);//sequnce
				position += 8;
				var DataL:uint = convertToValue('4',value,position);//sequnce
				position += 4;
				try
				{
					var stream:ByteArray = convertToValue('d',value,position,DataL);
					position += DataL;
					dealRemoteSendData({'pieceID':pid2,'data':stream});
				}
				catch(err:Error){trace("读取数据失败！");}
//				trace(
//					"respCount:"+respCount
//					,"type3:"+type3
//					,"pid2:"+pid2
//					//,"DataL:"+DataL
//				);
			}
			
			var peerCount:uint = convertToValue('4',value,position);//sequnce
			position += 4;
			for(var iii:uint = 0; iii < peerCount;iii++){
				var peerheadL:uint = convertToValue('4',value,position);//sequnce
				position += 4;
				var url:String = convertToValue('utf',value,position,peerheadL);
				//			convertToValue('4',value,position)
				position += peerheadL;
//				trace(
//					"peerCount:"+peerCount
//					,"peerheadL:"+peerheadL
//					,"url:"+url
//				);
			}
			//接受完回复数据
			HartBeatTimer(false);
		}
	
		protected function outPutP2PState(data:Array):void
		{
			var requestArr:Array = data[4]["requestItems"] as Array;
			var responseArr:Array = data[6]["responseItems"] as Array;
			var tempPiece:Piece;
			var type:String;
			for(var i:int=0 ; i<requestArr.length ; i++)
			{	
				Statistic.getInstance().P2PWantData(requestArr[i][0]["type_2"]+"_"+requestArr[i][1]["start_8"],ws_pipe.remoteID);
			}
			for(var j:int=0 ; j<responseArr.length ; j++)
			{
				try
				{
					type = "TN";
					if(responseArr[j][0]["type_2"] == 1)
					{
						type = "PN";
					}
					tempPiece = dataManager.getPiece({"groupID":groupID,"pieceKey":responseArr[j][1]["start_8"],"type":type});
					tempPiece.share++;
					Statistic.getInstance().P2PShareData(type+"_"+responseArr[j][1]["start_8"],ws_pipe.remoteID);
				}catch(err:Error)
				{
					console.log(this,"err:"+err+err.getStackTrace());	
				}
			}			
		}
		//表头分析
		private function parseHTTPHeader(line:String):Object {
			var header:Array = line.split(/\: +/);
			return header.length === 2 ? {
				name: header[0],
				value: header[1]
			} : null;
		}
		
		public function dataSuccess(receive_byteArray:ByteArray):void
		{
			//接受的数据块信息
			//trace("接受的数据块信息");
			parseRecieveData(receive_byteArray);
		}
		
		protected function dealRemoteSendData(obj:Object):void
		{
			var tmpPiece:Piece;
//			if(requestArr.length==0)
//			{
//				return;
//			}
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
						tmpPiece.protocol = "ws";
						tmpPiece.setStream((obj.data as ByteArray),ws_pipe.remoteID,this.remoteClientType);
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
		
		public function isActivePeer():Boolean
		{
			if( getTime()-beginTime > 9*1000 )
			{
				return false;
			}
			return true;
		}
		//////////////
		private function peerHartBeatTimer(event:* = null):void
		{
			HartBeatTimer(true);
		}
		private var peerGap:Number = 0;
		private function HartBeatTimer(isHeart:Boolean=false):void
		{	
			//			if (isHeart && (getTime() - peerGap < 1000))
			//			{
			//				return;
			//			}
			
			if (ws_pipe.canSend)
			{
				sendHartBeat();
				//				peerGap = getTime();
			}
		}
		public function isDead():Boolean
		{
			return (Math.floor((new Date()).time) - beginTime) > (3*60*1000);
		}
		//心跳
		private function sendHartBeat():void
		{
			//send bitmap
			if(!handshakeIsOk)
			{
				return;
			}
			//trace("sendData---connect="+handshakeIsOk);
			handleSendWebSocketData();
			
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
			obj.remoteID	= ws_pipe.remoteID;
			
			var callBackObj:Object = dataManager.getP2PTask(obj);
			obj = null;
			return callBackObj;
		}
		private function sendDataRequest(piece:Piece):void
		{
			//ws_pipe.sendData(22,temp_byteArray);
		}
		public function resetHartBeatTimer(nStep:int):void
		{			
		}
		private function toHexString(byteArray:ByteArray):String
		{
			var out:String = "";
			var value:String = "";
			var i:int = 0;
			byteArray.position = 0;
			while(byteArray.bytesAvailable>0)
			{
				
				value = (byteArray[byteArray.position].toString(16))
				out += (value.length==1?(" 0"+value):" "+value);
				i++;
				if(i== 16){
					out += "\n"
					i=0;
				}
				
				byteArray.position++;
			}
			byteArray.position = 0;
			return out;
		}
		public function clear():void
		{
			console.log(this,"clear");
			remotePNList = null;
			remoteTNList = null;
			requestArr = null;
			remoteCDNTaskPieceList = null;			
			
			if(_peerHartBeatTimer)
			{
				_peerHartBeatTimer.stop();
				_peerHartBeatTimer.addEventListener(TimerEvent.TIMER, peerHartBeatTimer);
				_peerHartBeatTimer = null;
			}
			
			if(this.p2pLoader)
			{
				this.p2pLoader = null;
			}
			
			if(this.ws_pipe)
			{
				ws_pipe.dataSuccess	= null;
				ws_pipe.connectSuccess	= null;
				this.ws_pipe.clear();
				this.ws_pipe = null;
			}
			
			this.dataManager = null;
		}
		protected function getData(arr:Array):Array
		{
			var tmpArray:Array = new Array;
			if(null == arr)
			{
				return tmpArray;
			}
			
			var tmpPiece:Piece;
			var readySendData:Object;
			
			for(var i:int=0;i<arr.length;i++)
			{
				if(arr[i])
				{
					var type:String			= arr[i]["type"];
					var key:String			= arr[i]["key"];
					if(type && key)
					{
						//trace("type="+type+"|key="+key);
						tmpPiece =  dataManager.getPiece(
							{
								"groupID":this.groupID,
								"type":arr[i].type,
								"pieceKey":arr[i].key
							}
						)
						
						if(!tmpPiece || false == tmpPiece.isChecked)
						{
							continue;
						}
						
						if(type == "TN" && tmpPiece.checkSum != arr[i]["checksum"])
						{
							continue;
						}
						trace("---------");
						readySendData = 
							{
								"type":tmpPiece.type,
									"key":tmpPiece.pieceKey,
									"data":tmpPiece.getStream()
							}
						
						tmpArray.push(readySendData);
						if(tmpArray.length>0)
						{
							break;
						}
					}else
					{
						continue;
					}
				}
			}// end for arr loop
			tmpPiece = null;
			return tmpArray;
		}
		public function get remoteID():String
		{
			return ws_pipe.remoteID;
		}
		
		public function get groupID():String
		{
			return ws_pipe.groupID;
		}
		
		public function get canRecieved():Boolean
		{
			return ws_pipe.canRecieved;
		}
		
		public function get romoteUir():String
		{
			return ws_pipe.uir;
		}
		
		public function set canRecieved(value:Boolean):void
		{
			ws_pipe.canRecieved = value;
		}
		
		public function get canSend():Boolean
		{
			return ws_pipe.canSend;
		}
		
		public function set canSend(value:Boolean):void
		{
			ws_pipe.canSend = value;
		}
	}
}