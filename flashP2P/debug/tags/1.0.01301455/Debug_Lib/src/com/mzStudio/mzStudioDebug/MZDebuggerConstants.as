package com.mzStudio.mzStudioDebug
{
	internal class MZDebuggerConstants
	{
		public static const COMMAND_HELLO					:String = "HELLO";
		public static const COMMAND_INFO					:String = "INFO";
		public static const COMMAND_TRACE					:String = "TRACE";
		public static const COMMAND_CUSTOM_TRACE			:String = "CUSTOM_TRACE";
		public static const COMMAND_RECT_TRACE				:String = "RECT_TRACE";
		public static const COMMAND_PAUSE					:String = "PAUSE";
		public static const COMMAND_RESUME					:String = "RESUME";
		public static const COMMAND_BASE					:String = "BASE";
		public static const COMMAND_INSPECT					:String = "INSPECT";
		public static const COMMAND_GET_OBJECT				:String = "GET_OBJECT";
		public static const COMMAND_GET_PROPERTIES			:String = "GET_PROPERTIES";
		public static const COMMAND_GET_FUNCTIONS			:String = "GET_FUNCTIONS";
		public static const COMMAND_GET_PREVIEW				:String = "GET_PREVIEW";
		public static const COMMAND_SET_PROPERTY			:String = "SET_PROPERTY";
		public static const COMMAND_CALL_METHOD				:String = "CALL_METHOD";
		public static const COMMAND_HIGHLIGHT				:String = "HIGHLIGHT";
		public static const COMMAND_START_HIGHLIGHT			:String = "START_HIGHLIGHT";
		public static const COMMAND_STOP_HIGHLIGHT			:String = "STOP_HIGHLIGHT";
		public static const COMMAND_CLEAR_TRACES			:String = "CLEAR_TRACES";
		public static const COMMAND_MONITOR					:String = "MONITOR";
		public static const COMMAND_SAMPLES					:String = "SAMPLES";
		public static const COMMAND_SNAPSHOT				:String = "SNAPSHOT";
		public static const COMMAND_NOTFOUND				:String = "NOTFOUND";
		
		
		// Types
		public static const TYPE_VOID					:String = "void";
		public static const TYPE_NULL					:String = "null";
		public static const TYPE_ARRAY					:String = "Array";
		public static const TYPE_BOOLEAN				:String = "Boolean";
		public static const TYPE_NUMBER					:String = "Number";
		public static const TYPE_OBJECT					:String = "Object";
		public static const TYPE_VECTOR					:String = "Vector.";
		public static const TYPE_STRING					:String = "String";
		public static const TYPE_INT					:String = "int";
		public static const TYPE_UINT					:String = "uint";
		public static const TYPE_XML					:String = "XML";
		public static const TYPE_XMLLIST				:String = "XMLList";
		public static const TYPE_XMLNODE				:String = "XMLNode";
		public static const TYPE_XMLVALUE				:String = "XMLValue";
		public static const TYPE_XMLATTRIBUTE			:String = "XMLAttribute";
		public static const TYPE_METHOD					:String = "MethodClosure";
		public static const TYPE_FUNCTION				:String = "Function";
		public static const TYPE_BYTEARRAY				:String = "ByteArray";	
		public static const TYPE_WARNING				:String = "Warning";
		public static const TYPE_NOT_FOUND				:String = "Not found";
		public static const TYPE_UNREADABLE				:String = "Unreadable";
		
		
		// Path delimiter
		public static const DELIMITER					:String = ".";
	}
}