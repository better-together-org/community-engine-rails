# frozen_string_literal: true

module BetterTogether
  # Resolves class names from untrusted inputs using explicit allow-lists
  module SafeClassResolver
    module_function

    # Resolve a class from a candidate name using an allow-list.
    # allowed: array of Class or String (fully qualified names)
    # Returns Class or nil when not allowed or not found
    def resolve(candidate, allowed: [])
      return nil if candidate.blank?

      normalized_candidate = normalize_name(candidate)
      allowed_names = Array(allowed).map { |a| normalize_name(a.is_a?(Class) ? a.name : a) }
      return nil unless allowed_names.include?(normalized_candidate)

      # Safe constant resolution because we verified it's in allow-list
      candidate.to_s.safe_constantize || normalized_candidate.safe_constantize
    end

    # Resolve or raise an error when disallowed
    def resolve!(candidate, allowed:, error_class: ArgumentError)
      klass = resolve(candidate, allowed:)
      return klass if klass

      raise error_class, "Disallowed class: #{candidate}"
    end

    def normalize_name(name)
      name.to_s.delete_prefix('::')
    end
  end
end
