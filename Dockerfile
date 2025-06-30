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
RUN echo "--- Listing built frontend assets in stage 1 ---" && ls -la /app/frontend/dist

# Stage 2: Build the Rust backend
FROM --platform=linux/amd64 debian:bullseye AS rust-builder
RUN apt-get update && apt-get install -y curl clang libclang-dev p7zip-full protobuf-compiler
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
WORKDIR /app
COPY . .
COPY --from=frontend-builder /app/frontend/dist /app/easytier-web/frontend/dist
RUN echo "--- Listing copied frontend assets in stage 2 ---" && ls -la /app/easytier-web/frontend/dist
WORKDIR /app/easytier-web
RUN cargo build --release --features embed

# Stage 3: Create the final image
FROM debian:bullseye-slim
WORKDIR /app
COPY --from=rust-builder /app/target/release/easytier-web /usr/local/bin/easytier-web
COPY --from=rust-builder /app/easytier-web/locales /app/locales
COPY --from=rust-builder /app/easytier-web/resources /app/resources
EXPOSE 11211
EXPOSE 8081
EXPOSE 22020/udp
RUN mkdir -p /data
CMD ["/usr/local/bin/easytier-web", "--db", "/data/et.db", "--api-server-port", "11211", "--web-server-port", "8081"]