package com.hls_p2p.data
{
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.events.EventWithData;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.CheckSum;
	
	import flash.utils.ByteArray;

	public class Piece
	{
		public var isDebug:Boolean=false;
		public function Piece(_blockList:BlockList)
		{
			this._blockList = _blockList;
		}
		
		private var _blockList:BlockList;
		//固有属性======================================
		/**每片piece在所属block的pieces数组中的索引*/
		public var id:int				= 0;	
		/**每片piece保存在piece总表中的键值:pieceID*/
		public var pieceKey:String		= "";
		/**该片数据是tn或pn数据*/
		public var type:String			= "PN";
		/**该片数据所属的groupID*/
		public var groupID:String		= "";
		/**数据流*/
		private var _stream:ByteArray 	= new ByteArray;
		//调度===================================
		/**数据来源:http或p2p，获得数据后赋值*/
		public var from:String			= "";
		/**该piece的状态 ： 1为http调度紧急区设置； 2为p2p调度 ；3为已经有正确数据，默认是 2为p2p调度*/
		public var iLoadType:int		= 0;
		
		/***/
		public var isChecked:Boolean 	= false;
		public var checkSum:String   	= "";
		public var size:Number 	  		= 0;
		
		//p2p========================================
		/**每片数据peerID,其值是分配的临节点*/
		public var peerID:String		= "";
		/**对方节点的名称*/
//		public var peerName:String		= "";
		//统计===========================================
		/**数据开始索取时的时间，获得数据前赋值*/
		public var begin:Number			= 0;
		/**获得数据时的时间，获得数据赋值*/
		public var end:Number			= 0;
		/**被分享的次数，分享时赋值，没分享一次累加一次*/
		public var share:int			= 0;
		
		public var isLoad:Boolean		= false;
		
		/**数据来源的终端设备类型PC,TV,MP,BOX*/
		public var clientType:String 	= "PC";
		
		//public var blockID:Number 		= -1;
		
		public var blockIDArray:Array	= new Array;
		/**checksum 失败或下载字节不对，该值累加*/
		public var errorCount:int		= 0;
/*
		public function set blockIDArray( blockID:Number ):void
		{
			if( -1 == _blockIDArray.indexOf(blockID) )
			{
				_blockIDArray.push( blockID );
			}
		}

		public function get blockIDArray():Array
		{
			return _blockIDArray;
		} 
		*/
		private function doCheckSum(byteArray:ByteArray=null):Boolean
		{
//			if(from == "http")
//			{
//				return true;
//			}
			
			if( byteArray.length == this.size)
			{
//				var crc32:CRC32 = new CRC32();			
//				crc32.update(byteArray);
//				crc32.getValue();
				//////////////////////
				var cksValue:uint = (new CheckSum).checkSum2(byteArray);
//				var cksValue:uint = (new CheckSum).checkSum(byteArray);
				if(uint(checkSum)==cksValue)
//				if(true)
				{
					return true;
				}
				else
				{
					P2PDebug.traceMsg(this,"checkSum有问题！！ "+this.id+",key="+pieceKey+",CS="+checkSum+",CV="+cksValue,this.blockIDArray);
					if(from == "http")
					{
						(errorCount++)>=10?errorCount=10:errorCount;
						Statistic.getInstance().P2PCheckSumFailed("CDN CS Error "+this.id+",key="+pieceKey+",bID="+blockIDArray+",CS="+checkSum+",CV="+cksValue);
					}
					else
					{
						Statistic.getInstance().P2PCheckSumFailed("P2P CS Error "+this.id+",key="+pieceKey+",bID="+blockIDArray+",CS="+checkSum+",CV="+cksValue);
					}
				}
			}
			else
			{
				P2PDebug.traceMsg(this,"size有问题！！ "+this.id+" s="+this.size+" l="+byteArray.length,blockIDArray);
				if(from == "http")
				{
					(errorCount++)>=10?errorCount=10:errorCount;
					Statistic.getInstance().P2PCheckSumFailed("CDN SIZE Error "+this.id+",key="+pieceKey+",bID="+blockIDArray+",s="+size+",l="+byteArray.length);
				}
				else
				{
					Statistic.getInstance().P2PCheckSumFailed("P2P SIZE Error "+this.id+",key="+pieceKey+",bID="+blockIDArray+",s="+size+",l="+byteArray.length);
				}
			}
			return false;			
		}
		public function setStream(byteArray:ByteArray,remoteID:String="",clientType:String="PC"):Boolean
		{
			if( _stream.length == 0 
				&& isChecked ==false
				&& doCheckSum(byteArray) )
			{			
				byteArray.position = 0;
				this._stream.clear();
				byteArray.readBytes(this._stream);
				P2PDebug.traceMsg(this,"streamPiece:"+this.id+" pKey:"+this.pieceKey+" bID:",this.blockIDArray,this.type,this.size + "_stream.length" + _stream.length );
				
				_blockList.streamSize += size;
				
//				if("TN" == this.type/*.toLocaleUpperCase()*/)
//				{
//					_blockList.addTNRange(this.groupID,Number(this.pieceKey));
//				}
//				else if("PN" == this.type/*.toLocaleUpperCase()*/)
//				{
//					_blockList.addPNRange(this.groupID,Number(this.pieceKey));	
//				}
				
				_blockList.eliminate();
				
				/**当有数据要更改数据状态*/
				this.isChecked = true;
				this.iLoadType = 3;
				
				if( true == isLoad )
				{
					_blockList.deleteCDNIsLoadPiece(this);
				}
				
				if(remoteID != "" && peerID == "")
				{
					this.peerID = remoteID;
				}
				this.clientType = clientType;
				dispatcherReceiveStream();				
				return true;
			}
			if(!isChecked)
			{
				var resetType:String="";
				if(from == "http")
				{
					resetType = "cdn";
				}
				else
				{
					resetType = peerID;
				}
				onlyResetParam();
			}
			return false;
		}

		private function dispatcherReceiveStream():void
		{
			var tempStr:String = "";
			if(this.type == "TN")
			{
				tempStr = "TN_"
			}
			
			if(from == "http")
			{
				Statistic.getInstance().httpGetData(tempStr+blockIDArray+"_"+this.pieceKey,begin,end,size,groupID);
			}
			else
			{
				Statistic.getInstance().P2PGetData(tempStr+blockIDArray+"_"+this.pieceKey,begin,end,size,peerID,groupID,clientType);
			}
		}
		public function getStream():ByteArray
		{
			return this._stream;
		}
		
		public function onlyResetParam():void
		{
			begin 		= 0;
			end   		= 0;
			iLoadType 	= 0;
			peerID 		= "";
			from   		= "";
			
			isChecked = false;
			
			if(this._stream.length>0 )
			{
//				if("TN" == this.type)
//				{
//					_blockList.deleteTNRange(this.groupID,Number(this.pieceKey));	
//				}
//				else if("PN" == this.type)
//				{
//					_blockList.deletePNRange(this.groupID,Number(this.pieceKey));	
//				}
				
				_blockList.streamSize -= _stream.length;
				
				Statistic.getInstance().removeData("reset:"+this.id+"->"+Math.round(_blockList.streamSize/(1024*1024))+"->"+_blockList.blockArray.length);
			}
			
			P2PDebug.traceMsg(this,"resetPiece:"+this.id+" pKey:"+this.pieceKey+" bID:",this.blockIDArray,this.type,this.size);
			this._stream.clear();
		}
		
		public function reset( blockID:Number ):void
		{
			
			if(  -1 != blockIDArray.indexOf(blockID)
				&& blockIDArray.length > 1 )
			{
				//不做任何处理，如果做了处理，会破坏正在使用同一个流的其他引用
				return;
			}
			
			onlyResetParam();
			P2PDebug.traceMsg(this,"reset:"+this.id+" pieceKey:"+this.pieceKey+" ty:"+" bID",blockIDArray);
			
		}
		public function getPieceIndication():Object
		{
			return {"groupID":this.groupID,"pieceKey":this.pieceKey,"type":this.type};
		}
		public function clear( blockID:Number ):void
		{
			P2PDebug.traceMsg(this,"clearStream: id："+this.id+" pKey:"+this.pieceKey+"bID:"+blockID,blockIDArray,_blockList);
			if( -1 != blockIDArray.indexOf(blockID) )
			{
				blockIDArray.splice(blockIDArray.indexOf(blockID),1);
				if( blockIDArray.length != 0 )
				{
					return;
				}
			}

			
			begin 		= 0;
			end   		= 0;
			iLoadType 	= 0;
			peerID 		= "";
			from   		= "";
			
			isChecked = false;
			_blockList.streamSize -= _stream.length;
			
			if(this._stream.length >= 0 /*&& this.isChecked*/)
			{
//				if("TN" == this.type)
//				{
//					_blockList.deleteTNRange(this.groupID,Number(this.pieceKey));	
//				}
//				else if("PN" == this.type)
//				{
//					_blockList.deletePNRange(this.groupID,Number(this.pieceKey));	
//				}
//				
				Statistic.getInstance().removeData("clear:"+this.id+" "+blockID+"->"+Math.round(_blockList.streamSize/(1024*1024))+"->"+_blockList.blockArray.length);
			}
			this._stream.clear();
			
			id			= 0;	
			pieceKey	= "";
			type		= "PN";
			groupID 	= "";
			size		= 0;
			_blockList 	= null;
			checkSum	= "";
		}
	}
}