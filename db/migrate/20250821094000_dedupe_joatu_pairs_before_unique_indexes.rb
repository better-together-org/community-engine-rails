# frozen_string_literal: true

class DedupeJoatuPairsBeforeUniqueIndexes < ActiveRecord::Migration[7.1] # rubocop:todo Style/Documentation
  disable_ddl_transaction!

  def up # rubocop:todo Metrics/MethodLength
    # Remove duplicate agreements keeping the earliest row per offer/request pair
    say_with_time 'Deduping better_together_joatu_agreements' do
      execute <<~SQL
        DELETE FROM better_together_joatu_agreements a
        USING better_together_joatu_agreements b
        WHERE a.offer_id = b.offer_id
          AND a.request_id = b.request_id
          AND a.id <> b.id
          AND a.created_at > b.created_at;
      SQL
    end

    # Ensure at most one accepted agreement per offer (keep earliest accepted)
    say_with_time 'Deduping accepted agreements per offer' do
      execute <<~SQL
        DELETE FROM better_together_joatu_agreements a
        USING better_together_joatu_agreements b
        WHERE a.offer_id = b.offer_id
          AND a.status = 'accepted'
          AND b.status = 'accepted'
          AND a.id <> b.id
          AND a.created_at > b.created_at;
      SQL
    end

    # Ensure at most one accepted agreement per request (keep earliest accepted)
    say_with_time 'Deduping accepted agreements per request' do
      execute <<~SQL
        DELETE FROM better_together_joatu_agreements a
        USING better_together_joatu_agreements b
        WHERE a.request_id = b.request_id
          AND a.status = 'accepted'
          AND b.status = 'accepted'
          AND a.id <> b.id
          AND a.created_at > b.created_at;
      SQL
    end

    # Remove duplicate response links keeping the earliest row per source/response pair
    say_with_time 'Deduping better_together_joatu_response_links' do
      execute <<~SQL
        DELETE FROM better_together_joatu_response_links a
        USING better_together_joatu_response_links b
        WHERE a.source_type = b.source_type
          AND a.source_id = b.source_id
          AND a.response_type = b.response_type
          AND a.response_id = b.response_id
          AND a.id <> b.id
          AND a.created_at > b.created_at;
      SQL
    end
  end

  def down
    # no-op
  end
end
