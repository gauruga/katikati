# 小役カウンター（katikati）

スロットの小役回数を数える Flutter 製の Android アプリ。

## 開発

```sh
flutter pub get
flutter run
```

課金は RevenueCat 経由。API キーはリポジトリに置かず、ビルド時に渡す。

```sh
flutter run --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx
flutter build appbundle --dart-define=REVENUECAT_ANDROID_KEY=goog_xxx
```

キーを渡さないデバッグビルドは RevenueCat の Test Store（擬似課金）で動く。
キーを渡さないリリースビルドは課金 UI が「準備中」になる。

## コミット前に通すもの

CI は使っていないので、ローカルで必ず 3 つとも通す。

```sh
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib/ test/
```

## 署名

リリース署名は `android/key.properties`（gitignore 済み）から読む。
このファイルが無い環境では debug 鍵にフォールバックするので、
`flutter run --release` は鍵を持っていなくても動く。

## プライバシーポリシー

`docs/privacy.html` を GitHub Pages で公開し、その URL を
Play Console のストア掲載情報とアプリ内メニューの両方から参照する。
