package com.p2p.data
{
	//import com.mzStudio.mzStudioDebug.MZDebugger;
	
	import flash.utils.ByteArray;
	
	import protocol.Protocol;
	
	public class Chunks
	{
		protected var _chunksObject:Object;//-----真正存放数据的对象
		protected var _cloneChunksObject:Object;//-----真正存放数据的对象
		protected var _maxChunks:uint;	     //-----内存容量允许的最大chunk数量
		public function Chunks(mMemoryLength:uint,mChunkSize:uint)
		{
			_maxChunks = uint(Math.floor(mMemoryLength/mChunkSize));
			_chunksObject = new Object();			
		}
		public function get chunksObject():Object
		{
			return _chunksObject;
		}
		/*
		根据传入的索引值，取得与索引相对应chunk
		*/
		public function getChunk(index:uint):Chunk
		{
            return _chunksObject[index];
		}		
		/*
		淘汰算法
		*/
		public function eliminate(playHead:uint):int
		{
			var nMinValue:Number = Number.MAX_VALUE ;
			var index:uint = 0;
			var numberChunk:uint = 0;
			var sumChunk:uint = 0;
			var theMaxIdx:uint = 0;//有数据的chunk中最大的那个idx
			
			for(var i:String in _chunksObject)
			{
			  var chunk:Chunk = _chunksObject[i] as Chunk;
			  if (chunk.id < playHead)
			  {
				  //trace("_chunk.iLoadType  "+_chunk.iLoadType)
				  if(chunk.iLoadType != 3)
				  {
					  //将播放点之前，没有数据但已经分配了下载任务的chunk从_chunksObject中删除
					  removeChunk(uint(i));
					  continue;
				  }
			
				  var nWeightValue:Number = chunk.getWeightValue();
				  if(nMinValue > nWeightValue)
				  {
					  nMinValue = nWeightValue;
					  index = uint(i);
				  }
				  numberChunk++;	
				  
			  }
			  //整个chunks中统计那些有数据的chunk数量，并保存最后一个chunk的idx
			  if(chunk.iLoadType == 3)
			  {
				  sumChunk++;
				  theMaxIdx = uint(i);
			  }
			}
			//
			//trace("playHead = "+playHead+"  numberChunk = "+numberChunk+"  sumChunk = "+sumChunk+"  _maxChunks = "+_maxChunks)
			if (sumChunk >= _maxChunks)//播放点前的没有淘汰，需要淘汰的是播放点后面的数据
			{
				if(nMinValue !=Number.MAX_VALUE)
				{
					//trace("播放点之前淘汰 = "+index);
					removeChunk(index);
					return index;
				}
			}
			//trace("不需淘汰")
			return -1;//空间足够，不需要淘汰
			//
		}
	    /*
		向_chunksObject中添加数据
		*/
//		private var dateSize:Number=0;
		public function addChunk(obj:Object):void
		{
			//var temStr:String="";
			var chunk:Chunk = _chunksObject[obj.id];
			if (chunk == null)
			{
				chunk = new Chunk();
				_chunksObject[obj.id] = chunk;
			}
//			for(var p:* in _chunksObject){
//				temStr+=" "+_chunksObject[p].id;				
//			}
//			if(temStr.length>50){temStr=temStr.substr(0,100);}
//			//MZDebugger.trace(this,"addChunk"+(obj.id)+"_chunksObject:"+temStr);
//			if(temStr.length>50){temStr=""}
			
			chunk.id = obj.id;
			chunk.data = ByteArray(obj.data);
//			try{
//				if(chunk.data){
//					dateSize+=chunk.data.length;
//					//MZDebugger.customTrace(this,Protocol.DATASIZE,""+dateSize);
//				}
//			}catch(err:Error){
//			}
			chunk.from = String(obj.from);
			//
			if(obj.peerID != undefined)
			{
				chunk.peerID = obj.peerID;
			}
			//
			chunk.begin = Number(obj.begin);
			chunk.end   = Number(obj.end);
			chunk.iLoadType = obj.iLoadType;
	
		}
		/*
		当数据淘汰时从_chunksObject中删除数据
		*/
		public function removeChunk(index:uint):void
		{
			//MZDebugger.trace(this,"clear:"+index);
			_chunksObject[index].clear();
			delete _chunksObject[index];
		
		}
		public function clear():void
		{
			_maxChunks=0;
			for(var i:String in _chunksObject)
			{
				removeChunk(uint(i));
			}
			_chunksObject = null;
		}
	}
}