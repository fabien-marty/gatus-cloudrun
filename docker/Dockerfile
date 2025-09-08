# Builder image
FROM golang:1.24.7-bookworm AS builder
ARG GATUS_VERSION=v5.23.2
RUN go install github.com/TwiN/gatus/v5@${GATUS_VERSION}

# Runtime image
FROM debian:bookworm-slim AS runner

ENV APP_DIR=/app
ENV APP_USER=appuser

RUN mkdir -p ${APP_DIR}/data ${APP_DIR}/config ${APP_DIR}/bin

COPY --from=builder /go/bin/gatus ${APP_DIR}/bin/gatus

RUN apt-get update && apt-get -y upgrade && \
    apt-get -y install curl gnupg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \ 
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    apt-get update && \
    apt-get install -y sqlite3 google-cloud-cli yamllint && \ 
    apt-get clean

RUN useradd -r -d ${APP_DIR} -s /bin/bash ${APP_USER} && \
    chown -R ${APP_USER} ${APP_DIR}
USER ${APP_USER}
WORKDIR ${APP_DIR}

COPY bin/ ${APP_DIR}/bin/
ADD entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
