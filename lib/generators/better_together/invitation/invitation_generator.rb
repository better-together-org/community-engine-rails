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
    # Namespace behavior:
    #   - In engine: Defaults to BetterTogether namespace
    #   - In host app: Defaults to no namespace (root level)
    #   - Override with: --namespace=MyApp or --namespace="" for explicit control
    #
    # Namespace options:
    #   rails generate better_together:invitation project --namespace=MyApp
    #   rails generate better_together:invitation project --namespace=BetterTogether
    #   rails generate better_together:invitation project --namespace=""  # No namespace
    #
    class InvitationGenerator < Rails::Generators::NamedBase # rubocop:todo Metrics/ClassLength
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      class_option :invitable_model, type: :string, default: nil,
                                     desc: 'The model that can be invited to (defaults to the invitation name)'
      class_option :namespace, type: :string, default: nil,
                               desc: 'The namespace for generated models (defaults to BetterTogether in engine, empty in host app)'
      class_option :skip_views, type: :boolean, default: false,
                                desc: 'Skip generating custom view templates'
      class_option :with_migration, type: :boolean, default: false,
                                    desc: 'Generate a migration for a separate table (not typically needed - invitations use STI)'

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

      def setup_database_table
        if options[:with_migration]
          migration_file_name = "create_#{table_name_prefix}#{invitation_name}_invitations.rb"
          migration_template 'invitation_migration.rb.erb',
                             "db/migrate/#{migration_file_name}"

          say_status :warning, 'Migration generated for separate table (non-STI approach)', :yellow
          say '  By default, invitations use Single Table Inheritance with the shared better_together_invitations table.', :yellow
          say '  You have chosen to generate a separate table migration.', :yellow
          say '  Make sure to update your model to NOT inherit from BetterTogether::Invitation if using a separate table.', :yellow
        else
          say_status :skip, 'Migration (using STI with shared better_together_invitations table)', :yellow
          say '  To generate a separate table migration, use: --with-migration', :yellow
        end
      end

      def update_invitable_model
        return unless File.exist?(invitable_model_path)

        inject_into_class invitable_model_path, invitable_model_class do
          "  include BetterTogether::Invitable\n"
        end
      rescue Thor::Error => e
        say "Could not update #{invitable_model_path}: #{e.message}", :yellow
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      def generate_routes
        routes_file_path = File.join(destination_root, 'config/routes.rb')
        return unless File.exist?(routes_file_path)

        routes_content = File.read(routes_file_path)

        if invitable_resource_exists?(routes_content)
          inject_invitations_into_existing_resource(routes_content, routes_file_path)
        else
          create_new_invitable_resource_with_invitations(routes_file_path)
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      def show_readme
        show_success_message
        show_next_steps
        show_generated_files
        show_system_info
      end

      # Required for Rails::Generators::Migration
      def self.next_migration_number(_dirname)
        Time.current.strftime('%Y%m%d%H%M%S')
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
        if options[:with_migration]
          say "2. Run 'rails db:migrate' to create the separate #{invitation_name}_invitations table"
          say "   NOTE: Using a separate table instead of STI - ensure your model doesn't inherit from Invitation"
        else
          say '2. Ensure your model inherits from BetterTogether::Invitation (uses STI with shared table)'
        end
        say "3. Update your #{invitable_model_name} model to include BetterTogether::Invitable"
        say '4. Customize the generated policy for authorization rules'
        say '5. Add translations for any custom messaging'
        say '6. Test the invitation system with the unified InvitationsController'
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
        say "  Migration: #{invitation_migration_path}" if options[:with_migration]
      end

      def show_system_info
        say
        show_namespace_info
        if options[:with_migration]
          say 'NOTE: You requested a separate table migration.'
          say "The #{table_name_prefix}#{invitation_name}_invitations table will be created separately."
          say 'Your model should NOT inherit from BetterTogether::Invitation in this case.'
        else
          say 'NOTE: Invitations use Single Table Inheritance (STI) by default.'
          say "Your #{invitation_class_name} will use the existing better_together_invitations table."
          say "The unified InvitationsController will automatically handle #{invitation_name} invitations."
        end
        say
      end

      def show_namespace_info
        if namespaced?
          say "Namespace: #{module_name}"
          say "Files generated under: #{namespace_path}/"
        else
          say 'Namespace: None (root level)'
          say 'Files generated at root app/ level'
        end
      end

      def invitation_name
        file_name.singularize
      end

      def invitation_class_name
        if namespaced?
          "#{module_name}::#{invitation_name.classify}Invitation"
        else
          "#{invitation_name.classify}Invitation"
        end
      end

      def invitable_model_name
        options[:invitable_model] || invitation_name.classify
      end

      def invitable_model_class
        if namespaced?
          "#{module_name}::#{invitable_model_name}"
        else
          invitable_model_name
        end
      end

      def module_name
        # Use explicit namespace if provided, otherwise use context-aware default
        return options[:namespace] if options[:namespace].present?

        # Default to BetterTogether when running inside the engine itself
        # Default to no namespace when running in a host app
        running_in_engine? ? 'BetterTogether' : nil
      end

      def running_in_engine?
        # Check if we're running inside the engine's own directory structure
        # by looking for the engine's gemspec file
        Dir.exist?(File.join(destination_root, 'app', 'models', 'better_together'))
      end

      def namespaced?
        module_name.present?
      end

      def namespace_path
        module_name&.underscore || ''
      end

      def table_name_prefix
        namespace_path.present? ? "#{namespace_path}_" : ''
      end

      def invitation_model_path
        if namespaced?
          "app/models/#{namespace_path}/#{invitation_name}_invitation.rb"
        else
          "app/models/#{invitation_name}_invitation.rb"
        end
      end

      def invitation_mailer_path
        if namespaced?
          "app/mailers/#{namespace_path}/#{invitation_name}_invitations_mailer.rb"
        else
          "app/mailers/#{invitation_name}_invitations_mailer.rb"
        end
      end

      def invitation_notifier_path
        if namespaced?
          "app/notifiers/#{namespace_path}/#{invitation_name}_invitation_notifier.rb"
        else
          "app/notifiers/#{invitation_name}_invitation_notifier.rb"
        end
      end

      def invitation_policy_path
        if namespaced?
          "app/policies/#{namespace_path}/#{invitation_name}_invitation_policy.rb"
        else
          "app/policies/#{invitation_name}_invitation_policy.rb"
        end
      end

      def invitation_factory_path
        if namespaced?
          "spec/factories/#{namespace_path}/#{invitation_name}_invitations.rb"
        else
          "spec/factories/#{invitation_name}_invitations.rb"
        end
      end

      def invitation_spec_path
        if namespaced?
          "spec/models/#{namespace_path}/#{invitation_name}_invitation_spec.rb"
        else
          "spec/models/#{invitation_name}_invitation_spec.rb"
        end
      end

      def invitation_mailer_spec_path
        if namespaced?
          "spec/mailers/#{namespace_path}/#{invitation_name}_invitations_mailer_spec.rb"
        else
          "spec/mailers/#{invitation_name}_invitations_mailer_spec.rb"
        end
      end

      def invitation_policy_spec_path
        if namespaced?
          "spec/policies/#{namespace_path}/#{invitation_name}_invitation_policy_spec.rb"
        else
          "spec/policies/#{invitation_name}_invitation_policy_spec.rb"
        end
      end

      def invitation_row_view_path
        if namespaced?
          "app/views/#{namespace_path}/shared/_#{invitation_name}_invitation_row.html.erb"
        else
          "app/views/shared/_#{invitation_name}_invitation_row.html.erb"
        end
      end

      def invitation_views_index_path
        if namespaced?
          "app/views/#{namespace_path}/#{invitation_name}_invitations/index.html.erb"
        else
          "app/views/#{invitation_name}_invitations/index.html.erb"
        end
      end

      def invitation_views_new_path
        if namespaced?
          "app/views/#{namespace_path}/#{invitation_name}_invitations/new.html.erb"
        else
          "app/views/#{invitation_name}_invitations/new.html.erb"
        end
      end

      def invitation_views_table_path
        if namespaced?
          "app/views/#{namespace_path}/#{invitation_name}_invitations/_invitations_table.html.erb"
        else
          "app/views/#{invitation_name}_invitations/_invitations_table.html.erb"
        end
      end

      def invitation_views_create_turbo_path
        if namespaced?
          "app/views/#{namespace_path}/#{invitation_name}_invitations/create.turbo_stream.erb"
        else
          "app/views/#{invitation_name}_invitations/create.turbo_stream.erb"
        end
      end

      def invitation_views_resend_turbo_path
        if namespaced?
          "app/views/#{namespace_path}/#{invitation_name}_invitations/resend.turbo_stream.erb"
        else
          "app/views/#{invitation_name}_invitations/resend.turbo_stream.erb"
        end
      end

      def invitation_locale_path(locale)
        "config/locales/#{invitation_name}_invitations.#{locale}.yml"
      end

      def invitation_migration_path
        "db/migrate/#{migration_timestamp}_create_#{table_name_prefix}#{invitation_name}_invitations.rb"
      end

      def invitable_model_path
        if namespaced?
          "app/models/#{namespace_path}/#{invitable_model_name.underscore}.rb"
        else
          "app/models/#{invitable_model_name.underscore}.rb"
        end
      end

      def migration_timestamp
        Time.current.strftime('%Y%m%d%H%M%S')
      end

      # Routes generation helper methods
      def invitable_resource_exists?(routes_content)
        # Check if resources :<invitable_name> already exists in routes
        routes_content.match?(/resources\s+:#{Regexp.escape(invitation_name.pluralize)}\b/)
      end

      def invitations_already_nested?(routes_content)
        # Check if invitations are already nested in the invitable resource
        # Look for pattern: resources :invitables do ... resources :invitations
        resource_block = extract_resource_block(routes_content)
        return false unless resource_block

        resource_block.match?(/resources\s+:invitations/)
      end

      def extract_resource_block(routes_content)
        # Extract the block for resources :<invitable_name>
        pattern = /resources\s+:#{Regexp.escape(invitation_name.pluralize)}.*?do\s*(?:\|[^|]*\|)?\s*(.*?)^\s*end/m
        match = routes_content.match(pattern)
        match ? match[1] : nil
      end

      def inject_invitations_into_existing_resource(routes_content, routes_file_path)
        if invitations_already_nested?(routes_content)
          say "Invitations already nested in #{invitation_name.pluralize} resource. Skipping route generation.", :yellow
          return
        end

        invitation_routes = invitation_nested_routes_content
        content = File.read(routes_file_path)

        # Check if resource has a block or is a single-line definition
        if resource_has_block?(routes_content)
          # Inject into existing block
          inject_into_resource_block(content, invitation_routes, routes_file_path)
        else
          # Convert single-line resource to block and inject
          convert_resource_to_block_and_inject(content, invitation_routes, routes_file_path)
        end
      end

      def resource_has_block?(routes_content)
        # Check if resources :invitable has a do...end block
        routes_content.match?(/resources\s+:#{Regexp.escape(invitation_name.pluralize)}.*?do/)
      end

      def inject_into_resource_block(content, invitation_routes, routes_file_path)
        # Find the resources :invitable block and inject invitations before the closing 'end'
        pattern = /(resources\s+:#{Regexp.escape(invitation_name.pluralize)}.*?do(?:\s*\|[^|]*\|)?\s*)(.*?)(^\s*end)/m

        new_content = content.sub(pattern) do |_match|
          opening = ::Regexp.last_match(1)
          body = ::Regexp.last_match(2)
          closing = ::Regexp.last_match(3)

          # Add invitations routes before the closing 'end'
          "#{opening}#{body}#{invitation_routes}#{closing}"
        end

        if new_content == content
          say "Could not inject invitations routes into #{invitation_name.pluralize} resource", :red
        else
          File.write(routes_file_path, new_content)
          say "Added invitations routes to existing #{invitation_name.pluralize} resource", :green
        end
      end

      def convert_resource_to_block_and_inject(content, invitation_routes, routes_file_path)
        # Match single-line resource definition and convert to block
        # Pattern matches: resources :projects, only: %i[...] or resources :projects
        pattern = /(\s*)(resources\s+:#{Regexp.escape(invitation_name.pluralize)})([^\n]*?)$/m

        new_content = content.sub(pattern) do |_match|
          indent = ::Regexp.last_match(1)
          resource_line = ::Regexp.last_match(2)
          options = ::Regexp.last_match(3)

          # Convert to block format
          "#{indent}#{resource_line}#{options} do\n#{invitation_routes.gsub(/^/, "#{indent}  ")}#{indent}end"
        end

        if new_content == content
          say "Could not inject invitations routes into #{invitation_name.pluralize} resource", :red
        else
          File.write(routes_file_path, new_content)
          say "Converted #{invitation_name.pluralize} resource to block and added invitations routes", :green
        end
      end

      def create_new_invitable_resource_with_invitations(routes_file_path)
        # Find the authenticated :user block and inject new resource
        route_content = <<~RUBY

            # #{invitation_name.humanize} invitations (generated)
            resources :#{invitation_name.pluralize} do
          #{invitation_nested_routes_content.gsub(/^/, '    ')}  end
        RUBY

        # Try to insert into authenticated :user block
        if authenticated_block_injection_successful?(route_content, routes_file_path)
          say "Added new #{invitation_name.pluralize} resource with invitations routes", :green
        else
          # Fallback: insert before final 'end' in locale scope
          content = File.read(routes_file_path)
          new_content = content.sub(/^(\s*end\s*(?:# locale scope)?)\s*$/m, "#{route_content}\\1")
          File.write(routes_file_path, new_content)
          say "Added #{invitation_name.pluralize} resource with invitations routes", :green
        end
      end

      def invitation_nested_routes_content
        <<~RUBY.chomp
          resources :invitations, only: %i[create destroy] do
              collection do
                get :available_people
              end
              member do
                put :resend
              end
            end
        RUBY
      end

      def authenticated_block_injection_successful?(route_content, routes_file_path)
        content = File.read(routes_file_path)

        # Find authenticated :user block and inject before its closing 'end'
        # This handles both 'authenticated :user do' and 'authenticated :user do # comment'
        pattern = /(authenticated\s+:user\s+do(?:\s*#[^\n]*)?\s*(?:# rubocop:[^\n]*)?\s*)(.*?)(^\s*end(?:\s*# authenticated)?)/m

        new_content = content.sub(pattern) do |_match|
          opening = ::Regexp.last_match(1)
          body = ::Regexp.last_match(2)
          closing = ::Regexp.last_match(3)

          # Add new resource before the closing 'end'
          "#{opening}#{body}#{route_content}#{closing}"
        end

        if new_content == content
          false
        else
          File.write(routes_file_path, new_content)
          true
        end
      end
    end
  end
end
