package com.p2p_live.data
{
	import flash.utils.ByteArray;
	
	public class Chunks
	{
		protected var _chunksObject:Object;//-----真正存放数据的对象
		//protected var _maxChunks:uint;	     //-----内存容量允许的最大chunk数量
		protected var _mMemoryLength:uint  //-----允许使用的内存容量（字节）
		public function Chunks(mMemoryLength:uint,mChunkSize:uint)
		{
			_mMemoryLength = mMemoryLength;
			//_maxChunks = uint(Math.floor(mMemoryLength/mChunkSize));
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
			var index:uint = 0;        //播放点前面的chunk中权重值最小的idx（前面的>>----->>playHead>>-----后面的>>）
			var numberChunk:uint = 0;  //播放点前面的有数据的chunk的累积大小
			var sumChunk:uint = 0;     //所有有数据的chunk的大小
			var theMaxIdx:uint = 0;    //有数据的chunk中最大的那个idx
			
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
				  
				  numberChunk += chunk.dataLength;	
				  
			  }
			  //整个chunks中统计那些有数据的chunk数量，并保存最后一个chunk的idx
			  if(chunk.iLoadType == 3)
			  {
				  sumChunk += chunk.dataLength ;
				  if(theMaxIdx < chunk.id)
				  {
					  theMaxIdx = chunk.id;
				  }
			  }
			}
			//
			if(sumChunk >= _mMemoryLength)
			{
				if(nMinValue != Number.MAX_VALUE)
				{
					removeChunk(index);
					//trace(index)
					return index;
				}
			}
			//trace("playHead = "+playHead+"  numberChunk = "+numberChunk+"  sumChunk = "+sumChunk+"  _maxChunks = "+_maxChunks)
			/*if (sumChunk >= _maxChunks)//
			{
				if(nMinValue !=Number.MAX_VALUE)
				{
					//trace("播放点之前淘汰 = "+index);
					removeChunk(index);
					return index;
				}
			}*/
			//trace("不需淘汰")
			return -1;//空间足够，不需要淘汰
			//
		}
	    /*
		向_chunksObject中添加数据
		*/
		public function addChunk(obj:Object):void
		{
			//
			var chunk:Chunk = new Chunk();
			chunk.id =  uint(obj.id) ;
			chunk.data = ByteArray(obj.data);
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
			_chunksObject[obj.id] = chunk;	
	
		}
		/*
		当数据淘汰时从_chunksObject中删除数据
		*/
		public function removeChunk(index:uint):void
		{
			trace("removeChunk=",index)
			_chunksObject[index].clear();
			delete _chunksObject[index];
		
		}
		public function clear():void
		{
			//_maxChunks=0;
			for(var i:String in _chunksObject)
			{
				//trace("clear=",uint(i));
				removeChunk(uint(i));
			}
			_chunksObject = null;
		}
	}
}