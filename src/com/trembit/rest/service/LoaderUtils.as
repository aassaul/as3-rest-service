/**
 * Created with IntelliJ IDEA.
 * User: Andrey Assaul
 * Date: 27.07.2015
 * Time: 15:29
 */
package com.trembit.rest.service {
import flash.net.URLLoader;

internal final class LoaderUtils {

    internal static const loaders:Array = [];
    public static function getLoader():URLLoader{
        for each (var loader:CacheURLLoader in loaders) {
            if(!loader.running){
                return loader;
            }
        }
        loader = new CacheURLLoader();
        loaders.push(loader);
        return loader;
    }

    public function LoaderUtils() {
        throw new Error("LoaderUtils is static and should not be instantiated");
    }
}
}

import flash.net.URLLoader;
import flash.net.URLRequest;

internal class CacheURLLoader extends URLLoader {

    private var _running:Boolean;

    public function get running():Boolean{
        return _running;
    }

    override public function load(request:URLRequest):void {
        _running = true;
        super.load(request);
    }

    override public function close():void {
        _running = false;
        super.close();
    }
}