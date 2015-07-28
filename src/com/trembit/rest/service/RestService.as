/**
 * Created with IntelliJ IDEA.
 * User: Andrey Assaul
 * Date: 27.07.2015
 * Time: 14:06
 */
package com.trembit.rest.service {
import com.trembit.rest.data.RequestParameter;

import flash.events.ErrorEvent;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.HTTPStatusEvent;
import flash.events.IEventDispatcher;
import flash.events.IOErrorEvent;
import flash.events.SecurityErrorEvent;
import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.net.URLRequestMethod;
import flash.net.URLVariables;
import flash.utils.Dictionary;

public class RestService extends EventDispatcher {

    private static const LOADER_TO_RESPONDER_MAP:Dictionary = new Dictionary();

    private var baseUrl:String;

    private function createRequest(method:String, parameters:Vector.<RequestParameter>, requestType:String):URLRequest {
        var request:URLRequest = new URLRequest(baseUrl + method);
        request.method = requestType;
        var data:URLVariables = new URLVariables();
        for each (var parameter:RequestParameter in parameters) {
            data[parameter.name] = parameter.value;
        }
        request.data = data;
        return request;
    }

    private static function load(request:URLRequest, resultType:String, eventTarget:IEventDispatcher, successHandler:Function, errorHandler:Function):void {
        var loader:URLLoader = LoaderUtils.getLoader();
        var responder:LoaderResponder = new LoaderResponder(resultType, eventTarget, successHandler, errorHandler);
        LOADER_TO_RESPONDER_MAP[loader] = responder;
        addListeners(loader);
        loader.load(request);
    }

    private static function addListeners(loader:URLLoader):void {
        loader.addEventListener(Event.COMPLETE, onComplete);
        loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
        loader.addEventListener(IOErrorEvent.IO_ERROR, onError);
        loader.addEventListener(HTTPStatusEvent.HTTP_STATUS, onStatus);
        if(HTTPStatusEvent.HTTP_RESPONSE_STATUS){
            loader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, onStatus);
        }
    }

    private static function removeEventListeners(loader:URLLoader):void {
        loader.removeEventListener(Event.COMPLETE, onComplete);
        loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
        loader.removeEventListener(IOErrorEvent.IO_ERROR, onError);
        loader.removeEventListener(HTTPStatusEvent.HTTP_STATUS, onStatus);
        if(HTTPStatusEvent.HTTP_RESPONSE_STATUS){
            loader.removeEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, onStatus);
        }
    }

    private static function finishRequest(loader:URLLoader):void {
        removeEventListeners(loader);
        delete LOADER_TO_RESPONDER_MAP[loader];
        loader.close();
    }

    private static function onError(event:ErrorEvent):void {
        var loader:URLLoader = URLLoader(event.currentTarget);
        var responder:LoaderResponder = LOADER_TO_RESPONDER_MAP[loader];
        var rawData:String = String(loader.data);
        finishRequest(loader);
        try {
            var errorData:Object = JSON.parse(rawData);
            var code:String = errorData.hasOwnProperty("code") ? errorData.code : event.errorID.toString();
            var message:String = errorData.hasOwnProperty("message") ? errorData.message : event.text;
            responder.onError(message, code, errorData);
        } catch (e:*) {
            responder.onError(event.text, responder.statusCode?responder.statusCode:event.errorID.toString(), rawData);
        }
    }

    private static function onStatus(event:HTTPStatusEvent):void{
        var loader:URLLoader = URLLoader(event.currentTarget);
        var responder:LoaderResponder = LOADER_TO_RESPONDER_MAP[loader];
        responder.statusCode = event.status.toString();
    }

    private static function onComplete(event:Event):void {
        var loader:URLLoader = URLLoader(event.currentTarget);
        var responder:LoaderResponder = LOADER_TO_RESPONDER_MAP[loader];
        var data:* = loader.data;
        finishRequest(loader);
        responder.onSuccess(data);
    }

    public function callPost(method:String, parameters:Vector.<RequestParameter>, resultType:String, successHandler:Function = null, errorHandler:Function = null):void {
        load(createRequest(method, parameters, URLRequestMethod.POST), resultType, this, successHandler, errorHandler);
    }

    public function callGet(method:String, parameters:Vector.<RequestParameter>, resultType:String, successHandler:Function = null, errorHandler:Function = null):void {
        load(createRequest(method, parameters, URLRequestMethod.GET), resultType, this, successHandler, errorHandler);
    }

    public function RestService(baseUrl:String) {
        super(this);
        this.baseUrl = baseUrl;
    }
}
}

import com.trembit.rest.constants.ResultType;

import flash.events.IEventDispatcher;

import mx.rpc.Fault;
import mx.rpc.events.FaultEvent;
import mx.rpc.events.ResultEvent;

internal final class LoaderResponder {
    private var _successHandler:Function;
    private var _errorHandler:Function;
    private var _resultType:String;
    private var _dispatcher:IEventDispatcher;

    private var faultEvent:FaultEvent;
    private var resultEvent:ResultEvent;

    public var statusCode:String;
    public var faultData:*;

    public function onSuccess(result:*):void {
        if (_successHandler != null) {
            resultEvent = ResultEvent.createEvent(getResult(result));
            _dispatcher.addEventListener(resultEvent.type, onResult);
            _dispatcher.dispatchEvent(resultEvent);
        } else {
            dispose();
        }
    }

    public function onError(message:String, code:String, faultContent:Object = null):void {
        if (_errorHandler != null) {
            faultEvent = FaultEvent.createEvent(new Fault(code, message));
            faultEvent.fault.content = faultContent;
            _dispatcher.addEventListener(faultEvent.type, onFault);
            _dispatcher.dispatchEvent(faultEvent);
        } else {
            dispose();
        }
    }

    public function LoaderResponder(resultType:String, eventTarget:IEventDispatcher, successHandler:Function, errorHandler:Function) {
        _successHandler = successHandler;
        _errorHandler = errorHandler;
        _resultType = resultType;
        _dispatcher = eventTarget;
    }

    private function onResult(event:ResultEvent):void {
        if (resultEvent === event) {
            _dispatcher.removeEventListener(event.type, onResult);
            _successHandler(event);
            dispose();
        }
    }

    private function onFault(event:FaultEvent):void {
        if (faultEvent === event) {
            _dispatcher.removeEventListener(event.type, onFault);
            _errorHandler(event);
            dispose();
        }
    }

    private function getResult(data:*):* {
        switch (_resultType) {
            case ResultType.JSON:
                return JSON.parse(data);
            case ResultType.XML:
                return new XML(data);
            case ResultType.NUMBER:
                return Number(data);
            case ResultType.STRING:
                return String(data);
        }
        return data;
    }

    private function dispose():void {
        _errorHandler = null;
        _successHandler = null;
        _dispatcher = null;
        _resultType = null;
        resultEvent = null;
        faultEvent = null;
    }
}