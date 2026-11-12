# frozen_string_literal: true

module BetterTogether
  # Gives a person who holds platform memberships on more than one platform a separate
  # account per platform (P1-4). The original account stays on its own platform; every
  # other platform gets a new user and person that take over that platform's memberships
  # and provider links. Passwords are never copied: the new account gets a reset token.
  #
  # Dry run is the default. Safe to repeat: a platform that already has an account for
  # the email is reported as already split and left alone.
  class UserPlatformSplitService
    Plan = Struct.new(:user_id, :email, :source_platform_id, :target_platform_id, :membership_ids,
                      :integration_ids, :status, keyword_init: true)

    def self.call(**) = new(**).call

    def initialize(dry_run: true, mailer: true)
      @dry_run = dry_run
      @mailer = mailer
    end

    def call
      plans = build_plans
      plans.each { |plan| apply(plan) } unless @dry_run
      plans
    end

    # Every row that still points at a person or user of a different platform than the
    # one it belongs to. Empty after a successful run.
    def verification_failures
      PersonPlatformMembership.includes(:member).filter_map do |membership|
        user = membership.member&.user
        next if user.nil? || user.platform_id == membership.joinable_id

        { membership_id: membership.id, user_id: user.id }
      end
    end

    private

    def build_plans
      grouped = PersonPlatformMembership.includes(member: :user).group_by { |m| m.member&.user }
      grouped.except(nil).flat_map do |user, memberships|
        memberships.reject { |m| m.joinable_id == user.platform_id }
                   .group_by(&:joinable_id).map { |platform_id, rows| plan_for(user, platform_id, rows) }
      end
    end

    def plan_for(user, platform_id, memberships)
      existing = User.where(platform_id:).where(User.arel_table[:email].lower.eq(user.email.downcase)).exists?
      Plan.new(user_id: user.id, email: user.email, source_platform_id: user.platform_id,
               target_platform_id: platform_id, membership_ids: memberships.map(&:id),
               integration_ids: integration_ids(user, platform_id),
               status: existing ? :already_split : :pending)
    end

    def integration_ids(user, platform_id)
      PersonPlatformIntegration.where(user_id: user.id, local_platform_id: platform_id).pluck(:id)
    end

    def apply(plan) # rubocop:disable Metrics/AbcSize
      return unless plan.status == :pending

      ApplicationRecord.transaction do
        source = User.find(plan.user_id)
        target = create_account(source, plan.target_platform_id)
        PersonPlatformMembership.where(id: plan.membership_ids).update_all(member_id: target.person.id)
        PersonPlatformIntegration.where(id: plan.integration_ids)
                                 .update_all(user_id: target.id, person_id: target.person.id)
        plan.status = :split
        target.send_reset_password_instructions if @mailer
      end
    end

    def create_account(source, platform_id)
      user = User.new(email: source.email, platform_id:, password: SecureRandom.base58(32))
      user.skip_confirmation! if source.confirmed?
      user.build_person(name: source.person.name,
                        identifier: "#{source.person.identifier}-#{SecureRandom.hex(4)}".first(100),
                        platform_id:)
      user.save!
      user
    end
  end
end
