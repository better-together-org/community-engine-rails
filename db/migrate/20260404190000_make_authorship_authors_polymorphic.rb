# frozen_string_literal: true

class MakeAuthorshipAuthorsPolymorphic < ActiveRecord::Migration[7.2]
  LEGACY_INDEX_NAME = 'by_authorship_author'
  POLYMORPHIC_INDEX_NAME = 'by_authorship_author_type_and_id'

  def up
    add_column :better_together_authorships, :author_type, :string unless column_exists?(
      :better_together_authorships, :author_type
    )

    execute <<~SQL.squish
      UPDATE better_together_authorships
      SET author_type = 'BetterTogether::Person'
      WHERE author_type IS NULL
    SQL

    change_column_null :better_together_authorships, :author_type, false

    if foreign_key_exists?(:better_together_authorships, :better_together_people, column: :author_id)
      remove_foreign_key :better_together_authorships, column: :author_id
    end

    remove_index :better_together_authorships, name: LEGACY_INDEX_NAME if index_exists?(
      :better_together_authorships, :author_id, name: LEGACY_INDEX_NAME
    )

    add_index :better_together_authorships, %i[author_type author_id], name: POLYMORPHIC_INDEX_NAME unless index_exists?(
      :better_together_authorships, %i[author_type author_id], name: POLYMORPHIC_INDEX_NAME
    )
  end

  def down
    remove_index :better_together_authorships, name: POLYMORPHIC_INDEX_NAME if index_exists?(
      :better_together_authorships, %i[author_type author_id], name: POLYMORPHIC_INDEX_NAME
    )

    add_index :better_together_authorships, :author_id, name: LEGACY_INDEX_NAME unless index_exists?(
      :better_together_authorships, :author_id, name: LEGACY_INDEX_NAME
    )

    add_foreign_key :better_together_authorships, :better_together_people, column: :author_id unless foreign_key_exists?(
      :better_together_authorships, :better_together_people, column: :author_id
    )

    remove_column :better_together_authorships, :author_type if column_exists?(:better_together_authorships, :author_type)
  end
end
