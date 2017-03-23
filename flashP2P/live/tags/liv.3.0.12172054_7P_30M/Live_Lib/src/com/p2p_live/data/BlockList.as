package com.p2p_live.data
{
	import com.mzStudio.mzStudioDebug.MZDebugger;

	public class BlockList
	{
		/**按照服务器创建时间块，按时间早晚正序排列，如5点排在6点之前*/
		private var _blocks:Vector.<Block>=null;
		
		private var _needDataList:Object=null
		private var _memoryLength:uint=0;
		private var _pieceSize:uint=0;
		private var _playBlock:Block;
		
		public function get blocks():Vector.<Block>
		{
			return _blocks;
		}
		
		public function get NeedData():Object
		{
			return _needDataList;
		}
		/**获得Piece总和*/
		private var pieceSum:int=0;
		
		/**
		 * BlockList为构建函数，如果没有给memoryLength和pieceSize赋值，其他功能都不生效
		 * @param memoryLength 内存容量，以字节为单位
		 * @param pieceSize 每片容量，以字节为单位
		 * 
		 */
		public function BlockList(memoryLength:uint,pieceSize:uint)
		{
			_memoryLength=memoryLength;
			_pieceSize=pieceSize;
			pieceSum=Math.floor(memoryLength/pieceSize);
			_blocks=new Vector.<Block>();
			_needDataList=new  Object;
		}
		
		/**
		 * 请求desc后处理，每次添加块时，会依据块的服务器的时间按序添加到对应的列中，示例
		 * <listing>
		 * var block:Block=new Block();
		 * block.id=...;
		 * block.size=...;
		 * block.checksum=...;
		 * block.duration=...;
		 * block.creatTime=...;
		 * blockList.addBlock(block);
		 * </listing> 
		 * @param block 添加块
		 * 
		 */
		public function addBlock(block:Block):void
		{
			if(pieceSum==0){MZDebugger.trace(this,"是否没有构建BlockList函数"); return;}
			
			if(block.needDataList==null){
				block.needDataList=_needDataList;
			}
			
			block.pieceSize=_pieceSize;
			var i:int=0;
			var bool:Boolean=false;
			//判断是否添加过该块
			for(i=_blocks.length-1;i>=0;i--){
				if(_blocks[i].id==block.id){
					return;
				}
			}
			
			//判断该块是否高于最大时间，或没有块时处理，以节省运算成本
			if(_blocks.length==0||block.creatTime>_blocks[_blocks.length-1].creatTime){
				_blocks.push(block);
			}else {
				if(block.creatTime<_blocks[0].creatTime){
					_blocks.splice(0,0,block);
				}
				//只有一块的情况
				if(_blocks.length==1){
					_blocks.splice(0,0,block);
				}else{
					for(i=_blocks.length-1;i>=1;i--){
						if(block.creatTime>_blocks[i-1].creatTime&&block.creatTime<_blocks[i].creatTime){
							_blocks.splice(i,0,block);
							break;
						}
					}
				}
			}
		}
		
		/**
		 * 下载.dat或.header使用或用于其他，示例
		 * <listing>
		 * var block:Block=blockList.getBlock("1354509880_6920_818214.dat");
		 * </listing> 
		 * <ul>
		 * <li>如添加块流:block.addBlockStream=(byteArray);</li>
		 * <li>返回关于块中的片是否有流数据的id:var streamState:StreamState=block.getPieceAboutStream();
		 * trace(streamState.noStream);
		 * trace(streamState.haveStream);
		 * </li>
		 * <li>如添加片流:block.setPieceElementStream(i,block.getPieceElement(0).stream);</li>
		 * <li>如获得片:var piece:Piece=block.getPieceElement(0);</li>
		 * <li>如获得片:var stream:ByteArray=block.getPieceElement(0).stream;</li>
		 * </ul>
		 * @param id
		 * @return 
		 * 
		 */
		public function getBlock(id:uint):Block{
			if(pieceSum==0){MZDebugger.trace(this,"是否没有构建BlockList函数"); return null;}
			var i:int=0;
			for(i=_blocks.length-1;i>=0;i--){
				if(id==_blocks[i].id){
					return _blocks[i];
				}
			}
			return null;
		}
		
		
		/**
		 *	依据当前播放的视频块id获得视频下一个块，并校验是否是要播放的 下一个块视频
		 * @param id
		 * @return
		 * 
		 */
		public function getNextBlock(id:uint):Block{
			if(pieceSum==0){MZDebugger.trace(this,"是否没有构建BlockList函数"); return null;}
			var i:int=0;
			var currentID:int=0;
			for(i=_blocks.length-1;i>=0;i--){
				if(id==_blocks[i].id){
					currentID=i;
					break;
				}
			}
			if(currentID+1==_blocks.length){
				return null;
			}else{
				return _blocks[currentID+1];
			}
			
			return null;
		}
		
		/**
		 *超出内存片，离播放位置绝对值大的块被淘汰
		 * @param block 当前播放的block
		 * @return 
		 * 
		 */
		public function eliminate(playBlock:Block):int
		{
			MZDebugger.rectTrace({"type":"blockPlay","blockID":playBlock.id});
			_playBlock=playBlock;
			var len:int=_blocks.length;
			var currentID:int=_blocks.length-1;
			var i:int=0;
			var countPiece:int=0;
			
			for(i=_blocks.length-1;i>=0;i--){
				if(playBlock.id==_blocks[i].id){
					currentID=i;
				}
				countPiece+=_blocks[i].pieces.length;
//				trace("_blocks[i].pieces"+_blocks[i].pieces.length);
//				countPiece+=(_blocks[i].getPieceAboutHasStream() as StreamState).haveStream.length;
//				countPiece+=(_blocks[i].getPieceAboutHasStream() as StreamState).noStream.length;
			}
			
			if(countPiece<=pieceSum){
				return -1;
			}
			else
			{
				if(_blocks[0].id < playBlock.id)
				{
					_blocks[0].deleteAllNeedDataList();
					return (_blocks.shift() as Block).id;
				}
				
				if(_blocks[_blocks.length-1].id-60*60>this._playBlock.id){
					_blocks[_blocks.length-1].deleteAllNeedDataList();
					return (_blocks.pop() as Block).id;
				}
				/*if(_blocks.length<=2*currentID){
					//删除队前
					trace("q "+(_blocks.pop() as Block).id);
					return (_blocks.shift() as Block).id;
				}else{
					//删除队尾
					trace("w "+(_blocks.pop() as Block).id);
					return (_blocks.pop() as Block).id;
				}*/
			}
			return -1;
		}
		
		public function getAllPieceAboutHasStream():Object
		{
			var pieces:Vector.<Piece>=new Vector.<Piece>;
			var i:int=0;
			var j:int=0;
			var max:int=900;
			var count:int=0;
			for(i=_blocks.length-1;i>=0;i--){
				
				for(j=_blocks[i].pieces.length-1;j>=0;j--){
					count++;
					pieces.push({
						"playid": _playBlock.id,
						"blockid": _blocks[i].id,
						"pieceid":_blocks[i].pieces[j].id,
						"iLoadType":_blocks[i].pieces[j].iLoadType,
						"share:":_blocks[i].pieces[j].share,
						"haveData":(_blocks[i].pieces[j].stream.length>0)
						})
					if(count>=max){
						break;
					}
				}
				if(count>=max){
					break;
				}
			}
			return pieces;
		}
		
		/**获得播放点之后有流的数据 */
		public function getPlayHeadAfterData(id:uint):Vector.<Object>{
			if(_blocks.length==0){
				return null;
			}
			if(/*id<_blocks[0].id ||*/ id >= _blocks[_blocks.length-1].id){
				return null;
			}
			
			var i:int=0;
			var j:int=0;
			for(i=_blocks.length-1;i>=1;i--){
				if(/*id<=_blocks[i].id && */id>=_blocks[i-1].id){
					break;
				}
			}
			/*if(i==_blocks.length-1){return null;}else{if(playBlock.id==_blocks[i].id){i++;}}*/
			var obj:Vector.<Object>=new Vector.<Object>();
			var wangData:Object=null;
			//var debugStr:String="";
			for(i;i<_blocks.length;i++){
				for(j=0;j<_blocks[i].pieces.length;j++){
					if(_blocks[i].pieces[j].iLoadType==3){
						wangData=new Object();
						wangData.blockID=_blocks[i].id;
						wangData.pieceID=_blocks[i].pieces[j].id;
						//debugStr+=wangData.blockID+"_"+wangData.pieceID+"\n";
						//
						wangData.cs = _blocks[i].checksum;
						//
						obj.push(wangData);
					}
				}
			}
			//trace("播放头之后的数据："+debugStr);
			return obj;
		}
		
		/**
		 * 获得想要的数据，该方法依据远程节点的wantdata类型数组数据和自身_needDataList做交集，
		 * 在交集中获得离播放点最近的指定个数的wantdata数据，索取流
		 * @param remoteHaveData 远程所拥有本地的数据
		 * @param farID 远程节点
		 * @param wantCount 期望想要返回的最大可能数据流，默认是3块
		 * @return 
		 * 返回对象，对象中的类型是wantdata类型
		 */
		public function getWantPiece(remoteHaveData:Vector.<Object>,farID:String,wantCount:int=3):Vector.<Object>{
			var i:int=0;
			var j:int=0;
			var count:int=0;
			var obj:Vector.<Object>=new Vector.<Object>();
			var id:String="";
			//var debugStr1:String="";
			//var debugStr2:String="";
			for(i;i<remoteHaveData.length;i++){
				if(remoteHaveData[i].blockID<=_playBlock.id){
					//播放器之前的数据不索取
					continue;
				}else{
					id=remoteHaveData[i].blockID+"_"+remoteHaveData[i].pieceID;
					//debugStr1+=id+"\n";
					if(_needDataList.hasOwnProperty(id))
					{
						if(getBlock(remoteHaveData[i].blockID))
						{
							if(getBlock(remoteHaveData[i].blockID).pieces[remoteHaveData[i].pieceID].iLoadType == 3)
							{
								//当已经下载了数据，不进行数据请求
								continue;
							}
						}
						if(_needDataList[id]["remoteID"]!="")
						{
							//分配了p2p索要的数据 ，将不在分配出去
							continue;
						}
						//debugStr2+=id+"\n";
						//分配 p2p数据，记录分配的时间和远程地址，
						//其中时间在定长后，将等待重新分配，其中farID表示是否分配了索要数据
						trace("申请数据 = "+remoteHaveData[i].blockID+"_"+remoteHaveData[i].pieceID+"  _needDataList = "+_needDataList[id])
						_needDataList[id]["remoteID"]=farID;
						_needDataList[id]["beginTime"]=(new Date()).time;
						obj.push(remoteHaveData[i]);
						count++;
						if(count==wantCount){
							break;
						}
					}
				}
			}
			//trace("播放头：\n"+_playBlock.id);
			//trace("远端有数据：\n"+debugStr1);
			//trace("索要的数据：\n"+debugStr2);
			//debugStr2="";
			//for(var p:String in _needDataList){
				//debugStr2+=p+"\n";
			//}
			//trace("所有需要的数据：\n"+debugStr2);
			return obj;
		}
		
		/**
		 * 每个数据要么在等待分配任务队列，要么在获得任务等待获取数据队列，
		 * 每个remote定时检查等待的切片是否获得数据，如果超时将废弃获取数据队列，列入等待分配任务队列
		 * @param farID 检查对应的远程服务器
		 * @param clear 如果为true，强制执行进入等待分配任务队列
		 * @param removeHaveClear 如果为true，表示对应的远程客户端将该数据已经删除，_needDataList中的对应的数据应该等待再次分配
		 */
		public function handlerTimeOutWantPiece(farID:String,clear:Boolean=false,farRemoveHave:Boolean=false):void{
			var time:Number=(new Date()).time;
			for each(var wantData:WantData in _needDataList)
			{
				if(wantData.remoteID==farID){
					if(clear){
						wantData.remoteID="";
						wantData.beginTime=0;
						continue;
					}
					if(Math.floor((time-wantData.beginTime)/1000)>10 || farRemoveHave){
						wantData.remoteID="";
						wantData.beginTime=0;
					}
				}
			}
		}
		
		/**清除needList数据*/		
		public function clearNeedData():void
		{
			for(var p:* in _needDataList){
				delete _needDataList[p];
			}
			
			_needDataList=new Object;
		}
		
		public function clear():void
		{
			try{
				_blocks=null;
			}catch(err:Error){
				MZDebugger.trace(this,"1:"+err.getStackTrace());
			}
			try{
			_blocks=new Vector.<Block>();
			}catch(err:Error){
				MZDebugger.trace(this,"2:"+err.getStackTrace());
			}
			_memoryLength=0;
			_pieceSize=0;
		}
	}
}