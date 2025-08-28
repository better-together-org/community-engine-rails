# frozen_string_literal: true

module BetterTogether
  class AddressPolicy < ContactDetailPolicy
    # Inherits from ContactDetailPolicy

    class Scope < ContactDetailPolicy::Scope
      def resolve
        base_scope = scope.includes(:contact_detail)

        # Build a scope that filters out addresses with no meaningful address components
        component_scope = base_scope.where("COALESCE(line1,'') <> '' OR COALESCE(city_name,'') <> '' OR COALESCE(state_province_name,'') <> '' OR COALESCE(postal_code,'') <> '' OR COALESCE(country_name,'') <> ''")

        # Platform managers can see everything
        return component_scope if permitted_to?('manage_platform')

        # Unauthenticated users only see public addresses that have components
        return component_scope.where(privacy: 'public') unless agent

        visible_ids = []

        # Public addresses (with components)
        visible_ids.concat(component_scope.where(privacy: 'public').pluck(:id))

        # Addresses for the user's person (via contact_detail) that have components
        if agent
          person_cd_ids = BetterTogether::ContactDetail.where(contactable: agent).pluck(:id)
          visible_ids.concat(component_scope.where(contact_detail_id: person_cd_ids).pluck(:id)) if person_cd_ids.any?

          # Addresses for communities the user is a member of
          community_ids = agent.person_community_memberships.pluck(:joinable_id)
          if community_ids.any?
            community_cd_ids = BetterTogether::ContactDetail
                               .where(contactable_type: 'BetterTogether::Community', contactable_id: community_ids)
                               .pluck(:id)
            if community_cd_ids.any?
              visible_ids.concat(component_scope.where(contact_detail_id: community_cd_ids).pluck(:id))
            end
          end
        end

        base_scope.where(id: visible_ids.uniq)
      end
    end
  end
end
