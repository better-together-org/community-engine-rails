class CreateBetterTogetherAuthorables < ActiveRecord::Migration[6.0]
  def change
    create_table :better_together_authorables do |t|
      t.string :bt_id,
               null: false,
               index: {
                 name: 'authorable_by_bt_id',
                 unique: true
               },
               limit: 50
      t.references  :authorable,
                    null: false,
                    polymorphic: true,
                    index: {
                      name: 'by_authorable',
                      unique: true
                    }

      t.integer :lock_version, null: false, default: 0
      t.timestamps null: false
    end
  end
end
