FROM rust:1.67

WORKDIR /usr/src/myapp
COPY . .

RUN cargo install --path .
RUN cargo install diesel_cli --no-default-features --features mysql
