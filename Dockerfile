# Stage 1: Build Frontend Assets
# This stage uses Node.js to build the Vue frontend.
FROM node:20-slim AS frontend-builder
RUN npm install -g pnpm
WORKDIR /app

# Copy all frontend source code
COPY ./easytier-web/frontend /app/frontend
COPY ./easytier-web/frontend-lib /app/frontend-lib

# Create pnpm workspace config and install dependencies.
# It's better to have pnpm-workspace.yaml in your repo,
# but here we replicate the logic from the previous build log.
RUN echo "packages:\n  - 'frontend'\n  - 'frontend-lib'" > /app/pnpm-workspace.yaml
RUN pnpm install

# Build the frontend library and the main application.
RUN pnpm --filter easytier-frontend-lib build
RUN pnpm --filter easytier-frontend build

# Stage 2: Build Rust Application
# This stage uses the Rust toolchain to compile the backend.
FROM rust:1.84-bullseye AS rust-builder
# Install build dependencies required by some crates.
RUN apt-get update && apt-get install -y clang libclang-dev protobuf-compiler
WORKDIR /app

# Copy the entire workspace source code.
COPY . .

# Copy the pre-built frontend assets from the previous stage.
COPY --from=frontend-builder /app/frontend/dist /app/easytier-web/frontend/dist

# Build the release binary for the easytier-web package with embedded assets.
# This command is run from the workspace root '/app' to ensure correct output paths.
RUN cargo build --release --package easytier-web --features embed

# Stage 3: Create Final, Minimal Image
# This stage creates the final, small image for deployment.
FROM debian:bullseye-slim

# Copy the compiled binary from the rust-builder stage.
# The binary is located in the workspace's target directory.
COPY --from=rust-builder /app/target/release/easytier-web /usr/local/bin/easytier-web

# Set the default command to run the web server.
# The server will listen on port 8081, which you can map to the host.
CMD ["easytier-web", "--web-server-port", "8081"]