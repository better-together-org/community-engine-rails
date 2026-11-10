# frozen_string_literal: true

# Links existing addresses to their already-resolved geography records.
class BackfillBetterTogetherAddressGeographyLinks < ActiveRecord::Migration[7.2]
  def up
    # Loading again when the host already loaded the engine's tasks would run the action twice.
    unless Rake::Task.task_defined?('better_together:geography:backfill_address_links')
      load BetterTogether::Engine.root.join('lib', 'tasks', 'better_together', 'geography_backfill_address_links.rake')
    end

    begin
      Rake::Task['better_together:geography:backfill_address_links'].invoke
    rescue RuntimeError
      Rake::Task['app:better_together:geography:backfill_address_links'].invoke
    end
  end

  def down
    # Links are additive and harmless to keep.
  end
end
