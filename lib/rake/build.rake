require_relative '../../deployment'
require 'cdo/chat_client'
require 'cdo/rake_utils'
require 'cdo/git_utils'
require lib_dir 'cdo/data/logging/rake_task_event_logger'
require 'dynamic_config/dcdo'

include TimedTaskWithLogging

namespace :build do
  desc 'Builds apps.'
  timed_task_with_logging :apps do
    Dir.chdir(apps_dir) do
      # Only rebuild if any of the apps_build_trigger_paths have changed since last build.
      commit_hash = apps_dir('build/commit_hash')
      if !RakeUtils.git_staged_changes?(*apps_build_trigger_paths) &&
          File.exist?(commit_hash) &&
          File.read(commit_hash) == calculate_apps_commit_hash

        ChatClient.log '<b>apps</b> unchanged since last build, skipping.'
        next
      end

      ChatClient.log 'Installing <b>apps</b> dependencies...'
      RakeUtils.yarn_install

      ChatClient.log 'Building <b>apps</b>...'
      npm_target = CDO.optimize_webpack_assets ? 'build:dist' : 'build'
      RakeUtils.system "npm run #{npm_target}"
      File.write(commit_hash, calculate_apps_commit_hash)

      if rack_env?(:staging) && DCDO.get('deploy_storybook', false)
        ChatClient.log 'Deploying <b>storybook</b>...'
        RakeUtils.system 'npm run storybook:deploy'
      end
    end
  end

  desc 'Builds broken link checker.'
  timed_task_with_logging :tools do
    Dir.chdir(File.join(tools_dir, "scripts", "brokenLinkChecker")) do
      ChatClient.log 'Installing <b>broken link checker</b> dependencies...'
      RakeUtils.yarn_install
    end
  end

  desc 'Builds dashboard (install gems, migrate/seed db, compile assets).'
  timed_task_with_logging dashboard: :package do
    Dir.chdir(dashboard_dir) do
      # Unless on production, serve UI test directory
      unless rack_env?(:production)
        RakeUtils.ln_s('../test/ui', dashboard_dir('public', 'ui_test'))
      end

      ChatClient.log 'Installing <b>dashboard</b> bundle...'
      RakeUtils.bundle_install

      if CDO.daemon
        ChatClient.log 'Migrating <b>dashboard</b> database...'
        RakeUtils.rake 'db:setup_or_migrate'

        # Update the schema cache file, except for production which always uses the cache.
        unless rack_env?(:production)
          schema_cache_file = dashboard_dir('db/schema_cache.yml')
          RakeUtils.rake 'db:schema:cache:dump'
          # NOTE: Temporarily commenting the `else` check below (and ignoring
          # Rubocop's suggestion to combine the conditionals) because the dump
          # is consistently generating non-matching files that are functionally
          # equivalent.
          # rubocop:disable Style/SoleNestedConditional
          if GitUtils.file_changed_from_git?(schema_cache_file)
            # Staging is responsible for committing the authoritative schema cache dump.
            if rack_env?(:staging)
              RakeUtils.system 'git', 'add', schema_cache_file
              ChatClient.log "Committing updated #{schema_cache_file} file...", color: 'purple'
              RakeUtils.system 'git', 'commit', '-m', '"Update schema cache dump after schema changes."', schema_cache_file
              RakeUtils.git_push
              # The schema dump from the test database should always match that generated by staging.
              # elsif rack_env?(:test) && GitUtils.current_branch == 'test' && !ENV['CI']
              # raise 'Unexpected database schema difference between staging and test. (Another DTT usually resolves- see https://docs.google.com/document/d/114KxAdupbPKdhrMTX8DAEhD42Z12Gb95iGorF8Ysp28/edit)'
            end
          end
          # rubocop:enable Style/SoleNestedConditional
        end

        # Allow developers to skip the time-consuming step of seeding the dashboard DB.
        # Additionally allow skipping when running in CircleCI, as it will be seeded during `rake install`
        if (rack_env?(:development) || ENV['CI']) && CDO.skip_seed_all
          ChatClient.log "Not seeding <b>dashboard</b> due to CDO.skip_seed_all...\n" \
              "Until you manually run 'rake seed:all' or disable this flag, you won't\n" \
              "see changes to: videos, concepts, levels, scripts, prize providers, \n " \
              "callouts, hints, secret words, or secret pictures."
        else
          ChatClient.log 'Seeding <b>dashboard</b>...'
          ChatClient.log 'consider setting "skip_seed_all" in locals.yml if this is taking too long' if rack_env?(:development)
          RakeUtils.rake_stream_output 'seed:default', (rack_env?(:test) ? '--trace' : nil)
        end

        # Restart Active Job workers before restarting dashboard server so that:
        # 1. the order of the restarts will be consistent between production and
        # other environments, and
        # 2. the server code which is queueing new jobs does not need to be
        # backward compatible (although the job code itself still does).
        #
        # When making breaking changes to a job's api contract, the best
        # practice is to update the job (in a backward compatible manner) in a
        # first deploy, then update the code which calls it in a separate
        # deploy, similarly to how we sequence deploys with database migrations
        # or seeding changes.
        #
        # The sequencing described here is the best for mitigating any issues
        # that may arise when that best practice is not followed.
        ChatClient.log 'Restarting <b>dashboard</b> Active Job worker(s).'
        if rack_env?(:production)
          # WARNING: the number of workers in production is safe to increase,
          # but is not safe to lower without additional steps. specifically, if
          # you lower the number of jobs from 10 to 8 (for example), you'll need
          # to manually kill workers 8 and 9 (zero-based). otherwise, those
          # workers will continue to run jobs using older code indefinitely.
          RakeUtils.system 'bin/delayed_job', '-n', '10', 'restart'
        elsif !rack_env?(:development)
          # development environment does not use delayed_job by default.
          # all other non-production daemons should run one worker.
          RakeUtils.system 'bin/delayed_job', 'restart'
        end

        # Commit dsls.en.yml changes on staging
        dsls_file = dashboard_dir('config/locales/dsls.en.yml')
        if rack_env?(:staging) && GitUtils.file_changed_from_git?(dsls_file)
          RakeUtils.system 'git', 'add', dsls_file
          ChatClient.log 'Committing updated dsls.en.yml file...', color: 'purple'
          RakeUtils.system 'git', 'commit', '-m', '"Update dsls.en.yml"', dsls_file
          RakeUtils.git_push
        end

        # if rack_env?(:staging)
        #  This step will only complete successfully if we succeed in
        #  generating all curriculum PDFs.
        #  ChatClient.log "Generating missing pdfs..."
        #  RakeUtils.rake_stream_output 'curriculum_pdfs:generate_missing_pdfs'
        # end
      end

      # Skip asset precompile in development.
      if CDO.optimize_rails_assets
        # If we did not optimize webpack assets, then rails asset precompilation
        # will add digests to the names of webpack assets, after which webpack
        # will be unable to find them.
        raise "do not optimize rails assets without optimized webpack assets" unless CDO.optimize_webpack_assets

        ChatClient.log 'Cleaning <b>dashboard</b> assets...'
        RakeUtils.rake 'assets:clean'
        ChatClient.log 'Precompiling <b>dashboard</b> assets...'
        RakeUtils.rake 'assets:precompile', '--quiet'
      end

      ChatClient.log 'Restarting <b>dashboard</b> web server.'
      RakeUtils.restart_service CDO.dashboard_web_server_name unless rack_env?(:development)

      if rack_env?(:production)
        RakeUtils.rake "honeybadger:deploy TO=#{rack_env} REVISION=`git rev-parse HEAD`"
      end
    end
  end

  desc 'Builds pegasus (install gems, migrate/seed db).'
  timed_task_with_logging :pegasus do
    Dir.chdir(pegasus_dir) do
      ChatClient.log 'Installing <b>pegasus</b> bundle...'
      RakeUtils.bundle_install
      if CDO.daemon
        ChatClient.log 'Updating <b>pegasus</b> database...'
        begin
          RakeUtils.rake_stream_output 'pegasus:setup_db', (rack_env?(:test) ? '--trace' : nil)
        rescue => exception
          ChatClient.log "/quote #{exception.message}\n#{CDO.backtrace exception}", message_format: 'text'
          raise exception
        end
      end

      ChatClient.log 'Restarting <b>pegasus</b> web server.'
      RakeUtils.restart_service CDO.pegasus_web_server_name unless rack_env?(:development)
    end
  end

  desc 'Builds i18n'
  timed_task_with_logging :i18n do
    Dir.chdir(bin_dir('i18n')) do
      ChatClient.log 'Installing <b>i18n</b> dependencies...'
      RakeUtils.npm_install
    end
  end

  tasks = []
  tasks << :apps if CDO.build_apps
  tasks << :dashboard if CDO.build_dashboard
  tasks << :pegasus if CDO.build_pegasus
  tasks << :tools if rack_env?(:staging)
  tasks << :i18n if CDO.build_i18n
  timed_task_with_logging all: tasks
end

desc 'Builds everything.'
timed_task_with_logging :build do
  ChatClient.wrap('build') {Rake::Task['build:all'].invoke}
end

# List of paths that, if changed, should trigger an apps build.
# This contains the apps source itself and any other dependency that affects the apps build,
# e.g. shared constants (which generate js apps code during apps/script/generateSharedConstants)
def apps_build_trigger_paths
  [
    apps_dir,
    shared_constants_file,
    shared_constants_dir
  ]
end

def calculate_apps_commit_hash
  RakeUtils.git_folder_hash(*apps_build_trigger_paths)
end
