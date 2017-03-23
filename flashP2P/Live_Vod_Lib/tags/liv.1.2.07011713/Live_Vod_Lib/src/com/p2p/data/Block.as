package com.p2p.data
{
	/**
	 * 
	 * @author Administrator
	 * 
	 * 该类的对象保存视频播放使用的大数据块,包含多个逻辑分片Piece
	 * 
	 */	
	
	import com.p2p.data.vo.Clip;
	import com.p2p.data.vo.LiveVodConfig;
	import com.p2p.data.vo.Piece;
	import com.p2p.logs.P2PDebug;
	import com.p2p.statistics.Statistic;
	import com.p2p.utils.CRC32;
	
	import flash.utils.ByteArray;
	
	public class Block
	{	
		public var isDebug:Boolean=false;
		/**数据的索引值,对应2012120312/1354509880_6920_818214.dat的1354509880类型的数据,加载desc赋值*/
		public var id:Number = 0;
		
		/**保存block的文件名称，当从CDN加载数据时，用来与url组成真正的block下载地址*/
		public var name:String = "";
		
		/**block所属的head索引*/
		public var head:Number = 0;
		
		/**分配任务的时间 */		
		public var begin:Number = 0;
		
		/**收到数据的时间 */		
		public var end:Number = 0;
		
		/**数据来源 */		
		public var from:String = "";				
		
		/**该片影片时长*/
		public var duration:Number = 0;
		
		/**校验数据*/
		public var checkSum:String = "";
		
		/**序列号*/
		public var sequence:Number=0;
		
		/**存储逻辑分片数据,加载desc分配空间*/
		public var pieces:Vector.<Piece> = new Vector.<Piece>();	
		
		/**该块的视频数据大小*/
		private var _size:Number = 0;
	
		/**是否已经checksum验证过*/
		private var _isChecked:Boolean = false;
		
		/**获得数据的流的block离散列表*/
		private var _blockList:BlockList;
		/**0:空闲状态； 1、http下载状态； 2、p2p下载状态*/
		public var _downLoadStat:int = 0;
		
		
		public function Block(blockList:BlockList)
		{			
			_blockList = blockList;
		}
		
		public function set size(_size:Number):void
		{
			if(pieces.length>0){return;}
			this._size=_size;
			var i:int=0;
			
			while(_size-LiveVodConfig.CLIP_INTERVAL>0)
			{
				_size=_size-LiveVodConfig.CLIP_INTERVAL;
				pieces[i]    = new Piece;
				pieces[i].id = i;
				i++;
			}
			if(_size>0 && _size<=LiveVodConfig.CLIP_INTERVAL)
			{
				pieces[i]=new Piece;
				pieces[i].id=i;
			}
		}
		
		public function get size():Number
		{
			return _size;
		}
		
		public function get isChecked():Boolean
		{
			return _isChecked;
		}
		

		/**获得块对应.dat文件,默认返回null*/
		public function getBlockStream():ByteArray
		{
			var byteArray:ByteArray = new ByteArray;
			var readLen:uint=0;
			for(var i:uint=0;i<pieces.length;i++)
			{
				if(pieces[i].stream.bytesAvailable > 0 )
				{
					try
					{
						byteArray.writeBytes(pieces[i].stream);
					}catch(err:Error)
					{
						P2PDebug.traceMsg(this,err);
						return new ByteArray;
					}
				}
			}
			//
			return byteArray;
		}
		
		/**获得块对应.dat或.header的单个片,默认返回null*/
		public function getPiece(id:uint):Piece
		{
			if(id >= pieces.length)
			{
				return null;
			}
			//
			return pieces[id];
		}
		
		/**向片添加数据流*/
		public function setPieceStream(pieceID:uint,byteArray:ByteArray,remoteName:String=""):Boolean
		{
			
			if(pieces.length==0)
			{
				P2PDebug.traceMsg(this,"没有设置文件大小"); 
				return false;
			}
			//
			if(pieceID >= pieces.length)
			{
				P2PDebug.traceMsg(this,"setPieceElementStream超界"); 
				return false;
			}
			//
			if(pieces[pieceID] == null)
			{
				P2PDebug.traceMsg(this,"没有设置文件大小"); 
				return false;
			}
			//
			if(byteArray && byteArray.bytesAvailable <= 0 )
			{
				P2PDebug.traceMsg(this,"没有数据流");
				return false;
			}
			//if(_isFull){return false;}
			
			/******设置接收结束时间*********
			 * 当不是通过http下载时需设置piece.end
			 * */
			if(pieces[pieceID].from == "p2p")
			{
				pieces[pieceID].end = (new Date()).time;
				pieces[pieceID].peerName = remoteName;
			}
			/***************写入流**********/
			//pieces[pieceID].stream = new ByteArray();
			byteArray.position = 0;
			pieces[pieceID].stream.clear();
			byteArray.readBytes(pieces[pieceID].stream);
			/**当有数据要更改数据状态*/
			pieces[pieceID].iLoadType = 3; //获得了数据
			
			//_blockList.count++;
			
			/**检查该Block所有的piece是否已经添加满*/
			var _isFull:Boolean = true;
			for(var i:uint=0;i < pieces.length;i++)
			{
				if(pieces[i].stream.bytesAvailable <= 0)
				{
					_isFull=false;
					break;
				}
			}
			//
			if (_isFull)
				_downLoadStat = 3;
			//
			/**checkSum校验*/
			if(_isFull && !_isChecked)
			{
				if(doCheckSum(getBlockStream()))
				{
					_isChecked = true;
				}
				else
				{
					this.reset();
					P2PDebug.traceMsg(this,"checkSum有问题！！ "+this.id);
					Statistic.getInstance().P2PCheckSumFailed(String(this.id));
				}
			}
			
			/**向统计发送成功接收数据的信息*/
			dispatchGetData(pieces[pieceID]);			
			this._blockList.eliminate();
			return true;
		}
		
		private function dispatchGetData(piece:Piece):void
		{
			if(piece.from == "http")
			{
				/**输出面板显示http得到数据*/
				Statistic.getInstance().httpGetData(String(id+"_"+piece.id),piece.begin,piece.end,Number(piece.stream.bytesAvailable));
			}
			else if(piece.from == "p2p")
			{
				/**输出面板显示p2p得到数据*/
				Statistic.getInstance().P2PGetData(String(id+"_"+piece.id),piece.begin,piece.end,Number(piece.stream.bytesAvailable),piece.peerName);	
			}
			
		}
		
		private function doCheckSum(byteArray:ByteArray=null):Boolean
		{
			var crc32:CRC32 = new CRC32();			
			crc32.update(byteArray);
			if( byteArray.length==_size)
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
		
		/**从片获取数据流*/
		public function getPieceStream(id:uint):ByteArray
		{
			if(id >= pieces.length || id < 0)
			{
				P2PDebug.traceMsg(this,"setPieceElementStream超界"); 
				return new ByteArray;
			}
			//
			if(pieces[id] == null)
			{
				P2PDebug.traceMsg(this,"没有设置文件大小"); return null;
			}
			//
			if(pieces[id].stream.bytesAvailable <= 0)
			{
				return new ByteArray;
			}
			/**考虑在调度方法里设置share*/
			//pieces[id].share++;
			return  pieces[id].stream;

		}
		
		/**清除该块所有数据*/
		public function clear():void
		{
			reset();
			this._size = 0;
			
			pieces = new Vector.<Piece>();
			
		}
		/**恢复原始状态*/
		public function reset():void
		{
			_isChecked = false;
			this._downLoadStat = 0;		
			
			for(var i:int=0 ; i<pieces.length ; i++)
			{
				if(pieces[i])
				{
					pieces[i].reset();
					Statistic.getInstance().removeData(this.id+"_"+i+"->"+_blockList.count);
				}				
			}
		}
		
		public function _toString():String
		{
			var pieceStr:String="";
			for(var i:int=0;i<pieces.length;i++){
				pieceStr+=pieces[i]._toString();	
			}
			//
			return " name:"+name+" C:"+_isChecked+"\nps->"+pieceStr;
		}
	}
}