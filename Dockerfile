# Stage 1: Build the frontend
FROM node:20-slim AS frontend-builder
RUN npm install -g pnpm
WORKDIR /app
COPY ./easytier-web/frontend /app/frontend
COPY ./easytier-web/frontend-lib /app/frontend-lib
RUN echo "packages:\n  - 'frontend'\n  - 'frontend-lib'" > /app/pnpm-workspace.yaml
RUN cd /app && pnpm install
RUN cd /app && pnpm --filter easytier-frontend-lib build
RUN cd /app && pnpm --filter easytier-frontend build

# Stage 2: Build the Rust backend
FROM rust:1.84-bullseye AS rust-builder
RUN apt-get update && apt-get install -y clang libclang-dev p7zip-full protobuf-compiler
WORKDIR /app
COPY . .
COPY --from=frontend-builder /app/frontend/dist /app/easytier-web/frontend/dist
WORKDIR /app/easytier-web
RUN cargo build --release --features embed

# Stage 3: Create the final image
FROM debian:bullseye-slim
WORKDIR /app
COPY --from=rust-builder /app/target/release/easytier-web /usr/local/bin/easytier-web
EXPOSE 11211
EXPOSE 8081
EXPOSE 22020/udp
RUN mkdir -p /data
CMD ["/usr/local/bin/easytier-web", "--db", "/data/et.db", "--api-server-port", "11211", "--web-server-port", "8081"]