package com.mzStudio.tool
{
	import com.carlcalderon.arthropod.Debug;
	import com.hexagonstar.util.debug.Debug;
	import com.mzStudio.component.Strings;
	import com.mzStudio.mzStudioDebug.MZDebugger;
	
	import flash.external.ExternalInterface;

//	import flash.net.LocalConnection;
	
	public class Debug
	{
		
		/**
		 * <UL>
		 * <LI>Debug.output(this,"hello", 1);</LI>
		 * <LI>Debug.output(this,true, 1);</LI>
		 * </UL>
		 */
		public static function output(className:Object,message:*, type:int = 1):void 
		{
			
			if (message == undefined||message is String) {
				send( className, message ,type);
			} else if (message is Boolean || message is Number){
				send(className,' (' + message.toString() + ')',type);
			} else if ( message is Array) {
				Debug.object(className,message, type);
			} else {
				Debug.object(className,message, type);
			}
		}
		private static function object(className:Object,message:Object, type:int=1):void {
			var txt:String = ' ('+Strings.print_r(message)+ ')';
			send(className,txt,type);
		}
		private static function send(obj:Object,message:String,type:int=1):void 
		{
			if(_debugType!=MONSTER||_debugType!=MZDebug){
				var date:Date=new Date();
				var timeMsg:String="["+date.fullYear+"-"+date.month+"-"+date.day+
					" "+date.getHours()+":"+date.getMinutes()+":"+date.getSeconds()+"."+date.milliseconds+"]";
				message=timeMsg+" "+obj.toString()+" "+message;
			}
			switch (_debugType) {
				case ARTHROPOD:
					switch (type) {
						case LEVEL_DEBUG:
							com.carlcalderon.arthropod.Debug.log(message,0x8000FF);
							break;
						case LEVEL_INFO:
							com.carlcalderon.arthropod.Debug.log(message)
							break;
						case LEVEL_WARN:
							com.carlcalderon.arthropod.Debug.warning(message);
							break;
						case LEVEL_ERROR:
							com.carlcalderon.arthropod.Debug.error(message);
							break;
						case LEVEL_FATAL:
							com.carlcalderon.arthropod.Debug.log(message,0xff0000)
							break;
					}
					break;
				case CONSOLE:
					if (ExternalInterface.available) {
						ExternalInterface.call('console.log', message);
					}
					break;
				case TRACE:
					trace(message);
					break;
				case ALCON:
					com.hexagonstar.util.debug.Debug.trace(message,type);
					break;
				case NONE:
					break;
				case MONSTER:
//					MonsterDebugger.trace(obj, message);
					break;
				case MZDebug:
					MZDebugger.trace(obj, message);
				default:
					break;
			}
			
		}
		/**
		 * 设置debug的输出类型
		 * @param param的值是
		 * Debug.ARTHROPOD Debug.CONSOLE Debug.NONE Debug.TRACE Debug.ALCON
		 */
		public static function setDebugType(param:String):void {
			_debugType = param;
		}
		public static function MonsterInit(className:Object):void{
			if(className!=null){
//				MonsterDebugger.initialize(className);
			}
		}
		
		/**debug 类型*/
		private static var _debugType:String=ALCON;
		
		/** The Debug.LEVEL_DEBUG constant defines the value of the Debug Filtering Level.*/
		public static const LEVEL_DEBUG:int	= 0;
		/**The Debug.LEVEL_INFO constant defines the value of the Info Filtering Level. */
		public static const LEVEL_INFO:int	= 1;
		/**The Debug.LEVEL_WARN constant defines the value of the Warn Filtering Level. */
		public static const LEVEL_WARN:int	= 2;
		/** The Debug.LEVEL_ERROR constant defines the value of the Error Filtering Level. */
		public static const LEVEL_ERROR:int	= 3;
		/** The Debug.LEVEL_FATAL constant defines the value of the Fatal Filtering Level. */
		public static const LEVEL_FATAL:int	= 4;
		
		/** Constant defining the Arthropod output type. **/
		public static const ARTHROPOD:String = "arthropod";
		/** Constant defining the Firefox/Firebug console output type. **/
		public static const CONSOLE:String = "console";
		/** Constant defining there's no output. **/
		public static const NONE:String = "none";
		/** Constant defining the Flash tracing output type. **/
		public static const TRACE:String = "trace";
		/** Constant defining the ALCON output type. **/
		public static const ALCON:String = "alcon";
		/** Constant defining the MONSTER output type. 
		 * <p></p>
		 * <code>
		 * Debug.MonsterInit(obj);
		 * obj:为舞台对象
		 * <p></p>
		 * Debug.output(obj,msg,type);
		 *  obj:为当前对象
		 *  msg：输出信息
		 *  type：不同等级显示颜色级别不一样
		 * </code>		 * 
		 * **/
		public static const MONSTER:String = "Monster";
		
		public static const MZDebug:String = "MZDebug";		
	}
}