package lee.utils{
	public final class RandomUtil{
		public function RandomUtil() {
			throw new Error("RandomUtil类无需实例化！");
		}
		//获取一个随机的布尔值
		public static  function get boolean():Boolean {
			return Math.random()<0.5;
		}
		//获取一个随机的正负波动值
		public static  function get wave():int {
			return boolean?1:-1;
		}
		//在一个范围内获取一个随机数值，返回结果大于等于较小的数值，小于较大的数值
		public static  function number(min:Number=0,max:Number=100):Number {
			return (min<=max)?(min+Math.random()*(max-min)):(max+Math.random()*(min-max));
		}
		//在一个范围内获取一个随机整数值，返回结果大于等于较小的整数值，小于等于较大的整数值
		public static  function integer(min:int=0,max:int=100):int {
			return (min<=max)?Math.floor(min+Math.random()*(max+1-min)):Math.floor(max+Math.random()*(min+1-max));
		}
		//获取一个随机的颜色值
		public static  function color(rmin:uint=0,rmax:uint=255,gmin:uint=0,gmax:uint=255,bmin:uint=0,bmax:uint=255):uint{
			rmin=(rmin>=0&&rmin<=255)?rmin:0;
			rmax=(rmax>=0&&rmax<=255)?rmax:255;
			gmin=(gmin>=0&&gmin<=255)?gmin:0;
			gmax=(gmax>=0&&gmax<=255)?gmax:255;
			bmin=(bmin>=0&&bmin<=255)?bmin:0;
			bmax=(bmax>=0&&bmax<=255)?bmax:255;
			
			return integer(rmin,rmax)<<16|integer(gmin,gmax)<<8|integer(bmin,bmax);
		}
		//获取指定位数的随机字符串，默认随机范围为数字+大小写字母，也可以指定范围，格式：a-z,A-H,5-9
		public static  function string(len:int=1,str:String="0-9,A-Z,a-z"):String {
			var arr:Array=[];
			var tmparr:Array=str.split(",");
			for (var i:int=0;i<tmparr.length;i++)
			{
				var exparr:Array=tmparr[i].split("-");
				var min:int=String(exparr[0]).charCodeAt();
				var max:int=String(exparr[1]).charCodeAt();
				for(var j:int=min;j<=max;j++)
				{
					arr.push(String.fromCharCode(j));
				}
			}
			var ret:String="";
			for (var k:int=0;k<len;k++)
			{
				ret+=arr[Math.floor(number(0,arr.length))];
			}
			return ret;
		}
		//在多个范围内获取一个随机数值
		public static  function numberRanges(...args):Number {
			var len:int=args.length;
			if (len%2!=0||len==0)
			{
				throw new Error("参数错误！无法获取指定范围！");
			}
			var index:int=rangesIndex(args);
			return number(Number(args[index]),Number(args[index+1]));
		}
		//在多个范围内获取一个随机整数值
		public static  function integerRanges(...args):int {
			var len:int=args.length;
			if (len%2!=0||len==0)
			{
				throw new Error("参数错误！无法获取指定范围！");
			}
			var index:int=rangesIndex(args);
			return integer(int(args[index]),int(args[index+1]));
		}
		//================================================================================
		//在多个范围中根据范围大小随机获得一个目标范围的起始索引
		private static  function rangesIndex(args:Array):int{
			var len:int=args.length;
			var total:Number=0;
			var tmparr:Array=[];
			for (var i:int=0;i<len/2;i++)
			{
				var dvalue:Number=Math.abs(Number(args[i*2+1])-Number(args[i*2]));
				
				total+=dvalue;
				tmparr.push(dvalue);
			}
			var ran:Number=total*Math.random();
			var rvalue:Number=0;
			var index:int=-1;
			var tmparrlen:int=tmparr.length;
			for (var j:int=0;j<tmparrlen;j++)
			{
				rvalue+=tmparr[j];
				if(rvalue>ran)
				{
					index=j;
					break;
				}
			}
			return index*2;
		}
    }
}