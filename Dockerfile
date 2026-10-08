FROM swift:6.2-bookworm

WORKDIR /code
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && apt-get -q update && \
    apt-get -q install -y \
    openssl libssl-dev
COPY Package.swift /code/.
RUN swift package resolve
COPY ./Sources /code/Sources
COPY ./Tests /code/Tests

RUN swift build