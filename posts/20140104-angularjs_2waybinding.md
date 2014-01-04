# AngularJSの2way bindingの仕組みを追ってみた

AngularJSの特徴でもある、モデルとビューの2way binding。  
AngularJSの簡単なコードがあるとする。（投稿時点ではv1.2.6）

```
<body ng-app ng-init="message = 'nothing'">
  <div ng-controller="SampleCtrl">
    <input type="text" ng-model="message">
    <br>
    <button ng-click="clearMessage()">Clear</button>
    <br>
    <span>{{getMessage()}}</span>
  </div>
  <script>
  var SampleCtrl = function($scope) {
    $scope.message = '';
    $scope.clearMessage = function() {
      $scope.message = '';
    };
    $scope.getMessage = function() {
      return $scope.message;
    };
  };
  <script>
</body>
```

テキストボックスに文字を打ち込むと「{{getMessage()}}」に打ち込んだ文字がリアルタイムに表示されるし、「Set "init"」ボタンを押すとテキストボックスと「{{getMessage()}}」で表示されるテキストが空文字になる。  
テキストボックスに$scopeのmessageプロパティをバインドしているので、テキストボックスがインタラクティブになるのは分かる。  
しかしなぜ$scope.getMessage()も同じタイミングで実行されHTMLまで書き変わるのか。気になる。気になる・・！

AngularJSのソースがどう動いているのか追ってみる。  
AngularJSはuncompressedなファイルでは全体で20539行。  
ギリギリ読めないことはない。

20535行目でロード時のイベントハンドラが発火される。

```
jqLite(document).ready(function() {
  angularInit(document, bootstrap);
});
```

angularInit関数の中で、「'ng:app', 'ng-app', 'x-ng-app', 'data-ng-app'」をid,classあるいは属性で持つ要素がAngularアプリのベース要素としてセットされる。  
該当する要素がなければその後の処理はなにも実行されない。

1283行目のdoBootstrap関数が実行される。  
名前の通り初期化関数であり、ここでモジュールをロードし、Angular内の各サービスがファクトリー関数でインスタンス化される。  
ここで利用されるinjectorというオブジェクトは、内部関数を呼び出すための抽象レイヤーみたいなもの。  
本筋とはずれるが、window.nameに「NG\_DEFER\_BOOTSTRAP」という名前をセットしておくとdoBootstrap関数は呼ばれない。  
代わりにangular.resumeBootstrap(extraModules)という、後から手動でdoBootstrap関数を実行できる関数が生える。

サービスのファクトリー関数を見ると、名前の最後に"Provider"をつけて再起的にinvokeしていることが分かる。

```
createInternalInjector(instanceCache, function(servicename) {
  var provider = providerInjector.get(servicename + providerSuffix); // providersuffix == "Provider"
  return instanceInjector.invoke(provider.$get, provider);
});
```

doBootstrap関数では、最終的にScopeインスタンスの$apply関数が実行される。

```
injector.invoke(['$rootScope', '$rootElement', '$compile', '$injector', '$animate',
  function(scope, element, compile, injector, animate) {
    scope.$apply(function() {
      element.data('$injector', injector);
      compile(element)(scope);
    });
  }]
);
```

$apply関数でやっていることは引数に渡した関数を実行すること。  
ようやくcompile関数にたどり着いた。

compile関数で、引数に渡されたelementから再帰的にHTML要素を舐め、HTML要素にセットした「ng-\*」属性名からディレクティブを呼び出し、ディレクティブのcompile関数で属性値を$eval関数で処理する。  

例えば、ng-init属性に対応するngInitDirectiveディレクティブはこのようになっている。

```
var ngInitDirective = ngDirective({
  priority: 450,
  compile: function() {
    return {
      pre: function(scope, element, attrs) {
        scope.$eval(attrs.ngInit);
      }
    };
  }
});
```

ng-controllerやng-modelもcompile関数でディレクティブを集め、返却されたクロージャで各ディレクティブをコンパイルしていく。  
ここでまず、「ng-init="message = 'nothing'」といった初期化のための属性値はAngularが持つ構文解析にかけられ、対応するScopeインスタンスにセットされる。

実際に値をセットしているのは、10238行目のsetter関数で行われる。  
最初の引数の「obj」にはScopeインスタンスが入っている。

```
//////////////////////////////////////////////////
// Parser helper functions
//////////////////////////////////////////////////

function setter(obj, path, setValue, fullExp, options) {
  //needed?
  options = options || {};

  var element = path.split('.'), key;

  // カット

  key = ensureSafeMemberName(element.shift(), fullExp);
  obj[key] = setValue;
  return setValue;
}
```

コントローラについて、$ControllerProviderが返したクロージャが実行され、インスタンス化される。

```
return function(expression, locals) {
  var instance, match, constructor, identifier;

  if(isString(expression)) {
    match = expression.match(CNTRL_REG),
          constructor = match[1],
          identifier = match[3];
    expression = controllers.hasOwnProperty(constructor)
      ? controllers[constructor]
      : getter(locals.$scope, constructor, true) || getter($window, constructor, true);

    assertArgFn(expression, constructor, true);
  }

  instance = $injector.instantiate(expression, locals);

  if (identifier) {
    if (!(locals && typeof locals.$scope == 'object')) {
      throw minErr('$controller')('noscp',
          "Cannot export controller '{0}' as '{1}'! No $scope object provided via `locals`.",
          constructor || expression.name, identifier);
    }

    locals.$scope[identifier] = instance;
  }

  return instance;
};
```

実際にインスタンス化されるのは「$injector.instantiate(expression, locals)」の行だが、ここでユーザーが定義したコントローラーのコンストラクタを実行した結果が返る。  
新規で作ったFunctionオブジェクトをthisとしてコントローラーのコンストラクタを実行するのが面白い。

```
function invoke(fn, self, locals){
  var args = [],
      $inject = annotate(fn),
      length, i,
      key;

  for(i = 0, length = $inject.length; i < length; i++) {
    key = $inject[i];
    if (typeof key !== 'string') {
      throw $injectorMinErr('itkn',
          'Incorrect injection token! Expected service name as string, got {0}', key);
    }
    args.push(
        locals && locals.hasOwnProperty(key)
        ? locals[key]
        : getService(key)
        );
  }
  if (!fn.$inject) {
    // this means that we must be an array.
    fn = fn[length];
  }

  // http://jsperf.com/angularjs-invoke-apply-vs-switch
  // #5388
  return fn.apply(self, args);
}

function instantiate(Type, locals) {
  var Constructor = function() {},
      instance, returnedValue;

  // Check if Type is annotated and use just the given function at n-1 as parameter
  // e.g. someModule.factory('greeter', ['$window', function(renamed$window) {}]);
  Constructor.prototype = (isArray(Type) ? Type[Type.length - 1] : Type).prototype;
  instance = new Constructor();
  returnedValue = invoke(Type, instance, locals);

  return isObject(returnedValue) || isFunction(returnedValue) ? returnedValue : instance;
}
```

「ng-model」はNgModelControllerとしてインスタンス化され、属性値をwatchする。  
モデルに指定した変数の値が変更された場合、コントローラーの$viewValueに値をセットして再描画する。  
これがモデルからビューへのバインディングになっているわけか。

```
$scope.$watch(function ngModelWatch() {
    var value = ngModelGet($scope);

    // if scope model value and ngModel value are out of sync
    if (ctrl.$modelValue !== value) {
      var formatters = ctrl.$formatters,
      idx = formatters.length;

      ctrl.$modelValue = value;
      while(idx--) {
        value = formatters[idx](value);
      }

      if (ctrl.$viewValue !== value) {
        ctrl.$viewValue = value;
        ctrl.$render();
      }
    }

    return value;
});
```

要素が「input type="text"」の場合、textInputTypeというディレクティブが呼ばれる。  
キー入力を監視し、Scopeインスタンスの$apply関数でコントローラーの$setViewValue関数に新しい値を渡して再描画させる。  
他のinput要素などの再描画ロジックの違いはここで吸収し、ctrl.$renderに関数をセットしている。

```
var listener = function() {
  if (composing) return;
  var value = element.val();

  if (toBoolean(attr.ngTrim || 'T')) {
    value = trim(value);
  }

  if (ctrl.$viewValue !== value) {
    scope.$apply(function() {
        ctrl.$setViewValue(value);
    });
  }
};
```

「ng-pattern」という属性値をセットしておくと、バリデーションとしてセットできることも分かる。

```
// pattern validator
var pattern = attr.ngPattern,
    patternValidator,
    match;

var validate = function(regexp, value) {
  if (ctrl.$isEmpty(value) || regexp.test(value)) {
    ctrl.$setValidity('pattern', true);
    return value;
  } else {
    ctrl.$setValidity('pattern', false);
    return undefined;
  }
};
```

「{{getMessage()}}」で表現している箇所に関しては、TextInterpolateDirectiveのtextInterpolateLinkFn関数でテキストノードにリスナー関数をバインディングする。  
リスナー関数では「{{}}」を評価した結果を返し、値に変更があればテキストノードの値を書き換える。  
$scope.messageの値が変わったら、$scope.getMessage()の結果も変わるので、「{{}}」の部分が変更される。  
これでモデルからビューへのバインディングの仕組みが分かった。

```
function textInterpolateLinkFn(scope, node) {
  var parent = node.parent(),
      bindings = parent.data('$binding') || [];
  bindings.push(interpolateFn);
  safeAddClass(parent.data('$binding', bindings), 'ng-binding');
  scope.$watch(interpolateFn, function interpolateFnWatchAction(value) {
    node[0].nodeValue = value;
  });
}
```

最後に、$rootScope.$digest関数が呼ばれ、Scopeの階層を下りながらScopeのwatch対象に対してリスナー関数を実行していく。  
$scope.messageには"nothing"という文字列が新しく入っているので、変更後の値として扱われる。

```
if ((watchers = current.$$watchers)) {
  // process our watches
  length = watchers.length;
  while (length--) {
    try {
      watch = watchers[length];
      // Most common watches are on primitives, in which case we can short
      // circuit it with === operator, only when === fails do we use .equals
      if (watch) {
        if ((value = watch.get(current)) !== (last = watch.last) &&
            !(watch.eq
              ? equals(value, last)
              : (typeof value == 'number' && typeof last == 'number'
                && isNaN(value) && isNaN(last)))) {
          dirty = true;
          lastDirtyWatch = watch;
          watch.last = watch.eq ? copy(value) : value;
          watch.fn(value, ((last === initWatchVal) ? value : last), current);

          // カット
        }
      }
    }
  }
}
```

これでbootstrap関数で実行される処理は終わり。  

長い・・！フレームワークの特性上、ロード時にいろいろやってるのは想像つくけど、これはすごい。  
クロージャを上手く使ってキャプチャすることでなるべくプロトタイプに値を持たせずに引き回してたり、全体を見たときに作られるインスタンスがとても少ない。  
Scopeという概念がHTMLの階層とマッチしていて、値の変更時のキャプチャリング/バブリングを上手く抽象化していることが分かる。  
でもって、Scopeはその階層でのハンドラや独自処理をプロトタイプに書けると。  
invokeの使い方はAngular使わないコードでも参考になるなー。  
あと、GoogleClosureLibraryを使ったことのある人だったら見覚えのある実装がいくつかあったりしてニヤッとしたり。

これで2way bindingの仕組みが分かったので、AngularJSと少し仲良くなれた気がする。  
次はDIともうちょっとディレクティブをちゃんと追ってみよう。
