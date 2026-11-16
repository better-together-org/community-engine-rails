# frozen_string_literal: true

require_relative '20261116200000_add_type_to_platforms'

# Every platform now has a type. Classifies any row still missing one (rows created between the previous
# migration and this one), then makes the column required. New rows get their type from the subclass they are
# built as, or from Platform#infer_type.
class RequirePlatformType < ActiveRecord::Migration[7.2]
  TABLE = :better_together_platforms

  def up
    return unless table_exists?(TABLE) && column_exists?(TABLE, :type)

    AddTypeToPlatforms.new.send(:classify_rows)
    change_column_null TABLE, :type, false
  end

  def down
    return unless table_exists?(TABLE) && column_exists?(TABLE, :type)

    change_column_null TABLE, :type, true
  end
end
