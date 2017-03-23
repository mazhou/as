package 
{
	//import fl.controls.Button;
	
	import fl.controls.RadioButton;
	
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	
	import lee.player.Player;
	


	public class BtnArea extends Sprite
	{
		private var _player:Function;
		private var _obj:Object;
		private var _str1:String;
		private var _str2:String;
		private var _str3:String;
		
		private var btn1:RadioButton;
		public function BtnArea(fun:Function,str1:String="",str2:String="",str3:String="")
		{
			_player=fun;
			_obj=new Object;
			
			_str1=str1;
			_str2=str2;
			_str3=str3;
			if(str1!="")
			{
				btn1=new RadioButton;
				btn1.label="标清";
				addChild(btn1);
				btn1.width=150;
				btn1.height=20;
				btn1.y=320;
				btn1.addEventListener(MouseEvent.CLICK,btnChange);
			}
			
			if(str2!="")
			{
				var btn2:RadioButton=new RadioButton;
				btn2.label="高清";
				addChild(btn2);
				btn2.width=150;
				btn2.height=20;
				btn2.y=340;
				btn2.addEventListener(MouseEvent.CLICK,btnChange);
			}
			
			if(str3!="")
			{
				var btn3:RadioButton=new RadioButton;
				btn3.label="超清";
				addChild(btn3);
				btn3.width=150;
				btn3.height=20;
				btn3.y=360;
				btn3.addEventListener(MouseEvent.CLICK,btnChange);
			}
			
			btn1.dispatchEvent(new MouseEvent(MouseEvent.CLICK));
		}
		
		private function btnChange(e:MouseEvent):void
		{
			var code:String=e.currentTarget.label
			switch(code)
			{
				case "标清":
					_obj.dispatch=_str1;
					break;
				case "高清":
					_obj.dispatch=_str2;
					break;
				case "超清":
					_obj.dispatch=_str3;
					break;
			}
			_player.call(this,_obj.dispatch);
			
		}
	}
}