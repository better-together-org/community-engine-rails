# Stage 1: Build environment
FROM ruby:3.2.2 AS builder

# Define build-time variables
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ARG FOG_DIRECTORY
ARG FOG_HOST
ARG FOG_REGION
ARG ASSET_HOST
ARG CDN_DISTRIBUTION_ID

# Set environment variables for asset precompilation
ENV AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
ENV AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
ENV FOG_DIRECTORY=${FOG_DIRECTORY}
ENV FOG_HOST=${FOG_HOST}
ENV FOG_REGION=${FOG_REGION}
ENV ASSET_HOST=${ASSET_HOST}
ENV CDN_DISTRIBUTION_ID=${CDN_DISTRIBUTION_ID}

# Install dependencies
RUN apt-get update -qq \
  && apt-get install -y --no-install-recommends \
    build-essential \
    postgresql-client \
    libpq-dev \
    nodejs \
    libssl-dev \
    apt-transport-https \
    ca-certificates \
    libvips42 \
    curl

# Set working directory
WORKDIR /community-engine

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install bundler and gems
RUN gem uninstall bundler \
  && gem install bundler:2.4.13 \
  && bundle install --jobs 4 --retry 3

# Copy the rest of the application code
COPY . .

# Precompile assets and sync to S3
RUN bundle exec rake assets:precompile

# Stage 2: Runtime environment
FROM ruby:3.2.2

# Install runtime dependencies
RUN apt-get update -qq \
  && apt-get install -y --no-install-recommends \
    libpq-dev \
    nodejs \
    libssl-dev \
    libvips42 \
    curl \
  && curl -sL https://sentry.io/get-cli/ | bash \
  && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /community-engine

# Copy the application code from the build stage
COPY --from=builder /community-engine /community-engine

# Create and set permissions for tmp/pids directory
RUN mkdir -p tmp/pids
RUN chmod -R 755 tmp

# Set environment variables
ENV RAILS_ENV=production
ENV RACK_ENV=production

# Run the application
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
