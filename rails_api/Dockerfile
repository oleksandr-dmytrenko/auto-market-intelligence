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

# Copy dependency files
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test

# Copy application code
COPY . .

# Precompile assets (if using asset pipeline)
# RUN bundle exec rails assets:precompile

EXPOSE 3000

# Use Puma for production
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
