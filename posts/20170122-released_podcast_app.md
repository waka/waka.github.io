# 78.9 (7hack)というPodcastを聴くためのAndroidアプリを作った

本当に今更ながら、通勤でPodcastを聴くことが習慣づいてきた。
[なんかこの1年くらいTech系のPodcast増えてませんか](http://qiita.com/suginoy/items/dada11eef775b883320f)。どれも面白くてすごい。

自分の携帯端末はAndroidなのでFM Playerというアプリで聴いていて、非常に高機能でよくできたアプリなんだけど、自分にはオススメ番組や後で聴く機能とか必要なくて、なんかもうちょっと軽くて操作に集中できるUIのアプリないかなと探してもしっくりくるのがなかった。
そんな折、年末に新しいAndroid端末に変えてAndroid愛が高まったのと、ここ最近Android開発ご無沙汰だったので、最近の開発環境をキャッチアップするのも兼ねてPodcastアプリを作ってみました。

というわけで、先ほど[78.9(7hack)というアプリをPlayStoreに公開しました](https://play.google.com/store/apps/details?id=io.github.waka.sevenhack)。よかったら。
Podcastを「探す」「見る」「聴く」に特化した機能のみなので、自分のようにサッと登録してチャッと聴きたい人向け。
78.9というのは地元のFMラジオの周波数で、昔Nack5(79.5)をよく聴いていたのを思い出したのでモジってみた。

もちろん[ソースコードも公開しています](https://github.com/waka/SevenHack)。
最近のSupportLibraryを結構使ってるのと、RxJava2とSQLBriteを組み合わせて使ってたりします。

## 開発メモ的な

自分が業務でAndroidの機能実装したの、2年前にMaterialDesign対応して以来なので、最近はSupportLibraryでのMaterialDesign表現が充実していてびっくりした。
特にCollapsingToolbarLayoutやFloatingActionButtonが標準で用意されてるなんて・・、キーラインもほとんど自前で定義する必要なくなってて進化すごい。

### DBアクセス層

RSSフィードをSQLiteに保存したいが、生SQLiteHelperもアレだし何か使おうと思って探してみたところ、いい感じに薄そうだったSQLBriteを採用。
SQLBriteのいいところは、いい感じに薄いのでDAO層を作りやすいのと、Transactionが使いやすいところ。
逆にそうでもなかったところは、SQLBriteが標準で用意しているRxJavaサポートで、これはSelect文を発行するObservableをSubscribeしておくと、そのテーブルに行が挿入/削除など変更があったときに自動でSubscriberを実行してくれるというもの。
RecyclerViewでnotifyDataChangedでなくnotifyItemRemovedやnotifyItemChangedを使ってアニメーションさせたり変更を最小限にしようと思っても、Subscriberで再読み込みされてしまうので、実装が複雑になって相性がよくないと感じた。

結局、DAO層はSQLBrite#queryを愚直に使ってObservableを返さずEntityを返すのみにして、ビジネスロジックを扱うLogic層でDAOの結果を返すObservableを返すようにした。
どのみち、SQLBriteが依存しているRxJavaは1系なので、RxJava2を入れた時点でこうするしかない。
UI層から直接DAOを叩くことはしないので、実装的には見通しがよくなってよかった。

EpisodeDao

```java
@Singleton
public class EpisodeDao {
    public List<Episode> findAll(Podcast podcast, int limit, int offset) {
        List<Episode> items = new ArrayList<>();
        Formatter formatter = new Formatter(new StringBuilder(), Locale.JAPANESE);
        String sql = formatter.format(LIST_QUERY, podcast.id, limit, offset).toString();

        Cursor cursor = db.query(sql);
        if (cursor == null) {
            return items;
        }
        try {
            while (cursor.moveToNext()) {
                // entityに詰める
            }
        } finally {
            cursor.close();
        }
        return items;
    }
}
```

EpisodeLogic

```java
@Singleton
public class EpisodeLogic {
    public Observable<List<Episode>> list(Podcast podcast, int limit, int offset) {
        return Observable.just(episodeDao.findAll(podcast, limit, offset))
                .flatMap(this::withEnclosureCache)
                .subscribeOn(Schedulers.newThread())
                .observeOn(AndroidSchedulers.mainThread());
    }

    private Observable<List<Episode>> withEnclosureCache(List<Episode> episodes) {
        return Observable.just(enclosureCacheDao.findAll(episodes))
                .map(enclosureCaches -> {
                    for (Episode episode : episodes) {
                        // set cache to episode
                    }
                    return episodes;
                });
    }
}
```

この辺をやってるところで、[Orma](https://github.com/gfx/Android-Orma)の存在に気づいてあーっとなった。
Ormaもいい感じに薄い上に、relationの定義も簡単だし、migrationも使いやすそう。多分次何か作る場合はOrmaを採用すると思います。

### APIアクセス層

[Retrofit2](https://github.com/square/retrofit)を採用してみた。
Retrofit1時代にSimpleXMLConverterを使ってみたことがあって、そのときは結構バギーな印象だったけど、今の所特に問題は起きてない。
宣言的なAPIクライアントとPOJOだけでよくなるのでXMLのパースをサクッと書けて最高でした。
話はずれるが、PodcastのATOMフィードは各番組でXMLの仕様が微妙に違っていて辛い。

### StethoとLeakCanary

今回使ってみて感動した開発向けライブラリを2つ。

[Stetho](http://facebook.github.io/stetho/)を使うとSQLiteの中身や通信の中身をChromeのdeveloper consoleで見ることができる。
（通信の中身を見る場合はOKHttp用のヘルパーを別途dependencyで指定する必要はある）
以前PonyDebuggerというのがあって、同様にChromeから通信内容見れたけど、それの高機能版という感じか。
SQLiteの中身をLocalStorage見る感覚で確認できるの最高。
使い方も簡単で、Applicationクラスで初期化するだけでOK。

```java
public class MainApplication extends Application {
    @Override
    public void onCreate() {
        super.onCreate();
        Stetho.initializeWithDefaults(this);
    }
}
```

[LeakCanary](https://github.com/square/leakcanary)はメモリリークを検出するライブラリ。
アプリを操作してメモリーリークが発生すると、通知されてどこでリークが発生したかが分かる。
ログを見てると、GCを走らせてactivityの参照が残ってないかをチェックしている？
リークが一定時間発生しなかったら「No leak!」と通知されて気持ちいい。
こちらもApplicationクラスで初期化するだけでOK。

```java
public class MainApplication extends Application {
    @Override
    public void onCreate() {
        super.onCreate();
        LeakCanary.install(this);
    }
}
```
