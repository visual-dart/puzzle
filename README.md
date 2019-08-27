# Visual XAML for Dart/Flutter

Use `xdml` for developing visual dart/flutter app.

## Install

1. add `xdml` into your `pubspec.yaml`
2. run `flutter packages get`

## Usage

there is a **[Demo](https://github.com/visual-dart/xdml-demo)** :

> main.xaml

```xml
<!DOCTYPE xdml>
<!-- Page -->
<x:Page
        xmlns:x="https://github.com/visual-dart/xdml/wiki/xdml"
        xmlns:bind="https://github.com/visual-dart/xdml/wiki/bind"
        xmlns:flutter="https://github.com/flutter/flutter/wiki"
        path="main.dart"
        class="MyAppState">

    <!-- ReferenceGroup -->
    <x:ReferenceGroup>
        <x:Import path="package:flutter/material.dart"></x:Import>
    </x:ReferenceGroup>

    <!-- PartialVuiew -->
    <x:ViewUnit ref="appBarTpl">
        <AppBar>
            <Text x:slot="title">{{
                'Welcome to Flutter'
                + ' '
                + bind:instance = platformVersion
                + bind:i = titleText
            }}</Text>
        </AppBar>
    </x:ViewUnit>

    <x:ViewUnit ref="fuckYou">fuck you !</x:ViewUnit>
    <!-- ViewBuilder -->
    <x:ViewBuilder
            ref="itemFn"
            params="context, int index"
            vars="ctx = context; ctxStr = context.toString()">
        <x:Execution>print("woshinidie")</x:Execution>
        <x:Execution>print(ctx)</x:Execution>
        <x:Execution>print(ctxStr)</x:Execution>
        <Text x:if="index % 2 == 0">123456</Text>
        <Text x:else="">654321</Text>
    </x:ViewBuilder>

    <!-- Host -->
    <MaterialApp
            x:host="build"
            title="{{ bind:i = titleText }}">
        <Scaffold
                x:slot="home"
                bind:appBar="appBarTpl">
            <ListView.builder
                    x:slot="body"
                    x:if="a == null"
                    itemCount="{{ list.length }}"
                    itemBuilder="{{ itemFn }}" />
            <ListView.builder
                    x:slot="body"
                    x:else-if="a == 34523"
                    itemCount="{{ list.length }}">
                <!-- Inner ViewBuilder -->
                <x:ViewBuilder
                        x:slot="itemBuilder"
                        param-context="BuildContext"
                        param-index="int"
                        var-ctx="666">
                    <x:Execution>print("woshinidie")</x:Execution>
                    <x:Execution>print(ctx)</x:Execution>
                    <Text x:if="index % 2 == 0">123456</Text>
                    <Text x:else="">654321</Text>
                </x:ViewBuilder>
            </ListView.builder>
            <Text
                    x:slot="body"
                    x:else-if="a == 2222">sbdx--wriririrriririri</Text>
            <Column
                    x:slot="body"
                    x:else=""
                    mainAxisAlignment="{{ MainAxisAlignment.center }}">
                <x:NodeList
                        x:slot="children"
                        type="Widget">
                    <x:Virtual._rule value="a is Map<dynamic, dynamic> && a.containsKey('b')" />
                    <Text x:if="bind:virtual = _rule">{{ a['b'] + '2#232#' }}</Text>
                    <Text x:else-if="a == 55">yyyyyyyyyyyy</Text>
                    <Text x:else-if="a == 556">tttttttttttt</Text>
                    <Text x:else-if="a == 999">rrrrrrrrrrrr</Text>
                    <Text x:else-if="a == 876">qqqqqqqqqq</Text>
                    <Text x:if="bind:v = _rule">wwwwwwwwww</Text>
                    <Text x:else-if="a == 5">eeeeeeeeeeeee</Text>
                    <Text x:else="">{{ fuckYou }}</Text>
                    <Text>{{ fuckYou }}</Text>
                </x:NodeList>
            </Column>
        </Scaffold>
    </MaterialApp>

</x:Page>
```

> main.dart

```dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:xdml/metadata.dart';
import 'package:demo/demo.dart';
import 'package:flutter/material.dart';
import 'main.binding.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() => MyAppState();
}

@Binding('main.xaml')
class MyAppState extends State<MyApp> {
  String platformVersion = 'Unknown';
  final String titleText = 'Hello World';
  int _inner(int v) {
    return 555555 + v;
  }

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion = await Demo.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }
    if (!mounted) return;
    setState(() {
      platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    var a = {"a": 23, "b": "2342"};
    print(_inner(a['a']));
    var list = [1, 2, 3, 4, 5, 6, 7, 8];
    var titleText = this.titleText;
    return bindXDML(this, context, a, list, titleText);
  }
}

```

generated automatically:

> main.binding.dart

```dart
import 'package:flutter/material.dart';
import 'main.dart';

Widget bindXDML(
    MyAppState __instance, BuildContext context, dynamic a, dynamic list) {
  var appBarTpl = AppBar(
      title: Text('Welcome to Flutter' +
          ' ' +
          __instance.platformVersion +
          __instance.titleText));
  var fuckYou = 'fuck you !';
  var itemFn = (dynamic context, int index) {
    var ctx = context;
    var ctxStr = context.toString();
    print("woshinidie");
    print(ctx);
    print(ctxStr);
    return index % 2 == 0 ? Text('123456') : Text('654321');
  };
  return MaterialApp(
      title: __instance.titleText,
      home: Scaffold(
          appBar: appBarTpl,
          body: a == null
              ? ListView.builder(itemCount: list.length, itemBuilder: itemFn)
              : a == 34523
                  ? ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (BuildContext context, int index) {
                        var ctx = 666;
                        print("woshinidie");
                        print(ctx);
                        return index % 2 == 0 ? Text('123456') : Text('654321');
                      })
                  : a == 2222
                      ? Text('sbdx--wriririrriririri')
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                              if (a is Map<dynamic, dynamic> &&
                                  a.containsKey('b'))
                                Text(a['b'] + '2#232#')
                              else if (a == 55)
                                Text('yyyyyyyyyyyy')
                              else if (a == 556)
                                Text('tttttttttttt')
                              else if (a == 999)
                                Text('rrrrrrrrrrrr')
                              else if (a == 876)
                                Text('qqqqqqqqqq'),
                              if (a is Map<dynamic, dynamic> &&
                                  a.containsKey('b'))
                                Text('wwwwwwwwww')
                              else if (a == 5)
                                Text('eeeeeeeeeeeee')
                              else
                                Text(fuckYou),
                              Text(fuckYou)
                            ])));
}

```

## Compile and watch

1. add an config.yaml into your project

```yaml
entry: lib
group: com.your.owner.group.name
watch: true
```

2. run command `packages pub run xdml --config=config.yaml`
3. now check binding files.

## Work with hot reload

In **android studio**, everything is ok.

If you're using **vscode**, you have to click hot-reload button to fresh your app manually after file changed.
