# frozen_string_literal: true

module BetterTogether
  module Quotas
    # Where limits beyond a type's built-in default come from. A provider (paid entitlements are the
    # one today: see Billing::Entitlements::QuotaAllowances) answers two questions about an owner and a
    # quota type, and registers itself by name:
    #
    #   amount(owner:, type:) -> Integer   extra allowance on top of the default, 0 for none
    #   pool?(owner:, type:)  -> Boolean   whether usage in this owner's content is charged to it (a
    #                                      paid community's pool) rather than to whoever created it
    #
    # Quotas.sync_limit! writes `default + sum of every provider's amount` onto the quota. Nothing is
    # reduced or deleted when an allowance goes away: the limit drops, usage stays, and only NEW
    # consumption is refused (when enforcement is on).
    module Allowances
      class << self
        def providers
          @providers ||= Concurrent::Map.new
        end

        def register(name, provider)
          providers[name.to_s] = provider
        end

        def unregister(name)
          providers.delete(name.to_s)
        end

        def reset!
          providers.clear
        end

        def extra_for(owner, type_key)
          providers.values.sum { |provider| provider.amount(owner:, type: type_key.to_s).to_i }
        end

        def pooled?(owner, type_key)
          providers.values.any? { |provider| provider.pool?(owner:, type: type_key.to_s) }
        end
      end
    end
  end
end
