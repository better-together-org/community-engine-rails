
FROM ruby:2.6.5

RUN apt-get update -qq \
  && apt-get install -y build-essential postgresql-client libpq-dev nodejs libssl-dev apt-transport-https ca-certificates

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update -qq && apt-get install -y yarn

RUN mkdir /btc
WORKDIR /btc
COPY Gemfile /btc/Gemfile
COPY Gemfile.lock /btc/Gemfile.lock

RUN gem uninstall bundler
RUN gem install bundler:2.0.2

COPY . /btc
