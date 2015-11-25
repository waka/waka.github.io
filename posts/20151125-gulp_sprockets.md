# RailsのAsset PipelineとPrecompileをNode.jsのみで処理できるgulp-sprocketsを作った

仕事ではRailsアプリを書いていて、JSやCSSなどのフロントエンドはRailsのAsset Pipelineの仕組みに則ってビルドしてる。

普通にRailsアプリ作ってると普段[Sprockets](https://github.com/sstephenson/sprockets)について特に意識しないと思う。  
Sprocketsはそこが凄くて、あまり考えなくてもドキュメント通りにやってれば、必要なAssetを結合できて、リリース時は変更がなければブラウザキャッシュから、変更があれば
新しく読み込まれるみたいなことをやってくれる。

なんだけど、もうそろそろ新しい機能はES2015で書きたいよねという人が増えてきた。

とはいえSprocketsは独自のディレクティブ以外は使えなくて、SprocketsWayから外れると途端に脆い。
ES2015 Modulesを使う場合、gulp&babelなどでES5でコンパイルされたJavaScriptファイルをSprocketsが解釈できるasset pathに吐いて、asset pipelineの上に乗せ直す必要がある。
エイヤでやっちゃえばいいじゃんとも思うが、規模がデカくなると一気にやるのは時間もかかるし、他の人も開発しているので中々に難しい。上手く区切りながら移行を進めていく必要がある。

そうなると、移行中はSprocketsによるビルドの仕組みとgulp両方覚える必要がある。
でないとデプロイ時にアセット周りで不具合が起きたときに追えない。
結構こいつが問題で、両方追える人増やすのも大変だし、できればより汎用的なツールであるgulpだけでフロントエンドをビルドできるようにしたいなと思い始めた。

その他にも、特殊な事情でPrecompile時のRuby版Sassのコンパイルが遅かったり、もうCoffeeScriptファイルが多すぎてdevelopment環境で初回ビルドが遅すぎるというのもやりたくなった理由だったりする。

XXX-railsなどGemで読んでいるフロントエンド系ライブラリも気づけば作者が全然アップデートしてくれなくなったものもあるし、依存ライブラリの定義がGemfileやpackage.json、Bowerfileなど散らばるのもよくない。全てpackage.jsonで管理したい。

## Sprocketsがやっていること

ざっくりいうと5つ。

- asset\_pathやimage\_urlなどのヘルパー関数を組み込む
- 「//= foo」や「/*= bar */」などのディレクティブを解釈してよしなにconcat
- CoffeeScriptやScssやJSTをコンパイル
- (Precompile時) concatしたファイルの内容からmd5ハッシュを作りファイル名につける
- (Precompile時) ビルドした各ファイルの情報をmanifest.jsonに書き込む

最後のはprecompile時のみ必要な処理で、development時は不要。
これらをNode.jsの世界で実現できれば、gulpfileのみでRailsのフロントエンドなファイルをビルドすることが可能になるはず。

## gulpだけでなんとかできない？

探してみると過去にSprockets脱却にチャレンジしている人は結構いる。
最後のは弊社の若手フロントエンドヤンキーによるスライド。

- [Sprockets再考 モダンなJSのエコシステムとRailsのより良い関係を探す](http://qiita.com/joker1007/items/9068e223744b3ac8c6dd)
- [Sprockets絶ちに挑戦した](http://sssslide.com/speakerdeck.com/katryo/sprocketsjue-tinitiao-zhan-sita)
- [Sprocketsを捨てたい](http://www.slideshare.net/masatonoguchi169/sprockets-49965435)

manifest.jsonについてはjoker1007さんの[gulp-rev-rails-manifest](https://github.com/joker1007/gulp-rev-rails-manifest)を使えば解決できそう。  

上のスライドにも書かれている、SCSS内に書かれたasset\_pathやimage\_urlなどのSprocketsが提供しているヘルパー関数をどう解決するかが難関っぽい。
Precompile時はmd5ハッシュ値を使ったファイル名に変換するなどしないと画像を読み込めなくなってしまう。。
SprocketsではSassコンパイラにカスタム関数として定義してコンパイル時に変換している。

「//=require XXX」などのディレクティブについてもCommonJSやES2015 Modulesに全て置き換えるのが前提となっている。
規模が大きいとその書き換えが大変なので、できればそのまま使えるようにしたい。

ソリューションが必要だ！

## 全部解決できるgulpプラグイン作った

[gulp-sprockets](https://github.com/waka/gulp-sprockets)

詳しくはREADMEとsample下をどうぞ。
移行後はサクッと外すだけにしたかったので、各種処理を提供するgulpストリームとして作った。
実際社内のRailsアプリで試してAsset PipelineのOn/Off両方で動いているのが確認できた。

こんな感じでgulpでビルドするとSprocketsでビルドしたときと同等の成果物ができる。

```js
import sprockets from 'gulp-sprockets';

gulp.task('build:css', () => {
  return gulp.src('app/assets/stylesheets/*.css')
    .pipe(sprockets.css())
    .pipe(gulpIf(process.env.NODE_ENV === 'release', sprockets.precompile()))
    .pipe(gulp.dest(destPath));
});
```

ヘルパー関数はそういえばnode-sassもv3からカスタム関数定義できることを思い出したのでコンパイラに定義した。

ディレクティブは最近はEsprimaやPostCSSを使うとコメント部をASTから簡単に取ってこれるので取得したコメントから雑に解釈させてる。

コンパイル処理もサポートしたので、ES2015で書いたファイルもrequireディレクティブで読み込めるとかそういうのも出来そう。
