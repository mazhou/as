package lee.utils{
	public final class ArrayUtil{
		public function ArrayUtil() {
			throw new Error("ArrayUtil类无需实例化！");
		}
		//从一个开始位置向后搜索数组，如果项的属性值与要匹配的值全等(===)，就返回项的索引位置，如果没有匹配的项就返回-1 
		public static  function indexByField(arr:Array,field:String,value:*,fromIndex:int=0):int {
			var ret:int=-1;
			var len:int=arr.length;
			if(fromIndex<0)
			{
				fromIndex+=len;
			}
			for(var i:int=fromIndex;i<len;i++)
			{
				if(arr[i][field]===value)
				{
					ret=i;
					break;
				}
			}
			return ret;
		}
		//从一个开始位置向前搜索数组，如果项的属性值与要匹配的值全等(===)，就返回项的索引位置，如果没有匹配的项就返回-1 
		public static  function lastIndexByField(arr:Array,field:String,value:*,fromIndex:int=-1):int {
			var ret:int=-1;
			var len:int=arr.length;
			if(fromIndex<0)
			{
				fromIndex+=len;
			}
			for(var i:int=fromIndex;i>-1;i--)
			{
				if(arr[i][field]===value)
				{
					ret=i;
					break;
				}
			}
			return ret;
		}
    }
}