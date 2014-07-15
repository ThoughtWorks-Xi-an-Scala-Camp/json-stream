package com.qifun.jsonStream.rpc;

import com.dongxiguo.continuation.Continuation;
import com.dongxiguo.continuation.utils.Generator;
import com.qifun.jsonStream.JsonStream;
import com.qifun.jsonStream.rpc.JsonHandler.JsonResponse;

#if macro
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.*;
import com.qifun.jsonStream.JsonDeserializer;
import com.qifun.jsonStream.JsonSerializer;
#end


@:dox(hide)
class OutgoingProxyRuntime
{

  @:extern
  @:noUsing
  private static inline function extract1<Element, Result>(iterator:Iterator<Element>, handler:Element->Result):Result return
  {
    if (iterator.hasNext())
    {
      var element = iterator.next();
      if (iterator.hasNext())
      {
        throw JsonDeserializer.JsonDeserializerError.TOO_MANY_FIELDS(iterator, 1);
      }
      else
      {
        handler(element);
      }
    }
    else
    {
      throw JsonDeserializer.JsonDeserializerError.NOT_ENOUGH_FIELDS(iterator, 1, 0);
    }
  }

  @:extern
  @:noUsing
  public static inline function optimizedExtract1<Element, Result>(iterator:Iterator<Element>, handler:Element->Result):Result return
  {
    var generator = Std.instance(iterator, (Generator:Class<Generator<Element>>));
    if (generator == null)
    {
      extract1(iterator, handler);
    }
    else
    {
      extract1(generator, handler);
    }
  }

  @:noUsing
  public static function object1(key1:String, value1:JsonStream):JsonStream return
  {
    JsonStream.OBJECT(new Generator(Continuation.cpsFunction(
      function(yield):Void
        yield(new JsonStreamPair(key1, value1)).async())));
  }
}

class OutgoingProxyFactory
{

  #if macro

  static function processName(sb:StringBuf, s:String):Void
  {
    var i = 0;
    while (i != -1)
    {
      var prev = i;
      i = s.indexOf("_", prev);
      if (i != -1)
      {
        sb.addSub(s, prev, i - prev);
        sb.add("__");
      }
      else
      {
        sb.addSub(s, prev);
        break;
      }
    }
  }

  static function proxyMethodName(pack:Array<String>, name:String):String
  {
    var sb = new StringBuf();
    sb.add("outgoingProxy_");
    for (p in pack)
    {
      processName(sb, p);
      sb.add("_");
    }
    processName(sb, name);
    return sb.toString();
  }

  static function proxyClassName(pack:Array<String>, name:String):String
  {
    var sb = new StringBuf();
    sb.add("OutgoingProxy_");
    for (p in pack)
    {
      processName(sb, p);
      sb.add("_");
    }
    processName(sb, name);
    return sb.toString();
  }

  static function outgoingProxyField(accessExpr:Expr, localPrefix:Expr, serviceClassType:ClassType):Field return
  {
    var typeParameters =
    [
      for (p in serviceClassType.params)
      {
        TPType(TPath({ pack: [], name: p.name }));
      }
    ];
    var typeParameterDeclarations:Array<TypeParamDecl> =
    [
      for (p in serviceClassType.params)
      {
        name: p.name,
        // TODO: Constraits
      }
    ];
    var serviceModule = serviceClassType.module;
    var pack = Context.getLocalModule().split(".");
    pack[pack.length - 1] = "outgoingProxies_" + pack[pack.length - 1];
    var fields:Array<Field> = [];
    for (field in serviceClassType.fields.get())
    {
      switch (field)
      {
        case { kind: FVar(_) | FMethod(MethMacro) }: continue;
        case
        {
          kind: FMethod(methodKind),
          type: TFun(args, futureType),
          name: fieldName,
        }:
        {
          var responseTypes = Future.FutureTypeResolver.getAwaitResultTypes(futureType);
          var methodName = field.name;
          var numRequestArguments = args.length;
          var methodParameterDeclarations:Array<TypeParamDecl>  =
          [
            for (p in field.params)
            {
              name: p.name,
              // TODO: Constraits
            }
          ];
          var allParameterDeclarations = typeParameterDeclarations.concat(methodParameterDeclarations);
          var requestYieldExprs =
          [
            for (i in 0...numRequestArguments)
            {
              var requestType = args[i].t;
              var complexRequestType = TypeTools.toComplexType(requestType);
              var requestName = "request" + i;
              var serializeExpr =
                JsonSerializerGenerator.resolvedSerialize(
                  complexRequestType,
                  macro $i{requestName},
                  allParameterDeclarations);
              macro yield($serializeExpr).async();
            }
          ];
          var requestBlock =
          {
            expr: EBlock(requestYieldExprs),
            pos: Context.currentPos(),
          }

          function parseResponses(
            readArray:Expr,
            responseHandler:Expr,
            responseIndex:Int):Expr return
          {
            if (responseIndex < responseTypes.length)
            {
              var reponseType = responseTypes[responseIndex];
              var complexResponseType = TypeTools.toComplexType(reponseType);
              var responseName = "response" + responseIndex;
              var next =
                parseResponses(
                  readArray,
                  responseHandler,
                  responseIndex + 1);
              var deserializeExpr =
                JsonDeserializerGenerator.resolvedDeserialize(
                  complexResponseType,
                  macro elementStream,
                  allParameterDeclarations);
              macro com.qifun.jsonStream.rpc.OutgoingProxyFactory.OutgoingProxyRuntime.optimizedExtract1($readArray, function(elementStream):Void
              {
                var $responseName:$complexResponseType = $deserializeExpr;
                $next;
              });
            }
            else
            {
              var parameters =
              [
                for (i in 0...responseTypes.length)
                {
                  var responseName = "response" + i;
                  macro $i{responseName};
                }
              ];
              macro $responseHandler($a{parameters});
            }
          }
          var parseResponseExpr =
            parseResponses(
              macro readResponse,
              macro responseHandler,
              0);
          var implementationArgs:Array<FunctionArg> =
          [
            for (i in 0...numRequestArguments)
            {
              var arg = args[i];
              {
                name: "request" + i,
                type: TypeTools.toComplexType(arg.t),
              }
            }
          ];
          var methodBody =
            macro return com.qifun.jsonStream.rpc.Future.FutureHelper.newFuture(
              function(responseHandler, catcher:Dynamic->Void):Void
              {
                this.outgoingRpc.apply(
                  com.qifun.jsonStream.rpc.OutgoingProxyFactory.OutgoingProxyRuntime.object1(
                    $v{methodName},
                    com.qifun.jsonStream.JsonStream.ARRAY(
                      new com.dongxiguo.continuation.utils.Generator(
                        com.dongxiguo.continuation.Continuation.cpsFunction(
                          function(yield:com.dongxiguo.continuation.utils.Generator.YieldFunction <
                            com.qifun.jsonStream.JsonStream > ):Void
                            $requestBlock)))),
                  new com.qifun.jsonStream.rpc.JsonHandler(
                    function(response:com.qifun.jsonStream.rpc.JsonHandler.JsonResponse):Void
                    {
                      switch (response)
                      {
                        case FAILURE(errorStream):
                        {
                          $localPrefix.handleError(catcher, errorStream);
                        }
                        case SUCCESS(com.qifun.jsonStream.JsonStream.ARRAY(readResponse)):
                        {
                          $parseResponseExpr;
                        }
                        case SUCCESS(response):
                        {
                          throw com.qifun.jsonStream.JsonDeserializer.JsonDeserializerError.UNMATCHED_JSON_TYPE(response, [ "ARRAY" ]);
                        }
                      }
                    }));
              });
          //trace(ExprTools.toString(methodBody));
          fields.push(
            {
              name: fieldName,
              pos: Context.currentPos(),
              access: switch(methodKind)
              {
                case MethInline: [ APublic, AInline ];
                case MethNormal: [ APublic ];
                case MethDynamic: [ APublic, ADynamic ];
                case _: throw "Unexpected MethodKind";
              },
              kind: FFun(
                {
                  args: implementationArgs,
                  ret: TypeTools.toComplexType(futureType),
                  expr: methodBody,
                  params:
                  [
                    for (typeParameter in field.params)
                    {
                      name: typeParameter.name,
                      // TODO: constraits
                    }
                  ],
                }),

            });

        }
        case _: throw "Expect method!";
      }
    }
    var proxyDefinition =
    {
      pack: pack,
      name: proxyClassName(serviceClassType.pack, serviceClassType.name),
      pos: Context.currentPos(),
      params: typeParameterDeclarations,
      isExtern: false,
      meta: [ { name: ":access", params: [ accessExpr ], pos: Context.currentPos(), } ],
      kind: TDClass(
        {
          pack: [ "com", "qifun", "jsonStream", "rpc" ],
          name: "OutgoingProxy",
        },
        [
          {
            pack: serviceClassType.pack,
            name: serviceModule.substring(serviceModule.lastIndexOf(".") + 1),
            sub: serviceClassType.name,
            params: typeParameters,
          }
        ],
        false),
      fields: fields,
    };
    Context.defineType(proxyDefinition);
    var proxyImplementationPath:TypePath =
    {
      name: proxyDefinition.name,
      pack: proxyDefinition.pack,
      params: typeParameters
    };
    {
      name: proxyMethodName(serviceClassType.pack, serviceClassType.name),
      access: [ AStatic, APublic ],
      pos: Context.currentPos(),
      kind: FFun(
        {
          params: typeParameterDeclarations,
          args:
          [
            {
              name: "outgoingRpc",
              type: null,
            }
          ],
          ret: null,
          expr: macro return new $proxyImplementationPath(outgoingRpc),
        })
    }
  }

  static function catcherField():Field return
  {
    name: "handleError",
    access: [ AStatic ],
    pos: Context.currentPos(),
    kind: FFun(
      {
        args:
        [
          {
            type: null,
            name: "catcher",
          },
          {
            type: null,
            name: "errorResponse",
          }
        ],
        ret: null,
        expr: macro
        {
          var error:Dynamic = com.qifun.jsonStream.JsonDeserializer.deserialize(errorResponse);
          catcher(error);
        },
      }),
  }

  #end

  @:noUsing
  macro public static function generateOutgoingProxyFactory(includeModules:Array<String>):Array<Field> return
  {
    var fields = Context.getBuildFields();

    fields.push(catcherField());
    var localClass = Context.getLocalClass().get();
    var packExpr = MacroStringTools.toFieldExpr(localClass.pack);
    var localModuleName = localClass.module.substring(localClass.module.lastIndexOf(".") + 1);
    var moduleExpr = packExpr == null ? macro $i{localModuleName} : macro $packExpr.$localModuleName;
    var localName = localClass.name;
    var localPrefix = macro $moduleExpr.$localName;
    var accessExpr = packExpr == null ? macro $i{localName} : macro $packExpr.$localName;
    for (moduleName in includeModules)
    {
      for (rootType in Context.getModule(moduleName))
      {
        switch (rootType)
        {
          case TInst(_.get() => classType, args) if (classType.isInterface):
          {
            fields.push(outgoingProxyField(accessExpr, localPrefix, classType));
          }
          default:
        }
      }
    }
    fields;
  }

}
