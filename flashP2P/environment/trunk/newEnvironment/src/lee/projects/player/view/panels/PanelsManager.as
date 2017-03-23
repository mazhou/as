package lee.projects.player.view.panels{
	import lee.bases.BaseUI;
	
	import lee.projects.player.view.panels.BasePanel;
	import lee.projects.player.view.panels.HomePanel;
	import lee.projects.player.view.panels.LoadPanel;
	import lee.projects.player.view.panels.BufferPanel;
	import lee.projects.player.view.panels.PausePanel;
	import lee.projects.player.view.panels.StopPanel;
	import lee.projects.player.view.panels.ErrorPanel;
	
	import flash.display.Sprite;
	
	public class PanelsManager extends BaseUI {
		protected var _homePanel:HomePanel;
		protected var _loadPanel:LoadPanel;
		protected var _bufferPanel:BufferPanel;
		protected var _pausePanel:PausePanel;
		protected var _stopPanel:StopPanel;
		protected var _errorPanel:ErrorPanel;
		
		protected var _currentPanel:BasePanel;
		protected var _currentPanelType:String;
		
		public function PanelsManager() {

			_homePanel=new HomePanel(new HomePanelSkin() as Sprite);
			_loadPanel=new LoadPanel(new BufferPanelSkin() as Sprite);
			_bufferPanel=new BufferPanel(new BufferPanelSkin() as Sprite);
			_pausePanel=new PausePanel(new StopPanelSkin() as Sprite);
			_stopPanel=new StopPanel(new StopPanelSkin() as Sprite);
			_errorPanel=new ErrorPanel(new ErrorPanelSkin() as Sprite);
			
			_homePanel.hide();
			_loadPanel.hide();
			_bufferPanel.hide();
			_pausePanel.hide();
			_stopPanel.hide();
			_errorPanel.hide();
			
			addChild(_homePanel);
			addChild(_loadPanel);
			addChild(_bufferPanel);
			addChild(_pausePanel);
			addChild(_stopPanel);
			addChild(_errorPanel);
			
			this.mouseEnabled=false;
		}
		override public function setSize(w:Number,h:Number):void{
			if(_width!=w||_height!=h)
			{
				_width=w;
				_height=h;
				_homePanel.setSize(w,h);
				_loadPanel.setSize(w,h);
				_bufferPanel.setSize(w,h);
				_pausePanel.setSize(w,h);
				_stopPanel.setSize(w,h);
				_errorPanel.setSize(w,h);
			}
		}
		public function currentPanelType():String{
			return _currentPanelType;
		}
		public function updateInfo(type:String,info:Object=null):void{
			if(_currentPanel&&_currentPanelType==type)
			{
				_currentPanel.updateInfo(info);
			}
		}
		public function show(type:String,info:Object=null,callback:Function=null):void{
			hide();
			_currentPanelType=type;
			_currentPanel=getPanelByType(type);
			_currentPanel.show(info,callback);
		}
		public function hide():void{
			if(_currentPanel)
			{
				_currentPanel.hide();
				_currentPanel=null;
				_currentPanelType=null;
			}
		}
		
		protected function getPanelByType(type:String):BasePanel{
			var panel:BasePanel;
			switch (type)
			{
				case "homePanel" :
				    panel=_homePanel;
					break;
				case "loadPanel" :
				    panel=_loadPanel;
					break;
				case "bufferPanel" :
				    panel=_bufferPanel;
					break;
				case "pausePanel" :
				    panel=_pausePanel;
					break;
				case "stopPanel" :
				    panel=_stopPanel;
					break;
				case "errorPanel" :
				    panel=_errorPanel;
					break;
			}
			return panel;
		}
	}
}