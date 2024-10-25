class RemoveMessagesContentColumnNull < ActiveRecord::Migration[7.1]
  def change
    change_column_null :better_together_messages, :content, true
  end
end
