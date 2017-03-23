package lee.projects.player.view{
	import lee.bases.BaseUI;
	import lee.player.Player;
	import lee.player.PlayerState;
	import lee.player.PlayerError;
	import lee.player.PlayerEvent;
	import lee.projects.player.view.panels.PanelsManager;
	public class Infobox extends BaseUI {
		protected var _player:Player;
		protected var _panelsManager:PanelsManager;
		public function Infobox(player:Player,config:XML=null) {
			_player=player;
			_player.addEventListener(PlayerEvent.ERROR,_player_ERROR);
			_player.addEventListener(PlayerEvent.MESSAGE,_player_MESSAGE);
			_player.addEventListener(PlayerEvent.BUFFER_UPDATE,_player_BUFFER_UPDATE);
			_player.addEventListener(PlayerEvent.STATE_CHANGE,_player_STATE_CHANGE);
			
			
			_panelsManager=new PanelsManager();
			addChild(_panelsManager);
		}
		override public function setSize(w:Number,h:Number):void{
			if(_width!=w||_height!=h)
			{
				_width=w;
				_height=h;
				_panelsManager.setSize(w,h);
			}
		}
		public function showInfoPanel(type:String,info:Object=null,callback:Function=null):void{
			_panelsManager.show(type,info,callback);
		}
		//==============
		protected function _player_ERROR(event:PlayerEvent):void{
			_panelsManager.show("errorPanel",String(event.info)+"！");
		}
		protected function _player_MESSAGE(event:PlayerEvent):void{
			if(_player.type=="letvRtmpLive")
			{
				if(Number(event.info)==1)
				{
					_panelsManager.show("loadPanel","正在连接服务器，请稍候...");
				}
			}
		}
		protected function _player_BUFFER_UPDATE(event:PlayerEvent):void{
			if(_player.state==PlayerState.BUFFERING)
			{
			    //_panelsManager.updateInfo("bufferPanel","已缓冲 "+String(int(Number(event.info)*100))+"% ，节目即将播放...");
			    if(int(Number(event.info)*100)==100)
			    {
				    _panelsManager.hide();
			    }
			}
		}
		protected function _player_STATE_CHANGE(event:PlayerEvent):void{
			var pstate:String=String(event.info);
			switch (pstate)
			{
				case PlayerState.LOADING :
				    _panelsManager.show("loadPanel","正在加载数据，请稍候...");
					break;
				case PlayerState.BUFFERING :
				    _panelsManager.show("bufferPanel","正在缓冲数据，请稍候...");
					break;
				case PlayerState.PLAYING :
				    _panelsManager.hide();
					break;
				case PlayerState.PAUSED :
				    _panelsManager.hide();
					break;
				case PlayerState.STOPPED :
				    _panelsManager.hide();
					break;
				case PlayerState.IDLE :
				    _panelsManager.hide();
					break;
			}
		}
	}
}