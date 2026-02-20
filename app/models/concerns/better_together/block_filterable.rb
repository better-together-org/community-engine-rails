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
                              .where(author_id: blocked_ids, authorable_type: base_class.name)
                              .select(:authorable_id)
        where.not(id: blocked_authorships)
      }
    end
  end
end
