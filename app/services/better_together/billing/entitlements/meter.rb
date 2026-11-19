# frozen_string_literal: true

module BetterTogether
  module Billing
    module Entitlements
      # How much of a quota an owner has used, for the usage meters. Read-only: it asks the quota framework what
      # it would decide for consuming nothing, so it can never hold or change anything.
      module Meter
        Reading = Data.define(:limit, :used) do
          def unlimited? = limit.nil?
          def remaining = unlimited? ? nil : [limit - used, 0].max
          def percent = unlimited? || limit.zero? ? 0 : [(used * 100.0 / limit).round, 100].min
          def over? = !unlimited? && used > limit
        end

        module_function

        def for(owner:, type:)
          usage = BetterTogether::Quotas.usage_for(type:, owner:)
          Reading.new(limit: usage[:limit], used: usage[:used])
        end
      end
    end
  end
end
