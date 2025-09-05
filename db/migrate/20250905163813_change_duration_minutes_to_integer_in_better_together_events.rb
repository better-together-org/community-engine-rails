class ChangeDurationMinutesToIntegerInBetterTogetherEvents < ActiveRecord::Migration[7.2]
  def up
    # First, convert any existing decimal values to integers
    execute <<-SQL
      UPDATE better_together_events#{' '}
      SET duration_minutes = ROUND(duration_minutes::numeric)
      WHERE duration_minutes IS NOT NULL
    SQL

    # Change the column type from decimal to integer
    change_column :better_together_events, :duration_minutes, :integer
  end

  def down
    # Revert back to decimal type
    change_column :better_together_events, :duration_minutes, :decimal
  end
end
