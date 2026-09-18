# frozen_string_literal: true

module BetterTogether
  # Resolves a class constant from an untrusted candidate string using an explicit
  # allow-list. Never constantizes arbitrary input; only resolves when the normalized
  # candidate name is present in `allowed`.
  #
  # candidate: String or Symbol of the class name (e.g., "BetterTogether::Page")
  # allowed: Array of Class objects and/or String/Symbol fully-qualified class names.
  #   Most call sites pass `SomeConcern.included_in_models.map(&:name)`, but Class objects
  #   are accepted directly too (normalized via #name) for callers that already have the
  #   list of allowed classes rather than their names.
  module SafeClassResolver
    module_function

    def resolve(candidate, allowed: [])
      return nil if candidate.blank?

      normalized_candidate = normalize_name(candidate)
      allowed_names = Array(allowed).map { |a| normalize_name(a.is_a?(Class) ? a.name : a) }
      return nil unless allowed_names.include?(normalized_candidate)

      # Safe constant resolution because we verified it's in the allow-list — safe_constantize
      # returns nil rather than raising for malformed/malicious/non-existent input, and (unlike
      # a manual Object.const_get walk) doesn't risk Ruby's ancestor/lexical-scope constant
      # lookup resolving an unintended constant of the same short name.
      candidate.to_s.safe_constantize || normalized_candidate.safe_constantize
    end

    # Resolve a constant if allowed, otherwise raise.
    #
    # error_class: custom error class to raise when resolution is not permitted
    def resolve!(candidate, allowed: [], error_class: ArgumentError)
      klass = resolve(candidate, allowed:)
      return klass if klass

      raise error_class, "Disallowed class: #{candidate}"
    end

    def normalize_name(name)
      name.to_s.delete_prefix('::')
    end
  end
end
