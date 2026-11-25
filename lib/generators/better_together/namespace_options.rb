# frozen_string_literal: true

require 'rails/generators/base'

module BetterTogether
  module Generators
    # Shared --namespace handling: BetterTogether inside the engine, none in a host app.
    module NamespaceOptions
      def self.included(base)
        base.class_option :namespace, type: :string, default: nil,
                                      desc: 'Namespace module (BetterTogether in the engine, none in a host app)'
      end

      private

      def module_name
        return options[:namespace].presence if options[:namespace]

        Dir.exist?(File.join(destination_root, 'app', 'models', 'better_together')) ? 'BetterTogether' : nil
      end

      def ns_path
        module_name ? "#{module_name.underscore}/" : ''
      end

      def qualified(name)
        [module_name, name].compact.join('::')
      end

      # Wraps a block of lines in the namespace module when there is one.
      def namespaced_lines(body)
        return body unless module_name

        indented = body.lines.map { |line| line.strip.empty? ? line : "  #{line}" }.join
        "module #{module_name}\n#{indented}end\n"
      end
    end
  end
end
