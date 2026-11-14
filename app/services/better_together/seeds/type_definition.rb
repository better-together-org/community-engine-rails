# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength

module BetterTogether
  module Seeds
    # Declarative description of one seedable record type: which model it maps to, how a
    # record is found again (natural key), what a packet may write, and what it points at.
    # Built through the Registry DSL, frozen once registered.
    class TypeDefinition
      HOOKS = %i[before_resolve transform after_plant].freeze
      Reference = Data.define(:name, :types, :optional)
      Attachment = Data.define(:name, :many)

      attr_reader :name, :model_name, :natural_key_columns, :within, :by_refs, :platform_column,
                  :writable_attributes, :translated_attributes, :references, :attachments,
                  :position_column, :depends_on, :hooks, :sti_column, :sti_allowed

      def initialize(name)
        @name = name.to_sym
        @natural_key_columns = [:identifier]
        @within = nil
        @by_refs = []
        @platform_column = :platform_id
        @writable_attributes = []
        @translated_attributes = []
        @references = {}
        @attachments = {}
        @depends_on = []
        @hooks = {}
      end

      def model
        model_name.constantize
      end

      # Resolves the record a packet key stands for, scoped to the target platform.
      # `parent_refs` carries already-resolved records for `within:` and `by_refs:` types.
      def find(platform:, key:, parent_refs: {})
        scope = platform_column && model.column_names.include?(platform_column.to_s) ? model.where(platform_column => platform.id) : model.all
        return find_by_refs(scope, parent_refs) if by_refs.any?

        scope = scope.where(within_column => parent_refs.fetch(within).id) if within
        scope.find_by(natural_key_columns.first => key)
      end

      def writable?(attribute)
        (writable_attributes + translated_attributes).include?(attribute.to_sym)
      end

      def hook(name)
        hooks[name]
      end

      # Types that must be planted before this one: declared references plus explicit extras.
      def dependencies
        (references.values.flat_map(&:types) + depends_on).uniq - [name]
      end

      def validate!
        raise ArgumentError, "seed type #{name} needs a model" if model_name.blank?
        raise ArgumentError, "seed type #{name} needs a natural key" if natural_key_columns.empty? && by_refs.empty?
        raise ArgumentError, "seed type #{name}: within #{within} is not a reference" if within && !references.key?(within)

        missing = by_refs - references.keys
        raise ArgumentError, "seed type #{name}: by_refs #{missing.join(', ')} are not references" if missing.any?

        self
      end

      def freeze
        [writable_attributes, translated_attributes, references, attachments, depends_on, hooks].each(&:freeze)
        super
      end

      private

      def within_column
        model.reflect_on_association(within).foreign_key
      end

      def find_by_refs(scope, parent_refs)
        conditions = by_refs.to_h { |ref| [model.reflect_on_association(ref).foreign_key, parent_refs.fetch(ref).id] }
        scope.find_by(conditions)
      end

      # Collects the DSL calls; kept separate so a definition is read-only after registration.
      class Builder
        def initialize(definition)
          @definition = definition
        end

        def model(class_name)
          @definition.instance_variable_set(:@model_name, class_name)
        end

        def natural_key(*columns, within: nil, by_refs: [])
          @definition.instance_variable_set(:@natural_key_columns, columns)
          @definition.instance_variable_set(:@within, within)
          @definition.instance_variable_set(:@by_refs, Array(by_refs))
        end

        def platform_column(column)
          @definition.instance_variable_set(:@platform_column, column)
        end

        def attributes(*names)
          @definition.writable_attributes.concat(names)
        end

        def translated(*names)
          @definition.translated_attributes.concat(names)
        end

        def reference(name, to:, optional: false)
          @definition.references[name.to_sym] = Reference.new(name.to_sym, Array(to).map(&:to_sym), optional)
        end

        def attachment(name, many: false)
          @definition.attachments[name.to_sym] = Attachment.new(name.to_sym, many)
        end

        def position(column)
          @definition.instance_variable_set(:@position_column, column)
        end

        def depends_on(*types)
          @definition.depends_on.concat(types.map(&:to_sym))
        end

        # Single-table-inheritance column a record may choose its subclass through.
        def sti(column, allowed:)
          @definition.instance_variable_set(:@sti_column, column)
          @definition.instance_variable_set(:@sti_allowed, allowed)
        end

        TypeDefinition::HOOKS.each do |hook_name|
          define_method(hook_name) { |&block| @definition.hooks[hook_name] = block }
        end
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/LineLength
