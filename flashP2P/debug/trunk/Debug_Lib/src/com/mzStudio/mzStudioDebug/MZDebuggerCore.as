package com.mzStudio.mzStudioDebug
{
	import com.mzStudio.event.EventExtensions;
	import com.mzStudio.util.DateFormat;
	
	import flash.external.ExternalInterface;
	import flash.system.Capabilities;
	import flash.system.System;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;
	import flash.utils.getQualifiedSuperclassName;

	internal class MZDebuggerCore
	{
		internal static function getInstance() : MZDebuggerCore {
			if ( instance == null ) instance = new MZDebuggerCore(new SingleTon() );
			return instance as MZDebuggerCore;
		}
		
		public function initialize():void
		{
			_monitorTime = new Date().time;
		}
		public function rectTrace(object:*):void
		{
			var data:Object = {
				"command":	MZDebuggerConstants.COMMAND_RECT_TRACE,					
				"rects":		object
			};
			// Send the data
			send(data,true);
		}
		public function customTrace(caller:*, key:String,value:*, color:uint = 0xffffff):void
		{
//			if(key.length>100){
//				key=key.substr(0,100)+"..."
//			}
//			if((value is String)&& (value.length>100)){
//				value=value.substr(0,80)+"..."+value.substr(value.length-20,20)
//			}
			var data:Object = {
				"command":	MZDebuggerConstants.COMMAND_CUSTOM_TRACE,
				"key":			key,
				"value":		value,
				"color":		color
			};
			// Send the data
			send(data,true);
		}
		public function trace(caller:*, object:*, person:String = "", color:uint = 0x000000):void{
//			if(object is String&&object.length>100){
//				object=object.substr(0,80)+"..."+object.substr(object.length-20,20);
//			}
			var data:Object = {
					"command":	MZDebuggerConstants.COMMAND_TRACE,
					"date":		new DateFormat().returnDateFormat(new Date()),
					"target":		"["+getClassName(caller)+"]",
					"object":		object,
//					"reference":	getQualifiedSuperclassName(caller),
					"person":		person,
					"color":		color
			};
			//data["object"].
			// Send the data
			send(data);
		}
		private function getClassName(caller:Object):String{
			var str:String=getQualifiedClassName(caller);
			if(str.indexOf("::")>0&&str.indexOf("::")<str.length){
				str=str.split("::")[1];
			}
			return str;
		}
		private  function send(data:Object, direct:Boolean = false):void
		{
//			if (MZDebugger.getInstance().enabled) {
			if (MZDebugger.isEnable) {
				MZDebuggerConnection.getInstance().send(MZDebuggerCore.getInstance().ID, data, direct);
			}
		}
		public function handle(item:MZDebuggerData):void
		{
//			if (MZDebugger.getInstance().enabled) {
			if (MZDebugger.isEnable) {	
				// If the id is empty just return
				if (item.id == null || item.id == "") {
					return;
				}
				// Check if we should handle the call internaly
				if (item.id == MZDebuggerCore.getInstance().ID) {
					handleInternal(item);
				}
			}
		}
		private function handleInternal(item:MZDebuggerData):void
		{
			// Vars for loop
			var obj:*;
			var xml:XML;
			var method:Function;
			// Do the actions
			switch(item.data["command"])
			{
				// Get the application info and start processing queue
				case "DATA":
//					trace(this, {"key":"INIT","value":item.data['data']["value"]});
					MZDebugger.getInstance().dispatchEvent(new EventExtensions("DATA",item.data['data']));
					break;
				case MZDebuggerConstants.COMMAND_HELLO:
					sendInformation();
					break;
				
				// Get the root xml structure (object)
				case MZDebuggerConstants.COMMAND_BASE:
//					obj = MZDebuggerUtils.getObject(_base, "", 0);
//					if (obj != null) {
//						xml = XML(MZDebuggerUtils.parse(obj, "", 1, 2, true));
//						send({command:MZDebuggerConstants.COMMAND_BASE, xml:xml});
//					}
					break;
				
				// Inspect
				case MZDebuggerConstants.COMMAND_INSPECT:
//					obj = MZDebuggerUtils.getObject(_base, item.data["target"], 0);
//					if (obj != null) {
//						_base = obj;
//						xml = XML(MZDebuggerUtils.parse(obj, "", 1, 2, true));
//						send({command:MZDebuggerConstants.COMMAND_BASE, xml:xml});
//					}
					break;
				
				// Return the parsed object
				case MZDebuggerConstants.COMMAND_GET_OBJECT:
//					obj = MZDebuggerUtils.getObject(_base, item.data["target"], 0);
//					if (obj != null) {
//						xml = XML(MZDebuggerUtils.parse(obj, item.data["target"], 1, 2, true));
//						send({command:MZDebuggerConstants.COMMAND_GET_OBJECT, xml:xml});
//					}
					break;
				
				// Return a list of properties
				case MZDebuggerConstants.COMMAND_GET_PROPERTIES:
//					obj = MZDebuggerUtils.getObject(_base, item.data["target"], 0);
//					if (obj != null) {
//						xml = XML(MZDebuggerUtils.parse(obj, item.data["target"], 1, 1, false));
//						send({command:MZDebuggerConstants.COMMAND_GET_PROPERTIES, xml:xml});
//					}
					break;
				
				// Return a list of functions
				case MZDebuggerConstants.COMMAND_GET_FUNCTIONS:
//					obj = MZDebuggerUtils.getObject(_base, item.data["target"], 0);
//					if (obj != null) {
//						xml = XML(MZDebuggerUtils.parseFunctions(obj, item.data["target"]));
//						send({command:MZDebuggerConstants.COMMAND_GET_FUNCTIONS, xml:xml});
//					}
					break;
				
				// Adjust a property and return the value
				case MZDebuggerConstants.COMMAND_SET_PROPERTY:
//					obj = MZDebuggerUtils.getObject(_base, item.data["target"], 1);
//					if (obj != null) {
//						try {
//							obj[item.data["name"]] = item.data["value"];
//							send({command:MZDebuggerConstants.COMMAND_SET_PROPERTY, target:item.data["target"], value:obj[item.data["name"]]});
//						} catch (e1:Error) {
//							//
//						}
//					}
					break;
				
				// Return a preview
				case MZDebuggerConstants.COMMAND_GET_PREVIEW:
//					obj = MZDebuggerUtils.getObject(_base, item.data["target"], 0);
//					if (obj != null && MZDebuggerUtils.isDisplayObject(obj)) {
//						var displayObject:DisplayObject = obj as DisplayObject;
//						var bitmapData:BitmapData = MZDebuggerUtils.snapshot(displayObject, new Rectangle(0, 0, 300, 300));
//						if (bitmapData != null) {	
//							var bytes:ByteArray = bitmapData.getPixels(new Rectangle(0, 0, bitmapData.width, bitmapData.height));
//							send({command:MZDebuggerConstants.COMMAND_GET_PREVIEW, bytes:bytes, width:bitmapData.width, height:bitmapData.height});
//						}
//					}
					break;
				
				// Call a method and return the answer
				case MZDebuggerConstants.COMMAND_CALL_METHOD:
//					method = MZDebuggerUtils.getObject(_base, item.data["target"], 0);
//					if (method != null && method is Function) {
//						if (item.data["returnType"] == MZDebuggerConstants.TYPE_VOID) {
//							method.apply(null, item.data["arguments"]);
//						} else {
//							try {
//								obj = method.apply(null, item.data["arguments"]);
//								xml = XML(MZDebuggerUtils.parse(obj, "", 1, 5, false));
//								send({command:MZDebuggerConstants.COMMAND_CALL_METHOD, id:item.data["id"], xml:xml});
//							} catch (e2:Error) {
//								//
//							}							
//						}
//					}
					break;
				
				// Pause the application
				case MZDebuggerConstants.COMMAND_PAUSE:
//					MZDebuggerUtils.pause();
//					send({command:MZDebuggerConstants.COMMAND_PAUSE});
					break;
				
				// Resume the application
				case MZDebuggerConstants.COMMAND_RESUME:
//					MZDebuggerUtils.resume();
//					send({command:MZDebuggerConstants.COMMAND_RESUME});
					break;
				
				// Set the highlite on an object
				case MZDebuggerConstants.COMMAND_HIGHLIGHT:
//					obj = MZDebuggerUtils.getObject(_base, item.data["target"], 0);
//					if (obj != null && MZDebuggerUtils.isDisplayObject(obj)) {
//						if (DisplayObject(obj).stage != null && DisplayObject(obj).stage is Stage) {
//							_stage = obj["stage"];
//						}
//						if (_stage != null) {
//							highlightClear();
//							send({command:MZDebuggerConstants.COMMAND_STOP_HIGHLIGHT});
//							_highlight.removeEventListener(MouseEvent.CLICK, highlightClicked);
//							_highlight.mouseEnabled = false;
//							_highlightTarget = DisplayObject(obj);
//							_highlightMouse = false;
//							_highlightUpdate = true;
//						}
//					}
					break;
				
				// Show the highlight
				case MZDebuggerConstants.COMMAND_START_HIGHLIGHT:
//					highlightClear();
//					_highlight.addEventListener(MouseEvent.CLICK, highlightClicked, false, 0, true);
//					_highlight.mouseEnabled = true;
//					_highlightTarget = null;
//					_highlightMouse = true;
//					_highlightUpdate = true;
//					send({command:MZDebuggerConstants.COMMAND_START_HIGHLIGHT});
					break;
				
				// Remove the highlight
				case MZDebuggerConstants.COMMAND_STOP_HIGHLIGHT:
//					highlightClear();
//					_highlight.removeEventListener(MouseEvent.CLICK, highlightClicked);
//					_highlight.mouseEnabled = false;
//					_highlightTarget = null;
//					_highlightMouse = false;
//					_highlightUpdate = false;
//					send({command:MZDebuggerConstants.COMMAND_STOP_HIGHLIGHT});
					break;
			}
		}
		
		private function sendInformation():void
		{
			// Get basic data
			var playerType:String = Capabilities.playerType;
			var playerVersion:String = Capabilities.version;
			var isDebugger:Boolean = Capabilities.isDebugger;
			var isFlex:Boolean = false;	
			var fileTitle:String = "";
			var fileLocation:String = "";
			
			// Check for Flex framework
			// Get the location
			// Check for browser
			if (playerType == "ActiveX" || playerType == "PlugIn") {
				if (ExternalInterface.available) {
					try {
						var tmpLocation:String = ExternalInterface.call("window.location.href.toString");
						var tmpTitle:String = ExternalInterface.call("window.document.title.toString");
						if (tmpLocation != null) fileLocation = tmpLocation;
						if (tmpTitle != null) fileTitle = tmpTitle;
					} catch (e2:Error) {
						// External interface FAIL
					}
				}
			}
			// Check for Adobe AIR
			if (playerType == "Desktop") {
				try{
					var NativeApplicationClass:* = getDefinitionByName("flash.desktop::NativeApplication");
					if (NativeApplicationClass != null) {
						var descriptor:XML = NativeApplicationClass["nativeApplication"]["applicationDescriptor"];
						var ns:Namespace = descriptor.namespace();
						var filename:String = descriptor.ns::filename;
						var FileClass:* = getDefinitionByName("flash.filesystem::File");
						if (Capabilities.os.toLowerCase().indexOf("windows") != -1) {
							filename += ".exe";
							fileLocation = FileClass["applicationDirectory"]["resolvePath"](filename)["nativePath"];
						} else if (Capabilities.os.toLowerCase().indexOf("mac") != -1) {
							filename += ".app";
							fileLocation = FileClass["applicationDirectory"]["resolvePath"](filename)["nativePath"];
						}
					}
				} catch (e3:Error) {}
			}
			if (fileTitle == "" && fileLocation != "") {
				var slash:int = Math.max(fileLocation.lastIndexOf("\\"), fileLocation.lastIndexOf("/"));
				if (slash != -1) {
					fileTitle = fileLocation.substring(slash + 1, fileLocation.lastIndexOf("."));
				} else {
					fileTitle = fileLocation;
				}
			}
			
			// Default
			if (fileTitle == "") {
				fileTitle = "Application";
			}
			// Create the data
			var data:Object = {
				command:			MZDebuggerConstants.COMMAND_INFO,
					debuggerVersion:	MZDebugger.getInstance().VERSION,
					playerType:			playerType,
					playerVersion:		playerVersion,
					isDebugger:			isDebugger,
					isFlex:				isFlex,
					fileLocation:		fileLocation,
					fileTitle:			fileTitle
			};
			// Send the data direct
			send(data, true);
			
			// Start the queue after that
			MZDebuggerConnection.getInstance().processQueue();
		}
		public function clear():void
		{
//			if (MZDebugger.getInstance().enabled) {
			if (MZDebugger.isEnable) {
				send({"command":MZDebuggerConstants.COMMAND_CLEAR_TRACES});
			}
		}
		public function MZDebuggerCore(singleTon:SingleTon=null){if(singleTon==null)throw Error("SingleTon,do not call structure method")}
		private var _monitorTime:Number;
		private static var instance:MZDebuggerCore;
		public const ID:String = "com.mzStudio.debugger.core";
	}
}
class SingleTon{}