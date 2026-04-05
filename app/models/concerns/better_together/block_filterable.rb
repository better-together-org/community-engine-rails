# frozen_string_literal: true

module BetterTogether
  # Adds a scope to filter out records authored by people blocked by the given person
  module BlockFilterable
    extend ActiveSupport::Concern

    included do
      scope :excluding_blocked_for, lambda { |person|
        next all unless person

        blocked_ids = person.blocked_people.select(:id)
        blocked_authorships = BetterTogether::Authorship
                              .where(author_type: 'BetterTogether::Person',
                                     author_id: blocked_ids,
                                     authorable_type: base_class.name)
                              .select(:authorable_id)
        relation = where.not(id: blocked_authorships)
        next relation unless column_names.include?('creator_id')

        relation.where.not(creator_id: blocked_ids)
      }
    end
  end
end
