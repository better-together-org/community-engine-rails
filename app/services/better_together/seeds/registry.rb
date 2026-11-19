# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength

module BetterTogether
  module Seeds
    # Registry of seedable record types. Core types register in DefaultTypes; host apps
    # add theirs (districts, venues) with Registry.register in an initializer, no importer class.
    module Registry
      class UnknownType < KeyError; end
      class DependencyCycle < StandardError; end

      @types = {}
      @defaults_loaded = false
      @mutex = Mutex.new

      class << self
        def register(name, &)
          definition = TypeDefinition.new(name)
          TypeDefinition::Builder.new(definition).instance_eval(&)
          definition.validate!
          @mutex.synchronize { @types[definition.name] = definition.freeze }
        end

        def fetch(name)
          load_defaults!
          @types.fetch(name.to_sym) { raise UnknownType, "unknown seed type: #{name}" }
        end

        def registered?(name)
          load_defaults!
          @types.key?(name.to_sym)
        end

        def types
          load_defaults!
          @types.values
        end

        # Types in an order where every type follows the types it references.
        def ordered(names = nil)
          load_defaults!
          wanted = names ? names.map(&:to_sym) : @types.keys
          result = []
          visiting = []
          wanted.each { |type| visit(type, result, visiting) }
          result.map { |type| @types.fetch(type) }
        end

        # Test seam: drop everything, optionally keeping the defaults loaded afterwards.
        def reset!
          @mutex.synchronize do
            @types = {}
            @defaults_loaded = false
          end
        end

        private

        def visit(type, result, visiting)
          return if result.include?(type)
          raise DependencyCycle, "seed types depend on each other: #{(visiting + [type]).join(' -> ')}" if visiting.include?(type)

          definition = @types.fetch(type) { raise UnknownType, "unknown seed type: #{type}" }
          visiting.push(type)
          definition.dependencies.each { |dependency| visit(dependency, result, visiting) }
          visiting.pop
          result << type
        end

        def load_defaults!
          return if @defaults_loaded

          @mutex.synchronize { @defaults_loaded = true }
          DefaultTypes.register_all
        end
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength
