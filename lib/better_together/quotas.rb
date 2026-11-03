# frozen_string_literal: true

module BetterTogether
  # Usage ledger facade for the quota framework. `owner:` is always caller-computed, never resolved
  # internally: a ledger row's `subject` (e.g. an Attachment, for idempotency) and the owner-resolution
  # target (its *owning record*) are different values.
  #
  # Enforcement is per quota (`enforcement_mode`, set for a whole platform by a steward and left at
  # `shadow` by default): `off` and `shadow` never refuse; `soft` never refuses but says so; `hard`
  # refuses NEW consumption that would pass the limit. Nothing already stored is ever reduced or deleted.
  # reserve!/settle!/reverse! raise on a bug, caught non-fatally per call site (see record_failure).
  module Quotas # rubocop:disable Metrics/ModuleLength
    class NonReversibleQuotaError < StandardError; end

    # Raised, in `hard` mode only, when consuming `amount` more would pass the limit.
    class QuotaExceeded < StandardError
      attr_reader :quota, :remaining

      def initialize(quota, remaining)
        @quota = quota
        @remaining = remaining
        super("#{quota.quota_type} limit reached")
      end
    end

    # What check! found. `allowed` is false only when a hard limit would be passed (and check! raises);
    # `exceeded` is true whenever the limit would be passed in any mode, so soft mode can warn.
    Decision = Data.define(:allowed, :exceeded, :mode, :limit, :remaining) do
      def allowed? = allowed
      def exceeded? = exceeded
    end

    class << self # rubocop:disable Metrics/ClassLength
      # Convenience resolution entry point, equivalent to calling OwnerResolver
      # directly, resolving from `subject` when present, else from `actor`.
      def attribute(subject: nil, actor: nil, **)
        OwnerResolver.resolve(subject || actor)
      end

      # Would consuming `amount` more pass the limit? Advisory: it reads the balance without holding the
      # lock, so use it to refuse early (and to warn). To keep two concurrent consumers from both passing, hold
      # the amount with reserve! (which checks under the lock) before doing the work.
      def check!(type:, owner:, amount:, subject: nil, actor: nil) # rubocop:disable Lint/UnusedMethodArgument
        type_class = Type.find(type)
        quota = find_or_build_quota(type_class, owner)
        decision = decide(quota, QuotaBalance.committed(quota, period_key_for(type_class, Time.current)), amount)
        raise QuotaExceeded.new(quota, decision.remaining) unless decision.allowed

        decision
      end

      # Holds `amount` against the quota until it is settled or the hold expires. In `hard` mode the check
      # and the hold happen under the quota's lock, so two reservations racing for the last bytes cannot
      # both succeed. `enforce: false` records the hold without ever refusing it.
      def reserve!(type:, owner:, amount:, idempotency_key:, subject: nil, actor: nil, ttl: 5.minutes, enforce: true) # rubocop:disable Metrics/ParameterLists
        type_class = Type.find(type)
        quota = find_or_build_quota(type_class, owner)
        period_key = period_key_for(type_class, Time.current)

        reservation = quota.with_lock do
          existing = QuotaReservation.find_by(idempotency_key:)
          next existing if existing

          refuse_if_over!(quota, period_key, amount) if enforce
          create_reservation(quota, type, owner, amount, idempotency_key, period_key, subject, actor, ttl)
        end

        QuotaBalance.refresh_reserved!(quota, period_key)
        reservation
      end

      # `occurred_at:` picks the period the usage belongs to; it defaults to now and is only passed
      # explicitly by the backfill, so historical monthly/daily usage lands in the period it actually
      # happened in rather than the current one. Settling never refuses: the work is done and the usage is
      # a fact (the refusing happens before, in reserve!/check!).
      def settle!(type:, owner:, amount:, idempotency_key:, subject: nil, actor: nil, event: 'settle', occurred_at: nil) # rubocop:disable Metrics/ParameterLists
        type_class = Type.find(type)
        return if subject && !type_class.counts_toward_quota?(subject)

        quota = find_or_build_quota(type_class, owner)
        period_key = period_key_for(type_class, occurred_at || Time.current)
        usage = write_once(QuotaUsage, idempotency_key) do |u|
          u.assign_attributes(quota:, quota_type: type.to_s, amount:, period_key:, subject:, actor:, owner:, event:,
                              platform_id: platform_id_for(owner))
        end

        # Only a newly written row moves the balance; an idempotent repeat returns the
        # existing row and must not count twice.
        QuotaBalance.apply_usage!(quota, period_key, usage.amount) if usage.previously_new_record?
        usage
      end

      def reverse!(type:, owner:, amount:, idempotency_key:, subject: nil, actor: nil) # rubocop:disable Metrics/ParameterLists
        type_class = Type.find(type)
        raise NonReversibleQuotaError, "#{type} is not reversible" unless type_class.reversible?

        settle!(type:, owner:, amount: -amount.abs, idempotency_key:, subject:, actor:, event: 'reverse')
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

      # Lets go of holds whose time ran out (an upload begun and never finished), so the bytes stop counting.
      def expire_reservations!(now: Time.current)
        QuotaReservation.status_held.where(QuotaReservation.arel_table[:expires_at].lt(now)).find_each do |reservation|
          reservation.update!(status: 'expired')
          QuotaBalance.refresh_reserved!(reservation.quota, reservation.period_key)
        rescue StandardError => e
          record_failure(e, 'expire_reservations')
        end
      end

      # The limit an owner has now: the type's default plus whatever the registered allowance providers add.
      def effective_limit(type_class, owner)
        type_class.default_limit(owner) + Allowances.extra_for(owner, type_class.key)
      end

      # Brings the stored limit (and the platform's enforcement mode) in line with the providers. Called when
      # an allowance is granted, renewed, lapses or changes. Lowering a limit below current usage is allowed:
      # nothing is deleted, and only new consumption is refused.
      def sync_limit!(type:, owner:)
        type_class = Type.find(type)
        quota = find_or_build_quota(type_class, owner)
        quota.with_lock do
          quota.update!(limit: effective_limit(type_class, owner), enforcement_mode: enforcement_mode_for(owner, type_class.key))
        end
        quota
      end

      # Sets one quota type's enforcement on every quota of the platform's owners (a steward's switch).
      def apply_enforcement!(platform, type_key)
        mode = platform.quota_enforcement_mode(type_key)
        Quota.where(platform_id: platform.id, quota_type: type_key.to_s).find_each { |quota| quota.update!(enforcement_mode: mode) }
      end

      # What was lost when a quota hook failed. These hooks never break the work they track, so the failure
      # is logged, reported and counted instead of passing silently: a recording that fails open is a limit
      # that is not being enforced.
      def record_failure(error, what)
        Rails.logger.error("[Quotas] #{what} failed non-fatally: #{error.class}: #{error.message}")
        BetterTogether.report_error(error, context: { quota_hook: what })
        Rails.cache.increment('bt:quotas:failures', 1, expires_in: 1.day, initial: 0)
      end

      def failures_today = Rails.cache.read('bt:quotas:failures').to_i

      # The platform an owner's quota rows belong to, set explicitly: a row written from a job has no
      # Current.platform, and the host fallback would put another tenant's usage on the host.
      def platform_id_for(owner)
        owner.is_a?(BetterTogether::Platform) ? owner.id : owner.try(:platform_id)
      end

      private

      def find_or_build_quota(type_class, owner)
        platform_id = platform_id_for(owner)
        Quota.find_or_create_by!(owner:, quota_type: type_class.key) do |q|
          q.limit = effective_limit(type_class, owner)
          q.period = type_class.period
          q.platform_id = platform_id
          q.enforcement_mode = enforcement_mode_for(owner, type_class.key)
        end
      rescue ActiveRecord::RecordNotUnique
        Quota.find_by!(owner:, quota_type: type_class.key)
      end

      def enforcement_mode_for(owner, type_key)
        platform = owner.is_a?(BetterTogether::Platform) ? owner : BetterTogether::Platform.find_by(id: owner.try(:platform_id))
        platform ? platform.quota_enforcement_mode(type_key) : 'shadow'
      end

      def decide(quota, committed, amount)
        remaining = quota.limit - committed
        exceeded = amount.to_i > remaining
        hard = quota.enforcement_mode_hard? && quota.status_active?
        Decision.new(allowed: !(hard && exceeded), exceeded:, mode: quota.enforcement_mode, limit: quota.limit, remaining: [remaining, 0].max)
      end

      # Called with the quota locked, so what is committed cannot change under it.
      def refuse_if_over!(quota, period_key, amount)
        decision = decide(quota, QuotaBalance.committed(quota, period_key), amount)
        raise QuotaExceeded.new(quota, decision.remaining) unless decision.allowed
      end

      def create_reservation(quota, type, owner, amount, idempotency_key, period_key, subject, actor, ttl) # rubocop:disable Metrics/ParameterLists
        write_once(QuotaReservation, idempotency_key) do |r|
          r.assign_attributes(quota:, quota_type: type.to_s, amount:, period_key:, subject:, actor:, owner:, expires_at: ttl.from_now,
                              platform_id: platform_id_for(owner))
        end
      end

      # Writes a ledger row once per idempotency key. Two writers racing for the same key both pass the
      # lookup; the unique index refuses the second, which then reads the first's row instead of failing.
      def write_once(model, idempotency_key)
        model.find_by(idempotency_key:) || model.new(idempotency_key:).tap do |row|
          yield row
          row.save!
        end
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
        # Either the unique index or the model's own uniqueness check saw the other writer's row.
        model.find_by(idempotency_key:) || raise(e)
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
