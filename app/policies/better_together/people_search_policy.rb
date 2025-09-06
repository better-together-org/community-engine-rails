# frozen_string_literal: true

module BetterTogether
  class PeopleSearchPolicy < ApplicationPolicy
    def search?
      # Only authenticated users who are community members can search for people
      user&.person&.primary_community.present?
    end
  end
end
