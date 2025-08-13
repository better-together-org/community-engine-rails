# frozen_string_literal: true

# Backfill authorships for existing pages based on creator_id
class BackfillPageAuthorshipsForCreator < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up # rubocop:todo Metrics/MethodLength
    return unless column_exists?(:better_together_pages, :creator_id)

    say_with_time 'Backfilling page authorships for existing creator_id values' do
      BetterTogether::Page.reset_column_information
      BetterTogether::Authorship.reset_column_information

      BetterTogether::Page.find_each do |page|
        next unless page.creator_id.present?

        BetterTogether::Authorship.find_or_create_by!(
          author_id: page.creator_id,
          authorable_type: 'BetterTogether::Page',
          authorable_id: page.id
        )
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
