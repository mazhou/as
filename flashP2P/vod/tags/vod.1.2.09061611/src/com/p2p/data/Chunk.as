package com.p2p.data
{
	import flash.utils.ByteArray;
	
	import flash.utils.getTimer;
	
	public class Chunk
	{
		
		private var _data:ByteArray;   //flv的2进制数据
		private var _from:String;      //数据来源http或p2p
		private var _peerID:String;    //如果收到过p2p数据，保存该数据是从哪个邻居收到的
		private var _id:uint;          //数据的索引值
		private var _begin:Number=0;     //数据开始索取时的时间
		private var _end:Number=0;       //获得数据时的时间
		private var _share:Number=0.1; //被分享的次数
		private var _iLoadType:uint=0; //该chunk目前的状态 ：0为未调度； 1为http调度； 2为p2p调度 ；3为已经有正确数据
		/*
		为统计方块提供不同权重的等级，试方块呈现出不同颜色
		*/
		public function getShareLevel():int
		{
			var N:int = int(_share);
			switch(N)
			{
				case 0: return 0; break;
				case 1: return 1; break;
				case 2: return 2; break;
				case 3: return 3; break;
				case 4: return 4; break;
				case 5: return 5; break;
				case 6: return 6; break;
				case 7: return 7; break;
				case 8: return 8; break;
				default: return 9; break;
			}
			//
			return 0;
		}
		/*
		返回权重值：被分享次数/数据存在时间
		*/
		public function getWeightValue():Number
		{
			var _timer:Number=Math.floor((new Date()).time)
			return _share/(_timer-_end);
		}
		public function set iLoadType(i:uint):void
		{
			_iLoadType=i;
		}
		public function get iLoadType():uint
		{
			return _iLoadType;
		}
				
		public function set data(_ByteArray:ByteArray):void
		{
			_data=_ByteArray;
		}
		public function get data():ByteArray
		{
			return _data;
		}
		public function set from(_str:String):void
		{
			_from=_str;
		}
		public function get from():String
		{
			return _from;
		}
		public function set peerID(_str:String):void
		{
			_peerID=_str;
		}
		public function get peerID():String
		{
			return _peerID;
		}
		public function set id(_i:uint):void
		{
		    _id=_i;
		}
		public function get id():uint
		{
			return _id;
		}
		public function set begin(_w:Number):void
		{
			_begin=_w;
		}
		public function get begin():Number
		{
			return _begin;
		}
		public function set end(_w:Number):void
		{
			_end=_w;
		}
		public function get end():Number
		{
			return _end;
		}
		public function set share(_s:Number):void
		{
			_share=_s;
		}
		public function get share():Number
		{
			return _share;
		}
				
		public function Chunk()
		{
			clear();
			_share=0.1;
		}
		public function clear():void
		{
			if(_data)
			{
				_data.clear();
			}			
			_data=null;
			_from="";
			_peerID="";
			_id=0;
			_begin=0;
			_end=0;
			_share=0.1;
			_iLoadType=0;
		}
	}
}