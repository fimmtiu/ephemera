# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.3.8
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /app

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    curl \
    cron \
    git \
    libffi-dev \
    libjemalloc2 \
    libsqlite3-dev \
    libvips \
    libyaml-dev \
    nginx \
    certbot \
    python3-certbot-nginx \
    libimage-exiftool-perl \
    pkg-config \
    sqlite3 \
    gettext-base && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
    TZ="America/Los_Angeles"

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY . .

RUN bundle exec bootsnap precompile --gemfile && \
    bundle exec bootsnap precompile app/ lib/

RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

COPY config/crontab /etc/cron.d/ephemera
RUN chmod 0644 /etc/cron.d/ephemera && crontab /etc/cron.d/ephemera

RUN mkdir -p /var/log && \
    touch /var/log/postpic.log /var/log/certbot.log && \
    mkdir -p db tmp/pids tmp/cache tmp/sockets log

EXPOSE 80 443

CMD ["/app/bin/start.sh"]
