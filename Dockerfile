# Stage 1: Build the application
FROM alpine:3.21.3 AS builder

RUN apk update && apk --no-cache add libc-dev xz curl

ARG ZIG_VERSION=0.14.0

RUN curl -o zig.tar.xz "https://ziglang.org/download/${ZIG_VERSION}/zig-linux-$(uname -m)-${ZIG_VERSION}.tar.xz" && \
  mkdir -p /usr/local/zig && \
  tar -xf zig.tar.xz -C /usr/local/zig --strip-components=1 && \
  rm zig.tar.xz

ENV PATH="/usr/local/zig:${PATH}"
WORKDIR /app
COPY . .
RUN zig build

CMD ["/app/zig-out/bin/cryp_change_zig"]

# Stage 2: Run the application
# FROM alpine:3.21.3
# COPY --from=builder /app/zig-out/bin/cryp_change_zig .
# EXPOSE 5882
# CMD ["/cryp_change_zig"]
