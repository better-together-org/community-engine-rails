# release.sh
#!/bin/bash
set -e

mkdir -p spec/dummy/tmp/pids
bash -c "rm -f spec/dummy/tmp/pids/server.pid && cd ./spec/dummy && bundle exec puma -C config/puma.rb"
