FROM ruby:3.2-alpine

RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    git \
    nodejs \
    yarn \
    tzdata \
    yaml-dev \
    bash

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000

CMD ["bundle", "exec", "rails", "s", "-b", "0.0.0.0"]
