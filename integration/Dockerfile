# Integration harness: build the yup-hexdump binary for Linux, then run it inside a
# Debian image (GNU coreutils) so its flags, inputs, and outputs can be checked
# against the real `hexdump` reference. Invoked by `make integration`.
FROM golang:1.26 AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -o /out/yup-hexdump .

FROM debian:stable-slim
# hexdump is not in coreutils; it ships in util-linux's bsdextrautils package.
RUN apt-get update && apt-get install -y --no-install-recommends bsdextrautils && rm -rf /var/lib/apt/lists/*
COPY --from=build /out/yup-hexdump /usr/local/bin/yup-hexdump
COPY integration/run.sh /run.sh
ENTRYPOINT ["/bin/sh", "/run.sh"]
