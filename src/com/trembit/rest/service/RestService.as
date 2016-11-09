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
import flash.net.URLRequestHeader;
import flash.net.URLRequestMethod;
import flash.net.URLVariables;
import flash.utils.Dictionary;

import mx.utils.Platform;

public class RestService extends EventDispatcher {

    public static const JSON_MIME:String = "application/json";

    private static const LOADER_TO_RESPONDER_MAP:Dictionary = new Dictionary();
    private const METHOD_NAME_TO_METHOD_OBJECT_MAP:Dictionary = new Dictionary();

    private static function load(request:URLRequest, resultType:String, eventTarget:IEventDispatcher, successHandler:Function, errorHandler:Function):void {
        var loader:URLLoader = LoaderUtils.getLoader();
        var responder:LoaderResponder = new LoaderResponder(resultType, eventTarget, successHandler, errorHandler);
        responder.url = request.url + "?" + request.data;
        LOADER_TO_RESPONDER_MAP[loader] = responder;
        addListeners(loader);
        loader.load(request);
    }

    private static function addListeners(loader:URLLoader):void {
        loader.addEventListener(Event.COMPLETE, onComplete);
        loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
        loader.addEventListener(IOErrorEvent.IO_ERROR, onError);
        if (HTTPStatusEvent.HTTP_RESPONSE_STATUS) {
            loader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, onStatus);
        } else {
            loader.addEventListener(HTTPStatusEvent.HTTP_STATUS, onStatus);
        }
    }

    private static function removeEventListeners(loader:URLLoader):void {
        loader.removeEventListener(Event.COMPLETE, onComplete);
        loader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
        loader.removeEventListener(IOErrorEvent.IO_ERROR, onError);
        if (HTTPStatusEvent.HTTP_RESPONSE_STATUS) {
            loader.removeEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, onStatus);
        } else {
            loader.removeEventListener(HTTPStatusEvent.HTTP_STATUS, onStatus);
        }
    }

    private static function finishRequest(loader:URLLoader):void {
        removeEventListeners(loader);
        delete LOADER_TO_RESPONDER_MAP[loader];
        loader.close();
    }

    private static function callFault(rawData:*, errorCode:String, errorText:String, statusCode:String, responder:LoaderResponder):void {
        try {
            var errorData:Object = (rawData is String) ? JSON.parse(rawData) : rawData;
            var code:String = errorData.hasOwnProperty("code") ? errorData.code : errorCode;
            var message:String = errorData.hasOwnProperty("message") ? errorData.message : errorText;
            responder.onError(message, code, errorData);
        } catch (e:*) {
            responder.onError(errorText, statusCode || errorCode, rawData);
        }
    }

    public function RestService(baseUrl:String) {
        super(this);
        this.baseUrl = baseUrl;
    }

    private var _baseUrl:String;

    public function callPost(method:String, parameters:Vector.<RequestParameter>, headers:Vector.<URLRequestHeader>, resultType:String, successHandler:Function = null, faultHandler:Function = null):void {
        load(createRequest(method, parameters, headers, URLRequestMethod.POST), resultType, this, successHandler, faultHandler);
    }

    public function callGet(method:String, parameters:Vector.<RequestParameter>, headers:Vector.<URLRequestHeader>, resultType:String, successHandler:Function = null, faultHandler:Function = null):void {
        load(createRequest(method, parameters, headers, URLRequestMethod.GET), resultType, this, successHandler, faultHandler);
    }

    public function callMapped(method:String, values:Array, headers:Array = null, successHandler:Function = null, faultHandler:Function = null):void {
        var methodObject:RestMethod = METHOD_NAME_TO_METHOD_OBJECT_MAP[method];
        if (values.length != methodObject.parameters.length) {
            throw new ArgumentError("values number expected to be " + methodObject.parameters.length);
        }
        for (var i:int = 0; i < values.length; i++) {
            methodObject.parameters[i].value = values[i];
        }
        if (methodObject.headers.length && !(headers && headers.length == methodObject.headers.length)) {
            throw new ArgumentError("headers number expected to be " + methodObject.headers.length);
        }
        if (headers) {
            for (i = 0; i < headers.length; i++) {
                methodObject.headers[i].value = headers[i];
            }
        }
        load(createRequest(method, methodObject.parameters, methodObject.allHeaders, methodObject.urlRequestMethod), methodObject.resultType, this, successHandler, faultHandler);
    }

    public function isMapped(method:String):Boolean {
        return (method in METHOD_NAME_TO_METHOD_OBJECT_MAP);
    }

    /**
     * Maps remote method to ordered parameters see callMapped
     * @param method Name of remote method.
     * @param parameterString Parameters, separated with '&' character: name&email.
     * @param resultType Value from ResultType
     * @param urlRequestMethod Value from URLRequestMethod
     * @param defaultHeaders The array of HTTP request headers to be appended to the HTTP request
     */
    public function map(method:String, parameterString:String, resultType:String, urlRequestMethod:String, defaultHeaders:Vector.<URLRequestHeader> = null, headerString:String = null):void {
        var parameterNames:Array = parameterString.split("&");
        var parameters:Vector.<RequestParameter> = new Vector.<RequestParameter>();
        for each (var parameterName:String in parameterNames) {
            if (parameterName != "") {
                parameters.push(new RequestParameter(parameterName, ""));
            }
        }

        var headers:Vector.<URLRequestHeader> = new Vector.<URLRequestHeader>();
        if(headerString) {
            var headerNames:Array = headerString.split("&");
            for each (var headerName:String in headerNames) {
                if (headerName != "") {
                    headers.push(new URLRequestHeader(headerName, ""));
                }
            }
        }

        METHOD_NAME_TO_METHOD_OBJECT_MAP[method] = new RestMethod(urlRequestMethod, resultType, parameters, defaultHeaders, headers);
    }

    private function createRequest(method:String, parameters:Vector.<RequestParameter>, headers:Vector.<URLRequestHeader>, requestType:String):URLRequest {
        var request:URLRequest = new URLRequest(_baseUrl + method);
        request.method = requestType;
        var contentType:String = null;
        for each(var h:URLRequestHeader in headers) {
            request.requestHeaders.push(h);
            if (h.name == "Content-type") {
                contentType = h.value;
            }
        }
        if (contentType) {
            request.contentType = contentType;
        }
        var data:URLVariables = new URLVariables();
        for each (var parameter:RequestParameter in parameters) {
            data[parameter.name] = parameter.value;
        }
        if (Platform.isBrowser && contentType != JSON_MIME && !(parameters && parameters.length)) {
            /*	according to
             If running in Flash Player and the referenced form has no body, Flash Player automatically uses a GET operation, even if the method is set to URLRequestMethod.POST. For this reason, it is recommended to always include a "dummy" body to ensure that the correct method is used.
             http://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/net/URLRequest.html#method
             */
            data["dummyData"] = "dummyData";
        }
        request.data = (contentType == JSON_MIME) ? JSON.stringify(data) : data;
        if (Platform.isBrowser && request.requestHeaders.length && requestType != URLRequestMethod.POST) {
            request.method = URLRequestMethod.POST;
            request.requestHeaders.push(new URLRequestHeader("X-HTTP-Method-Override", requestType));
        }

        return request;
    }

    private static function onError(event:ErrorEvent):void {
        var loader:URLLoader = URLLoader(event.currentTarget);
        var responder:LoaderResponder = LOADER_TO_RESPONDER_MAP[loader];
        var rawData:* = loader.data;
        finishRequest(loader);
        callFault(rawData, event.errorID.toString(), event.text, responder.statusCode, responder);
    }

    private static function onStatus(event:HTTPStatusEvent):void {
        var loader:URLLoader = URLLoader(event.currentTarget);
        var responder:LoaderResponder = LOADER_TO_RESPONDER_MAP[loader];
        responder.statusCode = event.status.toString();
        if (event.type === HTTPStatusEvent.HTTP_RESPONSE_STATUS) {
            responder.headers = event.responseHeaders;
        }
    }

    private static function onComplete(event:Event):void {
        var loader:URLLoader = URLLoader(event.currentTarget);
        var responder:LoaderResponder = LOADER_TO_RESPONDER_MAP[loader];
        var data:* = loader.data;
        finishRequest(loader);
        if (responder.statusCode && responder.statusCode != "200") {
            callFault(data, responder.statusCode, data, responder.statusCode, responder);
        } else {
            responder.onSuccess(data);
        }
    }

    public function get baseUrl():String {
        return _baseUrl;
    }

    public function set baseUrl(value:String):void {
        _baseUrl = value;
    }
}
}

import com.trembit.rest.constants.ResultType;
import com.trembit.rest.data.RequestParameter;

import flash.events.IEventDispatcher;
import flash.net.URLRequestHeader;

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
    public var headers:Array;
    public var url:String;

    public function onSuccess(result:*):void {
        if (_successHandler != null) {
            resultEvent = ResultEvent.createEvent(getResult(result));
            _dispatcher.addEventListener(resultEvent.type, onResult);
            _dispatcher.dispatchEvent(resultEvent);
        } else {
            dispose();
        }
    }

    public function onError(message:String, code:String, faultContent:Object):void {
        if (_errorHandler != null) {
            faultEvent = FaultEvent.createEvent(new Fault(code, message, url), null);
            faultEvent.fault.content = faultContent;
            faultEvent.headers = headers;
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
                return (data is String) ? JSON.parse(data) : data;
            case ResultType.XML:
                return (data is XML) ? data : new XML(data);
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
        statusCode = null;
        headers = null;
        url = null;
    }
}
internal class RestMethod {
    private var _urlRequestMethod:String;
    private var _resultType:String;
    private var _parameters:Vector.<RequestParameter>;
    private var _headers:Vector.<URLRequestHeader>;
    private var _defaultHeaders:Vector.<URLRequestHeader>;

    public function get urlRequestMethod():String {
        return _urlRequestMethod;
    }

    public function get resultType():String {
        return _resultType;
    }

    public function get parameters():Vector.<RequestParameter> {
        return _parameters;
    }

    public function RestMethod(urlRequestMethod:String, resultType:String, parameters:Vector.<RequestParameter>, defaultHeaders:Vector.<URLRequestHeader> = null, headers:Vector.<URLRequestHeader> = null) {
        _urlRequestMethod = urlRequestMethod;
        _resultType = resultType;
        _parameters = parameters;
        _defaultHeaders = defaultHeaders;
        _headers = headers;
    }

    public function get allHeaders():Vector.<URLRequestHeader> {
        var res:Vector.<URLRequestHeader> = new Vector.<URLRequestHeader>();
        if(_defaultHeaders) {
            res = res.concat(_defaultHeaders);
        }
        if(_headers) {
            res = res.concat(_headers);
        }
        return res;
    }

    public function get headers():Vector.<URLRequestHeader> {
        return _headers;
    }
}