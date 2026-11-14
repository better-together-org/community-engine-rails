# frozen_string_literal: true

namespace :better_together do
  namespace :content_security do
    desc 'Enroll existing scannable attachments (for example Upload#file) in malware scanning so ' \
         'they can be served once clean. Run after enabling a surface in BT_MALWARE_SCANNING_SURFACES. ' \
         'Set DRY_RUN=1 to count only. Safe to re-run.'
    task backfill: :environment do
      summary = BetterTogether::ContentSecurity::AttachmentBackfill.call(dry_run: ENV['DRY_RUN'].present?)

      if BetterTogether::ContentSecurity::Configuration.enabled?
        puts "Content security backfill#{' (dry run)' if ENV['DRY_RUN'].present?}: " \
             "#{summary.enrolled} record(s) across #{summary.models.join(', ').presence || 'no enabled surfaces'}."
        puts "#{summary.skipped_surface_disabled} attachment(s) skipped because their surface is disabled."
      else
        puts 'Malware scanning is disabled (BT_MALWARE_SCANNING_ENABLED is not true). Nothing to do.'
      end
    end
  end
end
