#!/usr/bin/env bash

# Script for running unit tests within a docker container.
# In most cases, you will not run this script directly, but instead
# use docker-compose to run using the unit-tests-compose.yml file in this directory. See instructions in that file.

set -e

export CI=true
export RAILS_ENV=test
export RACK_ENV=test
export DISABLE_SPRING=1
export LD_LIBRARY_PATH=/usr/local/lib

# set up locals.yml
echo "
build_apps: true
build_dashboard: true
build_i18n: true
build_pegasus: true
bundler_use_sudo: false
cloudfront_key_pair_id: $CLOUDFRONT_KEY_PAIR_ID
cloudfront_private_key: \"$CLOUDFRONT_PRIVATE_KEY\"
dashboard_db_reader: \"mysql://readonly@localhost/dashboard_test\"
dashboard_enable_pegasus: true
dashboard_workers: 5
disable_all_eyes_running: true
google_maps_api_key: boguskey
ignore_eyes_mismatches: true
localize_apps: true
optimize_rails_assets: false
optimize_webpack_assets: false
skip_seed_all: true
use_my_apps: true
" >> locals.yml
echo "Wrote secrets from env vars into locals.yml."

set -x

bundle install --quiet
bundle exec rake install
bundle exec rake build
bundle exec rake circle:run_tests
