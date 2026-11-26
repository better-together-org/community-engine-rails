# frozen_string_literal: true

module BetterTogether
  module Billing
    # The one way billing tells people something.
    #
    #   Notifications.deliver('order_paid', subject: order)
    #
    # It looks up who hears about that kind (see Catalog), finds the people (see Recipients), and
    # sends one notification per person. It is safe to call twice for the same thing: each person
    # gets a receipt first, in the same transaction as the notification, so a replayed webhook, a
    # retried job or a double click never notifies twice.
    #
    # It runs after the surrounding database transaction commits, so nobody is told about
    # something that was then rolled back. A failure to notify is logged and reported, and never
    # fails the work that triggered it.
    module Notifications
      module_function

      # `dedupe_key` says what this notification is about. By default that is the subject and the
      # kind, once; pass your own when the same subject can legitimately happen again (a second
      # failed payment, say).
      def deliver(kind, subject:, dedupe_key: nil, actor: nil)
        raise ArgumentError, "unknown notification kind #{kind.inspect}" unless Catalog.kind?(kind)

        key = dedupe_key || "#{subject.class.name}:#{subject.id}"
        ActiveRecord.after_all_transactions_commit { send_all(kind.to_s, subject, key, actor) }
        nil
      end

      def send_all(kind, subject, key, actor)
        Catalog.audiences(kind).each { |audience| send_to(audience, kind, subject, key, actor) }
      rescue StandardError => e
        Rails.logger.error("[billing] could not notify about #{kind}: #{e.class}")
        BetterTogether.report_error(e, context: { kind:, subject: subject.class.name })
      end

      def send_to(audience, kind, subject, key, actor)
        recipients = Recipients.call(audience:, subject:, actor:)
        NotificationReceipt.transaction do
          fresh = recipients.select { |person| record_receipt(person, kind, audience, subject, key) }
          Notifier.with(record: subject, kind:, audience:).deliver_later(fresh) if fresh.any?
        end
      end

      # True when this person had not been told yet.
      def record_receipt(person, kind, audience, subject, key)
        NotificationReceipt.create!(platform_id: subject.platform_id, recipient: person, kind:, audience: audience.to_s, dedupe_key: key)
        true
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        false
      end
    end
  end
end
