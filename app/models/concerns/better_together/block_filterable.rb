# frozen_string_literal: true

module BetterTogether
  # Adds a scope to filter out records authored by people blocked by the given person
  module BlockFilterable
    extend ActiveSupport::Concern

    included do
      scope :excluding_blocked_for, lambda { |person|
        next all unless person

        blocked_ids = person.blocked_people.select(:id)
        joins(:authorships).where.not(better_together_authorships: { author_id: blocked_ids }).distinct
      }
    end
  end
end
