# GitHubとTravisCIで作るブログぽいもの

いまさら感ありますがGithub Pagesをメモ置き場として使い始めた。  
[Jekyll](http://jekyllrb.com/)のソースコードを見ていたら、いつの間にか[musakoというMarkdownからHTMLを生成するGem](https://github.com/waka/musako)を作って初めてのPostをpushしていた。

Jekyllでもいいんだけど、Markdownのタイトル付けの書式とかめんどいし、カテゴリもいらない。  
必要最低限の依存ライブラリで高速に動くものがあればよかったので、自作した（あと[slim](https://github.com/slim-template/slim)使いたかったというのもある）。  
musakoという名前は武蔵小杉に住んでいるからで特に意味はない。


なるほど、Github Pagesではユーザーリポジトリのmasterブランチをブラウザからそのまま表示する。  
なので、TravisCIなどのCIサービスで別のブランチをビルドして出来た成果物（HTML、アセット）をafter hookでmasterブランチとしてpushすればいいわけか。

それにしても、

- Markdownでメモを書く
- GitHubにPushする

```
$ vim posts/hello.md
$ git push origin notes
```

たったこれだけで今書いたものをHTMLとして世界中に公開できる。  
必要な手順が2つというのがすごい。GitHubを中心とするエコシステムは本当にすごい。
