# Macの環境構築にhomebrew-cask+Brewfile便利

先週 Macbook Air を新しいマシンにリプレースした際に、環境構築どうしようかなーと思って、[homebrew-cask](https://github.com/phinze/homebrew-cask)を使ってみたらかなり捗った。

Mac上の環境構築でよく聞くのは、GitHubが公開している[Boxen](http://boxen.github.com/)だと思うけど、PuppetのDSL覚えるの面倒くさいし、パッケージ情報をメンテナンスするのも結構ヘビーだったりする。  
対してhomebrew-caskは、Homebrewの仕組みを拡張して、GUIアプリも入れられるようにして、全部brewコマンドで管理できるようにしようぜという思想で作られている。

1つずつコマンド打って全部入れていってもいいんだけど、最近のHomebrewはBrewfileを使ってパッケージ管理できるので一発で入れられて便利。

```sh
# Make sure using latest Homebrew
update

# Update already-installed formula
upgrade

# Add Repository
tap phinze/homebrew-cask || true
tap homebrew/binary || true

# Packages for development
install zsh
install git
install vim

# Packages for brew-cask
install brew-cask

# .dmg from brew-cask
cask install google-chrome
cask install virtualbox
cask install vagrant

# Remove outdated versions
cleanup
```

こんな感じのBrewfileがあるディレクトリで、ターミナルから「brew bundle」と打つと、書いたとおりにソフトウェアがインストールされる。  
アップデートも「brew update」でよしなにやってくれる。

BrewfileをGithubかなにかで管理しておけば、新しいマシンが来たときは「brew bundle」を実行するだけだし、新しく環境作り直す場合もbrewコマンドで消すかHomebrewのディレクトリをまるごと削除するだけでいいので簡単。  

デフォルトの設定だとインストール先は「/opt/homebrew-cask/Caskroom」になり、「~/Applications」にシンボリックリンクを貼る模様。  
これを変えたい場合は、「HOMEBREW\_CASK\_OPTS」という環境変数に指定すれば変更できる。  
自分はhomebrew本体と同様にCaskroomを「/usr/local」下に置きたかったのと、シンボリックリンクは「/Applications」に貼りたかったので変更した。

```sh
export HOMEBREW_CASK_OPTS="--appdir=/Applications --caskroom=/usr/local/Caskroom"
```

ちなみに自分はAlfredをランチャーアプリとして使っていて、homebrew-caskで入れたアプリはシンボリックリンクなので検索対象になってくれなかった。  
ただ、対応策としてサブコマンドがちゃんと用意されていて、そいつを実行すると検索対象に含まれるようになった。  

```sh
$ brew cask alfred
$ brew cask alfred link # CaskroomをAlfredの検索パスに追加
```
