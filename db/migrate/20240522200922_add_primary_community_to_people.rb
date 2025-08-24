# frozen_string_literal: true

class AddPrimaryCommunityToPeople < ActiveRecord::Migration[7.0] # rubocop:todo Style/Documentation
  def change
    change_table :better_together_people do |t|
      unless column_exists?(:better_together_people, :community_id, :uuid)
        # Custom community reference here to allow for null references for existing records
        t.bt_references :community, target_table: :better_together_communities, null: true,
                                    index: { name: 'by_person_community' }
      end
    end
  end
end
