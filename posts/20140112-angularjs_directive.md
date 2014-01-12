# AngularJSのディレクティブの仕組みを追ってみた

追ってみたシリーズ第3回目。

AngularJSのディレクティブ、名前は聞いたことあるけどあれでしょ？自前の「ng-hoge」を作るための仕組みでしょ？  
だいたいそんな感じですが、どうやって実現しているのか。

## ディレクティブの役割

ディレクティブはHTMLビューを書き出すためだけのものじゃない。  
「ng-controller」や「ng-model」など、HTMLに対して処理をバインド/注入する機能もディレクティブで出来ている。  
AngularJSが持つ[組み込みのディレクティブ](http://docs.angularjs.org/api/ng#directive)だけでもこれだけの数がある。

まさしくAngularJSのベースとなっている仕組みがDirectiveというわけか。

## 追ってみる

ベースとなるngDirective関数を見ると、"link"と"restrict"プロパティを持ったオブジェクトを返す関数を作っていることが分かる。

```
function ngDirective(directive) {
  if (isFunction(directive)) {
    directive = {
      link: directive
    };
  }
  directive.restrict = directive.restrict || 'AC';
  return valueFn(directive);
}
```

これだけじゃよく分からないので、「ng-model」ディレクティブを見てみる。

```
var ngModelDirective = function() {
  return {
    require: ['ngModel', '^?form'],
    controller: NgModelController,
    link: function(scope, element, attr, ctrls) {
      // notify others, especially parent forms

      var modelCtrl = ctrls[0],
          formCtrl = ctrls[1] || nullFormCtrl;

      formCtrl.$addControl(modelCtrl);

      scope.$on('$destroy', function() {
        formCtrl.$removeControl(modelCtrl);
      });
    }
  };
};
```

「[AngularJSの2way bindingの仕組みを追ってみた](http://waka.github.io/2014/1/4/angularjs_2waybinding.html)」で追っていた初期化処理（bootstrap関数）でcollectDirective関数が呼ばれ、スコープが管理するHTML内で「ng-model」が定義されていると、AngularJS内で「ngModel」をキーをしてマッピングされているngModelDirectiveが実行される。  
ここで返されたオブジェクトがディレクティブとなる。  
compileプロパティを持たず、linkプロパティを持っている場合は、linkプロパティを返す関数がcompileプロパティとしてディレクティブにセットされる。

このとき、ディレクティブに自動でセットされるプロパティは以下のものになる。

* compile（ディレクティブの実行内容）
* priority（DOMに複数のディレクティブが定義されている場合の優先順位）
* index（DOMに対して何番目に定義されたディレクティブか）
* name（ディレクティブにつけられている名前）
* require（依存関係を持つディレクティブ）
* restrict（ディレクティブの適用条件。"A"なら属性名、"E"なら要素名、"AE"ならどちらにもマッチ）

そして返されたディレクティブは、要素のcompileプロセスにおいて、applyDirectivesToNode関数で要素に対して「POST LINKING」というリンク関数としてセットされる。  
リンク関数には「PRE LINKING」「POST LINKING」があるが、これは子要素に対してリンク関数を実行する前に実行するか後に実行するかというフェーズがある。  
「PRE LINKING」にするか「POST LINKING」にするかは、ディレクティブを定義する際のcomlileプロパティに"pre"か"post"を指定すれば選択可能。

```
compile: function compile(scope, element, attr) {
  return {
    pre: function preLink(scope, iElement, iAttrs, controller) { ... },
    post: function postLink(scope, iElement, iAttrs, controller) { ... }
  }
  // or
  return function postLink( ... ) { ... }
}
```

この後、nodeLinkFnというクロージャ関数でリンク関数としてディレクティブのcompileに指定した処理がようやく実行される。
このとき、ディレクティブにcontrollerプロパティが指定されていれば、コントローラーがインスタンス化され、自分が所属するスコープ内の検索対象として使われる（requireで"^"がついていない場合）。  
見つかったコントローラーは、コンパイル時の指定関数の第4引数に配列でセットされ渡される。

## ディレクティブでできること

* 自分が定義した要素名が使えるようになり、その要素に対する初期処理をAngularJS内のフェーズごとに書ける
* 既存の要素に対し、初期処理をAngularJS内のフェーズごとに書ける
* 特定の要素、属性を持つスコープやコントローラーに対し、処理を外側から追加することができる

このスコープやコントローラーに処理を追加できるのがキモだと思われます。  
独自にAngularJSに機能を追加するプラグインやライブラリを書く場合、「PRE LINKING」で所属するスコープに関数を生やしたり、コントローラーに新たに処理をバインドしたりといったことはディレクティブを使うとよさそうです。


今回はディレクティブの外部テンプレート機能については触れていないので、それはまた次に調べる。
