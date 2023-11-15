MIGRATION_CLASS =
  if ActiveRecord::VERSION::MAJOR >= 5
    ActiveRecord::Migration["#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"]
  else
    ActiveRecord::Migration
  end

class CreateFriendlyIdSlugs < MIGRATION_CLASS
  def change
    create_table :friendly_id_slugs do |t|
      t.string   :slug,           :null => false
      t.bt_references :sluggable, polymorphic: true, null: false, index: { name: 'by_sluggable' }
      t.string   :scope

      t.integer :lock_version, null: false, default: 0
      t.timestamps null: false
    end
    add_index :friendly_id_slugs, [:sluggable_type, :sluggable_id]
    add_index :friendly_id_slugs, [:slug, :sluggable_type], length: { slug: 140, sluggable_type: 50 }
    add_index :friendly_id_slugs, [:slug, :sluggable_type, :scope], length: { slug: 70, sluggable_type: 50, scope: 70 }, unique: true
  end
end
