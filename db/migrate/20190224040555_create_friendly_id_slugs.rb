# frozen_string_literal: true

MIGRATION_CLASS =
  if ActiveRecord::VERSION::MAJOR >= 5
    ActiveRecord::Migration["#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"]
  else
    ActiveRecord::Migration
  end

  # Creates friendly id slugs table 
  class CreateFriendlyIdSlugs < MIGRATION_CLASS
  def change
    create_table :friendly_id_slugs do |t|
      t.string   :slug,           null: false
      t.uuid :sluggable_id, null: false
      t.string :sluggable_type, null: false
      t.string :scope

      t.integer :lock_version, null: false, default: 0
      t.timestamps null: false
    end
    add_index :friendly_id_slugs, %i[sluggable_type sluggable_id], name: 'by_sluggable'
    add_index :friendly_id_slugs, %i[slug sluggable_type], length: { slug: 140, sluggable_type: 50 }
    add_index :friendly_id_slugs, %i[slug sluggable_type scope],
              length: { slug: 70, sluggable_type: 50, scope: 70 }, unique: true
  end
end
