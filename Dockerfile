FROM ruby:2.5
RUN apt-get update -qq && apt-get install -y build-essential nodejs postgresql-client libssl-dev
RUN mkdir /better_together-core
WORKDIR /better_together-core
COPY . /better_together-core

# RUN gem install bundler
# RUN gem install nokogiri
# RUN gem install mini_racer -v '0.1.15'

# Use a persistent volume for the gems installed by the bundler
ENV BUNDLE_GEMFILE=/better_together-core/Gemfile \
  BUNDLE_JOBS=2 \
  BUNDLE_PATH=/bundler \
  GEM_PATH=/bundler \
  GEM_HOME=/bundler
RUN bundle install

# Add a script to be executed every time the container starts.
#COPY entrypoint.sh /usr/bin/
#RUN chmod +x /usr/bin/entrypoint.sh
#NTRYPOINT ["entrypoint.sh"]
#EXPOSE 3000

# Start the main process.
#CMD ["rails", "server", "-b", "0.0.0.0"]
