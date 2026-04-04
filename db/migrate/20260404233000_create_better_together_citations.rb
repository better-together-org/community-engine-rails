class CreateBetterTogetherCitations < ActiveRecord::Migration[7.1]
  def change
    create_table :better_together_citations, id: :uuid do |t|
      t.references :citeable, polymorphic: true, null: false, type: :uuid, index: { name: 'idx_bt_citations_on_citeable' }
      t.references :creator, foreign_key: { to_table: :better_together_people }, type: :uuid
      t.integer :position
      t.string :reference_key, null: false
      t.string :source_kind, null: false, default: 'webpage'
      t.string :title, null: false
      t.string :source_author
      t.string :publisher
      t.string :source_url
      t.string :locator
      t.date :published_on
      t.date :accessed_on
      t.text :excerpt
      t.text :rights_notes
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :better_together_citations,
              %i[citeable_type citeable_id reference_key],
              unique: true,
              name: 'idx_bt_citations_on_citeable_and_reference_key'
  end
end
