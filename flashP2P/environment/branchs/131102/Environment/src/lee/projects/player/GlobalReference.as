package lee.projects.player{
	import flash.display.DisplayObjectContainer;
	import flash.display.Stage;
	
	import lee.projects.player.controller.Controller;
	import lee.projects.player.controller.HttpController;
	import lee.projects.player.controller.M3u8Controller;
	import lee.projects.player.controller.HLSController;

	public class GlobalReference {
		public static var stage:Stage;
		public static var root:DisplayObjectContainer;
		public static var controller:Controller;
		public static var httpcontroller:HttpController;
		public static var m3u8controller:M3u8Controller;
		public static var HLScontroller:HLSController;
		public static var statisticManager:StatisticManager;
		public static var m3u8statisticManager:M3u8StatisticManager;
		public static var HLSstatisticManager:HLSStatisticManager;
		public static var version:String;
	}
}