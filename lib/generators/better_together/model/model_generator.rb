# frozen_string_literal: true

require 'rails/generators/base'
require 'rails/generators/migration'

module BetterTogether
  module Generators
    # Generates a Community Engine model with its migration, factory, specs, policy,
    # JSON:API resource and locale stubs.
    #
    # Usage:
    #   rails generate better_together:model project title:string --translatable=name,description
    #   rails generate better_together:model event_series --privacy --friendly-id --no-platform-scoped
    #
    # Namespace: BetterTogether inside the engine, none in a host app; override with --namespace.
    class ModelGenerator < Rails::Generators::NamedBase # rubocop:todo Metrics/ClassLength
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      argument :attributes, type: :array, default: [], banner: 'field[:type][:index] field[:type][:index]'

      class_option :namespace, type: :string, default: nil,
                               desc: 'Namespace module (BetterTogether in the engine, none in a host app)'
      class_option :translatable, type: :array, default: [],
                                  desc: 'Mobility-translated attributes, for example name description'
      class_option :friendly_id, type: :boolean, default: false, desc: 'Add a translated slug from the first translatable'
      class_option :privacy, type: :boolean, default: false, desc: 'Include the Privacy concern and column'
      class_option :platform_scoped, type: :boolean, default: true, desc: 'Inherit PlatformRecord and add platform_id'
      class_option :skip_migration, type: :boolean, default: false
      class_option :skip_policy, type: :boolean, default: false
      class_option :skip_resource, type: :boolean, default: false

      def create_migration_file
        return if options[:skip_migration]

        migration_template 'migration.rb.tt', "db/migrate/create_#{table_name}.rb"
      end

      def create_model
        template 'model.rb.tt', "app/models/#{ns_path}#{file_name}.rb"
      end

      def create_factory
        template 'factory.rb.tt', "spec/factories/#{ns_path}#{plural_file_name}.rb"
      end

      def create_model_spec
        template 'model_spec.rb.tt', "spec/models/#{ns_path}#{file_name}_spec.rb"
      end

      def create_policy
        return if options[:skip_policy]

        template 'policy.rb.tt', "app/policies/#{ns_path}#{file_name}_policy.rb"
        template 'policy_spec.rb.tt', "spec/policies/#{ns_path}#{file_name}_policy_spec.rb"
      end

      def create_resource
        return if options[:skip_resource]

        template 'resource.rb.tt', "app/resources/#{ns_path}api/v1/#{file_name}_resource.rb"
      end

      def create_locale_files
        %w[en es fr uk].each do |locale|
          @locale = locale
          template 'locales/locale.yml.tt', "config/locales/#{file_name}.#{locale}.yml"
        end
      end

      def self.next_migration_number(_dirname)
        Time.current.strftime('%Y%m%d%H%M%S')
      end

      private

      def module_name
        return options[:namespace].presence if options[:namespace]

        Dir.exist?(File.join(destination_root, 'app', 'models', 'better_together')) ? 'BetterTogether' : nil
      end

      def ns_path
        module_name ? "#{module_name.underscore}/" : ''
      end

      def namespace_prefix
        module_name ? "#{module_name}::" : ''
      end

      def full_class_name
        "#{namespace_prefix}#{class_name}"
      end

      def table_name
        "#{"#{module_name.underscore}_" if module_name}#{plural_file_name}"
      end

      def bt_table?
        module_name == 'BetterTogether'
      end

      def translatable_names
        Array(options[:translatable]).map(&:to_s)
      end

      def slug_source
        translatable_names.first || 'name'
      end

      def parent_class
        if options[:platform_scoped]
          'BetterTogether::PlatformRecord'
        else
          bt_table? ? 'BetterTogether::ApplicationRecord' : 'ApplicationRecord'
        end
      end

      def concerns
        list = []
        list << 'Privacy' if options[:privacy]
        list << 'Translatable' if translatable_names.any?
        list.map { |name| "BetterTogether::#{name}" }
      end

      def column_attributes
        attributes.reject(&:reference?)
      end

      def reference_attributes
        attributes.select(&:reference?)
      end

      def resource_namespaces
        [module_name, 'Api', 'V1'].compact
      end

      def policy_parent
        options[:platform_scoped] ? 'BetterTogether::PlatformRecordPolicy' : 'BetterTogether::ApplicationPolicy'
      end

      def factory_name
        "#{ns_path.tr('/', '_')}#{file_name}"
      end

      def resource_attributes
        (translatable_names + attributes.map(&:name)).uniq.map { |name| ":#{name}" }.join(', ')
      end

      def permitted_attribute_symbols
        (translatable_names + column_attributes.map(&:name)).uniq.map { |name| ":#{name}" }.join(' ')
      end
    end
  end
end
