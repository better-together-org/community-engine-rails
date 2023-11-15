class CreateBetterTogetherPeople < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :people do |t|
      t.bt_emoji_name
      t.bt_emoji_description
    end
  end
end
