# disel mysql example

[disel](https://github.com/diesel-rs/diesel/tree/master)

## 1. dockerでrust環境を作成する

rustのimageを利用するrust.dockerfileとdocker-compose.yamlを作成する。

```docker-compose.yaml
version: "3"

services:
  rust_container_image:
    container_name: rust_container_image
    build:
     context: .
     dockerfile: rust.dockerfile
    tty: true
    restart: always
    volumes:
      - ".:/usr/src/myapp"
```

```rust.dockerfile
FROM rust:1.67

WORKDIR /usr/src/myapp
COPY . .
```

上記を作成したら、

```terminal
% docker compose up --detach
% docker exec -it rust_container_image bash
```

## 2. diselの環境を作成する

```terminal
% cargo new myapp
```

```(before)Cargo.toml
[package]
name = "myapp"
version = "0.1.0"
edition = "2021"

# See more keys and their definitions at https://doc.rust-lang.org/cargo/reference/manifest.html

[dependencies]
```

```(after)Cargo.toml
[package]
name = "myapp"
version = "0.1.0"
edition = "2021"

# See more keys and their definitions at https://doc.rust-lang.org/cargo/reference/manifest.html

[dependencies]
chrono = { version = "0.4.24", features = ["serde"] }
diesel = { version = "2.0.0", features = ["mysql", "chrono"] }
dotenvy = "0.15"
```

```terminal
% cargo update
% cargo install diesel_cli --no-default-features --features mysql
```

api directoryが作成されたので、rust.dockerfileをapi以下に移動、また、docker-compose.yamlのbuild.contextをmyappに変更します。

rust.dockerfileをimage作成時に依存関係を解決してほしいので、以下のコードを追記します。

```myapp/
RUN cargo install --path .
```

disel cliをmigrationで利用したいため、rust.dockerfileを書き換えます。

```rust.dockerfile
FROM rust:1.67

WORKDIR /usr/src/myapp
COPY . .

RUN cargo install --path .
RUN cargo install diesel_cli --no-default-features --features mysql
```

## 3. mysqlのdocker環境を作成する

docker/mysql.dockerfileを作成していきます。
また、docker-compose.yamlにmysqlの構造体とdockerfileを編集していきます。

```docker/mysql.dockerfile
FROM mysql:8
```

```docker-compose.yaml
version: "3"

services:
  rust_container_image:
    container_name: rust_container_image
    build:
     context: ./api
     dockerfile: rust.dockerfile
    tty: true
    restart: always
    volumes:
      - "./myapp:/usr/src/myapp"
    networks:
      - local
      
  mysql_container_image:
    container_name: mysql_container_image
    build:
      context: ./docker
      dockerfile: mysql.dockerfile
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: root_password
      MYSQL_DATABASE: disel_example
    ports:
      - "3306:3306"
    volumes:
      - "my_db_volume:/var/lib/mysql"
    networks:
      - local

volumes:
  my_db_volume: {}

networks:
  local: {}
```

## 4. diselの環境を整備する

`.env`を利用してmysqlのurlをやりとりして、migrationを実施する。

```.env
DATABASE_URL=mysql://root:root_password@mysql_container_image:3306/disel_example
```

次にdieselのsetupを実施します。

```terminal
% diesel setup
```

## 5. migrationの実施

migrationのdirectoryが作成されるので、
up.sqlとdown.sqlを記載していく。

```terminal
% diesel migration generate create_users
```

```migrations/XXX_create_users/up.sql
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTO_INCREMENT,
  name TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

```migrations/XXX_create_users/down.sql
DROP TABLE users;
```

最後にmigrationを実施してdatabaseを確認します。

```terminal
% diesel migration run
```

```terminal
show columns from users;
+------------+-----------+------+-----+-------------------+-----------------------------------------------+
| Field      | Type      | Null | Key | Default           | Extra                                         |
+------------+-----------+------+-----+-------------------+-----------------------------------------------+
| id         | int       | NO   | PRI | NULL              | auto_increment                                |
| name       | text      | NO   |     | NULL              |                                               |
| created_at | timestamp | NO   |     | CURRENT_TIMESTAMP | DEFAULT_GENERATED                             |
| updated_at | timestamp | NO   |     | CURRENT_TIMESTAMP | DEFAULT_GENERATED on update CURRENT_TIMESTAMP |
+------------+-----------+------+-----+-------------------+-----------------------------------------------+
4 rows in set (0.00 sec)
```