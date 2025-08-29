# frozen_string_literal: true

class AddJoatuResponseLinks < ActiveRecord::Migration[7.0] # rubocop:todo Style/Documentation
  def change
    create_bt_table :joatu_response_links do |t|
      t.bt_references :source, polymorphic: true, null: false, index: { name: 'bt_joatu_response_links_by_source' }
      t.bt_references :response, polymorphic: true, null: false, index: { name: 'bt_joatu_response_links_by_response' }
      t.bt_creator
    end
  end
end
