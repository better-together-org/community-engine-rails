# frozen_string_literal: true

class BackfillFederatedMirroredIdentifiers < ActiveRecord::Migration[7.2]
  NAMESPACE_SEPARATOR = '--'

  def up
    say_with_time migration_message(:title) do
      backfill(::BetterTogether::Post, content_type: 'post') +
        backfill(::BetterTogether::Page, content_type: 'page') +
        backfill(event_backfill_class, content_type: 'event')
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # Migration-local stand-in for BetterTogether::Event. The real model
  # declares `enum :status, ...`, which Rails validates against the schema
  # at class-load time — but the `status` column isn't added until a later
  # migration (add_status_to_better_together_events). Loading the real class
  # here would abort any host upgrade that installs both migrations in one
  # batch. This stub only needs the table and the `platform` association.
  def event_backfill_class
    Class.new(ActiveRecord::Base) do
      self.table_name = 'better_together_events'
      # better_together_events.type backs STI on the real model. Without this,
      # Rails resolves the `type` column against the real BetterTogether::Event
      # class and rejects this stand-in as an invalid subclass.
      self.inheritance_column = :_type_disabled_for_backfill
      belongs_to :platform, class_name: 'BetterTogether::Platform', optional: true

      def self.name
        'BetterTogether::Event'
      end
    end
  end

  def backfill(model_class, content_type:)
    updated = 0

    model_class.where.not(source_id: [nil, '']).find_each do |record|
      source_platform = source_platform_for(record, content_type:)
      unless source_platform
        say migration_message(:skipped_missing_source_platform, model_name: model_class.name, record_id: record.id)
        next
      end

      new_identifier = ::BetterTogether::Federation::MirroredIdentifier.canonical(
        source_platform: source_platform,
        remote_identifier: remote_identifier_for_backfill(record, source_platform),
        remote_id: record.source_id,
        content_type:
      )

      next if record.identifier == new_identifier

      if model_class.where(identifier: new_identifier).where.not(id: record.id).exists?
        say migration_message(
          :skipped_identifier_conflict,
          model_name: model_class.name,
          record_id: record.id,
          identifier: new_identifier
        )
        next
      end

      record.update!(identifier: new_identifier)
      updated += 1
    end

    updated
  end

  def source_platform_for(record, content_type:)
    namespaced_source_platform(record.identifier) ||
      connection_source_platform(record.platform, content_type:)
  end

  def namespaced_source_platform(identifier)
    namespace = identifier.to_s.split(NAMESPACE_SEPARATOR, 2).first
    return if namespace.blank? || namespace == identifier

    ::BetterTogether::Platform.find_by(identifier: namespace)
  end

  def connection_source_platform(target_platform, content_type:)
    connections = ::BetterTogether::PlatformConnection
                  .active
                  .where(target_platform: target_platform)
                  .select do |connection|
      connection.content_sharing_policy == 'mirror_network_feed' &&
        shares_content_type?(connection, content_type)
    end

    return if connections.size != 1

    connections.first.source_platform
  end

  def shares_content_type?(connection, content_type)
    case content_type
    when 'post' then connection.share_posts?
    when 'page' then connection.share_pages?
    when 'event' then connection.share_events?
    else false
    end
  end

  def remote_identifier_for_backfill(record, source_platform)
    namespace = "#{source_platform.identifier}#{NAMESPACE_SEPARATOR}"
    return record.identifier.delete_prefix(namespace) if record.identifier.to_s.start_with?(namespace)

    record.identifier
  end

  def migration_message(key, **interpolations)
    I18n.t("better_together.federation.backfill.messages.#{key}", **interpolations)
  end
end
