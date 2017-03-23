package com.mzStudio.component
{
	/**
	 * This class groups a couple of commonly used string operations.
	 * @author Jeroen Wijering
	 **/
	public class Strings {
		
		/**
		 * Unescape a string and filter "asfunction" occurences ( can be used for XSS exploits).
		 *
		 * @param str	The string to decode.
		 * @return 		The decoded string.
		 **/
		public static function decode(str:String):String {
			if (str.indexOf('asfunction') == -1) {
				return unescape(str);
			} else {
				return '';
			}
		}
		
		/**
		 * Convert a number to a digital-clock like string.
		 *
		 * @param nbr	The number of seconds.
		 * @return		A MN:SS string.
		 **/
		public static function digits(nbr:Number):String {
			var min:Number = Math.floor(nbr / 60);
			var sec:Number = Math.floor(nbr % 60);
			var str:String = Strings.zero(min) + ':' + Strings.zero(sec);
			return str;
		}
		public static function digits2(t:Number):String{
			
			var hours:int=0;
			var minutes:int=0;
			var seconds:int=0;
			var s:String="";
			try{
				t=Math.floor(t);
				s="";
				hours=int(t/3600);
				minutes=int(t/60-hours*60);
				seconds=int(t%60);
				if(hours<10){
					s=s.concat("0"+String(hours)+":");
				}else{
					s=s.concat(String(hours)+":");
				}
				if(minutes<10){
					s=s.concat("0"+String(minutes)+":");
				}else{
					s=s.concat(String(minutes)+":");
				}
				if(seconds<10){
					s=s.concat("0"+String(seconds));
				}else{
					s=s.concat(String(seconds));
				}
			}catch(e:Error){
			}
			return s;
		}
		/**
		 * Convert a time-representing string to a number.
		 *
		 * @param str	The input string. Supported are 00:03:00.1 / 03:00.1 / 180.1s / 3.2m / 3.2h
		 * @return		The number of seconds.
		 **/
		public static function seconds(str:String):Number {
			str = str.replace(',', '.');
			var arr:Array = str.split(':');
			var sec:Number = 0;
			if (str.substr(-1) == 's') {
				sec = Number(str.substr(0, str.length - 1));
			} else if (str.substr(-1) == 'm') {
				sec = Number(str.substr(0, str.length - 1)) * 60;
			} else if (str.substr(-1) == 'h') {
				sec = Number(str.substr(0, str.length - 1)) * 3600;
			} else if (arr.length > 1) {
				sec = Number(arr[arr.length - 1]);
				sec += Number(arr[arr.length - 2]) * 60;
				if (arr.length == 3) {
					sec += Number(arr[arr.length - 3]) * 3600;
				}
			} else {
				sec = Number(str);
			}
			return sec;
		}
		
		/**
		 * Basic serialization: string representations of booleans and numbers are returned typed;
		 * strings are returned urldecoded.
		 *
		 * @param val	String value to serialize.
		 * @return		The original value in the correct primitive type.
		 **/
		public static function serialize(val:String):Object {
			if (val == null) {
				return null;
			} else if (val == 'true') {
				return true;
			} else if (val == 'false') {
				return false;
			} else if (isNaN(Number(val)) || val.length > 5) {
				return val;
			} else {
				return Number(val);
			}
		}
		
		/**
		 * Strip HTML tags and linebreaks off a string.
		 *
		 * @param str	The string to clean up.
		 * @return		The clean string.
		 **/
		public static function strip(str:String):String {
			var tmp:Array = str.split("\n");
			str = tmp.join("");
			tmp = str.split("\r");
			str = tmp.join("");
			var idx:Number = str.indexOf("<");
			while (idx != -1) {
				var end:Number = str.indexOf(">", idx + 1);
				end == -1 ? end = str.length - 1 : null;
				str = str.substr(0, idx) + " " + str.substr(end + 1, str.length);
				idx = str.indexOf("<", idx);
			}
			return str;
		}
		
		/**
		 * Add a leading zero to a number.
		 *
		 * @param nbr	The number to convert. Can be 0 to 99.
		 * @ return		A string representation with possible leading 0.
		 **/
		public static function zero(nbr:Number):String {
			if (nbr < 10) {
				return '0' + nbr;
			} else {
				return '' + nbr;
			}
		}
		/**
		 * Finds the extension of a filename or URL 
		 * @param filename 	The string on which to search
		 * @return 			Everything trailing the final '.' character
		 * 
		 */
		public static function extension(filename:String):String {
			if (filename.lastIndexOf(".") > 0) {
				return filename.substring(filename.lastIndexOf(".")+1, filename.length).toLowerCase();
			} else {
				return "";
			}
		}
		
		public static function main(filename:String):String
		{
			var dot:int = filename.lastIndexOf('.');
			return filename.substring(filename.lastIndexOf('/') + 1, dot >= 0 ? dot : filename.length);
		}
		
		/**
		 * Recursively creates a string representation of an object and its properties.
		 * 
		 * @param object The object to be converted to a string.
		 */
		public static function print_r(object:Object):String {
			var result:String = "";
			if (typeof(object) == "object") {
				result += "{";
			}
			for (var property:Object in object) {
				if (typeof(object[property]) == "object") {
					result += property + ": ";
				} else {
					result += property + ": " + object[property];
				}
				result += print_r(object[property]) +  ", ";
			}
			
			if (result != "{"){
				result = result.substr(0, result.length - 2);
			}
			
			if (typeof(object) == "object") {
				result += "}";
			}
			
			return result;
		}
		
	}
}