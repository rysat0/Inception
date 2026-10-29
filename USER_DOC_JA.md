# 利用者向けドキュメント

[English](USER_DOC.md)

この文書では、初期設定後のInceptionの操作方法を説明します。
初めて環境を構築する場合は[README](README.md)を参照してください。
ターミナルのコマンドは、VM内で`Makefile`のあるプロジェクトのルートディレクトリから実行します。

## 利用できるサービス

| サービス | 役割 |
| --- | --- |
| NGINX | `https://rysato.42.fr/`でHTTPS接続を受け付ける入口。 |
| WordPress / PHP-FPM | Webサイトの表示、コンテンツの編集、アカウントとコメントの管理。 |
| MariaDB | 投稿、固定ページ、コメント、アカウント、サイト設定の保存。 |
| 静的サイト（`website`） | `https://rysato.42.fr/intro/`でHTML/CSSによる42 Tokyoの紹介ページを配信。 |
| Adminer | `https://rysato.42.fr/adminer/`からブラウザでDBを閲覧・操作。 |

外部に公開するのは、入口のNGINXのHTTPS・443番ポートだけです。
NGINXがWordPress、静的サイト、Adminerへアクセスを振り分けます。
ブラウザからのDB操作にはAdminerを使います。MariaDBとPHP-FPMのポートはVM側へ公開しません。

## プロジェクトの起動と停止

VMとDockerが動いていることを確認し、プロジェクトを起動します。

```sh
make
make ps
```

`mariadb`、`wordpress`、`nginx`、`website`、`adminer`の5サービスが`Up`と表示されることを確認してください。
初回はWordPressのダウンロードとインストールがあるため、時間がかかる場合があります。
後述のチェックで、サイトが利用可能になったことも確認します。

| コマンド | 動作 |
| --- | --- |
| `make stop` | サービスを停止する。コンテナとデータは残る。 |
| `make` | プロジェクトを起動する。必要に応じてイメージもビルドする。 |
| `make restart` | 既存のコンテナを再起動する。 |
| `make down` | コンテナとプロジェクトのネットワークを削除する。サイトとDBのボリュームは残る。 |
| `make re` | コンテナを削除してから、ビルド・起動する。ボリュームは残る。 |

保存済みのWordPressのコンテンツはnamed volumeに置くため、これらの操作後も残ります。
ボリュームそのものを削除すると、保存済みデータも消えます。
VMの再起動後にサービスが自動起動しない場合は、`make`を実行してください。

## Webサイトと管理画面を開く

例では`rysato.42.fr`を使います。
`srcs/.env`の`DOMAIN_NAME`を変更した場合は、設定したホスト名に置き換えてください。

1. ブラウザを使うコンピューターの`/etc/hosts`で、ホスト名とVMの接続可能なIPアドレスを対応させます。
   VM内のブラウザを使う場合は`127.0.0.1`を指定します。
2. `https://rysato.42.fr/`を開くと、Webサイトが表示されます。
3. ブラウザに証明書の警告が出た場合は、このローカルプロジェクトの自己署名証明書を受け入れて進みます。
4. ログインする場合は`https://rysato.42.fr/wp-admin/`を開きます。

サイトの管理には管理者アカウントを、通常のコンテンツ公開にはauthorアカウントを使います。
初期アカウントの情報は、後述の認証情報の項目を参照してください。
authorでログインした場合、管理者に比べてダッシュボードで使える機能が少なくなります。

URLには必ず`https://`を付けてください。80番ポートのHTTP接続は利用できません。

| ページ | URL |
| --- | --- |
| WordPress | `https://rysato.42.fr/` |
| WordPress管理画面 | `https://rysato.42.fr/wp-admin/` |
| 42 Tokyoの静的紹介ページ | `https://rysato.42.fr/intro/` |
| Adminer | `https://rysato.42.fr/adminer/` |

`/intro`と`/adminer`は、末尾に`/`のあるパスへリダイレクトします。
静的紹介ページはログインせずに閲覧できます。

### Adminerへログインする

`https://rysato.42.fr/adminer/`を開き、DBアカウントの情報を入力します。

| 項目 | 入力内容 |
| --- | --- |
| システム欄がある場合 | MySQL。MariaDBへの接続にも使います。 |
| サーバー | `mariadb` |
| ユーザー名 | `srcs/.env`の`DB_USER`。 |
| パスワード | DBアカウントの現在のパスワード。初期値は`secrets/db_password.txt`の内容。 |
| データベース | `srcs/.env`の`DB_NAME`。 |

ログイン後、`wp_posts`などのテーブルを選び、保存されているデータを確認します。
Adminerには上記のDBアカウントを使います。
WordPressの管理者・authorはWebサイト側のアカウントで、認証情報は別です。
MariaDBのrootアカウントは、DBコンテナ内からのローカル接続用に設定しています。

### コンテンツの編集とコメントの確認

既存の固定ページを編集するには、管理者でログインし、Pages（固定ページ）から対象のページを選びます。
内容を変更したら、エディターの保存または更新ボタンで確定し、公開ページを開いて反映を確認します。
ブログの投稿はPosts（投稿）で管理します。

コメントを試すには、authorでログインし、コメントを受け付けている公開済みの投稿を開きます。
コメント欄から投稿し、承認待ちになった場合は管理者でログインしてComments（コメント）から承認します。
公開済みの投稿を再読み込みし、コメントが表示されることを確認してください。
コメントの投稿条件や承認ルールは、Settings > Discussion（設定 > ディスカッション）で変更できます。
詳しくは[WordPressのコメント管理ガイド](https://wordpress.org/documentation/article/comments-screen/)を参照してください。

## 認証情報の保存場所と管理

初期ユーザー名は`srcs/.env`で設定します。
パスワードは、プロジェクトのルートにある`secrets/`内のローカルファイルに保存します。

| アカウント | ユーザー名の設定 | 初期パスワードのファイル |
| --- | --- | --- |
| WordPress管理者 | `srcs/.env`の`WP_ADMIN_USER` | `secrets/wp_admin_password.txt` |
| WordPressのauthor | `srcs/.env`の`WP_USER` | `secrets/wp_user_password.txt` |
| WordPress用のDBアカウント | `srcs/.env`の`DB_USER` | `secrets/db_password.txt` |
| MariaDB管理者 | `root` | `secrets/db_root_password.txt` |

Adminerとサービス間の接続にはDBアカウントを、WordPressサイトへのログインにはWordPressのアカウントを使ってください。
パスワードファイルは、ほかの人に見られない環境で確認します。
`srcs/.env`と`secrets/`はGitの追跡対象に含めず、パスワードファイルへのアクセスをVMの管理者に制限してください。

### WordPressのパスワードを変更する

1. ログインし、ダッシュボードまたはアカウントメニューから自分のProfile（プロフィール）を開きます。
2. Account Management（アカウント管理）で新しい強いパスワードを生成するか、入力します。
3. プロフィールを保存します。以後のログインには新しいパスワードを使います。

管理者はUsers（ユーザー）で別のアカウントを選び、そのパスワードを設定することもできます。
詳しくは[WordPressのプロフィール設定ガイド](https://wordpress.org/documentation/article/users-your-profile-screen/)を参照してください。

secretファイルには、アカウントの初回作成時に使ったパスワードが入っています。
WordPressの画面でパスワードを変更しても、secretファイルは書き換わりません。
非公開で管理している認証情報の記録を更新してください。
secretファイルを現在のパスワードの記録としても使う場合は、そのファイルも安全に更新します。
再起動しても、既存のWordPressアカウントがsecretファイル内のパスワードに戻ることはありません。

DBのパスワードファイルを編集するだけでは、MariaDB内のアカウントは変更されません。
DBパスワードを変える場合は、既存のDBアカウントとWordPressの保存済み`wp-config.php`を合わせて変更する必要があります。
VMの管理者に作業を依頼してください。
この構成ではメール配信サービスを設定していないため、アカウントの復旧時にパスワード再設定メールを頼りにしないでください。

## サービスの動作確認

### コンテナの状態とログ

```sh
make ps
make logs
```

5サービスが`Up`を維持し、NGINXが`443`番ポートを公開していることを確認します。
`Restarting`を繰り返している場合や`Exited`の場合は、起動処理に問題があります。
Ctrl+Cでログ表示を終了できます。この操作でサービスは停止しません。

特定のサービスだけを調べる場合は、その名前を指定します。

```sh
docker compose -f srcs/docker-compose.yml logs --tail=100 wordpress
```

ほかのサービスを調べる場合は、`wordpress`を`mariadb`、`nginx`、`website`、`adminer`へ置き換えてください。

### WordPressの初期化とDB接続

```sh
docker compose -f srcs/docker-compose.yml exec wordpress \
    wp --allow-root --path=/var/www/html core is-installed \
    && echo "WordPress initialization: OK"
```

成功メッセージが表示されれば、WordPressはインストール済みです。
続いて、WordPressからDBへクエリを実行できることを確認します。

```sh
docker compose -f srcs/docker-compose.yml exec wordpress \
    wp --allow-root --path=/var/www/html db query 'SELECT 1;' --connect-timeout=2
```

クエリが成功し、`1`が返ることを確認してください。

### HTTPSの応答

VM内で実行します。

```sh
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/
```

初期化済みのサイトでは`HTTP/1.1 200 OK`が返ります。
この例の`--resolve`は、`/etc/hosts`に依存せずVM自身へ接続するための指定です。
`-k`は自己署名証明書の検証を省略します。
ブラウザでもサイトを開き、保存済みのコンテンツが表示されることを確認してください。

### 静的サイトとAdminer

```sh
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/intro/
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/intro/style.css
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/adminer/
```

`200 OK`が返り、CSSの応答が`Content-Type: text/css`になっていることを確認します。
ブラウザでは紹介ページの見た目と、Adminerでのログイン・WordPressの既存テーブルの表示を確認します。
再ビルドやVM再起動の後には、WordPressのトップページと管理画面も確認してください。

静的サイトのファイルとAdminer本体は、それぞれのイメージに含まれています。
ソースファイルを編集した場合は、開発者が該当するイメージを再ビルドする必要があります。
Adminerで変更したDBの内容は、既存のMariaDB用ボリュームに保存されます。

## よくある問題

| 症状 | 確認すること |
| --- | --- |
| ブラウザが`rysato.42.fr`を見つけられない。 | ブラウザを使うコンピューターの`/etc/hosts`と、VMの現在のIPアドレスを確認する。 |
| 証明書の警告が出る。 | 自己署名証明書を使っている。設定したプロジェクトのドメインにアクセスしていることを確認してから受け入れる。 |
| HTTPで接続できない。 | `https://`を使う。80番ポートは公開していない。 |
| HTTPSで接続できない。 | VMとDockerの起動、`make ps`でのNGINXの`Up`表示、ブラウザ側から443番ポートへ接続できるかを確認する。 |
| `502 Bad Gateway`が返る。 | NGINXと接続先のログを調べる。`/intro/`は`website`、`/adminer/`は`adminer`、WordPressのサイトは`wordpress`が接続先。 |
| 紹介ページの見た目が崩れる、または古い内容が表示される。 | `/intro/style.css`を確認する。ソース変更後は`make up`で再ビルドし、ブラウザのキャッシュを使わずに再読み込みする。 |
| Adminerへログインできない。 | サーバーに`mariadb`を指定し、`DB_USER`、`DB_NAME`、現在のDBパスワードを使う。MariaDBのログとアカウント設定も確認する。 |
| WordPressでDB接続エラーが出る。 | MariaDBとWordPressのログを調べる。DBアカウントとWordPressの保存済み設定が一致しているか確認する。 |
| パスワードファイルがない、または空になっている。 | 上記の正しいファイルを復元してから`make`を実行する。新しいパスワードを入れるだけでは既存のアカウントは更新されない。 |
| パスワード変更後にログインできない。 | 現在のWordPressのパスワードを使う。初期secretファイルが古い可能性がある。必要に応じて管理者に再設定を依頼する。 |
| コメントが表示されない。 | 投稿がコメントを受け付けているか、管理者のComments（コメント）画面で承認待ちになっていないか確認する。 |

環境構築と保存先の確認については、[README](README.md)と
[開発者向けドキュメント](DEV_DOC_JA.md)を参照してください。
