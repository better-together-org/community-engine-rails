# frozen_string_literal: true

module BetterTogether
  # Transitional contributable concern backed by BetterTogether::Authorship records.
  module Authorable
    extend ActiveSupport::Concern

    included do
      has_many :contributions,
               -> { positioned },
               as: :authorable,
               class_name: 'BetterTogether::Authorship'
      has_many :authorships,
               -> { positioned },
               as: :authorable,
               class_name: 'BetterTogether::Authorship'
      has_many :authors,
               -> { where(better_together_authorships: { author_type: 'BetterTogether::Person', role: BetterTogether::Authorship::AUTHOR_ROLE }) },
               through: :contributions,
               source: :author,
               source_type: 'BetterTogether::Person'
      has_many :robot_authors,
               -> { where(better_together_authorships: { author_type: 'BetterTogether::Robot', role: BetterTogether::Authorship::AUTHOR_ROLE }) },
               through: :contributions,
               source: :author,
               source_type: 'BetterTogether::Robot'
      has_many :contributors,
               through: :contributions,
               source: :author
    end

    class_methods do
      def extra_permitted_attributes
        super + [
          {
            author_ids: [],
            robot_author_ids: []
          }
        ]
      end
    end

    def governed_authors
      contributors_for(BetterTogether::Authorship::AUTHOR_ROLE)
    end

    def governed_contributors
      contributions.includes(:author).sort_by(&:position).map(&:author).compact
    end

    def contribution_records_for(role)
      contributions.for_role(role).includes(:author).sort_by(&:position)
    end

    def contributors_for(role)
      contribution_records_for(role).map(&:author).compact
    end

    def add_governed_contributor(actor, role: BetterTogether::Authorship::AUTHOR_ROLE,
                                 contribution_type: BetterTogether::Authorship::CONTENT_CONTRIBUTION)
      return unless actor

      contributions.find_or_create_by!(
        author: actor,
        role: role.to_s,
        contribution_type: contribution_type.to_s
      )
    end

    def add_creator_as_author
      return unless respond_to?(:creator_id) && creator_id.present?
      return if contributions.exists?

      add_governed_contributor(
        creator,
        role: BetterTogether::Authorship::AUTHOR_ROLE,
        contribution_type: BetterTogether::Authorship::CONTENT_CONTRIBUTION
      )
    end
  end
end
