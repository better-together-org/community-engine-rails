# frozen_string_literal: true

module BetterTogether
  # Used to represent a person's connection to a community with a specific role
  class PersonCommunityMembership < ApplicationRecord
    include Membership

    membership member_class: 'BetterTogether::Person',
               joinable_class: 'BetterTogether::Community'
  end
end
