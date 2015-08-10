/**
 * Created with IntelliJ IDEA.
 * User: Andrey Assaul
 * Date: 27.07.2015
 * Time: 19:11
 */
package com.trembit.rest.service {
import com.trembit.rest.constants.ResultType;
import com.trembit.rest.data.RequestParameter;

import flash.events.Event;

import flash.events.EventDispatcher;
import flash.net.URLRequestMethod;

import mx.rpc.events.FaultEvent;

import mx.rpc.events.ResultEvent;

import org.flexunit.asserts.assertEquals;
import org.flexunit.asserts.assertNotNull;

import org.flexunit.asserts.assertTrue;
import org.flexunit.asserts.fail;

import org.flexunit.async.Async;

public class RestServiceTest extends EventDispatcher{

    private static function failOnFault(data:FaultEvent):void{
        fail(data.fault.faultString);
    }

    private static function failOnComplete(data:ResultEvent):void{
        fail("Expected fault, but was complete");
    }

    [Test(async)]
    public function testCallGet():void {
        var service:RestService = new RestService("http://192.168.1.127:1715/");
        service.callGet("get", new <RequestParameter>[
                    new RequestParameter("param1", "value1"),
                    new RequestParameter("param2", "value 2")
                ],
                ResultType.JSON, onTestJSONResult, failOnFault);
        Async.proceedOnEvent(this, this, Event.COMPLETE, 5*1000);
    }

    private function onTestJSONResult(data:ResultEvent):void{
        assertTrue(data.result.hasOwnProperty("param1"));
        assertTrue(data.result.hasOwnProperty("param2"));
        assertEquals(data.result.param1, "value1");
        assertEquals(data.result.param2, "value 2");
        var service:RestService = RestService(data.currentTarget);
        assertNotNull(service);
        service.callGet("get1", null, null, failOnComplete, onTestFault);
        assertEquals(LoaderUtils.loaders.length, 1);
    }

    private function onTestFault(data:FaultEvent):void{
        var service:RestService = RestService(data.currentTarget);
        assertNotNull(service);
        service.callPost("post", new <RequestParameter>[
                    new RequestParameter("param1", "value1"),
                    new RequestParameter("param2", "value 2")
                ],
                ResultType.JSON, onTestPost, failOnFault);
        service.callGet("get", null, null, null, failOnFault);
        assertEquals(LoaderUtils.loaders.length, 2);
    }

    private function onTestPost(data:ResultEvent):void{
        assertTrue(data.result.hasOwnProperty("param1"));
        assertTrue(data.result.hasOwnProperty("param2"));
        assertEquals(data.result.param1, "value1");
        assertEquals(data.result.param2, "value 2");
        var service:RestService = RestService(data.currentTarget);
        service.map("get", "param1&param2", ResultType.JSON, URLRequestMethod.GET);
        assertTrue(service.isMapped("get"));
        service.callMapped("get", ["value1", "value 2"], onTestMap, failOnFault);
    }

    private function onTestMap(data:ResultEvent):void{
        assertTrue(data.result.hasOwnProperty("param1"));
        assertTrue(data.result.hasOwnProperty("param2"));
        assertEquals(data.result.param1, "value1");
        assertEquals(data.result.param2, "value 2");
        dispatchEvent(new Event(Event.COMPLETE));
    }
}
}
