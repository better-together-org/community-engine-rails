# frozen_string_literal: true

class MakeAuthorshipAuthorPolymorphic < ActiveRecord::Migration[7.2]
  def up
    add_column :better_together_authorships, :author_type, :string, default: 'BetterTogether::Person'

    execute <<~SQL.squish
      UPDATE better_together_authorships
      SET author_type = 'BetterTogether::Person'
      WHERE author_type IS NULL
    SQL

    change_column_null :better_together_authorships, :author_type, false

    if foreign_key_exists?(:better_together_authorships, column: :author_id)
      remove_foreign_key :better_together_authorships, column: :author_id
    end

    if index_exists?(:better_together_authorships, :author_id, name: 'by_authorship_author')
      remove_index :better_together_authorships, name: 'by_authorship_author'
    end

    add_index :better_together_authorships, %i[author_type author_id], name: 'by_authorship_author'
  end

  def down
    if index_exists?(:better_together_authorships, %i[author_type author_id], name: 'by_authorship_author')
      remove_index :better_together_authorships, name: 'by_authorship_author'
    end

    add_index :better_together_authorships, :author_id, name: 'by_authorship_author'

    unless foreign_key_exists?(:better_together_authorships, :better_together_people, column: :author_id)
      add_foreign_key :better_together_authorships, :better_together_people, column: :author_id
    end

    remove_column :better_together_authorships, :author_type
  end
end
