package com.qifun.jsonStream.deserializerPlugin;

import com.dongxiguo.continuation.utils.Generator;
import com.qifun.jsonStream.JsonStream;
import com.qifun.jsonStream.JsonDeserializer;
import haxe.Int64;

@:final
class Int64DeserializerPlugin
{

  public static function deserialize(stream:JsonDeserializerPluginStream<Int64>):Null<Int64> return
  {
    switch (stream.underlying)
    {
      case com.qifun.jsonStream.JsonStream.ARRAY(elements):
        com.qifun.jsonStream.IteratorExtractor.optimizedExtract2(
          elements, function(high, low) return Int64.make(cast high, cast low));
      case NULL:
        null;
      case _:
        throw "Expect number";
    }
  }
}

@:final
class IntDeserializerPlugin
{
  public static function deserialize(stream:JsonDeserializerPluginStream<Int>):Null<Int> return
  {
    switch (stream.underlying)
    {
      case com.qifun.jsonStream.JsonStream.NUMBER(value):
        cast value;
      case NULL:
        null;
      case _:
        throw "Expect number";
    }
  }
}

@:final
class UIntDeserializerPlugin
{
  public static function deserialize(stream:JsonDeserializerPluginStream<UInt>):Null<UInt> return
  {
    switch (stream.underlying)
    {
      case com.qifun.jsonStream.JsonStream.NUMBER(value):
        cast value;
      case NULL:
        null;
      case _:
        throw "Expect number";
    }
  }
}

#if (java || cs)
  @:final
  class SingleDeserializerPlugin
  {
    public static function deserialize(stream:JsonDeserializerPluginStream<Single>):Null<Single> return
    {
      switch (stream.underlying)
      {
        case com.qifun.jsonStream.JsonStream.NUMBER(value):
          value;
        case NULL:
          null;
        case _:
          throw "Expect number";
      }
    }
  }
#end

@:final
class FloatDeserializerPlugin
{
  public static function deserialize(stream:JsonDeserializerPluginStream<Float>):Null<Float> return
  {
    switch (stream.underlying)
    {
      case com.qifun.jsonStream.JsonStream.NUMBER(value):
        value;
      case NULL:
        null;
      case _:
        throw "Expect number";
    }
  }
}

@:final
class BoolDeserializerPlugin
{
  public static function deserialize(stream:JsonDeserializerPluginStream<Bool>):Null<Bool> return
  {
    switch (stream.underlying)
    {
      case com.qifun.jsonStream.JsonStream.FALSE: false;
      case com.qifun.jsonStream.JsonStream.TRUE: true;
      case NULL:
        null;
      case _: throw "Expect false | true";
    }
  }
}

@:final
class StringDeserializerPlugin
{
  public static function deserialize(stream:JsonDeserializerPluginStream<String>):Null<String> return
  {
    switch (stream.underlying)
    {
      case com.qifun.jsonStream.JsonStream.STRING(value):
        value;
      case NULL:
        null;
      case _:
        throw "Expect string";
    }
  }
}

@:final
class ArrayDeserializerPlugin
{

  @:extern
  public static function getDynamicDeserializerPluginType():Null<Array<Dynamic>> return
  {
    throw "Used at compile-time only!";
  }

  public static function deserializeForElement<Element>(stream:JsonDeserializerPluginStream<Array<Element>>, elementDeserializeFunction:JsonDeserializerPluginStream<Element>->Element):Array<Element> return
  {
    switch (stream.underlying)
    {
      case com.qifun.jsonStream.JsonStream.ARRAY(value):
        var generator = Std.instance(value, (Generator:Class<Generator<JsonStream>>));
        if (generator != null)
        {
          [
            for (element in generator)
            {
              elementDeserializeFunction(new JsonDeserializerPluginStream(element));
            }
          ];
        }
        else
        {
          [
            for (element in value)
            {
              elementDeserializeFunction(new JsonDeserializerPluginStream(element));
            }
          ];
        }
      case NULL:
        null;
      case _:
        throw "Expect array";
    }
  }
  
  macro public static function deserialize<Element>(stream:ExprOf<JsonDeserializerPluginStream<Array<Element>>>):ExprOf<Array<Element>> return
  {
    macro com.qifun.jsonStream.deserializerPlugin.PrimitiveDeserializerPlugins.ArrayDeserializerPlugin.deserializeForElement($stream, function(substream) return substream.deserialize());
  }
}

//TODO : StringMap and IntMap
