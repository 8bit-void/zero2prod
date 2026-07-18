# Chef stage
# latest cargo-chef + Rust stable release as base image
FROM lukemathwalker/cargo-chef:latest-rust-1.97.0 AS chef
# switch workdir to `app`, same as `cd app`
# creates a new directory with the name if it does not exist
WORKDIR /app
# install required dependencies for linking config to work
RUN apt update && apt install lld clang -y

# Planner stage
FROM chef AS planner
# copy all files from out work dir to our docker image /app dir
COPY . .
# Compute a lock-like file for project
RUN cargo chef prepare --recipe-path recipe.json

# Builder stage
FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json
# Build project dependencies, not the app
RUN cargo chef cook --release --recipe-path recipe.json
# Up to this point, if our dependency tree stays the same,
# all layers should be cached
COPY . .
# use cached sqlx queries
ENV SQLX_OFFLINE=true
# build in release mode
RUN cargo build --release --bin zero2prod

# Runtime stage
FROM debian:bookworm-slim AS runtime
WORKDIR /app
# Install OpenSSL - its dynamically linked by some of our dependencies
# Install ca-certificates - needed to verify TLS certs when establishing
# HTTPS connections
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends openssl ca-certificates \
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*
    # Copy compiled binary from builder environment
# to the runtime environment
COPY --from=builder /app/target/release/zero2prod zero2prod
# copy the config file for runtime read
COPY configuration configuration
# load production config (0.0.0.0)
ENV APP_ENVIRONMENT=production
# when `docker run` is executed, launch the binary
ENTRYPOINT ["./zero2prod"]
