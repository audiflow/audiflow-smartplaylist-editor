# Stage 1: Build Flutter web app
FROM ghcr.io/cirruslabs/flutter:3.38.5 AS web-build

WORKDIR /build

# Copy workspace root pubspec
COPY pubspec.yaml .

# Copy package pubspec files for dependency resolution
COPY packages/sp_shared/pubspec.yaml packages/sp_shared/pubspec.yaml
COPY packages/sp_web/pubspec.yaml packages/sp_web/pubspec.yaml
COPY packages/sp_server/pubspec.yaml packages/sp_server/pubspec.yaml

# Stub mcp_server so workspace resolves
RUN mkdir -p mcp_server
COPY mcp_server/pubspec.yaml mcp_server/pubspec.yaml

# Copy source code needed for web build
COPY packages/sp_shared/lib/ packages/sp_shared/lib/
COPY packages/sp_web/ packages/sp_web/

# Resolve dependencies and build
RUN flutter pub get
RUN cd packages/sp_web && flutter build web --release --dart-define=API_URL=


# Stage 2: Compile Dart server to AOT binary
FROM dart:3.10.4 AS server-build

WORKDIR /build

# Copy workspace root pubspec
COPY pubspec.yaml .

# Copy package pubspec files
COPY packages/sp_shared/pubspec.yaml packages/sp_shared/pubspec.yaml
COPY packages/sp_server/pubspec.yaml packages/sp_server/pubspec.yaml

# Stub unused packages so workspace resolves
RUN mkdir -p packages/sp_web && \
    echo 'name: sp_web' > packages/sp_web/pubspec.yaml && \
    echo 'publish_to: none' >> packages/sp_web/pubspec.yaml && \
    echo 'resolution: workspace' >> packages/sp_web/pubspec.yaml && \
    echo 'environment:' >> packages/sp_web/pubspec.yaml && \
    echo '  sdk: ^3.10.0' >> packages/sp_web/pubspec.yaml

RUN mkdir -p mcp_server && \
    echo 'name: sp_mcp_server' > mcp_server/pubspec.yaml && \
    echo 'publish_to: none' >> mcp_server/pubspec.yaml && \
    echo 'resolution: workspace' >> mcp_server/pubspec.yaml && \
    echo 'environment:' >> mcp_server/pubspec.yaml && \
    echo '  sdk: ^3.10.0' >> mcp_server/pubspec.yaml

# Copy source code
COPY packages/sp_shared/lib/ packages/sp_shared/lib/
COPY packages/sp_server/ packages/sp_server/

RUN dart pub get
RUN mkdir -p /app && dart compile exe packages/sp_server/bin/server.dart -o /app/server


# Stage 3: Slim runtime image
FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy AOT binary
COPY --from=server-build /app/server /app/server

# Copy Flutter web build output
COPY --from=web-build /build/packages/sp_web/build/web/ /app/public/

ENV PORT=8080
ENV WEB_ROOT=/app/public

EXPOSE 8080

ENTRYPOINT ["/app/server"]
