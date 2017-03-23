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
	import com.hls_p2p.dataManager.DataManager;
	import com.hls_p2p.logs.P2PDebug;
	import com.hls_p2p.statistics.Statistic;
	
	import flash.utils.ByteArray;
	
	public class Block
	{	
		public var isDebug:Boolean		= false;
		
		/** 数据的索引值,对应2012120312/1354509880_6920_818214.dat的1354509880类型的数据,加载desc赋值*/
		public var id:Number 			= -1;
		//TTT
		public var nextblkid:Number		= -1;
		/**该block所属的groupID*/
		public var groupID:String 		= "";	
		
		/**保存block的文件名称，当从CDN加载数据时，用来与url组成真正的block下载地址*/
		public var name:String 			= "";
		public var url_ts:String 		= "";
		/**该片影片时长*/
		public var duration:Number 		= 0;	
		/**该片影片时长*/
		public var width:Number 		= 0;	
		/**该片影片时长*/
		public var height:Number 		= 0;		
		/**该块ts文件的视频数据大小*/
		private var _size:Number 		= -1;
		public var offSize:Number 		= 0;
		/**是否已经checksum验证过*/
		private var _isChecked:Boolean 	= false;
		
		/**按先后顺序存储该block逻辑分片(piece)的索引,piece按照tn,pn出现的先后顺序填入pieceIdxArray中*/
		public var pieceIdxArray:Array  = new Array();	
		/**保存tn,pn分片数据（piece）的总表*/
		private var _pieceList:Object 	= new Object();
		
		/**获得数据的流的block离散列表*/
		private var _blockList:BlockList;

		
		public  var discontinuity:int	= 0;
		

		public function Block(blockList:BlockList)
		{			
			_blockList = blockList;
			_pieceList = _blockList.pieceList;
		}

		public function set pieceInfoArray(arr:Array):void
		{
			if( pieceIdxArray.length>0 )
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
			if( !_isChecked )
			{
				_isChecked = doCheck();
			}
			return _isChecked;
		}
		
		public function dodurationHandler():void
		{
			_isChecked = true;
			
			var i:int = LiveVodConfig.TaskCacheArray.indexOf(this.id);
			if( -1 != i )
			{
				LiveVodConfig.TaskCacheArray.splice(i, 1);
			}
		}
		
		private function doCheck():Boolean
		{
			if( false == _isChecked )
			{
				var piece:Piece = null;
				for each( var simplyPiece:* in pieceIdxArray )
				{
					piece = this._blockList.getPiece(simplyPiece);
					
					if( piece.isChecked == false && piece.errorCount <= 3 )
					{
						return false;
					}
				}
				var i:int = LiveVodConfig.TaskCacheArray.indexOf(this.id);
				if( -1 != i )
				{
					LiveVodConfig.TaskCacheArray.splice(i, 1);
				}
			}

			return true;
		}
		
		/**获得块对应.dat文件,默认返回null*/
		public function getBlockStream():ByteArray
		{
			var byteArray:ByteArray = new ByteArray;			
			var tempPiece:Piece;
			
			for( var i:int=0; i<pieceIdxArray.length; i++ )
			{				
				tempPiece = _blockList.getPiece(pieceIdxArray[i]);
				if( tempPiece )
				{
					var byte:ByteArray = tempPiece.getStream();
					if( byte.bytesAvailable > 0 )
					{
						try
						{
							byte.position = 0;
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
			
			byteArray.position = 0;
			if( byteArray.length != this.size)
			{
				P2PDebug.traceMsg(this,"blockSizeErr");
				return new ByteArray;
			}
			
			return byteArray;
		}
		/**验证该block的数据流是否已经完全下载并通过验证*/
		/*internal function checkAllPieceComplete():Boolean
		{
			var tempPiece:Piece;
			for( var i:int=0 ; i<pieceIdxArray.length ; i++ )
			{
				tempPiece = _blockList.getPiece(pieceIdxArray[i]);

				if( !tempPiece || !tempPiece.isChecked )
				{
					_isChecked = false;
					return false;
				}
			}
			
			_isChecked = true;
			return true;
		}*/
		/**获得块对应.dat或.header的单个片,默认返回null*/
		public function getPiece(id:uint):Piece
		{
			if( id >= pieceIdxArray.length )
			{
				return null;
			}
			
			return _blockList.getPiece(pieceIdxArray[id]);
		}
		
		/***/
		private function errorOutMsg(msg:String,pieceID:uint,reLoad:Boolean=false):void
		{
			if( !reLoad )
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
			_isChecked = false;	
			var tempPiece:Piece;
			
			for( var i:int=0; i<pieceIdxArray.length ; i++ )
			{				
				tempPiece = _blockList.getPiece(pieceIdxArray[i]);
				if( tempPiece )
				{
					if( tempPiece.isLoad )
					{
						this._blockList.deleteCDNIsLoadPiece(tempPiece);
					}
					this._blockList.deletePiece(tempPiece.getPieceIndication());
					tempPiece.clear( this.id );
					tempPiece = null;
					delete pieceIdxArray[i];
				}											
			}
			
			//Statistic.getInstance().removeData("clear:"+this.id+"->"+Math.round(_blockList.streamSize/(1024*1024)));
			
			this._size 		= 0;
			groupID 		= "";
			pieceIdxArray 	= null;
			_pieceList 		= null;
			_blockList		= null;
		}
		
		/**恢复原始状态*/
		public function reset():void
		{
			_isChecked = false;	
			var tempPiece:Piece;
			
			for( var i:int=0; i<pieceIdxArray.length ; i++ )
			{				
				tempPiece = _blockList.getPiece(pieceIdxArray[i]);
				if( tempPiece )
				{
					tempPiece.reset( this.id );
				}											
			}
			
			//Statistic.getInstance().removeData("reset:"+this.id+"->"+Math.round(_blockList.streamSize/(1024*1024)));
		}
	}
}