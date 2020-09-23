require_dependency 'better_together/api_resource'

module BetterTogether
  module Bt
    module Api
      module V1
        # Serializes the Membership class
        class MembershipResource < ::BetterTogether::ApiResource
          model_name '::BetterTogether::Membership'

          has_one :member, polymorphic: true, always_include_linkage_data: true
          has_one :joinable, polymorphic: true, always_include_linkage_data: true
          has_one :role

          filters :member, :joinable, :role
        end
      end
    end
  end
end
