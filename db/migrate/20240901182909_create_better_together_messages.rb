class CreateBetterTogetherMessages < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :messages do |t|
      t.text :content, null: false
      t.bt_references :sender, null: false, target_table: :better_together_people
      t.bt_references :conversation, null: false
    end
  end
end
