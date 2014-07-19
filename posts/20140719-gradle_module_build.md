# AndroidアプリをGradleでビルドする際にモジュール（というかVolley）のcompileSdkVersionとbuildToolsVersionを強制する

Android StudioがBetaになったので、0.8.2に上げようとしたらモジュールのビルドでハマった。

Android Studioのバージョンを上げるときは、build.gradleを弄る時でもある。
Betaに上げるからには最新版のGradleプラグインとAndroid SDKでコンパイル&ビルドできるようにしたい。  

```
// project/gradle/gradle-wrapper.properties
distributionUrl=http\://services.gradle.org/distributions/gradle-1.12-all.zip

// project/build.gradle
buildscript {
  repositories {
    mavenCentral()
  }
  dependencies {
    classpath 'com.android.tools.build:gradle:0.12.+'
  }
}

// project/app/build.gradle
android {
  compileSdkVersion 20
  buildToolsVersion '20.0.0'
}
```

しかしビルドエラー。  
ルートプロジェクトのGradleプラグインのバージョンを0.12に上げると、buildToolsVersionが"19.1"以上でないとビルドできない。  
僕の環境では[volley](https://android.googlesource.com/platform/frameworks/volley/)をモジュール（submodule）として組み込んでいて、compileSdkVersionとbuildToolsVersionがこのように指定されている。

```
// modules/volley/build.gradle
android {
  compileSdkVersion 19
  buildToolsVersion = 19
}
```

volleyのソースを見る限りbuildToolsVersionを20に上げても特に問題なさそうなので、何とかしてビルドが実行される前にandroid()の中身を上書きしたい。  
と思って、[Gradle User Guide](http://www.gradle.org/docs/1.12/userguide/userguide.html)を眺めていたら、Project.afterEvaluate()というものを見つけた。
Project.afterEvaluate()は、そのプロジェクトのビルドスクリプトが評価された後に実行されるらしい。まさにやりたいことと一致！

Gradleで分からないことがあれば、[Gradle User Guide](http://www.gradle.org/docs/1.12/userguide/userguide.html)を見るのがオススメ。
Gradleのバージョンごとに用意されているので、使っているものに合わせて見るとよさげ（ちょくちょく変わったりするので）。

```
subprojects { subproject ->
  afterEvaluate {
    if (subproject.plugins.hasPlugin('android-library')) {
      android {
        compileSdkVersion 20
        buildToolsVersion '20.0.0'
      }
    }
  }
}
```

これで、モジュールとして組み込んでいるライブラリプロジェクト全てのcompileSdkVersionとbuildToolsVersionをアプリのそれと合わせることができる。  
もし特定のプロジェクトだけどうしても"19.1"でビルドしたければ、プロジェクトごとに指定すればおk。

```
project(':modules:volley') {
  afterEvaluate {
    android {
      compileSdkVersion 20
      buildToolsVersion '19.1'
    }
  }
}
```
