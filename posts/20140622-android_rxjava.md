# 渋谷JavaでRxJavaをAndroidアプリでどう活用するかという話をした

少し、いやかなり前に渋谷Javaで「Android meets RxJava」というタイトルでLTしてきました。
スライド上げるのが遅くなってすいません。。。

<iframe src="//www.slideshare.net/slideshow/embed_code/36154175" width="427" height="356" frameborder="0" marginwidth="0" marginheight="0" scrolling="no" style="border:1px solid #CCC; border-width:1px 1px 0; margin-bottom:5px; max-width: 100%;" allowfullscreen> </iframe> <div style="margin-bottom:5px"> <strong> <a href="https://www.slideshare.net/yo_waka/rxjava-meets-android-java6" title="RxJava meets Android - 渋谷Java#6" target="_blank">RxJava meets Android - 渋谷Java#6</a> </strong> from <strong><a href="http://www.slideshare.net/yo_waka" target="_blank">yo_waka </a></strong> </div>

    
[freeeのAndroidアプリ](http://www.freee.co.jp/features/android)の開発前にチーム内で考えていたのが、テストの書きやすさを考慮するとどうしてもFragmentとAPIのやりとり含むビジネスロジックを切り分けたいというところで、
ViewController/ViewModel/Modelを上手く疎に分けられる仕組みが必要でした。

先行して開発していたiPhone版では、ReactiveCocoaを導入して上手くいったこともあり、FRPが出来るJavaのいいライブラリはないか探していたところ、上手くマッチしそうだったのがRxJavaでした。  
RxJavaのObservable、Subscriber、Func/Actionを使うことで、API呼び出し/モデルへの変換/画面への表示を上手く切り分けることが可能になります。
また、ViewModelのプロパティをFragmentからバインディングすることにより、データの状態をFragment側で管理する必要がなくなります。

Fragment側でデータの状態を持ってしまうと、いざそのテストを書く際にUIが必要になるので非常にめんどくさい。ViewModelまでで完結できればユニットテストだけでOK。
とはいえ、スライドにも書いてますが、ビジネスロジックがそこまで複雑でなければEventBusなどでやり取りするのもアリだと思います。

こういうFRPなライブラリをクライアントアプリで使うと、コアな部分で使うためどうしてもロックインを防げないのがデメリットです。
[Reactive Streams](http://www.reactive-streams.org/)による標準化に期待。
