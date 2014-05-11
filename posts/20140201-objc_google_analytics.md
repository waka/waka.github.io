# iOSアプリの全てのビューコントローラーにGoogleAnalyticsを一括で設定する

今作っているアプリで、改善のためにどれくらい画面が使われているか知りたかったので、GoogleAnalyticsを入れたときのメモ。

GoogleAnalyticsはご存知みんな知っているアクセス解析ツール。  
iOS用にもSDKが公開されていて、CocoaPodsを使っていればpod installで簡単に入れられる。

```sh
pod 'GoogleAnalytics-iOS-SDK', '~> 3.0'
```

画面の閲覧回数を取るためには、2つやり方がある。

1つは、GAITrackedViewControllerクラスを継承したUIViewControllerを作る。  
viewDidLoadなどでscreenNameに画面名をセットしておくと、viewDidAppearで自動でトラッキングリクエストが送信される。

```objc
@interface SampleViewController : GAITrackedViewController
@end

@implementation SampleViewController

- (void)viewDidLoad
{
    self.screenName = @"画面名";
}

end
```

もう1つは、ビューコントローラーのviewDidLoadかviewDidAppearで、GAITrackerクラスを使って画面名を送ってやるやり方。  
こっちはWebブラウザ版の使い方に近い。  
UITableViewControllerなどUIViewControllerのサブクラスを使っている場合は、こっちでやるしかない。

```objc
- (void)viewDidAppear
{
    [super viewDidAppear];

    id tracker = [[GAI sharedInstance] defaultTracker];
    [tracker set:kGAIScreenName value:@"画面名"];
    [tracker send:[[GAIDictionaryBuilder createAppView] build]];
}
```

つまり、UITableViewControllerをふんだんに使っていたり、UIViewControllerを継承したベースクラスを作っていると、1つ1つのビューに同じ処理を書かないといけない。  
これは絶対入れるの忘れそうなのでなんとかしたい。。。と思って調べてみた。

Objective-CにはMethod Swizzlingという、すでに実装されているクラスのメソッドを自前のメソッドに入れ替えるやり方が用意されているらしい。  
"objc/runtime.h"が提供している、method\_exchangeImplementations関数を使えばクラスメソッドの入れ替えが可能になる。

これを使ってUIViewControllerのメソッドを入れ替えれば各画面ごとにアナリティクス処理を書かずに済みそう。  
つまり、UIViewControllerのカテゴリ拡張を作って、viewDidAppearをGATrackerの処理を追加してものに入れ替える関数を用意する。  
画面名には「NSStringFromClass([self class])」でクラス名を自動でセットしてやる。

```objc
#import <objc/runtime.h>

@implementation UIViewController (GAInject)

- (void)replacedViewDidAppear:(BOOL)animated
{
    // 元のメソッド（名前は既に置き換わっているので注意）を呼び出す
    [self replacedViewDidAppear:animated];
              
    [[GAI sharedInstance].defaultTracker set:kGAIScreenName value:NSStringFromClass([self class])];
    [[GAI sharedInstance].defaultTracker send:[[GAIDictionaryBuilder createAppView] build]];
}

+ (void)exchangeMethod
{
    [self exchangeInstanceMethodFrom:@selector(viewDidAppear:) to:@selector(replacedViewDidAppear:)];
}

/**
 メソッドの入れ替え
  */
+ (void)exchangeInstanceMethodFrom:(SEL)from to:(SEL)to
{
    Method fromMethod = class_getInstanceMethod(self, from);
    Method toMethod   = class_getInstanceMethod(self, to);
    method_exchangeImplementations(fromMethod, toMethod);
}

@end
```

AppDelegateでこいつを呼び出してUIViewControllerのviewDidAppear関数を入れ替える。

```objc
#import "UIViewController+GAInject.h"

@implementation SampleAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // UIViewControllerのメソッド差し替え
    [UIViewController exchangeMethod];
}

@end
```

これで、UIViewControllerを継承しているUITableViewControllerや自作ビューコントローラーでも、自動でトラッキング処理が走るようになります。  
method\_exchangeimplementations、Rubyのalias\_method感覚で使えるヒッジョーに面白い仕組みですが、そのクラスと子クラスすべての挙動が変わるので使いどころには要注意ですね。
