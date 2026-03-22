# frozen_string_literal: true

class AddPageToBetterTogetherAgreements < ActiveRecord::Migration[7.1] # rubocop:todo Style/Documentation
  def change
    add_reference :better_together_agreements, :page, type: :uuid, foreign_key: { to_table: :better_together_pages },
                                                      null: true
  end
end
