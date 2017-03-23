package lee.player{
	import flash.media.Video;
	public interface IProvider{
        function set video(video:Video):void;
		function set volume(volume:Number):void;
		
		function get info():Object;
		function get type():String;
		function get ready():Boolean;
		function get state():String;
		function get time():Number;
		function get duration():Number;
		function get percentLoaded():Number;
		
		function play(info:Object):void;
		function clear():void;
		function resume():void;
		function pause():void;
		function stop():void;
		function replay():void;
		function seek(percent:Number):void;
	}
}

