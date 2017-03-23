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
	import com.p2p.data.vo.Config;
	import com.p2p.data.vo.DataRange;
	import com.p2p.data.vo.Piece;
	import com.p2p.data.vo.WantData;
	import com.p2p.logs.Debug;
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
		
		/**任务来源 */		
		public var from:String = "";				
		
		/**该片影片时长*/
		public var duration:Number = 0;
		
		/**校验数据*/
		public var checkSum:String = "";
		
		/**存储逻辑分片数据,加载desc分配空间*/
		public var pieces:Vector.<Piece> = new Vector.<Piece>();	
		
		/**存储每个piece对应的验证码*/
		public var sunCheckSum:Array = new Array();
		/**数据字节不匹配*/
		private var _isDestroy:Boolean=false;
		
		/**相邻的下一个Block的id*/
		public var nextID:Number = 0;
		
		/**相邻的上一个Block的id*/
		public var preID:Number = 0;
		
		/**该块的视频数据大小*/
		private var _size:Number = 0;
		
		/**分配数据，是否完成，用来检验每片数据的完整性*/
		private var _isFull:Boolean = false;
		
		/**是否已经checksum验证过*/
		private var _isChecked:Boolean = false;
		
		/**存放Block数据块*/
		//private var _stream:ByteArray;
		
		/**获得数据的流的block离散列表*/
		private var _blockList:BlockList;
		
		
		public function Block(blockList:BlockList)
		{			
			_blockList = blockList;
		}
		
		/**数据字节不匹配*/
		public function get isDestroy():Boolean
		{
			return _isDestroy;
		}

		/**
		 * @private
		 */
		public function set isDestroy(value:Boolean):void
		{			
			_isDestroy = value;
			//reset();
		}

		public function set size(_size:Number):void
		{
			if(pieces.length>0){return;}
			this._size=_size;
			var i:int=0;
			//var wangData:WantData=null;
			while(_size-Config.CLIP_INTERVAL>0){
				_size=_size-Config.CLIP_INTERVAL;
				//MZDebugger.rectTrace({"type":"blockCreat","blockID":id,"pieceID":i});
				pieces[i]=new Piece;
				pieces[i].id=i;
				i++;
			}
			if(_size>0 && _size<=Config.CLIP_INTERVAL)
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
		
		public function get isFull():Boolean
		{			
			return _isFull;
		}
		/**填加StreamRangeList在流添加时添加，按照片和块添加*/
		public function dispatchAddRange(pieceID:int=-1):void
		{
			/**添加rangeList基本单位*/
			var _dataRange:DataRange = new DataRange();
			_dataRange.startBlockID=id;
			_dataRange.startPieceID=pieceID;
			_dataRange.endBlockID=id;
			_dataRange.endPieceID=pieceID;
			// 找到该piece的下一个piece,作用是向后合并，用来判断			
			_dataRange.nextConnectBlockID=id;
			if(pieceID < pieces.length-1)
			{
				/**当该piece不是block的最后一片时*/
				_dataRange.nextConnectPieceID=(pieceID+1);
			}
			else
			{
				/**当该piece是block的最后一片时*/
				_dataRange.nextConnectBlockID=nextID;
				_dataRange.nextConnectPieceID=0;
			}
			_blockList.streamRangeList.addDataRange(_dataRange);					
		}
		
		
		/**添加块对应.dat文件,默认返回null*/
		public function setBlockStream(byteArray:ByteArray):void
		{
			if(_isChecked){return;}
			byteArray.position=0;
			var length:int=byteArray.bytesAvailable;
			var readLen:uint=0;
			/**首先校验checkSum*/
			if(doCheckSum(byteArray))
			{
				_isChecked = true;
				/**分配Piece*/
				for(var i:uint=0;i<pieces.length;i++){
					
					if(pieces[i].stream==null){
						if(i==pieces.length-1){
							readLen=_size-Config.CLIP_INTERVAL*(pieces.length-1);
						}else{
							readLen=Config.CLIP_INTERVAL;
						}
						pieces[i].stream=new ByteArray;
						//deleteNeedDataList(i);
						byteArray.position=i*Config.CLIP_INTERVAL;
						pieces[i].iLoadType=3;
						byteArray.readBytes(pieces[i].stream,0,readLen);
						
						dispatchAddRange(i);
					}
					else
					{
						continue;
					}
				}
				_isFull = true;
			}
			else
			{
				Debug.traceMsg(this,"checkSum有问题！！ "+this.id);
				return ;
			}
		}
		
		/**获得块对应.dat文件,默认返回null*/
		public function getBlockStream():ByteArray
		{
			//组装所有的片成块
			if(!_isFull)
			{
				return null;
			}
			Debug.traceMsg(this,"片满"+id);
			var byteArray:ByteArray=new ByteArray;
			var readLen:uint=0;
			for(var i:uint=0;i<pieces.length;i++)
			{
				if(!pieces[i].stream)
				{
					return null;
				}
				byteArray.writeBytes(pieces[i].stream);
			}
			return byteArray;
		}
		
		/**获得块对应.dat或.header的单个片,默认返回null*/
		public function getPiece(id:uint):Piece
		{
			if(id>=pieces.length)
			{
				return null;
			}
			return pieces[id];
		}
		
		/**向片添加数据流*/
		public function setPieceStream(pieceID:uint,byteArray:ByteArray,remoteName:String=""):Boolean
		{
			if(pieceID>=pieces.length)
			{
				Debug.traceMsg(this,"setPieceElementStream超界"); 
				return false;
			}
			if(pieces[pieceID]==null)
			{
				Debug.traceMsg(this,"没有设置文件大小"); 
				return false;
			}
			if(pieces[pieceID].stream!=null || pieces[pieceID].iLoadType ==3)
			{
				Debug.traceMsg(this,"已经有数据 "+id+"_"+pieceID+"  ; "+"length = "+pieces[pieceID].stream.length+"  ; iType = "+pieces[pieceID].iLoadType);
				return false;
			}
			if(byteArray==null /*|| cs != uint(checkSum)*/)
			{
				Debug.traceMsg(this,"没有数据流");
				return false;
			}
			if(_isFull){return false;}
			
			/******设置接收结束时间*********
			 * 当不是通过http下载时需设置piece.end
			 * */
			if(pieces[pieceID].from == "p2p")
			{
				pieces[pieceID].end = (new Date()).time;
				pieces[pieceID].peerName = remoteName;
			}
			/***************写入流**********/
			pieces[pieceID].stream = new ByteArray();
			byteArray.position = 0;
			var readLen:uint=byteArray.bytesAvailable;
			byteArray.readBytes(pieces[pieceID].stream,0,readLen);
			/**当有数据要更改数据状态*/
			pieces[pieceID].iLoadType=3; 
			/**更改streamRangeList列表*/
			//Debug.traceMsg(this,"from = "+pieces[pieceID].from);
			dispatchAddRange(pieceID);   
			/**检查该Block所有的piece是否已经添加满*/
			_isFull=true;
			for(var i:uint=0;i<pieces.length;i++){
				if(pieces[i].stream==null){
					_isFull=false;
					break;
				}
			}
			/**checkSum校验*/
			if(_isFull && !_isChecked)
			{
				if(doCheckSum(getBlockStream()))
				{
					_isChecked = true;
				}
				else
				{
					Debug.traceMsg(this,"checkSum有问题！！ "+this.id);
				}				
			}
			
			/**向统计发送成功接收数据的信息*/
			dispatchGetData(pieces[pieceID]);			
			
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
		
		private function doCheckSum(byteArray:ByteArray=null):Boolean{
			var crc32:CRC32 = new CRC32();			
			crc32.update(byteArray);
			if( byteArray.length==_size && uint(checkSum)==crc32.getValue()){
				return true;
			}
			return false;
			
		}
		
		/**从片获取数据流*/
		public function getPieceStream(id:uint):ByteArray
		{
			if(id>=pieces.length||id<0)
			{
				Debug.traceMsg(this,"setPieceElementStream超界"); 
				return null;
			}
			if(pieces[id]==null)
			{
				Debug.traceMsg(this,"没有设置文件大小"); return null;
			}
			if(pieces[id].stream!=null)
			{
				return null;
			}
			/**考虑在调度方法里设置share*/
			//pieces[id].share++;
			return  pieces[id].stream;
		}
		
		/**清除该块所有数据*/
		public function clear():void
		{			
			sunCheckSum = null;
			pieces = new Vector.<Piece>();
		}
		/**恢复原始状态*/
		public function reset():void
		{
			_isFull    = false;
			_isChecked = false;
			
			for(var i:int=0 ; i<pieces.length ; i++)
			{
				if(pieces[i].stream)
				{
					pieces[i].reset();
				}				
			}			
		}
		
		public function _toString():String{
			var pieceStr:String="";
			for(var i:int=0;i<pieces.length;i++){
				pieceStr+=pieces[i]._toString();	
			}
			return " name:"+name+" nID:"+nextID+" pID:"+preID+
				" _isDstry:"+_isDestroy+" _isF:"+_isFull+"\npc->"+pieceStr;
		}
	}
}