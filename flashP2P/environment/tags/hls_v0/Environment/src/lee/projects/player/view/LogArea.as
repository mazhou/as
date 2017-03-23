package lee.projects.player.view{
	import fl.controls.Button;
	import fl.controls.CheckBox;
	import fl.controls.TextArea;
	import fl.controls.TextInput;
	
	import flash.display.MovieClip;
	import flash.display.SimpleButton;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.system.System;
	import flash.text.TextField;
	import flash.text.TextFormat;
	
	import lee.bases.BaseUI;
	import lee.commons.StateButton;
	import lee.managers.RectManager;
	

	public class LogArea extends BaseUI {
		private var textArea1:TextArea;
		private var isShowLog:Boolean=true;
		private var isShowSpeed:Boolean=true;
		
		private var boo:Boolean=false;
		private var _lc:LogControlbarSkin;
		private var _playBtn:SimpleButton;
		private var _pauseBtn:SimpleButton;
		private var _copyBtn:SimpleButton;
		private var _deleteBtn:SimpleButton;
		private var _bg:Sprite;
		public function LogArea() {
			RectManager.showLogFun=showLogFun;
			RectManager.showSpeedFun=showSpeedFun;
			_lc=new LogControlbarSkin;
			addChild(_lc);
			
			
			_playBtn=_lc.getChildByName("playBtn") as SimpleButton;
			_pauseBtn=_lc.getChildByName("pauseBtn") as SimpleButton;
			_copyBtn=_lc.getChildByName("copyBtn") as SimpleButton;
			_deleteBtn=_lc.getChildByName("deleteBtn") as SimpleButton;
			_bg=_lc.getChildByName("background") as Sprite;
			
			_playBtn.addEventListener(MouseEvent.CLICK,_playBtnClick);
			_pauseBtn.addEventListener(MouseEvent.CLICK,_playBtnClick);
			_copyBtn.addEventListener(MouseEvent.CLICK,_copyBtnClick);
			_deleteBtn.addEventListener(MouseEvent.CLICK,_deleteBtnClick);
			
			
			
			textArea1=new TextArea();
			addChild(textArea1);
			_playBtn.visible=false;
		}
		override public function setSize(w:Number,h:Number):void{
			if(_width!=w||_height!=h)
			{
				_width=w;
				_height=h;
				
				textArea1.width=_width;
				textArea1.height=h-_lc.height;
				_bg.width=_width;
				_lc.y=h-_lc.height;
			}
		}
		public function showSpeedFun(log:Array):void
		{
			if(!isShowSpeed)
			{
				return;
			}
		}
		
		public function showLogFun(log:Array):void
		{
			if(!isShowLog)
			{
				return;
			}
			if (textArea1.maxVerticalScrollPosition>=10)
			{
				textArea1.htmlText="";
			}
			textArea1.htmlText+=log.toString()+"\n";
		}
		
		private function _playBtnClick(event:MouseEvent):void{
			if(isShowLog==false)
			{
				_playBtn..visible=false;
				_pauseBtn.visible=true;
				isShowLog=true;
			}else
			{
				isShowLog=false;
				_playBtn..visible=true;
				_pauseBtn.visible=false;
			}
		}
		
		private function _copyBtnClick(event:MouseEvent):void{			
			System.setClipboard( textArea1.text);
		}
		private function _deleteBtnClick(event:MouseEvent):void{
			textArea1.htmlText="";
		}

	}
}