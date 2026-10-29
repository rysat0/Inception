# 開発者向けドキュメント

[English Ver.](DEV_DOC.md)

この文書では、環境構築、設定、ビルド、コンテナの管理、データの永続化を説明します。
構成や技術選定の比較は[README](README.md)、Webサイトの操作方法は
[利用者向けドキュメント](USER_DOC_JA.md)を参照してください。

## 環境構築

### 前提条件

systemdが使え、管理者権限を持つLinuxのVMを用意します。
この構成はUbuntu 22.04.5 LTS ARM64で動作確認済みです。
コンテナイメージには、VM側のディストリビューションに関係なくDebian Bookwormを使います。

UbuntuまたはDebianでは、ホスト側で使うツールを次のようにインストールします。

```sh
sudo apt-get update
sudo apt-get install -y git make openssl curl
```

Docker EngineとComposeプラグインは、
[Ubuntu向け](https://docs.docker.com/engine/install/ubuntu/)または
[Debian向け](https://docs.docker.com/engine/install/debian/)の公式手順に従ってインストールします。
Makefileは`docker compose`を使うため、旧形式の独立した`docker-compose`コマンドだけでは動きません。
Makeを実行するユーザーがDockerを操作できるように設定し、次のコマンドで確認します。

```sh
docker version
docker compose version
timedatectl status
```

Dockerはクライアントとサーバーの両方の情報が表示されることを確認してください。
ビルド時にはパッケージ、WP-CLI、Adminerを、WordPressの初回起動時には本体のファイルを取得します。
VMがインターネットに接続でき、時刻が同期されていることも必要です。

リポジトリをcloneします。

```sh
git clone https://github.com/rysat0/Inception.git
cd Inception
```

以降のプロジェクト用コマンドは、このルートディレクトリで実行してください。
例ではログイン名を`rysato`としています。別のログイン名で使う場合は置き換えます。

### 初回ビルド前にDockerの保存先を設定する

アプリケーション用の2つのボリュームは、VMの`/home/<login>/data`配下に保存する必要があります。
このプロジェクトではbind mount用のdriver optionsを指定せず、Dockerのnamed volumeを使います。
ボリュームを作成する前に、root権限で動く通常のDockerデーモンの`data-root`を設定します。

既存のDockerデータを残す必要がある場合は、先に移行方法を検討してください。
`data-root`の変更だけでは、既存データは移動しません。

必要なディレクトリを作り、Dockerの設定ファイルを開きます。

```sh
sudo mkdir -p /home/rysato/data /etc/docker
sudoedit /etc/docker/daemon.json
```

既存の設定がある場合はその内容を残し、次の設定を追加します。
リポジトリには[設定例](srcs/config/daemon.json.example)もあります。

```json
{
  "data-root": "/home/rysato/data"
}
```

設定を検証してDockerを再起動します。

```sh
sudo dockerd --validate --config-file=/etc/docker/daemon.json
sudo systemctl restart docker
docker info --format '{{.DockerRootDir}}'
```

最後のコマンドで`/home/rysato/data`が表示されることを確認します。
この設定はnamed volumeの保存先に適用されます。
Docker Engine 29以降の新規インストールでcontainerd image storeを使っている場合、
イメージの内容とスナップショットはcontainerdの別の保存領域に置かれます。
その保存領域は`data-root`を変えても移動しません。
詳しくは[Dockerデーモンの設定](https://docs.docker.com/engine/daemon/)を参照してください。

### 環境変数ファイルを作成する

Gitの追跡対象から除外されている`srcs/.env`を作成します。

```dotenv
DB_NAME=wordpress
DB_USER=wpuser
DOMAIN_NAME=rysato.42.fr
WP_TITLE="Inception"
WP_ADMIN_USER=rysato_owner
WP_ADMIN_EMAIL=owner@example.com
WP_USER=rysato_author
WP_USER_EMAIL=author@example.com
```

8つの変数はすべてComposeで必須になっています。
WordPressの管理者名と一般ユーザー名には別の名前を指定してください。
管理者名に`admin`や`administrator`を含めることはできません。大文字・小文字を変えた表記も同様です。
メールアドレスの例は、実際に使うアカウントのアドレスへ置き換えます。

`DB_NAME`と`DB_USER`には英数字とアンダースコアを使ってください。
現在のMariaDB初期化SQLは設定値を直接埋め込んでおり、任意のSQL文字列をエスケープする処理はありません。

### secretsを作成する

次のコマンドで4つのパスワードファイルを生成します。既存のファイルは上書きしません。

```sh
umask 077
mkdir -p secrets
for name in db_root_password db_password wp_admin_password wp_user_password; do
    secret_file="secrets/$name.txt"
    if [ ! -e "$secret_file" ]; then
        openssl rand -hex 24 > "$secret_file"
    fi
done
```

16進数のパスワードを生成することで、初期化SQLでエスケープしていない引用符を避けています。
既存のファイルを使う場合も、中身が空でなく、初期化SQLで扱えるパスワードであることを確認してください。

| ホスト側のファイル | コンテナ内のsecret | 読み取るサービス |
| --- | --- | --- |
| `secrets/db_root_password.txt` | `/run/secrets/db_root_password` | MariaDB |
| `secrets/db_password.txt` | `/run/secrets/db_password` | MariaDB、WordPress |
| `secrets/wp_admin_password.txt` | `/run/secrets/wp_admin_password` | WordPress |
| `secrets/wp_user_password.txt` | `/run/secrets/wp_user_password` | WordPress |

Composeは、ホスト側のファイルパスを`srcs/docker-compose.yml`からの相対パスとして解決します。
各entrypointは、対応する`*_PASSWORD_FILE`環境変数で指定されたファイルを読み取ります。
`.env`とパスワードファイルはローカルで管理してください。
`.gitignore`では`srcs/.env`と`secrets/*`を除外しています。

### ドメインの名前解決を設定する

ブラウザを使うコンピューターの`/etc/hosts`に、接続先VMのIPアドレスと`rysato.42.fr`を登録します。
VM内のブラウザを使う場合は`127.0.0.1`を指定します。
ホスト名は`DOMAIN_NAME`と一致させてください。
NGINXは443番ポートを公開するため、ブラウザ側からこのポートに接続できるようにVMのネットワークを設定します。

## ビルドと起動

展開後の環境変数の値を表示せずに設定を検証し、ビルド・起動します。

```sh
docker compose -f srcs/docker-compose.yml config --quiet
make
make ps
```

`make`のデフォルトターゲットは`up`で、
`docker compose -f srcs/docker-compose.yml up -d --build`を実行します。
コンテナを起動せず、ビルドだけ行う場合は`make build`を使います。

Composeのプロジェクト名は`inception`です。
`mariadb:inception`、`wordpress:inception`、`nginx:inception`、
`website:inception`、`adminer:inception`の5つのローカルイメージをビルドします。
必須サービスはentrypointスクリプトを使います。
2つのボーナスサービスは、exec形式の`CMD`からNGINXまたはPHP-FPMを直接起動します。

5サービスは同じComposeファイルに含まれており、`make`で起動します。
ホスト側へポートを公開するのは入口のNGINXだけです。
`website`は内部の8080番、WordPressとAdminerはそれぞれのコンテナ内の9000番で待ち受けます。
コンテナが別であれば、内部のポート番号は同じでも構いません。

`depends_on`が指定するのは起動順序です。アプリケーションが利用可能になったことまでは保証しません。
そのため、WordPressはDBへのクエリを最大30回試し、接続できてから先へ進みます。
`make logs`で起動時の出力を確認できます。Ctrl+Cでログ表示を終了しても、コンテナは停止しません。

## 開発とコンテナ管理

| ソース | 用途 |
| --- | --- |
| `Makefile` | ビルドと起動・停止などの操作。 |
| `srcs/docker-compose.yml` | サービスの接続、設定、secrets、ボリューム、ネットワーク。 |
| `srcs/requirements/<service>/Dockerfile` | 各イメージのパッケージ、コピーするファイル、entrypoint。 |
| `srcs/requirements/<service>/conf/` | MariaDB、PHP-FPM、NGINXの設定。 |
| `srcs/requirements/<service>/tools/entrypoint.sh` | 起動時の検証と初期化。 |
| `srcs/requirements/bonus/website/` | 静的サイトのDockerfile、NGINX設定、`site/`内のHTML/CSS。 |
| `srcs/requirements/bonus/adminer/` | AdminerのDockerfileとPHP-FPMのプール設定。 |

Dockerfileは設定ファイルやスクリプトをイメージ内へコピーします。
これらを編集した後は`make up`を実行し、再ビルドと、変更の影響を受けるコンテナの再作成を行います。
全コンテナを再作成する場合は`make re`を使います。2つのデータ用ボリュームは残ります。
`make restart`は既存のコンテナを再起動するため、イメージやCompose設定の変更は反映しません。
詳しくは[Compose upのリファレンス](https://docs.docker.com/reference/cli/docker/compose/up/)を参照してください。

調査に使う主なコマンドは次のとおりです。

```sh
docker compose -f srcs/docker-compose.yml ps -a
docker compose -f srcs/docker-compose.yml images
docker compose -f srcs/docker-compose.yml logs --tail=100 mariadb
docker compose -f srcs/docker-compose.yml exec wordpress sh
docker compose -f srcs/docker-compose.yml exec nginx nginx -t
docker compose -f srcs/docker-compose.yml exec website nginx -t
docker compose -f srcs/docker-compose.yml exec adminer php-fpm8.2 -t
docker compose -f srcs/docker-compose.yml exec adminer php -l /var/www/adminer/index.php
docker network inspect inception_inception
```

コンテナのシェルからは`exit`で戻れます。
コンテナの書き込み可能なレイヤーに直接加えた変更は、そのコンテナを再作成すると失われます。
コードや設定の変更を残すには、ソースファイルを更新して再ビルドしてください。

停止には`make stop`、再起動には`make restart`、コンテナとネットワークの削除には`make down`を使います。
Makefileの`down`ターゲットは`--volumes`を指定しないため、named volumeは残ります。
詳しくは[Compose downのリファレンス](https://docs.docker.com/reference/cli/docker/compose/down/)を参照してください。

### 初期化と既存データへの変更

- MariaDBは`/var/lib/mysql/mysql`がない場合にシステムテーブルを作成します。
  `/var/lib/mysql/.inception-initialized`がない場合に初期化SQLを実行し、成功後にだけmarkerを作成します。
  bootstrapモードでは、アカウント操作のSQLより前に`FLUSH PRIVILEGES`を実行する必要があります。
- WordPressは`wp-load.php`がなければ本体をダウンロードし、`wp-config.php`がなければ設定ファイルを作成します。
  サイトのインストールは未インストールの場合だけ、authorアカウントの作成はそのユーザー名が存在しない場合だけ行います。
- NGINXは証明書か秘密鍵のいずれかが存在しない、または空の場合に、両方を生成します。
  これらはコンテナ内に保存するため、コンテナを再作成すると新しい証明書が生成されます。
  NGINXの設定ファイルは起動のたびに生成します。

`.env`やsecretファイルを変更しても、既存のDBアカウント、WordPressのパスワード、
保存済みのサイトURL、`wp-config.php`は更新されません。
これらは既存のアプリケーションとDBに対する変更として、明示的に更新してください。
特にDBパスワードを変更する際は、ボリューム内のWordPress設定も整合させる必要があります。
MariaDBのmarkerを削除する操作は、パスワードを変更するための手順ではありません。

## ボーナスサービスの開発

### 静的紹介サイト

`srcs/requirements/bonus/website/site/index.html`と`style.css`を編集します。
Dockerfileは`site/`を`website`イメージ内の`/var/www/website`へコピーします。
NGINXの設定は`srcs/requirements/bonus/website/conf/website.conf`にあり、8080番で待ち受けます。

入口側の`srcs/requirements/nginx/conf/nginx.conf`では、`/intro`を`/intro/`へリダイレクトし、
`/intro/`へのリクエストをHTTPで`website:8080`へ転送します。
`proxy_pass http://website:8080/;`の末尾の`/`により、転送時に`/intro/`部分を`/`へ置き換えます。
そのため、公開パスの下でも`./style.css`などの相対パスを使えます。

静的ファイルやサーバー設定を編集した後は、再ビルドします。

```sh
make up
```

静的ファイルはホストからbind mountせず、イメージ内へコピーします。
ソースの変更は再ビルドで反映されます。既存コンテナを再起動するだけでは反映されません。
このサービスに永続化用のボリュームは必要ありません。

### AdminerによるDB管理画面

`srcs/requirements/bonus/adminer/Dockerfile`は、Debian BookwormへPHP-FPM、PHP CLI、
MySQL用拡張をインストールします。
バージョンを固定したAdminer 6.2.0のMySQL/MariaDB向け配布物を
`/var/www/adminer/index.php`として取得し、ビルド中に`php -l`で構文を確認します。
プール設定は`srcs/requirements/bonus/adminer/conf/www.conf`です。
必要に応じてワーカーを作成するondemand方式で、9000番で待ち受けます。

入口側では`/adminer`を`/adminer/`へリダイレクトし、専用のFastCGI設定から
`fastcgi_pass adminer:9000`で接続します。
`SCRIPT_FILENAME`には、Adminerコンテナ内の固定パス`/var/www/adminer/index.php`を渡します。
入口側にこのPHPファイルをコピーする必要はありません。

Adminerはbridgeネットワーク経由でMariaDBへ接続します。
ログイン画面では、サーバーに`mariadb`、ユーザー名に`DB_USER`、DB名に`DB_NAME`を指定し、
現在のDBパスワードを入力します。初期パスワードは`secrets/db_password.txt`に保存されています。
この2つのボーナスに追加の環境変数、secretファイル、永続化用ボリュームは必要ありません。
Adminerはパスワードファイルをマウントしません。
ログイン手順は[利用者向けドキュメント](USER_DOC_JA.md)を参照してください。

## ボリューム管理とデータの保存場所

| Composeでの名前 | Docker上の名前 | コンテナ内のパス | 保存内容 |
| --- | --- | --- | --- |
| `mariadb_data` | `inception_mariadb_data` | MariaDBの`/var/lib/mysql` | システムテーブル、WebサイトのDB、初期化marker。 |
| `wordpress_data` | `inception_wordpress_data` | WordPressとNGINXの`/var/www/html` | WordPress本体、設定、テーマ、プラグイン、アップロードしたファイル。 |

WordPressはサイトのファイルを読み書きでき、NGINXは同じボリュームを読み取り専用でマウントします。
MariaDB側の`nocopy: true`は、イメージ内のファイルをボリュームへコピーする動作を抑え、
entrypointでDBを初期化するための指定です。

プロジェクトのボリューム一覧と、実際の保存先を確認します。

```sh
docker volume ls --filter label=com.docker.compose.project=inception
docker volume inspect inception_mariadb_data inception_wordpress_data \
    --format '{{.Name}}: {{.Mountpoint}}'
```

前述のストレージ設定を使う場合、マウント元は次のパスになります。

- `/home/rysato/data/volumes/inception_mariadb_data/_data`
- `/home/rysato/data/volumes/inception_wordpress_data/_data`

投稿、固定ページ、コメント、アカウントはMariaDBに保存します。
WebサイトのファイルとアップロードしたファイルはWordPress用のボリュームに保存します。
どちらのボリュームも、コンテナの作り直しや通常のVM再起動では消えません。
WordPress用のボリュームには、DBの認証情報を含む`wp-config.php`もあるため、非公開の情報として扱ってください。

ボーナス用のデータボリュームは追加しません。静的ファイルとAdminer本体はイメージに含まれます。
Adminerが操作するDBの保存先は`mariadb_data`です。
Adminerのログインセッションを専用ボリュームで永続化していないため、コンテナ再作成後には
ログインし直す必要がある場合があります。

サーバーの稼働中にMariaDBのデータファイルを直接編集しないでください。
`docker compose down --volumes`などでボリュームを削除すると、保存済みデータも消えます。
通常の再ビルド手順では、ボリュームを削除しません。

## 開発後の動作確認

`make up`の後に状態とログを調べ、VM内からWordPress、DB接続、HTTPSを確認します。

```sh
make ps
docker compose -f srcs/docker-compose.yml exec wordpress \
    wp --allow-root --path=/var/www/html core is-installed \
    && echo "WordPress initialization: OK"
docker compose -f srcs/docker-compose.yml exec wordpress \
    wp --allow-root --path=/var/www/html db query 'SELECT 1;' --connect-timeout=2
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/intro/
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/intro/style.css
curl -kI --resolve rysato.42.fr:443:127.0.0.1 https://rysato.42.fr/adminer/
```

初期化の成功メッセージ、クエリの結果の`1`、`HTTP/1.1 200 OK`が得られることを確認します。
curlのオプションは、この自己署名証明書を使うローカル環境の確認で、名前解決と証明書検証を省略するためのものです。
ブラウザでも変更した動作を確かめてください。コンテナの稼働状態だけでは、アプリケーション全体の正常動作は判断できません。

5サービスが稼働を維持することを確認します。静的サイトのCSSが`text/css`として配信され、
紹介ページの見た目が正しく表示されることを確認してください。
Adminerへログインし、`wp_posts`などの既存テーブルを閲覧します。
`/intro`と`/adminer`が末尾に`/`のあるURLへリダイレクトすることと、
WordPressのトップページ・管理画面が引き続き動作することも確認します。

永続化は次の手順で確認します。

1. WordPressの固定ページを編集して保存し、内容とボリュームのマウント元を記録します。
2. `make re`を実行し、保存した内容が残っていることを確認します。
3. VMを再起動します。サービスが自動起動しない場合は`make`を実行します。
4. 固定ページとアカウントが利用できることを確認し、ボリュームのマウント元も再確認します。
5. `/intro/`と`/adminer/`を再度開きます。静的ページを確認し、Adminerへログインして
   WordPressの既存テーブルにアクセスできることを確認します。

確認中は2つのボリュームを残してください。
これまでのVMでの確認結果は、[READMEのValidation](README.md#validation)に記載しています。
