# frozen_string_literal: true

module BetterTogether
  # Safely resolves class constants from strings using explicit allow-lists.
  # Never constantizes arbitrary input; only resolves when the class name is in the allow-list.
  module SafeClassResolver
    module_function

    # Resolve a constant if allowed. Returns the constant or nil when disallowed or not found.
    #
    # name: String or Symbol of the class name (e.g., "BetterTogether::Page")
    # allowed: Array<String> of fully qualified class names that are allowed
    def resolve(name, allowed: [])
      normalized = normalize_name(name)
      return nil if normalized.nil?
      return nil unless allowed&.include?(normalized)

      # At this point the name is allow-listed; constantize safely
      constantize_safely(normalized)
    rescue NameError
      nil
    end

    # Resolve a constant if allowed, otherwise raise.
    #
    # error_class: custom error class to raise when resolution is not permitted
    def resolve!(name, allowed: [], error_class: NameError)
      constant = resolve(name, allowed:)
      return constant if constant

      raise error_class, "Unsafe or unknown class resolution attempted: #{name.inspect}"
    end

    # Internal: normalize class name strings by removing leading :: and converting symbols.
    def normalize_name(name)
      return nil if name.nil?

      # rubocop:todo Style/IdenticalConditionalBranches
      str = name.is_a?(Symbol) ? name.to_s : name.to_s # rubocop:todo Lint/DuplicateBranch, Style/IdenticalConditionalBranches
      # rubocop:enable Style/IdenticalConditionalBranches
      str.delete_prefix('::')
    end
    private_class_method :normalize_name

    # Internal: safely constantize a fully-qualified constant name without evaluating arbitrary code.
    def constantize_safely(qualified_name)
      names = qualified_name.split('::')
      names.shift if names.first.blank?

      constant = Object
      names.each do |n|
        constant = constant.const_get(n)
      end
      constant
    end
    private_class_method :constantize_safely
  end
end
