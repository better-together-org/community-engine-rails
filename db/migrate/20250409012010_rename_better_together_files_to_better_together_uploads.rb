# frozen_string_literal: true

# Fixes class name collision with ::File
class RenameBetterTogetherFilesToBetterTogetherUploads < ActiveRecord::Migration[7.1]
  def change
    rename_table :better_together_files, :better_together_uploads, if_exists: true
    change_column_default :better_together_uploads, :type, from: 'BetterTogether::File', to: 'BetterTogether::Upload'
    execute <<~SQL
      UPDATE better_together_uploads
      SET type = 'BetterTogether::Upload'
      WHERE type = 'BetterTogether::File'
    SQL
  end
end
