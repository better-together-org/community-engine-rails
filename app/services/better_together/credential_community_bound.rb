# frozen_string_literal: true

module BetterTogether
  # Single definition of how a community-limited credential narrows a query.
  # Communities match by id, models with community_id are filtered, and
  # models with no community linkage return nothing (fail closed).
  module CredentialCommunityBound
    def self.apply(relation, community = Current.credential_community)
      return relation if community.nil?

      model = relation.respond_to?(:klass) ? relation.klass : relation
      return relation.where(id: community.id) if model <= BetterTogether::Community
      return relation.where(community_id: community.id) if model.column_names.include?('community_id')

      relation.none
    end
  end
end
