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

    remove_foreign_key :better_together_authorships, column: :author_id if foreign_key_exists?(:better_together_authorships,
                                                                                                 column: :author_id)
    remove_index :better_together_authorships, name: 'by_authorship_author' if index_exists?(:better_together_authorships,
                                                                                              :author_id,
                                                                                              name: 'by_authorship_author')
    add_index :better_together_authorships, %i[author_type author_id], name: 'by_authorship_author'
  end

  def down
    remove_index :better_together_authorships, name: 'by_authorship_author' if index_exists?(:better_together_authorships,
                                                                                              %i[author_type author_id],
                                                                                              name: 'by_authorship_author')
    add_index :better_together_authorships, :author_id, name: 'by_authorship_author'
    add_foreign_key :better_together_authorships, :better_together_people, column: :author_id unless foreign_key_exists?(:better_together_authorships,
                                                                                                                          :better_together_people,
                                                                                                                          column: :author_id)

    remove_column :better_together_authorships, :author_type
  end
end
