# Stage 1: Build React
FROM node:22-slim AS web-build
WORKDIR /build
RUN corepack enable
COPY packages/preset_react/package.json packages/preset_react/pnpm-lock.yaml ./packages/preset_react/
RUN cd packages/preset_react && pnpm install --frozen-lockfile
COPY packages/preset_react/ ./packages/preset_react/
RUN cd packages/preset_react && pnpm build

# Stage 2: Build Rust
FROM rust:1-bookworm AS rust-build
WORKDIR /build
COPY Cargo.toml Cargo.lock ./
COPY crates/ crates/
# rust-embed resolves the folder at compile time; copy web build output
# so embedded assets are included in the binary.
COPY --from=web-build /build/packages/preset_react/dist/ packages/preset_react/dist/
RUN cargo build --release

# Stage 3: Runtime
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=rust-build /build/target/release/audiflow-editor /usr/local/bin/
COPY --from=web-build /build/packages/preset_react/dist /app/public/
WORKDIR /data
EXPOSE 8080
ENTRYPOINT ["audiflow-editor", "serve", "--host", "0.0.0.0", "--port", "8080", "--static-dir", "/app/public", "--data-dir", "/data"]
