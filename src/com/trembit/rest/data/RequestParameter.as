/**
 * Created with IntelliJ IDEA.
 * User: Andrey Assaul
 * Date: 27.07.2015
 * Time: 15:18
 */
package com.trembit.rest.data {
public final class RequestParameter {

    private var _name:String;
    private var _value:String;

    public function get name():String {
        return _name;
    }

    public function get value():String {
        return _value;
    }

    public function RequestParameter(name:String, value:String) {
        _name = name;
        _value = value;
    }
}
}
