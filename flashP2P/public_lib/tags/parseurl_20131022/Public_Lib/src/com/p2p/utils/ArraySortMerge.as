package com.p2p.utils
{
	public class ArraySortMerge
	{
		public function ArraySortMerge()
		{
			
		}
		
		public static function init(_arr:Array):Array
		{
			var i:int= 0;
			var j:int=0;
			for(i=0;i<_arr.length;i++)
			{
				for(j=i+1;j<_arr.length;j++)
				{
					if(_arr[i][0]>_arr[j][0])
					{
						var beginNum:Number=_arr[i][0];
						_arr[i][0]=_arr[j][0];
						_arr[j][0]=beginNum;
						
						var endNum:Number=_arr[i][1];
						_arr[i][1]=_arr[j][1];
						_arr[j][1]=endNum;
					}
					if(_arr[i][1]>=_arr[j][0])
					{
						if(_arr[i][1]>=_arr[j][1])
						{
							_arr.splice(j,1)
							j--;
						}
						else
						{
							_arr[i][1]=_arr[j][1];
							_arr.splice(j,1)
							j--;
						}
					}
				}
				
			}
			return _arr;
		}
	}
}