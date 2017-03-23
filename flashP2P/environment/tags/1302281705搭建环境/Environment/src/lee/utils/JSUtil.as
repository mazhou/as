package lee.utils{
{
    /**
    *Author: ATHER Shu 2008.9.26
    * JSUtil类: 一些直接调用浏览器简单js的实用类
    * 功能：
    * 1.显示swf所在页面也就是浏览器地址栏地址 getPageUrl
    * 2.显示swf所在地址(未实现，求高手指点) getSwfUrl
    * 3.直接弹出浏览器提示 explorerAlert
    * 4.获取swf所在页面的编码方式 getpageEncoding
    * 5.获取浏览器类型 getBrowserType
    * 6.直接运行js代码 eval
    * http://www.asarea.cn
    * ATHER Shu(AS)
    */
    import flash.external.ExternalInterface;
    import flash.net.URLRequest;
    import flash.net.navigateToURL;
    
    public class JSUtil
    {
        //获取当前页面url
        public static function getPageUrl():String
        {
            //在ie中如果没有用object classid或者没有赋id属性，而直接用embed，该方法会失效！
            var pageurl:String = ExternalInterface.call("eval", "window.location.href");
            if(pageurl == null)
                pageurl = "none";//"not in a page or js called fail";
            return pageurl;
        }
        //获取swf文件所在url
        public static function getSwfUrl():String
        {
            //要用displayobject的loaderinfo而无法全局访问！
            return "get it later";
        }
        //通过js弹出浏览器提示alert
        public static function explorerAlert(msg:String):void
        {
            navigateToURL(new URLRequest("javascript:alert('"+msg+"')"), "_self");
        }
        //获取swf所在页面编码方式
        public static function getpageEncoding():String
        {
            //IE下用:document.charset
            //Firefox下用:document.characterSet
            var pageencoding:String = ExternalInterface.call("eval", "document.charset");
            if(pageencoding == null)
                pageencoding = ExternalInterface.call("eval", "document.characterSet");
            //
            if(pageencoding == null)
                pageencoding = "NONE";//can't get the page encoding
            return pageencoding.toUpperCase();
        }
        //获取浏览器类型
        public static function getBrowserType():String
        {
            //var browsertype:String = ExternalInterface.call("eval", "navigator.appName");
            var browsertype:String = ExternalInterface.call("eval", "navigator.userAgent");
            return (browsertype ? browsertype:"NONE");
        }
        //直接运行js语句，eval
        public static function eval(code:String):Object
        {
            var rtn:Object = ExternalInterface.call("eval", code);
            return rtn;
        }
    }
}