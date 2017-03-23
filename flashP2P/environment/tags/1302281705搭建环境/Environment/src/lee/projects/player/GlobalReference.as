package lee.projects.player{
	import flash.display.DisplayObjectContainer;
	import flash.display.Stage;
	
	import lee.projects.player.controller.Controller;
	import lee.projects.player.controller.HttpController;
	

	public class GlobalReference {
		public static var stage:Stage;
		public static var root:DisplayObjectContainer;
		public static var controller:Controller;
		public static var httpcontroller:HttpController;
		
		public static var statisticManager:StatisticManager;
		public static var version:String;
	}
}