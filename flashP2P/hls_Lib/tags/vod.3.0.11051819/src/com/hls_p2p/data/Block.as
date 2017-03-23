package com.hls_p2p.data
{
	/**
	 * 
	 * @author Administrator
	 * 
	 * 该类的对象保存视频播放使用的大数据块,包含多个逻辑分片Piece
	 * 
	 */
	
	import com.hls_p2p.data.BlockList;
	import com.hls_p2p.data.vo.Clip;
	import com.hls_p2p.data.vo.LiveVodConfig;
	import com.hls_p2p.dispatcher.IDataManager;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	
	import flash.utils.ByteArray;
	
	public class Block
	{	
		public var isDebug:Boolean=true;
		
		/**数据的索引值,对应2012120312/1354509880_6920_818214.dat的1354509880类型的数据,加载desc赋值*/
		public var id:Number = 0;
		
		/**该block所属的groupID*/
		public var groupID:String = "";
		
		/**保存block的文件名称，当从CDN加载数据时，用来与url组成真正的block下载地址*/
		public var name:String = "";
		
		/**分配任务的时间 */		
		public var begin:Number = 0;
		
		/**收到数据的时间 */		
		public var end:Number = 0;
		
		/**数据来源 */		
		public var from:String = "";				
		
		/**该片影片时长*/
		public var duration:Number = 0;
		
		/**该片影片时长*/
		public var width:Number = 0;
		
		/**该片影片时长*/
		public var height:Number = 0;
				
		/**校验数据*/
		public var checkSum:String = "";
		
		/**序列号*/
		public var sequence:Number=0;
		
		/**按先后顺序存储该block逻辑分片(piece)的索引,piece按照tn,pn出现的先后顺序填入pieceIdxArray中*/
		public var pieceIdxArray:Array = new Array();	
		/**保存tn,pn分片数据（piece）的总表*/
		private var _pieceList:Object = new Object();
		
		/**该块ts文件的视频数据大小*/
		private var _size:Number = 0;
		
		public var offSize:Number = 0;
		/**是否已经checksum验证过*/
		private var _isChecked:Boolean = false;
		
		/**获得数据的流的block离散列表*/
		private var _blockList:BlockList;
		/**0:空闲状态； 1、http下载状态； 2、p2p下载状态*/
		private var _downLoadStat:int = 0;
		
		/**哪些邻居有该块数据，保存邻居的ID*/
		public var peersHaveData:Array = new Array;
		
		public function Block(blockList:BlockList)
		{			
			_blockList = blockList;
			_pieceList = _blockList.pieceList;
		}

		public function set downLoadStat(stat:int):void
		{
			_downLoadStat = stat;
			if(stat == 0)
			{
				var tempPiece:Piece;
				for(var i:int=0 ; i<pieceIdxArray.length ; i++)
				{
					tempPiece = _blockList.getPiece(pieceIdxArray[i]);
					if( tempPiece 
						&& tempPiece.isChecked == false
						&& tempPiece.iLoadType == 1)
					{
						/**当前为http正在下载时且http下载失败或seek时，取消http下载任务
						 * p2p取消任务不会调用该方法
						 * */
						tempPiece.iLoadType = 0;
					}					
				}
			}
		}
		
		public function get downLoadStat():int
		{
			return _downLoadStat;
		}
		
		public function set pieceInfoArray(arr:Array):void
		{
			if(pieceIdxArray.length>0)
			{
				return;
			}
			
			(new ParsePiece_uniform(this._blockList)).parseInfo(arr,groupID,_pieceList,pieceIdxArray,this.id);
		}
				
		public function set size(_sizeByte:Number):void
		{
			_size = _sizeByte;			
		}		
		
		public function get size():Number
		{
			return _size;
		}
		
		public function get isChecked():Boolean
		{
			if(!_isChecked)
			{
				_isChecked = doCheck();
			}
			return _isChecked;
		}
		
		public function doCheck():Boolean
		{
			var bool:Boolean = true;
			var piece:Piece = null;
			for each(var simplyPiece:* in pieceIdxArray)
			{
				piece = this._blockList.getPiece(simplyPiece);
				if(piece.isChecked == false)
				{
					return false;
				}
			}
			return bool;
		}
		
		public function set isChecked(value:Boolean):void
		{
			_isChecked = value;
		}
		
		/**获得块对应.dat文件,默认返回null*/
		public function getBlockStream():ByteArray
		{
			var byteArray:ByteArray = new ByteArray;			
			var tempPiece:Piece;
			
			for(var i:uint=0;i<pieceIdxArray.length;i++)
			{				
				
				tempPiece = _blockList.getPiece(pieceIdxArray[i]);
				if(tempPiece)
				{
					var byte:ByteArray = tempPiece.getStream();
					if(byte.bytesAvailable > 0 )
					{
						try
						{
							byte.position=0;
							byteArray.writeBytes(byte,byteArray.bytesAvailable,byte.length);
						}
						catch(err:Error)
						{
							P2PDebug.traceMsg(this,err);
							return new ByteArray;
						}
					}
				}
				else
				{
					return new ByteArray;
				}				
			}
			byteArray.position=0;
			if(byteArray.length != this.size)
			{
				P2PDebug.traceMsg(this,"blockSizeErr");
				return new ByteArray;
			}
			//
			return byteArray;
		}
		/**验证该block的数据流是否已经完全下载并通过验证*/
		internal function checkAllPieceComplete():Boolean
		{
			var tempPiece:Piece;
			for(var i:int=0 ; i<pieceIdxArray.length ; i++)
			{
				tempPiece = _blockList.getPiece(pieceIdxArray[i]);

				if(!tempPiece || !tempPiece.isChecked )
				{
					_isChecked = false;
					return false;
				}
			}
			_isChecked = true;
			return true;
		}
		/**获得块对应.dat或.header的单个片,默认返回null*/
		public function getPiece(id:uint):Piece
		{
			if(id >= pieceIdxArray.length)
			{
				return null;
			}
			//
			return _blockList.getPiece(pieceIdxArray[id]);
		}
		
		/***/
		private function errorOutMsg(msg:String,pieceID:uint,reLoad:Boolean=false):void
		{
			if(!reLoad)
			{
				Statistic.getInstance().setPieceStreamFailed(String(this.id+"_"+pieceID+","+msg));
			}
			else
			{
				Statistic.getInstance().setPieceStreamFailed(msg);
			}
		}
		
		/**清除该块所有数据*/
		public function clear():void
		{
			reset(true);
			this._size = 0;
			groupID = "";
			pieceIdxArray = null;
			_pieceList = null;
			
		}
		
		/**恢复原始状态*/
		public function reset(isClear:Boolean=false):void
		{
			_isChecked = false;
			this._downLoadStat = 0;		
			var tempPiece:Piece;
			for(var i:int=0 ; i<pieceIdxArray.length ; i++)
			{				
				tempPiece = _blockList.getPiece(pieceIdxArray[i]);
				if( tempPiece )
				{
					if(isClear)
					{
						tempPiece.clear();
					}
					else
					{
						tempPiece.reset();
					}
					
					Statistic.getInstance().removeData(this.id+"_"+i+"->"+Math.round(_blockList.streamSize/(1024*1024)));
				}											
			}
		}
	}
}