class MigrateTranslatedNameAttributesToStrings < ActiveRecord::Migration[7.2]
  def up
    # Move community and partner name translations from text to string translations
    # This handles cases where names were incorrectly stored as text type

    puts "Running mobility translation migration via rake task (with bulk operations)..."

    # Execute the rake task that contains the migration logic
    # This allows the migration logic to be tested and executed independently
    # Uses bulk operations for optimal performance:
    # - insert_all() for creating string translations
    # - delete_all() for removing text translations
    # - Bypasses ActiveRecord callbacks (Elasticsearch indexing)
    begin
      Rake::Task['translations:mobility:migrate_names_to_string'].invoke
    rescue RuntimeError
      Rake::Task['app:translations:mobility:migrate_names_to_string'].invoke
    end
  end

  def down
    # This migration is not easily reversible since we don't know which records
    # were originally in text translations vs string translations.
    # However, you can use the rake task system to create a reverse migration if needed.
    raise ActiveRecord::IrreversibleMigration,
          "Cannot reverse migration of name translations from text to string"
  end
end
