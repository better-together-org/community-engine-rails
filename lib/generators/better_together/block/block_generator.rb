# frozen_string_literal: true

require 'rails/generators/base'

module BetterTogether
  module Generators
    # Generates a Content::Block STI subclass following docs/content-block-completeness-checklist.md.
    #
    # Usage:
    #   rails generate better_together:block testimonial --translatable=quote:text author:string
    #   rails generate better_together:block countdown target_date:string label:string --icon=hourglass-half
    #
    # Fields are `name:type`. Translatable fields (--translatable name:type, type text or string)
    # are Mobility attributes; every other field is stored in content_data.
    class BlockGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      class_option :translatable, type: :array, default: [],
                                  desc: 'Translated fields as name or name:type (text or string)'
      class_option :icon, type: :string, default: 'puzzle-piece', desc: 'Font Awesome icon name for the pickers'
      class_option :skip_resource_registration, type: :boolean, default: false,
                                                desc: 'Do not add the resource alias to block_resource.rb'
      argument :fields, type: :array, default: [], banner: 'name:type name:type'

      def create_model
        template 'block.rb.tt', "app/models/better_together/content/#{block_name}.rb"
      end

      def create_views
        template 'display.html.erb.tt', "app/views/better_together/content/blocks/_#{block_name}.html.erb"
        template 'fields.html.erb.tt', "app/views/better_together/content/blocks/fields/_#{block_name}.html.erb"
        template 'picker_icon.html.erb.tt', "app/views/better_together/content/blocks/new/_#{block_name}.html.erb"
        template 'page_builder_card.html.erb.tt',
                 "app/views/better_together/content/page_blocks/block_types/_#{block_name}.html.erb"
      end

      def create_locales
        %w[en es fr uk].each do |locale|
          @locale = locale
          template 'locales/locale.yml.tt', "config/locales/#{block_name}.#{locale}.yml"
        end
      end

      def create_factory_and_spec
        template 'factory.rb.tt', "spec/factories/better_together/content/#{block_name}.rb"
        template 'block_spec.rb.tt', "spec/models/better_together/content/#{block_name}_spec.rb"
      end

      def register_resource
        path = 'app/resources/better_together/api/v1/block_resource.rb'
        return if options[:skip_resource_registration] || !File.exist?(File.join(destination_root, path))

        line = "      #{class_base}Resource = BlockResource\n"
        inject_into_file path, line, after: /^\s+VideoBlockResource\s+= BlockResource\n/
      end

      def show_next_steps
        say "Block #{class_base} generated. Remaining checklist items are manual:"
        say '  - add it to the MCP block tools (app/tools/better_together/mcp/list_page_blocks_tool.rb)'
        say '  - add view specs and docs screenshots for the display and fields partials'
        say '  - keep it out of the Add Block chooser until the form UX is reviewed'
      end

      private

      def class_base
        class_name.end_with?('Block') ? class_name : "#{class_name}Block"
      end

      def block_name
        class_base.underscore
      end

      def parsed(list)
        Array(list).map do |item|
          name, type = item.to_s.split(':')
          [name, type.presence || 'string']
        end
      end

      def translatable_fields
        parsed(options[:translatable]).map { |name, type| [name, type == 'text' ? 'text' : 'string'] }
      end

      def stored_fields
        parsed(fields)
      end

      def required_attribute
        (translatable_fields.first || stored_fields.first)&.first
      end

      def permitted_list
        (translatable_fields + stored_fields).map { |name, _| name }.join(' ')
      end

      def icon
        options[:icon].to_s.delete_prefix('fa-')
      end

      def human
        class_base.delete_suffix('Block').titleize
      end
    end
  end
end
