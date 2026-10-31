# frozen_string_literal: true

module BetterTogether
  module Quotas
    # Base class for a registered quota type. Concrete types (app/models/better_together/
    # quotas/types/) subclass this and override the class methods below; they self-register
    # at load time with Type.register. Unlike FeatureRegistry (pure YAML metadata), each
    # type needs real behavior (measure, attribution), so this is backed by Ruby classes.
    class Type
      class << self
        def registry
          @registry ||= {}
        end

        def register(key, klass)
          registry[key.to_s] = klass
        end

        def find(key)
          registry.fetch(key.to_s) { raise KeyError, "unknown quota type #{key}" }
        end

        def all
          registry.values
        end

        def keys
          registry.keys
        end

        def reset!
          @registry = {}
        end

        # --- overridden per concrete type ---

        def key
          raise NotImplementedError, "#{self} must define .key"
        end

        # :bytes, :tokens, etc, descriptive only, not enforced against a unit table.
        def unit
          raise NotImplementedError, "#{self} must define .unit"
        end

        # cumulative | monthly | daily; must match Quota#period's enum values.
        def period
          raise NotImplementedError, "#{self} must define .period"
        end

        # Fail-closed default: a type is only safe to decrement if it genuinely
        # measures a local, undo-able resource. A subtype must explicitly override
        # this to return true (see Types::MediaStorage); see
        # feedback_quota_reversibility_defaults_to_false for why this defaults false
        # rather than true.
        def reversible?
          false
        end

        # The byte/token/etc. amount a given subject represents.
        def measure(_subject)
          raise NotImplementedError, "#{self} must define .measure"
        end

        # Default limit for a lazily-created Quota row, keyed by owner class. Product
        # decision, not an engineering one: concrete types stub generous provisional
        # numbers; see each type's own comment.
        def default_limit(_owner)
          raise NotImplementedError, "#{self} must define .default_limit"
        end

        # Whether a given subject should be logged at all for this type. Defaults to
        # true: a type opts out selectively, it does not opt in selectively.
        def counts_toward_quota?(_subject)
          true
        end
      end
    end
  end
end
