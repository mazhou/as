package com.hls_p2p.data
{
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.events.EventWithData;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	import com.p2p.utils.CRC32;
	
	import flash.utils.ByteArray;

	public class Piece
	{
		public function Piece(_blockList:BlockList)
		{
			this._blockList = _blockList;
		}
		private var _blockList:BlockList;
		//固有属性======================================
		/**每片piece在所属block的pieces数组中的索引*/
		public var id:int;	
		/**每片piece保存在piece总表中的键值:pieceID*/
		public var pieceKey:String="";
		/**该片数据是tn或pn数据*/
		public var type:String="PN";
		/**该片数据所属的groupID*/
		public var groupID:String="";
		/**数据流*/
		private var _stream:ByteArray = new ByteArray;
		//调度===================================
		/**数据来源:http或p2p，获得数据后赋值*/
		public var from:String="";
		/**该piece的状态 ： 1为http调度紧急区设置； 2为p2p调度 ；3为已经有正确数据，默认是 2为p2p调度*/
		public var iLoadType:int=2;
		
		/***/
		public var isChecked:Boolean = false;
		public var checkSum:String   = "";
		public var size:Number 	  = 0;
		
		//public var ifLastPiece:Boolean = false;
		
		//p2p========================================
		/**每片数据peerID,其值是分配的临节点*/
		public var peerID:String="";
		/**对方节点的名称*/
		public var peerName:String="";
		
		/**有哪些节点有该piece的数据 lz 0723 add*/
		public var peerHaveData:Array = new Array();
		
		//统计===========================================
		/**数据开始索取时的时间，获得数据前赋值*/
		public var begin:Number=0;
		/**获得数据时的时间，获得数据赋值*/
		public var end:Number=0;
		/**被分享的次数，分享时赋值，没分享一次累加一次*/
		public var share:int=0;
		
		public var isLoad:Boolean=false;
		
		/**点播改进 01*/
		public var strVer:String  = "";
		
		
		public var blockID:Number = -1;
		/**数据来源的终端设备类型PC,TV,MP,BOX*/
		public var clientType:String = "PC";
		

		private function doCheckSum(byteArray:ByteArray=null):Boolean
		{			
			if(from == "http")
			{
				return true;
			}
			var crc32:CRC32 = new CRC32();			
			crc32.update(byteArray);
			if( byteArray.length==this.size)
			{
				if(uint(checkSum)==crc32.getValue())
				{
					return true;
				}
				else
				{
					P2PDebug.traceMsg(this,"checkSum有问题！！ "+this.id);
				}
			}
			else
			{
				P2PDebug.traceMsg(this,"size有问题！！ "+this.id+" s="+this.size+" l="+byteArray.length);
			}
			return false;			
		}
		public function setStream(byteArray:ByteArray,remoteID:String=""):Boolean
		{
			if( _stream.length == 0 
				&& isChecked ==false
				/*&& byteArray.length == size*/
				&& doCheckSum(byteArray))
			{
				if(byteArray.length != size)
				{
					return false;
				}
				
				byteArray.position = 0;
				this._stream.clear();
				byteArray.readBytes(this._stream);
				
				_blockList.streamSize += size;
				_blockList.eliminate();
				
				/**当有数据要更改数据状态*/
				this.isChecked = true;
				this.iLoadType = 3;
				if(remoteID != "" && peerID == "")
				{
					this.peerID = remoteID;
				}
				dispatcherReceiveStream();				
				return true;
			}
			if(!isChecked)
			{
				var resetType:String="";
				if(from == "http")
				{
					resetType = "cdn";
				}else
				{
					resetType = peerID;
				}
				reset(resetType);
			}
			return false;
		}
		
		
		public var blockOutmsg:Number	=0;/**测试用，后期删掉*/
		private function dispatcherReceiveStream():void
		{
			var tempStr:String = "";
			if(this.type == "TN")
			{
				tempStr = "TN_"
			}
			//var block:Block;
			if(from == "http")
			{
				Statistic.getInstance().httpGetData(tempStr+blockID+"_"+this.pieceKey,begin,end,size);
			}
			else
			{
				//id:String,begin:Number,end:Number,size:Number,peerID:String,clientType:String="PC"
				Statistic.getInstance().P2PGetData(tempStr+blockID+"_"+this.pieceKey,begin,end,size,peerID,clientType);
			}
		}
		public function getStream():ByteArray
		{
			return this._stream;
		}
		public function reset(resetType:String = ""):void
		{
			begin = 0;
			end   = 0;
			iLoadType = 2;
			peerID = "";
			from   = "";
			//size  = 0;

			if(resetType != "cdn" && peerHaveData)
			{
				for(var i:int = 0; i<peerHaveData.length ; i++)
				{
					if( resetType == peerHaveData[i] )
					{
						peerHaveData.splice(i,1);
						break;
					}
				}
			}
			isChecked = false;
			_blockList.streamSize -= _stream.length;
			this._stream.clear();
		}
		
		public function clear(p_block:Block = null):void
		{
			reset();
			blockID = -1;
			size	= 0;
			_stream = null;
			peerHaveData = null;
			_blockList = null;
		}
	}
}