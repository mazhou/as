package com.p2p.data.vo
{
	import com.p2p.logs.P2PDebug;
	import com.p2p.utils.CRC32;
	
	import flash.utils.ByteArray;

	public class Piece
	{
		//固有属性======================================
		/**每片数据id*/
		public var id:uint=0;		
		/**数据流*/
		private var _stream:ByteArray = new ByteArray;
		//调度===================================
		/**数据来源:http或p2p，获得数据后赋值*/
		public var from:String="";
		/**该piece的状态 ： 1为http调度紧急区设置； 2为p2p调度 ；3为已经有正确数据，默认是 2为p2p调度*/
		public var iLoadType:int=2;
		
		/***/
		public var isChecked:Boolean = false;
		public var checkSum:String = "";
		public var size:Number = 0;
		
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
		/**判断在紧急区之外，该piece是否以一定的概率随机分配给http进行下载*/
		public var isLoad:Boolean=false;
		
		private function doCheckSum(byteArray:ByteArray=null):Boolean
		{
			return true;
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
		public function setStream(byteArray:ByteArray):Boolean
		{
			if(doCheckSum(byteArray))
			{
				byteArray.position = 0;
				this._stream.clear();
				byteArray.readBytes(this._stream);
				/**当有数据要更改数据状态*/
				this.isChecked = true;
				this.iLoadType = 3;
				
				return true;
			}
			reset(true);
			return false;
		}
		public function getStream():ByteArray
		{
			return this._stream;
		}
		public function reset(checkError:Boolean=false):void
		{
			begin = 0;
			end   = 0;
			iLoadType = 2;
			peerID = "";
			from   = "";
			size  = 0;
			
			if(!checkError)
			{
				/**如果checkError=true说明此次调用reset为数据验证错误，需要从新分配加载。所以不需要将peerHaveData清空*/
				peerHaveData = new Array();
			}
			
			isChecked = false;
			
			this._stream.clear();
		}
		public function _toString():String{
			//var hasStream:String="";
			//if(stream){hasStream="Y"}else{hasStream="N"}
			return " id:"+id+" s:"+iLoadType+" f:"+from;
		}
	}
}