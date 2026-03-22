# frozen_string_literal: true

module BetterTogether
  # Access control for address records.
  class AddressPolicy < ContactDetailPolicy
    # Pundit scope for filtering visible Address records.
    class Scope < ContactDetailPolicy::Scope
      COMPONENT_CONDITION = <<~SQL
        COALESCE(line1,'') <> '' OR COALESCE(city_name,'') <> '' OR
        COALESCE(state_province_name,'') <> '' OR COALESCE(postal_code,'') <> '' OR
        COALESCE(country_name,'') <> ''
      SQL

      def resolve
        base_scope = scope.includes(:contact_detail)
        component_scope = base_scope.where(COMPONENT_CONDITION)

        return component_scope if platform_manager?
        return component_scope.where(privacy: 'public') unless agent

        base_scope.where(id: visible_address_ids(component_scope).uniq)
      end

      private

      def platform_manager?
        permitted_to?('manage_platform_settings') || permitted_to?('manage_platform')
      end

      def visible_address_ids(component_scope)
        ids = component_scope.where(privacy: 'public').pluck(:id)
        ids.concat(person_address_ids(component_scope))
        ids.concat(community_address_ids(component_scope))
        ids
      end

      def person_address_ids(component_scope)
        person_cd_ids = BetterTogether::ContactDetail.where(contactable: agent).pluck(:id)
        return [] if person_cd_ids.empty?

        component_scope.where(contact_detail_id: person_cd_ids).pluck(:id)
      end

      def community_address_ids(component_scope)
        community_ids = agent.person_community_memberships.pluck(:joinable_id)
        return [] if community_ids.empty?

        community_cd_ids = BetterTogether::ContactDetail
                           .where(contactable_type: 'BetterTogether::Community', contactable_id: community_ids)
                           .pluck(:id)
        return [] if community_cd_ids.empty?

        component_scope.where(contact_detail_id: community_cd_ids).pluck(:id)
      end
    end
  end
end
