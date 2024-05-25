
FROM ruby:3.2

RUN apt-get update -qq \
  && apt-get install -y build-essential postgresql-client libpq-dev nodejs libssl-dev apt-transport-https ca-certificates libvips42

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update -qq && apt-get install -y yarn

RUN mkdir /community-engine
WORKDIR /community-engine
COPY Gemfile /community-engine/Gemfile
COPY Gemfile.lock /community-engine/Gemfile.lock

RUN gem uninstall bundler
RUN gem install bundler:2.4.13

COPY . /community-engine
