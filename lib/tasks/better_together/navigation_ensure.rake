# frozen_string_literal: true

namespace :better_together do
  namespace :navigation do
    desc 'Add navigation items the default packet lists but the platform lacks (idempotent). DRY_RUN=1 only reports.'
    task ensure: :environment do
      dry_run = ENV['DRY_RUN'] == '1'
      changes = BetterTogether::Navigation::EnsurePacketItems.call(dry_run:)
      puts "#{dry_run ? 'Would change' : 'Changed'} #{changes.size} navigation item(s)"
      changes.each { |change| puts "  #{change.action} #{change.area}/#{change.identifier}" }
    end
  end
end
