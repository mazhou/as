// ActionScript file
package com.p2p.utils.httpSocket
{
	import flash.utils.ByteArray;
	
	
	/**
	 *字符串工具
	 * 
	 */
	public class StringUtil
	{
		
		//忽略大小字母比较字符是否相等;
		public static function equalsIgnoreCase(char1:String, char2:String):Boolean
		{
			return char1.toLowerCase() == char2.toLowerCase();
		}
		
		//比较字符是否相等;
		public static function equals(char1:String, char2:String):Boolean
		{
			return char1 == char2;
		}
		
		//是否为Email地址;
		public static function isEmail(char:String):Boolean
		{
			if (char == null)
			{
				return false;
			}
			char=trim(char);
			var pattern:RegExp=/(\w|[_.\-])+@((\w|-)+\.)+\w{2,4}+/;
			var result:Object=pattern.exec(char);
			if (result == null)
			{
				return false;
			}
			return true;
		}
		
		//是否是数值字符串;
		public static function isNumber(char:String):Boolean
		{
			if (char == null)
			{
				return false;
			}
			return !isNaN(parseInt(char))
		}
		
		//是否为Double型数据;
		public static function isDouble(char:String):Boolean
		{
			char=trim(char);
			var pattern:RegExp=/^[-\+]?\d+(\.\d+)?$/;
			var result:Object=pattern.exec(char);
			if (result == null)
			{
				return false;
			}
			return true;
		}
		
		//Integer;
		public static function isInteger(char:String):Boolean
		{
			if (char == null)
			{
				return false;
			}
			char=trim(char);
			var pattern:RegExp=/^[-\+]?\d+$/;
			var result:Object=pattern.exec(char);
			if (result == null)
			{
				return false;
			}
			return true;
		}
		
		//English;
		public static function isEnglish(char:String):Boolean
		{
			if (char == null)
			{
				return false;
			}
			char=trim(char);
			var pattern:RegExp=/^[A-Za-z]+$/;
			var result:Object=pattern.exec(char);
			if (result == null)
			{
				return false;
			}
			return true;
		}
		
		//中文;
		public static function isChinese(char:String):Boolean
		{
			if (char == null)
			{
				return false;
			}
			char=trim(char);
			var pattern:RegExp=/^[\u0391-\uFFE5]+$/;
			var result:Object=pattern.exec(char);
			if (result == null)
			{
				return false;
			}
			return true;
		}
		
		//双字节
		public static function isDoubleChar(char:String):Boolean
		{
			if (char == null)
			{
				return false;
			}
			char=trim(char);
			var pattern:RegExp=/^[^\x00-\xff]+$/;
			var result:Object=pattern.exec(char);
			if (result == null)
			{
				return false;
			}
			return true;
		}
		
		//含有中文字符
		public static function hasChineseChar(char:String):Boolean
		{
			if (char == null)
			{
				return false;
			}
			char=trim(char);
			var pattern:RegExp=/[^\x00-\xff]/;
			var result:Object=pattern.exec(char);
			if (result == null)
			{
				return false;
			}
			return true;
		}
		
		//注册字符;
		public static function hasAccountChar(char:String, len:uint=15):Boolean
		{
			if (char == null)
			{
				return false;
			}
			if (len < 10)
			{
				len=15;
			}
			char=trim(char);
			var pattern:RegExp=new RegExp("^[a-zA-Z0-9][a-zA-Z0-9_-]{0," + len + "}$", "");
			var result:Object=pattern.exec(char);
			if (result == null)
			{
				return false;
			}
			return true;
		}
		
		//URL地址;
		public static function isURL(char:String):Boolean
		{
			if (char == null)
			{
				return false;
			}
			char=trim(char).toLowerCase();
			var pattern:RegExp=/^http:\/\/[A-Za-z0-9]+\.[A-Za-z0-9]+[\/=\?%\-&_~`@[\]\':+!]*([^<>\"\"])*$/;
			var result:Object=pattern.exec(char);
			if (result == null)
			{
				return false;
			}
			return true;
		}
		
		// 是否为空白;        
		public static function isWhitespace(char:String):Boolean
		{
			switch(char)
			{
				case " ":
				case "\t":
				case "\r":
				case "\n":
				case "\f":
					return true;
				default:
					return false;
			}
		}
		
		//去左右空格;
		public static function trim(char:String):String
		{
			if (char == null)
			{
				return null;
			}
			return rtrim(ltrim(char));
		}
		
		//去左空格; 
		public static function ltrim(char:String):String
		{
			if (char == null)
			{
				return null;
			}
			var pattern:RegExp=/^\s*/;
			return char.replace(pattern, "");
		}
		
		//去右空格;
		public static function rtrim(char:String):String
		{
			if (char == null)
			{
				return null;
			}
			var pattern:RegExp=/\s*$/;
			return char.replace(pattern, "");
		}
		
		//是否为前缀字符串;
		public static function beginsWith(char:String, prefix:String):Boolean
		{
			return (prefix == char.substring(0, prefix.length));
		}
		
		//是否为后缀字符串;
		public static function endsWith(char:String, suffix:String):Boolean
		{
			return (suffix == char.substring(char.length - suffix.length));
		}
		
		//去除指定字符串;
		public static function remove(char:String, remove:String):String
		{
			return replace(char, remove, "");
		}
		
		//字符串替换;
		public static function replace(char:String, replace:String, replaceWith:String):String
		{
			return char.split(replace).join(replaceWith);
		}
		
		//utf16转utf8编码;
		public static function utf16to8(char:String):String
		{
			var out:Array=new Array();
			var len:uint=char.length;
			for(var i:uint=0; i < len; i++)
			{
				var c:int=char.charCodeAt(i);
				if (c >= 0x0001 && c <= 0x007F)
				{
					out[i]=char.charAt(i);
				}
				else if (c > 0x07FF)
				{
					out[i]=String.fromCharCode(0xE0 | ((c >> 12) & 0x0F), 0x80 | ((c >> 6) & 0x3F), 0x80 | ((c >> 0) & 0x3F));
				}
				else
				{
					out[i]=String.fromCharCode(0xC0 | ((c >> 6) & 0x1F), 0x80 | ((c >> 0) & 0x3F));
				}
			}
			return out.join('');
		}
		
		//utf8转utf16编码;
		public static function utf8to16(char:String):String
		{
			var out:Array=new Array();
			var len:uint=char.length;
			var i:uint=0;
			while(i < len)
			{
				var c:int=char.charCodeAt(i++);
				switch(c >> 4)
				{
					case 0:
					case 1:
					case 2:
					case 3:
					case 4:
					case 5:
					case 6:
					case 7:
						// 0xxxxxxx
						out[out.length]=char.charAt(i - 1);
						break;
					case 12:
					case 13:
						// 110x xxxx   10xx xxxx
						var char2:int=char.charCodeAt(i++);
						out[out.length]=String.fromCharCode(((c & 0x1F) << 6) | (char2 & 0x3F));
						break;
					case 14:
						// 1110 xxxx  10xx xxxx  10xx xxxx
						var char3:int=char.charCodeAt(i++);
						var char4:int=char.charCodeAt(i++);
						out[out.length]=String.fromCharCode(((c & 0x0F) << 12) | ((char3 & 0x3F) << 6) | ((char4 & 0x3F) << 0));
						break;
				}
			}
			return out.join('');
		}
		
		public static function autoReturn(str:String, c:int):String
		{
			var l:int=str.length;
			if (l < 0)
				return "";
			var i:int=c;
			var r:String=str.substr(0, i);
			while(i <= l)
			{
				r+="\n";
				r+=str.substr(i, c);
				i+=c;
			}
			return r;
		}
		
		public static function limitStringLengthByByteCount(str:String, bc:int, strExt:String="..."):String
		{
			if (str == null || str == "")
			{
				return str;
			}
			else
			{
				var l:int=str.length;
				var c:int=0;
				var r:String="";
				for(var i:int=0; i < l; ++i)
				{
					var code:uint=str.charCodeAt(i);
					if (code > 0xffffff)
					{
						c+=4;
					}
					else if (code > 0xffff)
					{
						c+=3;
					}
					else if (code > 0xff)
					{
						c+=2;
					}
					else
					{
						++c;
					}
					
					if (c < bc)
					{
						r+=str.charAt(i);
					}
					else if (c == bc)
					{
						r+=str.charAt(i);
						r+=strExt;
						break;
					}
					else
					{
						r+=strExt;
						break;
					}
				}
				return r;
			}
		}
		
		public static function getCharsArray(targetString:String, hasBlankSpace:Boolean):Array
		{
			var tempString:String=targetString;
			if (hasBlankSpace == false)
			{
				tempString=trim(targetString);
			}
			return tempString.split("");
		}
		
		private static var CHINESE_MAX:Number = 0x9FFF;
		private static var CHINESE_MIN:Number = 0x4E00;
		
		private static var LOWER_MAX:Number = 0x007A;
		private static var LOWER_MIN:Number = 0x0061;
		
		private static var NUMBER_MAX:Number = 0x0039;
		private static var NUMBER_MIN:Number = 0x0030;
		
		private static var UPPER_MAX:Number = 0x005A;
		private static var UPPER_MIN:Number = 0x0041;
		/**
		 * 返回一段字符串的字节长度（汉字一个字占2，其他占1）
		 */
		public static function getStringBytes(str:String):int
		{
			return getStrActualLen(str);
			/*			var n:int=0;
			var l:int=str.length;
			for(var i:int=0; i < l; ++i)
			{
			var code:Number=str.charCodeAt(i);
			if (code >= CHINESE_MIN && code <= CHINESE_MAX)
			{
			n+=2;
			}
			else
			{
			++n;
			}
			}
			return n;*/
		}
		
		/**
		 * 按字节长度截取字符串（汉字一个字占2，其他占1）
		 */
		public static function substrByByteLen(str:String, len:int):String
		{
			if (str == "" || str == null)
				return str;
			var n:int=0;
			var l:int=str.length;
			for(var i:int=0; i < l; ++i)
			{
				var char:String=str.charAt(i);
				n += getStrActualLen(char);
				if (n > len)
				{
					str=str.substr(0, i - 1);
					break;
				}
			}
			return str;
		}
		
		/**
		 * 返回一段字符串的字节长度
		 */
		/*		public static function getStringByteLength(str:String):int
		{
		if (str == null)
		return 0;
		var t:ByteArray=new ByteArray();
		t.writeUTFBytes(str);
		return t.length;
		}*/
		
		public static function getStrActualLen(sChars:String) : int { 
			if (sChars == "" || sChars == null)
				return 0;
			else
				return sChars.replace(/[^\x00-\xff]/g,"xx").length; 
		}
		
		public static function isEmptyString(str:String):Boolean
		{
			return str == null || str == "";
		}
		
		private static var NEW_LINE_REPLACER:String=String.fromCharCode(6);
		
		public static function isNewlineOrEnter(code:uint):Boolean
		{
			return code == 13 || code == 10;
		}
		
		public static function removeNewlineOrEnter(str:String):String
		{
			str=replace(str, "\n", "");
			return replace(str, "\r", "");
		}
		
		/**
		 * 替换掉文本中的 '\n' 为 '\7'
		 */
		public static function escapeNewline(txt:String):String
		{
			return replace(txt, "\n", NEW_LINE_REPLACER);
		}
		
		/**
		 * 替换掉文本中的 '\7' 为  '\n'
		 */
		public static function unescapeNewline(txt:String):String
		{
			return replace(txt, NEW_LINE_REPLACER, "\n");
		}
		
		/**
		 * 判断哪些是全角字符,如果不含有返回空
		 */
		public static function judge(s:String):String
		{
			var temps:String="";
			var isContainQj:Boolean=false;
			for(var i:Number=0; i < s.length; i++)
			{
				//半角长度是一，特殊符号长度是三，汉字和全角长度是9
				if (escape(s.substring(i, i + 1)).length > 3)
				{
					temps+="'" + s.substring(i, i + 1) + "' ";
					isContainQj=true;
				}
			}
			if (isContainQj)
			{
				temps;
			}
			return temps;
		}
		
		/**
		 * 汉字、全角数字和全角字母都是双字节码，第一个字节的值减去160表示该字在字库中的区
		 码，第二个字节的值减去160为位码，如‘啊’的16进制编码为B0   A1，换算成十进制数就是
		 176和161，分别减去160后就是16和1，即‘啊’字的区位码是1601，同样数字和字母的区位
		 码也是如此，如‘0’是0316，‘1’是0317等，因此判断汉字及全角字符基本上只要看其连
		 续的两个字节是否大于160，至于半角字符和数字则更简单了，只要到ASCII码表中查一查就
		 知道了。
		 * //删除oldstr空格，把全角转换成半角
		 //根据汉字字符编码规则：连续两个字节都大于160，
		 //全角符号第一字节大部分为163
		 //～，全角空格第一字节都是161，不知道怎么区分？
		 * /
		/**
		 * 把含有的全角字符转成半角
		 */
		public static function changeToBj(s:String):String
		{
			if (s == null)
				return null;
			var temps:String="";
			for(var i:Number=0; i < s.length; i++)
			{
				if (escape(s.substring(i, i + 1)).length > 3)
				{
					var temp:String=s.substring(i, i + 1);
					if (temp.charCodeAt(0) > 60000)
					{
						//区别汉字
						var code:Number=temp.charCodeAt(0) - 65248;
						var newt:String=String.fromCharCode(code);
						temps+=newt;
					}
					else
					{
						if (temp.charCodeAt(0) == 12288)
							temps+=" ";
						else
							temps+=s.substring(i, i + 1);
					}
				}
				else
				{
					temps+=s.substring(i, i + 1);
				}
			}
			return temps;
		}
		
		/**
		 * 把含有的半角字符转成全角
		 */
		public static function changeToQj(s:String):String
		{
			if (s == null)
				return null;
			var temps:String="";
			for(var i:Number=0; i < s.length; i++)
			{
				if (escape(s.substring(i, i + 1)).length > 3)
				{
					var temp:String=s.substring(i, i + 1);
					if (temp.charCodeAt(0) > 60000)
					{
						//区别汉字
						var code:Number=temp.charCodeAt(0) + 65248;
						var newt:String=String.fromCharCode(code);
						temps+=newt;
					}
					else
					{
						temps+=s.substring(i, i + 1);
					}
				}
				else
				{
					temps+=s.substring(i, i + 1);
				}
			}
			return temps;
		}
		
		/**
		 * 在不够指定长度的字符串前补零
		 * @param str
		 * @param len
		 * @return
		 *
		 */
		public static function renewZero(str:String, len:int):String
		{
			var bul:String="";
			var strLen:int=str.length;
			if (strLen < len)
			{
				for(var i:int=0; i < len - strLen; i++)
				{
					bul+="0";
				}
				return bul + str;
			}
			else
			{
				return str;
			}
		}
		
		/**
		 * 检查字符串是否符合正则表达式
		 */
		public static function isUpToRegExp(str:String, reg:RegExp):Boolean
		{
			if (str != null && reg != null)
			{
				return str.match(reg) != null;
			}
			else
				return false;
		}
		
		/**
		 * 是否含有/0结束符的不正常格式的字符串
		 */
		public static function isErrorFormatString(str:String, len:int=0):Boolean
		{
			if (str == null || (len != 0 && str.length > len))
				return true;
			else
				return str.indexOf(String.fromCharCode(0)) != -1;
		}
		
		/**
		 * 返回格式化后的金钱字符串,如1000000 -> 1,000,000
		 */
		public static function getFormatMoney(money:Number):String
		{
			var moneyStr:String=money.toString();
			var formatMoney:Array=new Array();
			for(var index:Number=-1; moneyStr.charAt(moneyStr.length + index) != ""; index-=3)
			{
				if (Math.abs(index - 2) >= moneyStr.length)
					formatMoney.push(moneyStr.substr(0, moneyStr.length + index + 1));
				else
					formatMoney.push(moneyStr.substr(index - 2, 3));
			}
			formatMoney.reverse();
			return formatMoney.join(",");
		}
		
		/**
		 * 正整数转为中文数字
		 * 最大到十位
		 */		
		private static const ChineseNumberTable:Array = [0x96f6 ,0x4e00 ,0x4e8c ,0x4e09 ,0x56db ,0x4e94 ,0x516d ,0x4e03 ,0x516b ,0x4e5d ,0x5341];
		public static function uintToChineseNumber(u:uint):String {
			if (u <= 10) {
				return String.fromCharCode(ChineseNumberTable[u]);
			}
			else
				if (u < 20) {
					return String.fromCharCode(ChineseNumberTable[10], ChineseNumberTable[u - 10]);
				}
				else
					if (u < 100) {
						var t:uint = Math.floor(u / 10);
						var tt:uint = u % 10;
						if (tt > 0) {
							return String.fromCharCode(ChineseNumberTable[t], ChineseNumberTable[10], ChineseNumberTable[tt]);
						}
						else {
							return String.fromCharCode(ChineseNumberTable[t], ChineseNumberTable[10]);
						}
					}
					else {
						return "";
					}
		}
		
		/**
		 * 仿照C# 的 String.Format   {n}
		 * @param strFormat   Format-control string
		 * @param args
		 * @return 
		 * 
		 */		
		public static function format(strFormat:String, ...additionalArgs):String {
			var args:Array = additionalArgs;
			
			var reg:RegExp = /\{(\d+)\}/g;
			
			return strFormat.replace(reg, 
				function(strResult:String, strMatch:String, pos:int, strSource:String):String {
					return args[strMatch];
				});
		}
		
		public static const LV1_Split:String = ",";
		public static const LV2_Split:String = ":";
		/**
		 * 
		 * @param str		需要分析的字符串
		 * @param fnOnSplit	分析回调函数  fnOnSplit(str:String):void
		 * 
		 */		
		public static function lv1ParseString(str:String, fnOnSplit:Function):Boolean {
			if (str == null || str == "") {
				return false;
			}
			
			var r:Boolean = false;
			for each (var t:String in str.split(LV1_Split)) {
				fnOnSplit(t);
				r = true;
			}
			return r;
		}
		
		/**
		 * 
		 * @param str		需要分析的字符串
		 * @param fnOnSplit	分析回调函数  fnOnSplit(strSplits:Array<String>):void
		 * 
		 */		
		public static function lv2ParseString(str:String, fnOnSplit:Function):Boolean {
			if (str == null || str == "") {
				return false;
			}
			
			var r:Boolean = false;
			for each (var t:String in str.split(LV2_Split)) {
				if (t != null && t == "") {
					var a:Array = str.split(LV1_Split);
					if (a.length > 1) {
						fnOnSplit(a);
						r = true;
					}
					else {
						//return;
					}
				}
			}
			return r;
		}
		
		/**
		 * 
		 * @param infos				信息数组
		 * @param fnGetInfoString	fnGetInfoString(info:Object):String
		 * @return 
		 * 
		 */		
		public static function getLv1SplitString(infos:Array/*<Object>*/, fnGetInfoString:Function):String {
			if (infos == null || infos.length == 0) {
				return "";
			}
			
			var l:int = infos.length;
			var r:String = fnGetInfoString(infos[0]);
			var i:int = 1;
			while (i < l) {
				r += LV1_Split;
				r += fnGetInfoString(infos[i]);
				++i;
			}
			return r;
		}
		
		/**
		 * 
		 * @param infos				信息数组
		 * @param fnGetInfoString	fnGetInfoString(info:Object, strLv2Sep:String):String
		 * @return 
		 * 
		 */		
		public static function getLv2SplitString(infos:Array/*<Object>*/, fnGetInfoString:Function):String {
			if (infos == null || infos.length == 0) {
				return "";
			}
			
			var l:int = infos.length;
			var r:String = fnGetInfoString(infos[0], LV2_Split);
			var i:int = 1;
			while (i < l) {
				r += LV1_Split;
				r += fnGetInfoString(infos[i], LV2_Split);
				++i;
			}
			return r;
		}
		
		public function StringUtil()
		{
			throw new Error("StringUtil class is static container only");
		}
	}
}