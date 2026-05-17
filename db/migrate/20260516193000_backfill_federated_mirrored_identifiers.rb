# frozen_string_literal: true

class BackfillFederatedMirroredIdentifiers < ActiveRecord::Migration[7.2]
  def up
    say_with_time 'Backfilling federated mirrored identifiers' do
      backfill(::BetterTogether::Post, content_type: 'post') +
        backfill(::BetterTogether::Page, content_type: 'page') +
        backfill(::BetterTogether::Event, content_type: 'event')
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def backfill(model_class, content_type:)
    updated = 0

    model_class.where.not(source_id: [nil, '']).find_each do |record|
      new_identifier = ::BetterTogether::Federation::MirroredIdentifier.canonical(
        source_platform: record.platform,
        remote_identifier: record.identifier,
        remote_id: record.source_id,
        content_type:
      )

      next if record.identifier == new_identifier

      if model_class.where(identifier: new_identifier).where.not(id: record.id).exists?
        say "Skipped #{model_class.name} #{record.id}: identifier conflict on #{new_identifier}"
        next
      end

      record.update!(identifier: new_identifier)
      updated += 1
    end

    updated
  end
end
