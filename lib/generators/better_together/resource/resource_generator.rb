# frozen_string_literal: true

require_relative '../namespace_options'

module BetterTogether
  module Generators
    # rails generate better_together:resource Project name:string description:text [--namespace=X]
    class ResourceGenerator < Rails::Generators::NamedBase
      include NamespaceOptions

      source_root File.expand_path('templates', __dir__)

      argument :attributes, type: :array, default: [], banner: 'attribute attribute'

      def create_resource
        template 'resource.rb.tt', "app/resources/#{ns_path}api/v1/#{file_name}_resource.rb"
      end

      private

      def attribute_symbols
        attributes.map { |attribute| ":#{attribute.name}" }.join(', ')
      end

      def nested_modules
        [module_name, 'Api', 'V1'].compact
      end

      def resource_body
        lines = ["# Serializes #{class_name} for the JSON:API.",
                 "class #{class_name}Resource < ::BetterTogether::Api::ApplicationResource",
                 "  model_name '::#{qualified(class_name)}'"]
        lines += ['', "  attributes #{attribute_symbols}"] if attributes.any?
        lines << 'end'
        wrap(lines)
      end

      def wrap(lines)
        wrapped = nested_modules.reverse.reduce(lines) do |body, name|
          ["module #{name}", *body.map { |l| l.empty? ? l : "  #{l}" }, 'end']
        end
        "#{wrapped.join("\n")}\n"
      end
    end
  end
end
