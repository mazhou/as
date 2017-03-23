package com.p2p.loaders
{
	import com.p2p.data.vo.Config;
	import com.p2p.dataManager.IDataManager;
	import com.p2p.events.EventExtensions;
	import com.p2p.events.protocol.HTTPLOAD_PROTOCOL;
	import com.p2p.logs.Debug;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.utils.ByteArray;
	
	/**
	 *等同于dat加载 
	 * @author mazhoun
	 */
	public class HeadLoader extends DATLoader
	{
		private var _tempArray:Array=new Array
		public function HeadLoader(_dispather:IDataManager)
		{
			super(_dispather);
			isDebug=false;
		}
		/**因加载头有可能和加载dat有差别，所以错误加载重新定义了*/
		override protected function errorHandler(evt:ErrorEvent=null):void
		{
			/**事件垃圾回收*/
			stop();
			/**上报处理*/
			if(evt&&evt.text==HTTPLOAD_PROTOCOL.TIME_UP){
				
			}else if(evt&&evt.text==HTTPLOAD_PROTOCOL.IO_ERROR){
				
			}else if(evt&&evt.text==HTTPLOAD_PROTOCOL.SECURITY_ERROR){
				
			}
			/**重试或跳过机制(即跳过本分钟加载 下一分钟)加载下分钟机制*/
			if(evt){
				Debug.traceMsg(this,"head错误类型"+evt.text);
				//切换加载dat地址,重新加载dat，待邢波确认加载dat可以按照字节加载，地址要做处理
				loadURLIndex++;
				if(loadURLIndex==_initData.flvURL.length){
					loadURLIndex=0;
				}
				//如果连续出错，达到一定次数，将跳过本块的加载
				_errorCount++;
				start(_name,_errorCount);
				if(_errorCount==Config.DAT_ErrorTotalCount){
					//_dispather.addErrorByte(getBlockID());
					//isDownLoad=false;
				}
			}
		}
		override protected function dataHandler(evt:EventExtensions):void{
			try{
				_dispather.addHead(_name,evt.data as ByteArray);
			}catch(err:Error){
				//有可能死循环，需要进一步处理
				errorHandler();
			}
		}
		/**加载完成后，是否有临时的加载文件，有继续加载，没有设置加载结束状态isDownLoad*/
		override protected function completeHandler(evt:Event):void
		{
			if(_tempArray.length>0){
				Debug.traceMsg(this,"加载头成功"+_name+"继续加载下一个头");
				this.start(_tempArray.shift());
			}else{
				Debug.traceMsg(this,"加载头成功"+_name);
				isDownLoad=false;
			}
		}
		override protected function getDatURL():String{
//			Debug.traceMsg(this,"头调度器getDatURL"+_initData.flvURL[loadURLIndex].replace("desc.xml",_name));
			return _initData.flvURL[loadURLIndex].replace("desc.xml",_name);
		}
		/**扩展加载，如果当前有任务，就*/
		public function extendsLoad(_name:String):void{
			_tempArray.push(_name);
		}
		//		_xml=<root>
		//			<header name="1364221677.header"/>
		//			<clip name="2013032612/1364272625_6600_593976.dat" duration="6600ms" checksum="3485068282"/>
		//			<clip name="2013032612/1364272631_7920_702171.dat" duration="7920ms" checksum="2088142328"/>
		//			<clip name="2013032612/1364272639_7560_702148.dat" duration="7560ms" checksum="364880931"/>
		//		</root>
	}
}