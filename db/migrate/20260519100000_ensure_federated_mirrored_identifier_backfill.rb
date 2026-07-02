# frozen_string_literal: true

# Idempotent repair for 20260516193000_backfill_federated_mirrored_identifiers.
# The original loads live app models; this uses inline AR stubs (CE pattern from
# 20260412223000) so it is safe on fresh installs in future gem versions.
# Only processes records with source_id but no namespace separator in identifier.
# `down` is a no-op — we do not undo a backfill that is already correct.
class EnsureFederatedMirroredIdentifierBackfill < ActiveRecord::Migration[7.2] # rubocop:disable Metrics/ClassLength
  NAMESPACE_SEPARATOR = '--'

  class MigrationPost < ActiveRecord::Base
    self.table_name = 'better_together_posts'
  end

  class MigrationPage < ActiveRecord::Base
    self.table_name = 'better_together_pages'
  end

  class MigrationEvent < ActiveRecord::Base
    self.table_name = 'better_together_events'
  end

  class MigrationPlatform < ActiveRecord::Base
    self.table_name = 'better_together_platforms'
  end

  # Reads storext settings attributes directly from the jsonb column.
  class MigrationPlatformConnection < ActiveRecord::Base
    self.table_name = 'better_together_platform_connections'

    scope :active_status, -> { where(status: 'active') }

    def content_sharing_policy = (settings || {})['content_sharing_policy'].to_s
    def share_posts?            = (settings || {})['share_posts'] == true
    def share_pages?            = (settings || {})['share_pages'] == true
    def share_events?           = (settings || {})['share_events'] == true
  end

  def up
    return unless tables_ready?

    [MigrationPost, MigrationPage, MigrationEvent,
     MigrationPlatform, MigrationPlatformConnection].each(&:reset_column_information)

    say_with_time 'EnsureFederatedMirroredIdentifierBackfill#up' do
      backfill(MigrationPost, content_type: 'post') +
        backfill(MigrationPage, content_type: 'page') +
        backfill(MigrationEvent, content_type: 'event')
    end
  end

  def down; end

  private

  def tables_ready?
    %w[
      better_together_posts
      better_together_pages
      better_together_events
      better_together_platforms
      better_together_platform_connections
    ].all? { |t| table_exists?(t) }
  end

  def backfill(model_stub, content_type:)
    updated = 0

    model_stub.where.not(source_id: [nil, '']).find_each do |record|
      # Idempotency guard: skip records that already have a namespaced identifier.
      next if record.identifier.to_s.include?(NAMESPACE_SEPARATOR)

      source_platform = source_platform_for(record, content_type:)
      unless source_platform
        say "  Skipping #{model_stub.table_name} id=#{record.id}: no source platform found"
        next
      end

      new_identifier = mirrored_identifier_canonical(
        source_platform:,
        remote_identifier: remote_identifier_for_backfill(record, source_platform),
        remote_id: record.source_id,
        content_type:
      )

      next if record.identifier == new_identifier

      if model_stub.where(identifier: new_identifier).where.not(id: record.id).exists?
        say "  Skipping #{model_stub.table_name} id=#{record.id}: conflict (#{new_identifier})"
        next
      end

      record.update_columns(identifier: new_identifier, updated_at: Time.current)
      updated += 1
    end

    updated
  end

  def source_platform_for(record, content_type:)
    namespaced_source_platform(record.identifier) ||
      connection_source_platform(record.platform_id, content_type:)
  end

  def namespaced_source_platform(identifier)
    namespace = identifier.to_s.split(NAMESPACE_SEPARATOR, 2).first
    return if namespace.blank? || namespace == identifier

    MigrationPlatform.find_by(identifier: namespace)
  end

  def connection_source_platform(target_platform_id, content_type:)
    connections = MigrationPlatformConnection
                  .active_status
                  .where(target_platform_id:)
                  .select do |connection|
      connection.content_sharing_policy == 'mirror_network_feed' &&
        shares_content_type?(connection, content_type)
    end

    return if connections.size != 1

    MigrationPlatform.find_by(id: connections.first.source_platform_id)
  end

  def shares_content_type?(connection, content_type)
    case content_type
    when 'post'  then connection.share_posts?
    when 'page'  then connection.share_pages?
    when 'event' then connection.share_events?
    else false
    end
  end

  def remote_identifier_for_backfill(record, source_platform)
    namespace = "#{source_platform.identifier}#{NAMESPACE_SEPARATOR}"
    return record.identifier.delete_prefix(namespace) if record.identifier.to_s.start_with?(namespace)

    record.identifier
  end

  # Inlined from BetterTogether::Federation::MirroredIdentifier.canonical to
  # avoid loading live app modules in migration context.
  def mirrored_identifier_canonical(source_platform:, remote_identifier:, remote_id:, content_type:)
    source_slug = normalize_slug_preserving_namespace(source_platform&.identifier).presence || 'remote'
    base = mirrored_identifier_base(remote_identifier:, remote_id:, content_type:)
    "#{source_slug}#{NAMESPACE_SEPARATOR}#{base}"
  end

  def mirrored_identifier_base(remote_identifier:, remote_id:, content_type:)
    normalized = normalize_slug_preserving_namespace(remote_identifier)
    return normalized if normalized.present?

    "federated-#{content_type}-#{fallback_remote_key(remote_id)}"
  end

  def fallback_remote_key(remote_id)
    normalized = normalize_slug_preserving_namespace(remote_id)
    return normalized if normalized.present?

    require 'digest'
    Digest::SHA256.hexdigest(remote_id.to_s)[0, 12]
  end

  # Inlined from BetterTogether::FriendlySlug.normalize_slug_preserving_namespace.
  def normalize_slug_preserving_namespace(value)
    value.to_s.split(NAMESPACE_SEPARATOR).map(&:parameterize).reject(&:blank?).join(NAMESPACE_SEPARATOR).presence
  end
end
