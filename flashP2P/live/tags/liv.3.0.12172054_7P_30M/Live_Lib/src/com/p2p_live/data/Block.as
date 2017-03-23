package com.p2p_live.data
{
	import com.mzStudio.mzStudioDebug.MZDebugger;
	import com.p2p.utils.CRC32;
	
	import flash.utils.ByteArray;

	/**大块数据，其中每片包含一个或多个片*/
	public class Block
	{
		public var needDataList:Object=null;
		
		/**数据的索引值,对应1354455065.header的1354455065；或2012120312/1354509880_6920_818214.dat的1354509880类型的数据,加载desc赋值*/
		public var id:uint=0;
		
		/**该block的前一个blockid,用来检索连续性*/
		public var preBlockId:uint=0;

		/**欲分配的每个块的字节, 默认每块是128*1024，初始化赋值*/
		public var pieceSize:uint=128*1024;
		
		/**存储每块数据,加载desc分配空间*/
		public var pieces:Vector.<Piece>=new Vector.<Piece>();
		
		/**http下载时获得的字节总数，用来和size做校验*/
		public function judgeLength(size:Number):Boolean{
			return (_size==size);
		}
		
		/**本块服务器创建时间*/
		public var creatTime:Number=0;
		
		/************1209 lz add**************/		
		/**分配任务的时间 */		
		public var begin:Number = 0;
		
		/**收到数据的时间 */		
		public var end:Number = 0;
		
		/**任务来源 */		
		public var from:String;
		/*************************************/
		
		/**每片的实际大小字节,加载desc赋值*/
		public function set size(_size:Number):void{
			if(pieces.length>0){return;}
			this._size=_size;
			var i:int=0;
			//var wangData:WantData=null;
			while(_size-pieceSize>0){
				_size=_size-pieceSize;
				MZDebugger.rectTrace({"type":"blockCreat","blockID":id,"pieceID":i});
				pieces[i]=new Piece;
				addNeedDataList(i);
				pieces[i].id=i;
				i++;
			}
			if(_size>0&&_size<=pieceSize)
			{
				addNeedDataList(i);
				pieces[i]=new Piece;
				pieces[i].id=i;
			}
		}
		
		private function addNeedDataList(pieceID:uint):void
		{
			var wangData:WantData=null;
			if(needDataList!=null){
				if(!needDataList[id+"_"+pieceID])
				{
					wangData=new WantData();
					wangData.blockID=id;
					wangData.pieceID=pieceID;
					needDataList[id+"_"+pieceID]=wangData;
				}
			}
		}
		public function deleteNeedDataList(pieceID:uint):void
		{
			if(needDataList!=null)
			{
				if(needDataList[this.id+"_"+pieceID])
				{
					//trace("删除片= "+this.id+"_"+id);
					needDataList[this.id+"_"+pieceID]=null;
					delete needDataList[this.id+"_"+pieceID];
				}				
			}
		}
		public function deleteAllNeedDataList():void
		{
			if(needDataList!=null)
			{
				//trace("删除块= "+this.id);
				for(var i:uint=0;i<pieces.length;i++){
					if(needDataList[this.id+"_"+i]){
						deleteNeedDataList(i);
					}
				}
			}
		}
		public function get size():Number{
			return _size;
		}
		private var _size:Number=0;
		
		
		/**该片影片时长*/
		public var duration:Number=0;
		
		/**校验数据*/
		public var checksum:uint=0;
		
		private var _isAllDataAssign:Boolean=false;
		/**分配数据，是否完成，用来检验每片数据的完整性*/
		public function get isAllDataAssign():Boolean{
			return _isAllDataAssign
		}
		/**添加片，对应.dat或.header文件*/
		public function set addBlockStream(byteArray:ByteArray):void{
			byteArray.position=0;
			var length:int=byteArray.bytesAvailable;
			var readLen:uint=0;
			var crc32:CRC32 = new CRC32();
			crc32.update(byteArray);
			if(length==_size&&checksum==crc32.getValue()){
				//trace("删除块= "+id);
				for(var i:uint=0;i<pieces.length;i++){
					
					if(pieces[i].stream==null){
						if(i==pieces.length-1){
							readLen=_size-pieceSize*(pieces.length-1);
						}else{
							readLen=pieceSize;
						}
						MZDebugger.rectTrace({"type":"httpAddDate","blockID":id,"pieceID":i});
						pieces[i].stream=new ByteArray;
						deleteNeedDataList(i);
						byteArray.position=i*pieceSize;
						pieces[i].iLoadType=3;
						byteArray.readBytes(pieces[i].stream,0,readLen);
						//trace("bl id = "+this.id+" _size  "+_size+"   pieces["+i+"].stream.length "+pieces[i].stream.length)
					}else{
						continue;
					}
				}
				_isAllDataAssign=true;
			}else{
				MZDebugger.trace(this,"出现异常，是否没有设置size或size设置不对");
			}
		}
		
		/**获得块对应.dat或.header文件,默认返回null*/
		public function get getBlockStream():ByteArray{
			//组装所有的片成块
			if(!_isAllDataAssign){return null;}
			var byteArray:ByteArray=new ByteArray;
			var readLen:uint=0;
			for(var i:uint=0;i<pieces.length;i++){
				if(i==pieces.length-1){
					readLen=_size-pieceSize*(pieces.length-1);
				}else{
					readLen=pieceSize;
				}
				MZDebugger.rectTrace({"type":"httpGetDate","blockID":id,"pieceID":i});
				byteArray.writeBytes(pieces[i].stream,0,readLen);
			}
			//trace("this id = "+this.id+"  length = "+i);
			return byteArray;
			/*var crc32:CRC32 = new CRC32();
			crc32.update(byteArray);
			if(checksum==crc32.getValue()){
				return byteArray
			}else{
				Debug.output(this,"校验异常"+this.id);
				return null
			}*/
		}
		
		/**获得块对应.dat或.header的单个片,默认返回null*/
		public function getPieceElement(id:uint):Piece
		{
			if(id>=pieces.length){return null;}
			return pieces[id];
		}
		
		/**向片添加数据流*/
		public function  setPieceElementStream(id:uint,byteArray:ByteArray,cs:uint):Boolean
		{
			if(id>=pieces.length)
			{
				MZDebugger.trace(this,"setPieceElementStream超界"); 
				return false;
			}
			if(pieces[id]==null)
			{
				MZDebugger.trace(this,"没有设置文件大小"); 
				return false;
			}
			if(pieces[id].stream!=null)
			{
				return false;
			}
			//var wangData:WantData
			if(byteArray==null || cs != checksum)
			{
				//错误数据删掉需要的数据
				addNeedDataList(id);
				needDataList[this.id+"_"+id]["remoteID"] = "";
				return false;
			}
			if(_isAllDataAssign){return false;}
			/**/
			if(!needDataList[this.id+"_"+id])
			{
				addNeedDataList(id);
				return false;
			}
			
			MZDebugger.rectTrace({"type":"p2pAddDate","blockID":this.id,"pieceID":id});
			//MZDebugger.trace(this,"p2pAddDate blockID"+this.id+" pieceID"+id);			
			
			pieces[id].begin = needDataList[this.id+"_"+id]["beginTime"];
			pieces[id].end   = (new Date()).time;
			pieces[id].stream = new ByteArray();
			byteArray.position = 0;
			var readLen:uint=byteArray.bytesAvailable;
			byteArray.readBytes(pieces[id].stream,0,readLen);
			deleteNeedDataList(id);
			
			pieces[id].iLoadType=3; //当有数据要更改数据状态
			_isAllDataAssign=true;
			for(var i:uint=0;i<pieces.length;i++){
				if(pieces[i].stream==null){
					_isAllDataAssign=false;
					break;
				}
			}
			/*if(_isAllDataAssign)
			{
				trace(this.id)
				trace("_isAllDataAssign------------------------------------------")
			}*/
			return true;
		}
		/**从片获取数据流*/
		public function  getPieceElementStream(id:uint):ByteArray
		{
			if(id>=pieces.length||id<0){MZDebugger.trace(this,"setPieceElementStream超界"); return null;}
			if(pieces[id]==null){MZDebugger.trace(this,"没有设置文件大小"); return null;}
			if(pieces[id].stream!=null){return null;}
			pieces[id].share++;
			MZDebugger.rectTrace({"type":"p2pGetDate","blockID":this.id,"pieceID":id});
			//MZDebugger.trace(this,"p2pGetDate blockID"+this.id+" pieceID"+id)
			return  pieces[id].stream;
		}
		
		/**返回没有流数据id,或有流数据*/ 
		public function getPieceAboutHasStream():Object
		{
			var streamState:StreamState=new StreamState;
			streamState.haveStream=new Array;
			streamState.noStream=new Array;
			for(var i:uint=0;i<pieces.length;i++){
				if(pieces[i].stream==null){
					streamState.noStream.push(pieces[i].id);
				}else{
					streamState.haveStream.push(pieces[i].id);
				}
			}
			return streamState;
		}
		
		public function clear():void{
			MZDebugger.rectTrace({"type":"blockClear","blockID":this.id,"pieceID":0});
			id=0;pieceSize=128*1024;pieces=new Vector.<Piece>;
			duration=0;checksum=0;_isAllDataAssign=false;
		}
		
	}
}