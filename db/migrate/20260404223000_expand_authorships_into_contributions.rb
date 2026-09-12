# frozen_string_literal: true

class ExpandAuthorshipsIntoContributions < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:better_together_authorships)

    ensure_string_column :role, default: 'author'
    ensure_string_column :contribution_type, default: 'content'
    ensure_jsonb_column :details, default: {}

    add_index_unless_exists :role, name: 'by_better_together_authorships_role'
    add_index_unless_exists :contribution_type, name: 'by_better_together_authorships_contribution_type'
    add_index_unless_exists %i[authorable_type authorable_id role], name: 'by_better_together_authorships_authorable_role'
  end

  def down
    return unless table_exists?(:better_together_authorships)

    remove_index_if_exists %i[authorable_type authorable_id role], name: 'by_better_together_authorships_authorable_role'
    remove_index_if_exists :contribution_type, name: 'by_better_together_authorships_contribution_type'
    remove_index_if_exists :role, name: 'by_better_together_authorships_role'

    remove_column :better_together_authorships, :details if column_exists?(:better_together_authorships, :details)
    remove_column :better_together_authorships, :contribution_type if column_exists?(:better_together_authorships, :contribution_type)
    remove_column :better_together_authorships, :role if column_exists?(:better_together_authorships, :role)
  end

  private

  def add_index_unless_exists(columns, name:)
    return if index_exists?(:better_together_authorships, columns, name:)

    add_index :better_together_authorships, columns, name:
  end

  def remove_index_if_exists(columns, name:)
    return unless index_exists?(:better_together_authorships, columns, name:)

    remove_index :better_together_authorships, name:
  end

  def ensure_string_column(column_name, default:)
    unless column_exists?(:better_together_authorships, column_name)
      add_column :better_together_authorships, column_name, :string, default:, null: false
      return
    end

    execute <<~SQL.squish
      UPDATE better_together_authorships
      SET #{quote_column_name(column_name)} = #{quote(default)}
      WHERE #{quote_column_name(column_name)} IS NULL
    SQL
    change_column_default :better_together_authorships, column_name, default
    change_column_null :better_together_authorships, column_name, false
  end

  def ensure_jsonb_column(column_name, default:)
    unless column_exists?(:better_together_authorships, column_name)
      add_column :better_together_authorships, column_name, :jsonb, default:, null: false
      return
    end

    execute <<~SQL.squish
      UPDATE better_together_authorships
      SET #{quote_column_name(column_name)} = #{quote(default.to_json)}::jsonb
      WHERE #{quote_column_name(column_name)} IS NULL
    SQL
    change_column_default :better_together_authorships, column_name, default
    change_column_null :better_together_authorships, column_name, false
  end
end
