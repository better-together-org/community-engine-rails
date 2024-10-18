class CreateBetterTogetherContactDetails < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :contact_details do |t|
      t.bt_references :contactable, polymorphic: true, null: false
    end
  end
end
