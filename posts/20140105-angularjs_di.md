# AngularJSのDIの仕組みを追ってみた

AngularJS黒魔術のうちの1つ。DI。

コントローラーの引数に$httpなどを指定すると、なぜ何もしなくてもHttpProviderの返り値が入ってくるのか。

```
var userControllers = angular.module('userControllers', []);

userControllers.controller('UsersCtrl', function($scope, $http) {
  $http.get('users/index.json').success(function(data) {
    $scope.users = data;
  });
});
```

これは、定義したコントローラーをインスタンス化する際にannotate関数でDI対象となる引数を取得して、該当するサービスオブジェクトに差し替えているから。

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
    fn = fn[length];
  }

  return fn.apply(self, args);
}
```

では、annotate関数では何をしているのか。  
FunctionオブジェクトをtoStringで文字列化して、引数に当たる文字列を抜き出し、返している。  
fn.lengthはその関数が受け取る引数の数を表す。

```
function annotate(fn) {
  var $inject,
      fnText,
      argDecl,
      last;

  if (typeof fn == 'function') {
    if (!($inject = fn.$inject)) {
      $inject = [];
      if (fn.length) {
        fnText = fn.toString().replace(STRIP_COMMENTS, '');
        argDecl = fnText.match(FN_ARGS);
        forEach(argDecl[1].split(FN_ARG_SPLIT), function(arg){
          arg.replace(FN_ARG, function(all, underscore, name){
            $inject.push(name);
          });
        });
      }
      fn.$inject = $inject;
    }
  }
  return $inject;
}
```

上の例の場合、argDecl[1]には"$scope, $http"という文字列が入る。  
これをsplitして、getService関数でファクトリ関数の返り値をキャッシュしたプールからオブジェクトを取り出し、コントローラーのコンストラクタに渡して実行する、というわけか。

このキャッシュプールから取り出すキーになるのが"$http"だったり"$routeParams"だったりするので、引数の名前が違うとDIされない。  
Angularが用意しているProviderを使いたければ、Angularが中で持っている名前にしないといけないし、module.factoryなどでユーザーが定義したサービスだったら、その名前で指定しないといけない。

また、よく言われるminifyのための注意として、ユーザーが定義するコントローラーやサービスには文字列でも引数を指定しておくというのも納得。  
そうしないとminify時に引数名が短縮されてしまうので、DIすべき対象が見つからなくなってしまう。

```
userControllers.controller('UsersCtrl', ['$scope', '$http', function($scope, $http) {
  $http.get('users/index.json').success(function(data) {
    $scope.users = data;
  });
}]);
```
