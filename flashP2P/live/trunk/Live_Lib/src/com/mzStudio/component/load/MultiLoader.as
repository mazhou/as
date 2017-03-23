package com.mzStudio.component.load
{
	import com.mzStudio.event.EventExtensions;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.utils.Dictionary;

	/**
	 * 多资源并行加载
	 * <p>
	 * 返回EventExtensions的data值，其中data.asset是加载的资源，data.error是错误的字符串
	 * </p> 
	 * @author mazhoun
	 */
	public class MultiLoader extends EventDispatcher
	{
		private var _assetS:Array=new Array();
		private var _errorS:Array=new Array();
		private var _legth:uint=0;
		public function MultiLoader()
		{
		}
		public function load(materials:Array,time:Number = 0,dataFormat:String=""):void{
			this._assetS=[];
			var astLoad:AssetLoader;
			_legth=materials.length;
			for(var i:uint=0;i<materials.length;i++){
				astLoad=new AssetLoader();
				astLoad.orderID=i.toString();
				astLoad.load(materials[i],time,dataFormat);
				astLoad.addEventListener(Event.COMPLETE,completeHandler);
				astLoad.addEventListener(Event.INIT,initHandler);
				astLoad.addEventListener(ErrorEvent.ERROR,errorHandler);
			}
		}
		protected function completeHandler(evt:EventExtensions):void
		{
			
			_legth--;
			_assetS[int((evt.target as AssetLoader).orderID)]=evt.data;
			var obj:Object=new Object();
			obj.asset=_assetS;
			obj.error=_errorS;
			if(_legth==0){
				dispatchEvent(new EventExtensions(Event.COMPLETE,obj));
			}
			try{
				evt.currentTarget.removeEventListener(Event.COMPLETE,completeHandler);
				evt.currentTarget.removeEventListener(Event.INIT,initHandler);
				evt.currentTarget.removeEventListener(ErrorEvent.ERROR,errorHandler);
			}catch(err:Error){
				
			}
		}
		protected function initHandler(evt:EventExtensions):void
		{
			
		}
		private function errorHandler(evt:ErrorEvent):void
		{
			_legth--;
			_errorS[int((evt.target as AssetLoader).orderID)]=evt.text;
			var obj:Object=new Object();
			obj.asset=_assetS;
			obj.error=_errorS;
			if(_legth==0){
				dispatchEvent(new EventExtensions(Event.COMPLETE,obj));
			}
			try{
				evt.currentTarget.removeEventListener(Event.COMPLETE,completeHandler);
				evt.currentTarget.removeEventListener(Event.INIT,initHandler);
				evt.currentTarget.removeEventListener(ErrorEvent.ERROR,errorHandler);
			}catch(err:Error){
				
			}
		}
	}
}