# frozen_string_literal: true

class CreatePrimaryCommunitiesForExistingPeople < ActiveRecord::Migration[7.0] # rubocop:todo Style/Documentation
  def up
    BetterTogether::Person.where(community_id: nil).each(&:save!)
  end

  def down; end
end
