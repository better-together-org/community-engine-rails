# frozen_string_literal: true

# Paths excluded from coverage. Shared by spec/spec_helper.rb (SimpleCov.start in every worker) and
# bin/ci-collate-coverage (which merges the CI shards' results), so the merged figure matches what
# a single run reports.
SIMPLECOV_FILTERS = %w[
  /app/assets
  /app/javascript
  /app/views
  /bin/
  /config/
  /coverage/
  /db/
  /deploy/
  /docker/
  /docs/
  /log/
  /node_modules/
  /public/
  /script/
  /scripts/
  /spec/
  /swagger/
  /tmp/
  /vendor/
].freeze
