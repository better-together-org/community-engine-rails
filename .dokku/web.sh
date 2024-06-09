# release.sh
#!/bin/bash
set -e

mkdir -p tmp/pids
bundle exec puma -C config/puma.rb
