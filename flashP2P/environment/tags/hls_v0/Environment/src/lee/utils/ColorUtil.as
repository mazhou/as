package lee.utils{
	public final class ColorUtil{
		public function ColorUtil() {
			throw new Error("ColorUtil类无需实例化！");
		}
		//获取一个RGB颜色
		public static function rgb(r:uint,g:uint,b:uint):uint{
			return r<<16|g<<8|b;
		}
		//获取RGB颜色中的红色值
		public static function rgbRed(rgb:uint):uint {
			return rgb>>16;
		}
		//获取RGB颜色中的绿色值
		public static function rgbGreen(rgb:uint):uint {
			return rgb>>8&0xFF;
		}
		//获取RGB颜色中的蓝色值
		public static function rgbBlue(rgb:uint):uint {
			return rgb&0xFF;
		}
		//=======================================================================
		//获取RGB的反色
		public static function rgbInvert(rgb:uint):uint{
			return ColorUtil.rgb(255-rgbRed(rgb),255-rgbGreen(rgb),255-rgbBlue(rgb));
		}
		//获取RGB的补色
		public static function rgbComplement(rgb:uint):uint{
			var r:uint=rgbRed(rgb);
			var g:uint=rgbGreen(rgb);
			var b:uint=rgbBlue(rgb);
			var max:uint=Math.max(r,g,b);
			var min:uint=Math.min(r,g,b);
			return ColorUtil.rgb(max+min-r,max+min-g,max+min-b);
		}
		//将rgb1平均过渡到rgb2,steps表示过渡的步幅
		public static function rgbTransit(rgb1:uint,rgb2:uint,steps:uint):Array{
			if(steps>2)
			{
				var ret:Array=new Array();
				ret.push(rgb1);
				var r:uint=rgbRed(rgb1);
				var g:uint=rgbGreen(rgb1);
				var b:uint=rgbBlue(rgb1);
				var len:int=steps-1;
				var rav:Number=(rgbRed(rgb2)-r)/len;
				var gav:Number=(rgbGreen(rgb2)-g)/len;
				var bav:Number=(rgbBlue(rgb2)-b)/len;
				for(var i:int=1;i<len;i++)
				{
					ret.push(ColorUtil.rgb(uint(r+rav*i),uint(g+gav*i),uint(b+bav*i)));
				}
				ret.push(rgb2);
				return ret;
			}
			else
			{
				return new Array(rgb1,rgb2);
			}
		}
		//=======================================================================
		//获取一个ARGB颜色
		public static function argb(a:uint,r:uint,g:uint,b:uint):uint{
			return a<<24|r<<16|g<<8|b;
		}
		//获取ARGB颜色中的Alpha值
		public static function argbAlpha(argb:uint):uint {
			return argb>>24;
		}
		//获取ARGB颜色中的红色值
		public static function argbRed(argb:uint):uint {
			return argb>>16&0xFF;
		}
		//获取ARGB颜色中的绿色值
		public static function argbGreen(argb:uint):uint {
			return argb>>8&0xFF;
		}
		//获取ARGB颜色中的蓝色值
		public static function argbBlue(argb:uint):uint {
			return argb&0xFF;
		}
    }
}