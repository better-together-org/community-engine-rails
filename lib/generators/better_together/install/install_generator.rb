# frozen_string_literal: true

module BetterTogether
  # Host app installer: initializer, routes, storage, hosts, generators, assets, theme and CI checks.
  class InstallGenerator < Rails::Generators::Base
    MOUNT_LINE = "mount BetterTogether::Engine => '/'"
    STORAGE_MARKER = 's3_compatible:'
    GENERATORS_MARKER = 'BetterTogether install: generators'

    desc 'Installs the Community Engine inside your app: initializer, routes mount, storage,
    hosts, CSP/head-tag hooks, theme stubs, generator defaults, manifest.js and a CI check.'

    source_root File.expand_path('templates', __dir__)

    class_option :migrations, type: :string, default: 'gem', enum: %w[gem install],
                              desc: 'gem runs the engine migrations in place; install copies them into db/migrate'
    class_option :skip_routes, type: :boolean, default: false, desc: 'Do not mount the engine in config/routes.rb'
    class_option :skip_storage, type: :boolean, default: false, desc: 'Do not add the s3_compatible storage service'
    class_option :skip_assets, type: :boolean, default: false, desc: 'Do not touch manifest.js or theme stubs'
    class_option :skip_generators, type: :boolean, default: false,
                                   desc: 'Do not set uuid/rspec/factory_bot generator defaults'
    class_option :skip_ci_check, type: :boolean, default: false, desc: 'Do not create bin/check-engine-migrations'

    def create_initializer_file
      template 'initializer.rb.tt', 'config/initializers/better_together.rb'
    end

    def mount_engine
      return if options[:skip_routes] || !File.exist?(destination_path('config/routes.rb'))
      return if File.read(destination_path('config/routes.rb')).include?('BetterTogether::Engine')

      route MOUNT_LINE
    end

    def add_storage_service
      return if options[:skip_storage] || !File.exist?(destination_path('config/storage.yml'))
      return if File.read(destination_path('config/storage.yml')).include?(STORAGE_MARKER)

      append_to_file 'config/storage.yml', "\n#{File.read(find_in_source_paths('storage_s3_compatible.yml'))}"
    end

    def configure_hosts
      create_file 'config/initializers/better_together_hosts.rb', File.read(find_in_source_paths('hosts.rb')),
                  skip: true
    end

    def configure_head_tag_provider
      create_file 'config/initializers/better_together_head_tags.rb', File.read(find_in_source_paths('head_tags.rb')),
                  skip: true
    end

    def configure_generators
      return if options[:skip_generators]
      return if File.read(destination_path('config/application.rb')).include?(GENERATORS_MARKER)

      inject_into_file 'config/application.rb', File.read(find_in_source_paths('generators.txt')),
                       after: /class Application < Rails::Application\n/
    rescue Errno::ENOENT
      say_status :skip, 'config/application.rb not found, add the generator defaults by hand', :yellow
    end

    def configure_assets
      return if options[:skip_assets]

      add_manifest_links
      create_file 'app/assets/stylesheets/host_theme.scss', File.read(find_in_source_paths('theme.scss')),
                  skip: true
    end

    def create_ci_check
      return if options[:skip_ci_check]

      copy_file 'check-engine-migrations', 'bin/check-engine-migrations'
      chmod 'bin/check-engine-migrations', 0o755
    end

    def print_next_steps
      say "\nNext steps (#{options[:migrations]} migrations):", :green
      say migration_instructions
      say 'Postgres needs the postgis adapter (adapter: postgis) in config/database.yml.'
      say 'Remove propshaft if present: this engine requires sprockets (see docs/developers/host_app_migrations_from_gem.md).'
      say 'Production server setup lives in bin/prod/host-setup.sh (see the host-setup docs).'
    end

    private

    def destination_path(path)
      File.join(destination_root, path)
    end

    def add_manifest_links
      manifest = 'app/assets/config/manifest.js'
      links = File.read(find_in_source_paths('manifest.js'))
      if File.exist?(destination_path(manifest))
        missing = links.lines.reject { |l| File.read(destination_path(manifest)).include?(l.strip) }
        append_to_file manifest, missing.join unless missing.empty?
      else
        create_file manifest, links
      end
    end

    def migration_instructions
      return "  bin/rails better_together:install:migrations && bin/rails db:migrate\n" unless options[:migrations] == 'gem'

      "  bin/rails db:create db:migrate   # engine migrations run from the gem, nothing is copied\n  " \
        "bin/check-engine-migrations      # CI guard: fails if db/migrate/*.better_together.rb appears\n"
    end
  end
end
