# DockerでRailsやるサンプルとチュートリアル

[→English](./README.md)

DockerでRailsアプリを作ったり動かしたりするサンプルとチュートリアルです。

## Windowsの方

コマンドプロンプトやPowerShell入力時、 `` `pwd` `` を `%CD%` に置き換えてください。

じゃないと例えばこんな感じのエラーになります。

> docker: Error response from daemon: create \`pwd\`/app: “`pwd`/app” includes invalid characters for a local volume name, only “[a-zA-Z0-9][a-zA-Z0-9_.-]” are allowed. If you intended to pass a host directory, use absolute path.

# 準備

事前に以下が必要です。

- Dockerインストール

# 新規にRailsアプリを作成

1. アプリ用ディレクトリーを用意
2. Dockerで `rails new` を実行
3. Gemを置く、アプリ用Dockerイメージを記述
4. DB設定
5. DB設定込みのDocker componentファイルを準備
6. DBファイルを無視
7. 起動
8. いったん止めてみる
9.  別のコンソールを開く
10. DB初期化
11. ブラウザーで開く

アプリの名前は "my-great-app" とします。
適宜ご自身のアプリ名に置き換えてください。

ディレクトリー構成はこんな感じ:

```
my-great-app/
+ app/
|  - (Railsファイル。例: `config.ru`)
+ db/
|  - (DBファイル)
+ .gitignore
+ docker-compose.yml
+ Dockerfile
+ README.md
```

## アプリ用ディレクトリーを用意

```console
$ mkdir my-great-app
$ cd my-great-app
```

ここで諸々作業します。

## Dockerで `rails new` を実行

さらに細かいステップに分けると、こう。

1. Dockerコンテナー起動
2. `rails new`
3. 空の `Gemfile.lock` 作成
4. 作成ファイルをホストマシンへ保存
5. Dockerコンテナー終了

まずDockerコンテナーを起動します。

```console
$ mkdir app
$ docker run --rm -ti -v `pwd`/app:/app rails:5.0.1 bash
```

`5.0.1` はイメージのタグで、Railsのバージョンでもあります。以下に一覧。

- [library/rails - Docker Hub](https://hub.docker.com/r/library/rails/tags/)

初回はDockerがRailsイメージをダウンロードするため、時間がかかるかもしれません。二回目以降はすぐ起動します。

で、Dockerコンテナー内へ入ることができました。とりあえずRailsのバージョンでも見ておきましょうか。

```console
root@b4227fbcb3b1:/# rails --version
Rails 5.0.1
root@b4227fbcb3b1:/#
```

Dockerコンテナー内部では `Ctrl-P` が使えないことにご留意ください。Docker的に特別な意味を持ってます。

Dockerコンテナー内で、オプション付けて `rails new` を実行します。

```console
root@b4227fbcb3b1:/# rails new my-great-app --skip-bundle --database=mysql
      create
      create  README.md
      create  Rakefile
      create  config.ru
...
      create  vendor/assets/stylesheets
      create  vendor/assets/stylesheets/.keep
      remove  config/initializers/cors.rb
root@b4227fbcb3b1:/#
```

`--skip-bundle` オプションは、読んで字のごとく `bundle install` を省略します。
インストールは後で行うので、ここでやる必要はありません。

`--database` オプションはお好きなものをどうぞ。
このチュートリアルではRailsアプリ用DBMSとしてMySQLを選びました。


`bundle install` を省略したんですが、後の操作でファイルは必要なので、空の状態で作成だけしておきます。

```console
$ touch /my-great-app/Gemfile.lock
```

できあがったファイル類をホストマシンへ保存するため、共有ボリュームへ移動します。そんで終了。

```console
root@b4227fbcb3b1:/# cp -rT my-great-app/* /app
root@b4227fbcb3b1:/# exit
```

`cp` の `-T` オプションはドットファイル (`.gitignore`) を複製するためです。

（`/app` 内に直接ファイル生成しないのは、Railsがディレクトリ名を利用してテンプレートからファイルを生成するためです。直接やるやり方あったら教えてくださいです。）

Dockerコンテナーの外に、ちゃんとファイルが出来上がっていることを確認しましょう。

```console
$ ls -a app/
.   .gitignore  Gemfile.lock  Rakefile  bin     config.ru  lib  public  tmp
..  Gemfile     README.md     app       config  db         log  test    vendor
```

## Gemを置く、アプリ用Dockerイメージを記述

新規に `Dockerfile` という、拡張子のないファイルを作成します。

```dockerfile
FROM rails:5.0.1

RUN mkdir /app
WORKDIR /app

COPY ./app/Gemfile /app/Gemfile
COPY ./app/Gemfile.lock /app/Gemfile.lock

RUN bundle install
CMD rm /app/tmp/pids/server.pid ; rails s
```

## DB設定

まだDBの用意はできてないけど、先にちょっとだけ設定します。

`app/config/database.yml` を開いて、 `host: localhost` を `host: db` へ変更します。

```yml
default: &default
  adapter: mysql2
  encoding: utf8
  pool: 5
  username: root
  password:
  host: db
```

この `db` は、次のステップでやる `docker-compose.yml` のservice名として利用します。

## DB設定込みのDocker componentファイルを準備

新規に `docker-compose.yml` というファイルを作成します。

```yml
version: "3"

services:

  rails:
    build: ./
    ports:
      - "3000:3000"
    volumes:
      - ./app:/app
    depends_on:
      - db

  db:
    image: mysql
    volumes:
      - ./db:/var/lib/mysql
    environment:
      MYSQL_ALLOW_EMPTY_PASSWORD: "true"
```

この設定だとパスワードなしのrootユーザーでDBを用意します。
安全じゃない場合もあるけど、まあ開発用途ならこんなもんかと。

## DBファイルを無視

Gitをお使いだろうので、 `.gitignore`  でDBファイルを無視するようにします。

```
/db/
```

## 起動

```console
$ docker-compose up
```

これも初回にまた時間がかかるかもしれません。

まず、 `Dockerfile` からプロジェクト用のDockerイメージが作成されます。このプロセスは `bundle install` を含みます。

また、起動後、MySQLが `db` の中に諸々のファイルを作成します。

まあコンソールの出力が落ち着くまでゆっくりしててください。

## いったん止めてみる


コンソールで `Ctrl-C` を押して止めてみてください。終了にもまた時間がかかります。ちょっとまっててね。

```console
Gracefully stopping... (press Ctrl+C again to force)
Stopping docker-rails-example_rails_1   ... done
Stopping docker-rails-example_db_1      ... done

$
```

起動と終了のやり方を覚えたら、起動し直して、次へ進みましょう。

## 別のコンソールを開く

Dockerコンテナーは起動したままにしておきます。

実行中は別のコンソールを起動して、そっちで作業してください。

## DB初期化

新しく開いた方のコンソールで、次の1行を入力してDBを作成します。
`docker-compose up` は最初のコンソールで実行中のままです。

```console
$ docker-compose exec rails rake db:create
Created database 'my-great-app_development'
Created database 'my-great-app_test'
```

## ブラウザーで開く

[`http://localhost:3000/`](http://localhost:3000/) を開いて、成果を確認します。
Yay! You’re on Rails!

![Welcome screen from Rails](doc/you-are-on-rails.png)

# 二回目以降の起動

かんたん。

```console
$ docker-compose up
```

そんで [`http://localhost:3000/`](http://localhost:3000/) を開くと。

あと `rails g scaffold` なんかのために別のコンソールを開くことになると思います。

# プロジェクトを更新する

## 基本的な考え方

`rails` とか `rake` とかそういうコマンドを実行したいことと思います。そういうとき、基本的には `docker-compose exec rails xxx` みたいな感じで実行します。

例えば `echo` をしたいとするじゃないですか。その場合はこうです。

```console
$ docker-compose exec rails echo Hello from Docker container!
```

このとき `docker-compose up` は既に実行中で、それとは別のコンソールを開いて実行する必要があるということを忘れないでください。

## scaffold生成したいときは

```console
$ docker-compose exec rails rails g scaffold post title:string body:text
      invoke  active_record
      create    db/migrate/20180806212720_create_posts.rb
      create    /models/post.rb
...
      create      /assets/stylesheets/posts.scss
      invoke  scss
      create    /assets/stylesheets/scaffolds.scss
```

マイグレーションをお忘れなく。（次項参照。）

## マイグレーションしたいときは

```console
$ docker-compose exec rails rake db:migrate
== 20180806212720 CreatePosts: migrating ======================================
-- create_table(:posts)
   -> 0.0766s
== 20180806212720 CreatePosts: migrated (0.0769s) =============================
```

## 試験実行したいときは

```console
$ docker-compose exec rails rake test
Run options: --seed 52703

# Running:

.......

Finished in 1.302024s, 5.3762 runs/s, 6.9123 assertions/s.
7 runs, 9 assertions, 0 failures, 0 errors, 0 skips
```

## 新しいGemを追加したときは

`Gemfile` を更新した場合、かつては普通に `bundle install` を実行していたものと思います。

Dockerでは、イメージを再構築する必要があります。そのプロセスで `bundle install` が実行され、また `Gemfile.lock` も更新されます。

再構築には `--force-recreate` オプションを与えます。

```console
$ docker-compose.exe up --build
```

付け忘れると、例えばこんなエラーが。（ログが長いので見つけづらいはず。）

```
rails_1  | /usr/local/lib/ruby/gems/2.3.0/gems/bundler-1.13.7/lib/bundler/resolver.rb:366:in `block in verify_gemfile_dependencies_are_found!': Could not find gem 'carrierwave' in any of the gem sources listed in your Gemfile or available on this machine. (Bundler::GemNotFound)
rails_1  |      from /usr/local/lib/ruby/gems/2.3.0/gems/bundler-1.13.7/lib/bundler/resolver.rb:341:in `each'
...
rails_1  |      from /usr/local/bundle/bin/rails:15:in `<main>'
```

# 他のプロジェクトへ参加する

こういうステップはREADMEとかに書いてあると良いよね。

1. リポジトリをクローン
2. Dockerコンテナー起動
3. DB初期化
4. 作業開始

## リポジトリをクローン

```console
$ git clone ...
$ cd xxx
```

## Dockerコンテナー起動

```console
$ docker-compose up
```

`Ctrl-C` で終了。

## DB初期化

別コンソールを開き、以下を実行。

```console
$ docker-compose exec rails rake db:create db:migrate db:seed
```

## 作業開始

[`http://localhost:3000/`](http://localhost:3000/) （とコンソールも？）開いて、諸々作業します。

がんばってねー。
