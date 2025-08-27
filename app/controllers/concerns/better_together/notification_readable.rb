# frozen_string_literal: true

module BetterTogether
  # Controller concern to mark Noticed notifications as read for a record
  module NotificationReadable
    extend ActiveSupport::Concern

    # Marks notifications (for the current person) as read for events bound to a record
    # via Noticed::Event#record_id (generic helper used across features).
    def mark_notifications_read_for_record(record, recipient: helpers.current_person)
      return unless recipient && record.respond_to?(:id)

      event_ids = Noticed::Event.where(record_id: record.id).select(:id)

      Noticed::Notification
        .where(recipient:)
        .where(event_id: event_ids)
        .where(read_at: nil)
        .update_all(read_at: Time.current)
    end

    # Marks notifications as read for a set of records associated to a given Noticed event class
    # using the event's record_id field.
    def mark_notifications_read_for_event_records(event_class, record_ids, recipient: helpers.current_person)
      return unless recipient && record_ids.present?

      event_ids = Noticed::Event
                  .where(type: event_class.to_s, record_id: Array(record_ids))
                  .select(:id)

      Noticed::Notification
        .where(recipient:)
        .where(event_id: event_ids)
        .where(read_at: nil)
        .update_all(read_at: Time.current)
    end

    # Marks Joatu match notifications as read for an Offer or Request record by matching
    # the record's GlobalID against the Noticed::Event params (supports both direct string
    # serialization and ActiveJob-style nested _aj_globalid key).
    def mark_match_notifications_read_for(record, recipient: helpers.current_person) # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      return unless recipient && record.respond_to?(:to_global_id)

      gid = record.to_global_id.to_s
      return if gid.blank?

      nn = Noticed::Notification.arel_table
      ne = Noticed::Event.arel_table

      join = nn.join(ne).on(ne[:id].eq(nn[:event_id])).join_sources

      relation = Noticed::Notification
                 .where(recipient:)
                 .where(nn[:read_at].eq(nil))
                 .joins(join)
                 .where(ne[:type].eq('BetterTogether::Joatu::MatchNotifier'))

      # JSONB params filter (offer/request match on direct string or AJ global id)
      json_filter_sql = <<~SQL.squish
        (noticed_events.params ->> 'offer' = :gid OR
         noticed_events.params -> 'offer' ->> '_aj_globalid' = :gid OR
         noticed_events.params ->> 'request' = :gid OR
         noticed_events.params -> 'request' ->> '_aj_globalid' = :gid)
      SQL
      relation = relation.where(
        ActiveRecord::Base.send(
          :sanitize_sql_array, [json_filter_sql, { gid: }]
        )
      )

      relation.update_all(read_at: Time.current)
    end
  end
end
