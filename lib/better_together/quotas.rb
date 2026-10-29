# frozen_string_literal: true

module BetterTogether
  # Usage ledger facade for the quota framework (Phase 5a, shadow mode). `owner:` is
  # always caller-computed, never resolved internally: a ledger row's `subject`
  # (e.g. an Attachment, for idempotency) and the owner-resolution target (its
  # *owning record*) are different values. check! is hardcoded permissive this
  # phase; reserve!/settle!/reverse! raise on a bug, caught non-fatally per call site.
  module Quotas
    class NonReversibleQuotaError < StandardError; end

    class << self
      # Convenience resolution entry point, equivalent to calling OwnerResolver
      # directly, resolving from `subject` when present, else from `actor`.
      def attribute(subject: nil, actor: nil, **)
        OwnerResolver.resolve(subject || actor)
      end

      # Always permissive this phase. Takes the same keyword shape reserve!/settle!
      # do so a future enforcement phase can swap this implementation without
      # touching call sites.
      # rubocop:todo Naming/PredicateMethod
      # rubocop:todo Lint/UnusedMethodArgument
      def check!(type:, owner:, amount:, subject: nil, actor: nil)
        true
      end
      # rubocop:enable Lint/UnusedMethodArgument
      # rubocop:enable Naming/PredicateMethod

      # rubocop:todo Metrics/ParameterLists
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/AbcSize
      def reserve!(type:, owner:, amount:, idempotency_key:, subject: nil, actor: nil, ttl: 5.minutes)
        type_class = Type.find(type)
        quota = find_or_build_quota(type_class, owner)
        period_key = period_key_for(type_class, Time.current)

        reservation = QuotaReservation.find_or_create_by!(idempotency_key:) do |r|
          r.quota = quota
          r.quota_type = type.to_s
          r.amount = amount
          r.period_key = period_key
          r.subject = subject
          r.actor = actor
          r.owner = owner
          r.expires_at = ttl.from_now
        end

        QuotaBalance.refresh_reserved!(quota, period_key)
        reservation
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/ParameterLists

      # rubocop:todo Metrics/ParameterLists
      # rubocop:todo Metrics/MethodLength
      # rubocop:todo Metrics/AbcSize
      # `occurred_at:` picks the period the usage belongs to; it defaults to now and
      # is only passed explicitly by the backfill, so historical monthly/daily usage
      # lands in the period it actually happened in rather than the current one.
      def settle!(type:, owner:, amount:, idempotency_key:, subject: nil, actor: nil, event: 'settle',
                  occurred_at: nil)
        type_class = Type.find(type)
        return if subject && !type_class.counts_toward_quota?(subject)

        quota = find_or_build_quota(type_class, owner)
        period_key = period_key_for(type_class, occurred_at || Time.current)

        usage = QuotaUsage.find_or_create_by!(idempotency_key:) do |u|
          u.quota = quota
          u.quota_type = type.to_s
          u.amount = amount
          u.period_key = period_key
          u.subject = subject
          u.actor = actor
          u.owner = owner
          u.event = event
        end

        # Only a newly written row moves the balance; an idempotent repeat returns the
        # existing row and must not count twice.
        QuotaBalance.apply_usage!(quota, period_key, usage.amount) if usage.previously_new_record?
        usage
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/ParameterLists

      # rubocop:todo Metrics/ParameterLists
      def reverse!(type:, owner:, amount:, idempotency_key:, subject: nil, actor: nil)
        # rubocop:enable Metrics/ParameterLists
        type_class = Type.find(type)
        raise NonReversibleQuotaError, "#{type} is not reversible" unless type_class.reversible?

        settle!(
          type:, owner:, amount: -amount.abs, idempotency_key:, subject:, actor:, event: 'reverse'
        )
      end

      # Marks the held reservations for `subject` (a direct-upload blob) settled once
      # the real usage row has been written, so `reserved` stops counting bytes that
      # are now in `consumed`.
      def settle_reservations_for!(subject)
        QuotaReservation.status_held.where(subject:).find_each do |reservation|
          reservation.update!(status: 'settled', settled_at: Time.current)
          QuotaBalance.refresh_reserved!(reservation.quota, reservation.period_key)
        end
      end

      private

      def find_or_build_quota(type_class, owner)
        Quota.find_or_create_by!(owner:, quota_type: type_class.key) do |q|
          q.limit = type_class.default_limit(owner)
          q.period = type_class.period
        end
      end

      def period_key_for(type_class, time)
        case type_class.period.to_s
        when 'cumulative' then 'cumulative'
        when 'monthly' then time.strftime('%Y-%m')
        when 'daily' then time.strftime('%Y-%m-%d')
        else raise ArgumentError, "unknown period #{type_class.period}"
        end
      end
    end
  end
end
