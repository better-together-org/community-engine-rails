# frozen_string_literal: true

module BetterTogether
  module Billing
    module Entitlements
      # Makes what an entitlement has applied match what its plan includes now: applies what is missing and
      # releases what the plan no longer includes. Returns the failures (a handler that raised), so the caller can
      # report them and try again; one failing handler never stops the others.
      class Reconcile
        def self.call(...) = new(...).call

        def initialize(entitlement)
          @entitlement = entitlement
        end

        def call
          failures = []
          desired = entitlement.plan.plan_grants.map(&:handler).select { |handler| handler.applies_to?(entitlement.beneficiary) }
          release_gone(desired.map(&:key), failures)
          desired.each { |handler| guarded(failures) { apply(handler) } }
          failures
        end

        private

        attr_reader :entitlement

        def release_gone(keys, failures)
          entitlement.grants.applied.where.not(grant_key: keys).find_each do |grant|
            guarded(failures) { ReleaseAll.release(grant) }
          end
        end

        def apply(handler)
          grant = entitlement.grants.find_by(grant_key: handler.key)
          return if grant&.applied?

          applied = handler.apply(entitlement)
          record(handler, grant, applied)
          sync_quota(handler)
        end

        def record(handler, grant, applied)
          attributes = { applied: applied.record, owned: applied.owned, quota_type: applied.quota_type, amount: applied.amount,
                         status: 'applied', released_at: nil }
          if grant
            grant.update!(attributes)
          else
            entitlement.grants.create!(attributes.merge(platform_id: entitlement.platform_id, grant_key: handler.key, kind: handler.kind,
                                                        parameters: handler.parameters))
          end
        end

        def sync_quota(handler)
          return unless handler.is_a?(Handlers::QuotaAllowance)

          Handlers::QuotaAllowance.sync(entitlement.beneficiary, handler.parameters['quota_type'])
        end

        def guarded(failures)
          yield
        rescue StandardError => e
          BetterTogether.report_error(e, context: { entitlement_id: entitlement.id })
          failures << e
        end
      end
    end
  end
end
