import 'dart:core';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/ast_factory.dart';
import 'package:analyzer/src/dart/ast/token.dart';
import 'package:front_end/src/scanner/token.dart';

import '../base.dart';
import '../app.dart';
import 'base.dart';

ListLiteral createNodeList(
    AstFactory fac, List<AttributeNode> attrs, List<dynamic> content) {
  // fix type mismatch
  List<CollectionElement> list = [];
  for (var item in content) {
    if (item is CollectionElement) {
      list.add(item);
    } else {
      print(
          "warning : [${item.runtimeType}] element is drop -> ${item.toString()}");
    }
  }
  var type = attrs.firstWhere((i) => i.name == "type" && i.ns == null,
      orElse: () => null);
  var typeMeta = type?.value;
  var typeList = typeMeta != null
      ? fac.typeArgumentList(
          null,
          [
            fac.typeName(
                fac.simpleIdentifier(
                    new StringToken(TokenType.STRING, typeMeta, 0)),
                null)
          ],
          null)
      : null;
  return fac.listLiteral(null, typeList, null, list, null);
}

dynamic createEscapeText(AstFactory fac, String text) {
  return fac.simpleIdentifier(new StringToken(TokenType.STRING, text, 0));
}

FunctionExpressionInvocation createFunctionInvokation(
    AstFactory fac, ComponentTreeNode app, List<dynamic> content) {
  // fix type mismatch
  List<Expression> list = [];
  for (var item in content) {
    if (item is Expression) {
      list.add(item);
    } else {
      print(
          "warning : [${item.runtimeType}] element is drop -> ${item.toString()}");
    }
  }
  return fac.functionExpressionInvocation(
      fac.simpleIdentifier(
          new StringToken(TokenType.IDENTIFIER, app.fullname, 0)),
      null,
      fac.argumentList(null, list, null));
}

InsertResult parseInsertExpression(String expression) {
  var valid = false;
  var reg = new RegExp("({{\r*([^}{]+)\r*}})");
  // print("input $expression --> matched:${reg.hasMatch(expression)}");
  var newExpression = expression.replaceAllMapped(reg, (matched) {
    if (matched is RegExpMatch) {
      if (valid == false) valid = true;
      // var insertExp = matched.group(1);
      var insertValue = matched.group(2).trim();
      // print("expr -> [$insertExp]");
      // print("matc -> [$insertValue]");
      return insertValue /*.replaceAll("this.", "_delegate.")*/;
    } else {
      return matched.input;
    }
  });
  return new InsertResult(valid, valid ? newExpression : "'$newExpression'");
}

NamedExpression createNamedParamByAttr(
    AstFactory fac, String slotName, String insert) {
  return fac.namedExpression(
      fac.label(
          fac.simpleIdentifier(new StringToken(TokenType.STRING, slotName, 0)),
          new SimpleToken(TokenType.COLON, 0)),
      fac.simpleIdentifier(new StringToken(TokenType.STRING, insert, 0)));
}

List<SimpleIdentifier> insertTextNode(AstFactory fac, String text) {
  List<SimpleIdentifier> content = [];
  var insert = parseInsertExpression(text);
  content.add(
      fac.simpleIdentifier(new StringToken(TokenType.STRING, insert.value, 0)));
  return content;
}

List<Turn> normalizeIfElseOfNodes(
    List<TempPayload> payloads, bool canUseIfElement) {
  List<Turn> turns = [];
  for (var idx = 0; idx < payloads.length; idx++) {
    // print("start step ${idx + 1}");
    var item = payloads[idx];
    var child = item.node;
    var ifIdx = child.attrs.indexWhere((i) => isStatementIf(i));
    if (ifIdx >= 0) {
      // print("${item.node.fullname} - if");
      item.isIf = true;
    }
    var elseIdx = child.attrs.indexWhere((i) => isStatementElse(i));
    if (elseIdx >= 0) {
      // print("${item.node.fullname} - else");
      item.isElse = true;
    }
    if (idx > 0) {
      var previousItem = payloads[idx - 1];
      if (previousItem.isIf && !previousItem.isSelf) {
        if (!canUseIfElement && !item.isElse) {
          throw UnsupportedError(
              "generate tree node failed -> statement 'if' can't exist without statement 'else'");
        }
        if (canUseIfElement && !item.isElse) {
          previousItem.isIfElement = true;
          continue;
        }
        previousItem.isIfStatement = true;
      }
    }
  }
  for (var idx = 0; idx < payloads.length; idx++) {
    // print(idx);
    var payload = payloads[idx];
    if (payload.isSelf) {
      var node = payload.node;
      var elseNode =
          node.attrs.firstWhere((i) => isStatementElse(i), orElse: () => null);
      var newEscape = new ComponentTreeNode(
          true,
          "EscapeText",
          /** 暂时不处理，需要改 */ null,
          XDML,
          [],
          [],
          elseNode?.value,
          node.parent);
      turns.add(
          new Turn([payload, new TempPayload(newEscape, payload.slot, -1)])
            ..type = TurnType.statement);
      continue;
    }
    if (payload.isIfStatement) {
      var payloadNext = payloads[idx + 1];
      turns.add(new Turn([payload, payloadNext])..type = TurnType.statement);
      idx++;
      continue;
    }
    if (payload.isIfElement) {
      var payloadNext = payloads[idx + 1];
      if (payloadNext.isElse) {
        turns.add(new Turn([payload, payloadNext])..type = TurnType.element);
        idx++;
      } else {
        turns.add(new Turn([payload])..type = TurnType.element);
      }
      continue;
    }
    turns.add(new Turn([payload])..type = TurnType.node);
  }
  return turns;
}
