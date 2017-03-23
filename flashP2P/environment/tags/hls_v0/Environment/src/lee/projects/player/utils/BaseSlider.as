package lee.projects.player.utils{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.MouseEvent;
	import flash.geom.Rectangle;
	
	import lee.bases.BaseEvent;
	import lee.managers.RectManager;
	public class BaseSlider extends EventDispatcher {
		public static const DRAG:String="drag";
		public static const CHANGE:String="change";
		public static const TRACKON:String="trackon";
		public static const TRACKOFF:String="trackoff";
		
		public var fullnessSprite:Sprite;
		public var handleSprite:Sprite;
		public var isDraging:Boolean=false;
		public var isFullOnDrag:Boolean=false;
		
        protected var _skin:Sprite;
		protected var backgroundSprite:Sprite;
		protected var progressSprite:Sprite;
	    
		protected var interactSprite:Sprite;
		
		protected var maskSprite:Sprite;
		
		protected var _position:Number;
		protected var _progress:Number;
		
		protected var _pressed:Boolean=false;		
		
		protected var _offset:Number;
		
		protected var _width:Number;
		
		protected var _prevFrameHandleX:Number;
		
		protected var _enabled:Boolean=true;
		
		protected var bufferSprite:Sprite;
		
		public function BaseSlider(skin:Sprite,offset:Number=NaN){
			_skin=skin;

			backgroundSprite=skin.getChildByName("background") as Sprite;
			progressSprite=skin.getChildByName("progress") as Sprite;
			fullnessSprite=skin.getChildByName("fullness") as Sprite;
			interactSprite=skin.getChildByName("interact") as Sprite;
			handleSprite=skin.getChildByName("handle") as Sprite;
			
			_offset=isNaN(offset)?(handleSprite.width/2):offset;
			
			
			bufferSprite=new Sprite();
			bufferSprite.x=_offset;
			//bufferSprite.y=-6;
			maskSprite=new Sprite();
			skin.addChild(maskSprite);
			skin.addChildAt(bufferSprite,2);
			
			
			_width=backgroundSprite.width;
			
			interactSprite.buttonMode=true;
			
			handleSprite.addEventListener(MouseEvent.ROLL_OVER,RollOver);
			handleSprite.addEventListener(MouseEvent.ROLL_OUT,RollOut);
			handleSprite.addEventListener(MouseEvent.MOUSE_DOWN,MouseDown);
			handleSprite.addEventListener(MouseEvent.MOUSE_UP,MouseUp);
			
			interactSprite.addEventListener(MouseEvent.ROLL_OVER,RollOver);
			interactSprite.addEventListener(MouseEvent.ROLL_OUT,RollOut);
			interactSprite.addEventListener(MouseEvent.MOUSE_DOWN,MouseDown);
			interactSprite.addEventListener(MouseEvent.MOUSE_UP,MouseUp);
			
			_skin.addEventListener(MouseEvent.ROLL_OUT,_skin_ROLL_OUT);
			_skin.addEventListener(MouseEvent.MOUSE_MOVE,_skin_MOUSE_MOVE);
			
			position=0;
			progress=0;
		}
		public function get skin():Sprite{
			return _skin;
		}
		
		public function get enabled():Boolean{
			return _enabled;
		}
		public function set enabled(boo:Boolean):void{
			if(_enabled!=boo)
			{
				_enabled=boo;
				_skin.mouseEnabled=boo;
				_skin.mouseChildren=boo;
				_skin.tabEnabled=boo;
				_skin.tabChildren=boo;
				if(boo&&_skin.hitTestPoint(_skin.stage.mouseX,_skin.stage.mouseY,true))
				{
					_skin_MOUSE_MOVE(null);
				}
			}
		}
		public function updateBuffer():void{
			if(RectManager.dataManager&&RectManager.dataManager.bufferTimeArray)
			{	
				var len:uint=uint(RectManager.dataManager.fileTotalChunks);
				bufferSprite.graphics.clear();
				bufferSprite.graphics.beginFill(0x666666,0);
				bufferSprite.graphics.drawRect(0,0,Number(RectManager.dataManager.bufferTimeArray[RectManager.dataManager.bufferTimeArray.length-1]),6);
				bufferSprite.graphics.endFill();
				
				
				//var pjtime:Number=Number(RectManager.dataManager.bufferTimeArray[RectManager.dataManager.bufferTimeArray.length-1])/RectManager.dataManager.bufferTimeArray.length;
				
					
				for(var i:uint=0;i<len;i++)
				{

					var btime:Number=Number(RectManager.dataManager.bufferTimeArray[i]);
					if(i!=0)
					{
						bufferSprite.graphics.lineStyle(btime-Number(RectManager.dataManager.bufferTimeArray[i-1]), 0x666666);
					}
					else
					{
						bufferSprite.graphics.lineStyle(btime, 0x666666);
					}
					
					
					var cobj:Object=RectManager.dataManager.chunk(i);
					if(cobj&&cobj.iLoadType==3)
					{
						
						if(i!=0)
						{
							bufferSprite.graphics.moveTo(btime,0);
							bufferSprite.graphics.lineTo(btime,18);
						}
						else
						{
							bufferSprite.graphics.moveTo(0,0);
							bufferSprite.graphics.lineTo(0,18);
						}
					}
				}
				//trace(_offset);
				bufferSprite.width=_width-_offset*2;
			}
			else
			{
				bufferSprite.graphics.clear();
			}
		}
		
		public function clearBuffer():void
		{
			bufferSprite.graphics.clear();
		}
		/*public function updateBuffer():void{
			//progressSprite.width=_offset*2+(_width-_offset*2)*value;
			if(RectManager.dataManager)
			{	
				var len:uint=uint(RectManager.dataManager.fileTotalChunks);
				bufferSprite.graphics.clear();
				bufferSprite.graphics.beginFill(0x666666,0);
				bufferSprite.graphics.drawRect(0,0,len,6);
				bufferSprite.graphics.endFill();
				bufferSprite.graphics.lineStyle(1, 0x000099);	
				for(var i:uint=0;i<len;i++)
				{
					var cobj:Object=RectManager.dataManager.chunk(i);
					if(cobj&&cobj.iLoadType==3)
					{
						bufferSprite.graphics.moveTo(i,0);
						bufferSprite.graphics.lineTo(i,6);
					}
				}
				//trace(_offset);
				bufferSprite.width=_width;
			}
			else
			{
				bufferSprite.graphics.clear();
			}
		}*/
		
		
		public function get position():Number{
			return _position;
		}
		public function set position(value:Number):void{
			if(_position!=value)
			{
				_position=value;
				setPosition(value);
			}
		}
		public function get progress():Number{
			return _progress;
		}
		public function set progress(value:Number):void{
			if(_progress!=value)
			{
				_progress=value;
				setProgress(value);
			}
		}
		public function set width(wid:Number):void{
			if(_width!=wid)
			{
				_width=wid;
				backgroundSprite.width=wid;
			    interactSprite.width=wid;
				setPosition(_position);
				setProgress(_progress);
				maskSprite.graphics.clear();
				maskSprite.graphics.beginFill(0xffffff,0);
				maskSprite.graphics.drawRect(0,0,_width,progressSprite.height);
				maskSprite.graphics.endFill();
				bufferSprite.mask=maskSprite;
			}
		}
		public function get width():Number{
			return _width;
		}
		protected function setPosition(value:Number):void{
			fullnessSprite.width=handleSprite.x=_offset+(_width-_offset*2)*value;
		}
		protected function setProgress(value:Number):void{
			progressSprite.width=_offset*2+(_width-_offset*2)*value;
		}
		protected function RollOver(event:MouseEvent):void {
			if (event.buttonDown&&_pressed)
			{
				handleSprite.stage.removeEventListener(MouseEvent.MOUSE_UP,MouseUpOutSide);
			}
        }
		protected function RollOut(event:MouseEvent):void {
            if (event.buttonDown&&_pressed)
			{
				handleSprite.stage.addEventListener(MouseEvent.MOUSE_UP,MouseUpOutSide);
			}
        }
		protected function MouseDown(event:MouseEvent):void {
			_pressed=true;
			startScroll(true);
        }
		protected function MouseUp(event:MouseEvent):void {
			_pressed=false;
			stopScroll();
        }
		protected function MouseUpOutSide(event:MouseEvent):void {
			_pressed=false;
			handleSprite.stage.removeEventListener(MouseEvent.MOUSE_UP,MouseUpOutSide);
			stopScroll();
			dispatchEvent(new BaseEvent(BaseSlider.TRACKOFF,null));
		}
		protected function _skin_ROLL_OUT(event:MouseEvent):void {
			if(!isDraging)
			{
				dispatchEvent(new BaseEvent(BaseSlider.TRACKOFF,null));
			}
		}
		protected function _skin_MOUSE_MOVE(event:MouseEvent=null):void {
			var mousex:Number=_skin.mouseX;
            if(mousex<_offset)
			{
				mousex=_offset;
			}
			if(mousex>(_width-_offset))
			{
				mousex=_width-_offset;
			}
			var value:Number=(mousex-_offset)/(_width-_offset*2);
			dispatchEvent(new BaseEvent(BaseSlider.TRACKON,value));
        }
		
		//开始滚动
		protected function startScroll(boo:Boolean=false):void {
			isDraging=true;
			_prevFrameHandleX=handleSprite.x;
			handleSprite.startDrag(boo,new Rectangle(_offset,0,_width-_offset*2,0));
			handleSprite.root.addEventListener(Event.ENTER_FRAME,draghandle);
        }
		//停止滚动
		protected function stopScroll():void {
			isDraging=false;
			handleSprite.root.removeEventListener(Event.ENTER_FRAME,draghandle);
			handleSprite.stopDrag();
			var value:Number=(handleSprite.x-_offset)/(_width-_offset*2);
			if(position!=value)
			{
				position=value;
				dispatchEvent(new BaseEvent(BaseSlider.CHANGE,value));
			}
        }
		protected function draghandle(event:Event):void{
			if(_prevFrameHandleX!=handleSprite.x)
			{
				_prevFrameHandleX=handleSprite.x;
				var value:Number=(handleSprite.x-_offset)/(_width-_offset*2);
				if(isFullOnDrag)
				{
					fullnessSprite.width=_width*value;
				}
				dispatchEvent(new BaseEvent(BaseSlider.DRAG,value));
				if(!_skin.hitTestPoint(_skin.stage.mouseX,_skin.stage.mouseY,true))
				{
					dispatchEvent(new BaseEvent(BaseSlider.TRACKON,value));
				}
			}
		}
	}
}