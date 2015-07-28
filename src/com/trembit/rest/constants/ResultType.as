/**
 * Created with IntelliJ IDEA.
 * User: Andrey Assaul
 * Date: 27.07.2015
 * Time: 19:51
 */
package com.trembit.rest.constants {
public final class ResultType {

    public static const JSON:String = "JSON";
    public static const XML:String = "XML";
    public static const STRING:String = "STRING";
    public static const NUMBER:String = "NUMBER";
    public static const DEFAULT:String = "DEFAULT";

    public function ResultType() {
        throw new Error("ResultType is static and should not be instantiated");
    }
}
}