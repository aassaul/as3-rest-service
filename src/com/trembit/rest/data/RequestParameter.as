/**
 * Created with IntelliJ IDEA.
 * User: Andrey Assaul
 * Date: 27.07.2015
 * Time: 15:18
 */
package com.trembit.rest.data {
public final class RequestParameter {

    private var _name:String;

    public var value:*;

    public function get name():String {
        return _name;
    }

    public function RequestParameter(name:String, value:* = null) {
        _name = name;
        this.value = value;
    }
}
}
