# frozen_string_literal: true

namespace :better_together do
  namespace :quotas do
    desc 'Backfill quota_usages from existing Ai::Log::Translation rows and every existing ' \
         'ActiveStorage attachment (engine or host app). Safe to re-run, idempotent on the ' \
         'ledger\'s idempotency_key.'
    task backfill: :environment do
      summary = BetterTogether::Quotas::Backfill.call

      puts "Quota backfill complete: #{summary.translation_usages} translation usage row(s), " \
           "#{summary.attachment_usages} attachment usage row(s) processed."
      puts "Attachment discovery cross-check: reflection walk found #{summary.reflection_attachment_count}, " \
           "raw ActiveStorage::Attachment count is #{summary.raw_attachment_count}."

      if summary.attachment_count_mismatch
        warn '[Quotas] WARNING: reflection-driven discovery and the raw attachment table ' \
             'disagree: something is attached through a path that bypasses an owning ' \
             "model's own reflections. Investigate before trusting this backfill's coverage."
      end
    end
  end
end
