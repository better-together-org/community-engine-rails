# frozen_string_literal: true

module BetterTogether
  module Billing
    module Entitlements
      module Handlers
        # Access to a gated feature, as the existing FeatureAccessGrant (`beta` or `alpha`).
        #
        #   { "feature_key": "person_linked_seeds", "access_level": "beta" }
        #
        # A grant the person already holds is adopted and never revoked; only one this entitlement made is revoked
        # when it lapses. People only: a community has no feature access of its own.
        class FeatureAccess < Base
          def self.parameter_errors(parameters, platform:) = new(parameters, platform:).errors

          def errors
            list = []
            list << :feature_unknown if BetterTogether::FeatureRegistry.find(parameters['feature_key']).nil?
            list << :level_unknown unless BetterTogether::FeatureAccessGrant::ACCESS_LEVELS.value?(parameters['access_level'])
            list
          end

          def kind = 'feature_access'

          def key = "feature_access:#{parameters['feature_key']}:#{parameters['access_level']}"

          def applies_to?(beneficiary) = beneficiary.is_a?(BetterTogether::Person) && errors.empty?

          def apply(entitlement)
            person = entitlement.beneficiary
            existing = BetterTogether::FeatureAccessGrant.active.find_by(platform_id: platform.id, person_id: person.id,
                                                                         feature_key: parameters['feature_key'])
            existing ? Applied.new(record: existing, owned: false) : Applied.new(record: create_grant(person), owned: true)
          end

          def create_grant(person)
            BetterTogether::FeatureAccessGrant.create!(platform_id: platform.id, person:, feature_key: parameters['feature_key'],
                                                       access_level: parameters['access_level'])
          end

          def release(grant)
            return unless grant.owned && grant.applied

            grant.applied.revoke!
          end
        end
      end
    end
  end
end
