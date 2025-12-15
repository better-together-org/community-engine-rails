# frozen_string_literal: true

require 'rails/generators/base'
require 'rails/generators/migration'

module BetterTogether
  module Generators
    # Generator for creating new invitation types
    #
    # Usage:
    #   rails generate better_together:invitation project
    #   rails generate better_together:invitation team --invitable-model=Organization
    #
    class InvitationGenerator < Rails::Generators::NamedBase # rubocop:todo Metrics/ClassLength
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      class_option :invitable_model, type: :string, default: nil,
                                     desc: 'The model that can be invited to (defaults to the invitation name)'
      class_option :skip_views, type: :boolean, default: false,
                                desc: 'Skip generating custom view templates'
      class_option :skip_migration, type: :boolean, default: false,
                                    desc: 'Skip generating database migration'

      def create_invitation_model
        template 'invitation_model.rb.erb', invitation_model_path
      end

      def create_invitation_mailer
        template 'invitation_mailer.rb.erb', invitation_mailer_path
      end

      def create_invitation_notifier
        template 'invitation_notifier.rb.erb', invitation_notifier_path
      end

      def create_invitation_policy
        template 'invitation_policy.rb.erb', invitation_policy_path
      end

      def create_factory
        template 'invitation_factory.rb.erb', invitation_factory_path
      end

      def create_model_spec
        template 'invitation_spec.rb.erb', invitation_spec_path
      end

      def create_mailer_spec
        template 'invitation_mailer_spec.rb.erb', invitation_mailer_spec_path
      end

      def create_policy_spec
        template 'invitation_policy_spec.rb.erb', invitation_policy_spec_path
      end

      def create_custom_views
        return if options[:skip_views]

        # Create view templates
        template 'invitation_views/index.html.erb', invitation_views_index_path
        template 'invitation_views/new.html.erb', invitation_views_new_path
        template 'invitation_views/_invitations_table.html.erb', invitation_views_table_path
        template 'invitation_views/create.turbo_stream.erb', invitation_views_create_turbo_path
        template 'invitation_views/resend.turbo_stream.erb', invitation_views_resend_turbo_path
      end

      def create_locale_files
        %w[en es fr].each do |locale|
          template "invitation_locales/#{locale}.yml.erb", invitation_locale_path(locale)
        end
      end

      def create_migration
        return if options[:skip_migration]

        # TODO: Fix Rails 8 migration_template API compatibility
        say 'Migration generation temporarily disabled due to Rails 8 API changes', :yellow
        # migration_template "invitation_migration.rb.erb", File.join("db/migrate", "create_better_together_#{invitation_name}_invitations.rb")
      end

      def update_invitable_model
        return unless File.exist?(invitable_model_path)

        inject_into_class invitable_model_path, invitable_model_class do
          "  include BetterTogether::Invitable\n"
        end
      rescue Thor::Error => e
        say "Could not update #{invitable_model_path}: #{e.message}", :yellow
      end

      def generate_routes
        route_content = <<~RUBY

          # #{invitation_name.humanize} invitation routes (generated)
          scope '/:locale', constraints: { locale: /\#{I18n.available_locales.join('|')}/ } do
            resources :#{invitation_name.pluralize} do
              resources :invitations, path: 'invitations', except: [:show, :edit, :update] do
                member do
                  put :resend
                end
              end
            end
          end
        RUBY

        insert_into_file 'config/routes.rb', route_content,
                         before: /^end\s*$/,
                         verbose: false
      end

      def show_readme
        show_success_message
        show_next_steps
        show_generated_files
        show_system_info
      end

      private

      def show_success_message
        say
        say "Invitation type '#{invitation_name}' has been generated successfully!", :green
        say
      end

      def show_next_steps
        say 'Next steps:'
        say '1. Review the generated files and customize as needed'
        say "2. Run 'rails db:migrate' to apply the database changes" unless options[:skip_migration]
        say "3. Update your #{invitable_model_name} model if it doesn't already include Invitable"
        say '4. Customize the generated policy for authorization rules'
        say '5. Test the invitation system with the unified controller'
        say
      end

      def show_generated_files
        say 'Generated files:'
        show_core_files
        show_view_files unless options[:skip_views]
        show_locale_and_migration_files
      end

      def show_core_files
        say "  Model: #{invitation_model_path}"
        say "  Mailer: #{invitation_mailer_path}"
        say "  Notifier: #{invitation_notifier_path}"
        say "  Policy: #{invitation_policy_path}"
        say "  Factory: #{invitation_factory_path}"
        say "  Specs: #{invitation_spec_path}, #{invitation_mailer_spec_path}, #{invitation_policy_spec_path}"
      end

      def show_view_files
        say "  Views: #{invitation_views_index_path}"
        say "         #{invitation_views_new_path}"
        say "         #{invitation_views_table_path}"
        say "         #{invitation_views_create_turbo_path}"
        say "         #{invitation_views_resend_turbo_path}"
      end

      def show_locale_and_migration_files
        say "  Locales: config/locales/#{invitation_name}_invitations.{en,es,fr}.yml"
        say "  Migration: #{invitation_migration_path}" unless options[:skip_migration]
      end

      def show_system_info
        say
        say 'The unified invitation system will automatically detect and handle'
        say "#{invitation_name} invitations using the existing InvitationsController."
        say
      end

      def invitation_name
        file_name.singularize
      end

      def invitation_class_name
        "#{module_name}::#{invitation_name.classify}Invitation"
      end

      def invitable_model_name
        options[:invitable_model] || invitation_name.classify
      end

      def invitable_model_class
        "#{module_name}::#{invitable_model_name}"
      end

      def module_name
        'BetterTogether'
      end

      def invitation_model_path
        "app/models/better_together/#{invitation_name}_invitation.rb"
      end

      def invitation_mailer_path
        "app/mailers/better_together/#{invitation_name}_invitations_mailer.rb"
      end

      def invitation_notifier_path
        "app/notifiers/better_together/#{invitation_name}_invitation_notifier.rb"
      end

      def invitation_policy_path
        "app/policies/better_together/#{invitation_name}_invitation_policy.rb"
      end

      def invitation_factory_path
        "spec/factories/better_together/#{invitation_name}_invitations.rb"
      end

      def invitation_spec_path
        "spec/models/better_together/#{invitation_name}_invitation_spec.rb"
      end

      def invitation_mailer_spec_path
        "spec/mailers/better_together/#{invitation_name}_invitations_mailer_spec.rb"
      end

      def invitation_policy_spec_path
        "spec/policies/better_together/#{invitation_name}_invitation_policy_spec.rb"
      end

      def invitation_row_view_path
        "app/views/better_together/shared/_#{invitation_name}_invitation_row.html.erb"
      end

      def invitation_views_index_path
        "app/views/better_together/#{invitation_name}_invitations/index.html.erb"
      end

      def invitation_views_new_path
        "app/views/better_together/#{invitation_name}_invitations/new.html.erb"
      end

      def invitation_views_table_path
        "app/views/better_together/#{invitation_name}_invitations/_invitations_table.html.erb"
      end

      def invitation_views_create_turbo_path
        "app/views/better_together/#{invitation_name}_invitations/create.turbo_stream.erb"
      end

      def invitation_views_resend_turbo_path
        "app/views/better_together/#{invitation_name}_invitations/resend.turbo_stream.erb"
      end

      def invitation_locale_path(locale)
        "config/locales/#{invitation_name}_invitations.#{locale}.yml"
      end

      def invitation_migration_path
        "db/migrate/#{migration_timestamp}_create_better_together_#{invitation_name}_invitations.rb"
      end

      def invitable_model_path
        "app/models/better_together/#{invitable_model_name.underscore}.rb"
      end

      def migration_timestamp
        Time.current.strftime('%Y%m%d%H%M%S')
      end

      # Required for Rails::Generators::Migration
      class << self
        private

        def next_migration_number(_dirname)
          Time.current.strftime('%Y%m%d%H%M%S')
        end
      end
    end
  end
end
