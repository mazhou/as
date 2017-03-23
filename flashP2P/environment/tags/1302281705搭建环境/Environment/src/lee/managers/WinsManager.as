package lee.managers{
	import flash.display.DisplayObjectContainer;
	import flash.display.InteractiveObject;
	import flash.display.Stage;
	import flash.events.Event;
	public class WinsManager {
		protected var _owner:DisplayObjectContainer;
		protected var _filterTarget:DisplayObjectContainer;
		protected var _filterArray:Array;
		protected var _wins:Array=[];
		public function WinsManager(owner:DisplayObjectContainer,filterTarget:DisplayObjectContainer,filterArray:Array=null) {
			_owner=owner;
			_filterTarget=filterTarget;
			_filterArray=filterArray;
			_owner.stage.addEventListener(Event.RESIZE,_owner_stage_RESIZE);
		}
		public function addWin(win:DisplayObjectContainer):void {
			if(_wins.length==0)
			{
				_filterTarget.mouseEnabled=false;
			    _filterTarget.mouseChildren=false;
			    _filterTarget.tabEnabled=false;
			    _filterTarget.tabChildren=false;
				_filterTarget.filters=_filterArray;
			}
			else
			{
				_filterTarget.addChild(_wins[_wins.length-1]);
			}
			_wins.push(win);
			_owner.addChild(win);
			alignWin(win);
		}
		public function removeWin(win:DisplayObjectContainer):void {
			var index:int=_wins.lastIndexOf(win);
			if(index!=-1)
			{
				_wins.splice(index,1); 
				win.parent.removeChild(win);
				if(_wins.length==0)
			    {
				    _filterTarget.mouseEnabled=true;
			        _filterTarget.mouseChildren=true;
			        _filterTarget.tabEnabled=true;
			        _filterTarget.tabChildren=true;
			        _filterTarget.filters=null;
			    }
			    else
			    {
				    _owner.addChild(_wins[_wins.length-1]);
			    }
			}
		}
		protected function _owner_stage_RESIZE(event:Event):void{
			var len:int=_wins.length;
			for(var i:int=0;i<len;i++)
			{
				alignWin(_wins[i] as DisplayObjectContainer);
			}
		}
		protected function alignWin(win:DisplayObjectContainer):void {
			win.x=int((_owner.stage.stageWidth-win.width)/2);
			win.y=int((_owner.stage.stageHeight-win.height)/2);
		}
	}
}