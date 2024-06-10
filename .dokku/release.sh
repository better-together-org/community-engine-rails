#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Ensure Sentry CLI is installed
if ! command -v sentry-cli &> /dev/null
then
    echo "sentry-cli could not be found, please install it."
    exit 1
fi

# Set the release version
RELEASE_VERSION=$(git rev-parse --short HEAD)

# Export the release version as an environment variable
export SENTRY_RELEASE=$RELEASE_VERSION

# Notify Sentry of the new release
sentry-cli releases new $SENTRY_RELEASE
sentry-cli releases finalize $SENTRY_RELEASE

echo "Sentry release $SENTRY_RELEASE has been set."

# Run any pending migrations (if needed)
bundle exec rails db:migrate

echo "Release step completed."
