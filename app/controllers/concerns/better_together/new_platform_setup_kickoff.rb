# frozen_string_literal: true

module BetterTogether
  # Shared draft-Platform-provisioning logic for kicking off a new_platform_setup
  # wizard run, used by both NewPlatformSetupController#start (staff-facing entry
  # point, gated on PlatformPolicy#create?) and
  # CommunityBillingsController#provision_platform (billing-gated entry point,
  # gated on the community's hosted entitlement + CommunityPolicy#update?).
  #
  # This concern does not authorize anything itself — callers must apply their
  # own authorization gate before invoking #provision_new_platform_setup_draft.
  module NewPlatformSetupKickoff
    extend ActiveSupport::Concern

    private

    # Rails' timezone select (ApplicationHelper#iana_time_zone_select /
    # COMMON_TIMEZONES) uses the IANA identifier "Etc/UTC", not the bare string
    # "UTC" — that string matches no <option> in the platform_identity step's
    # time_zone field, so nothing gets pre-selected and the field can never be
    # submitted (see NewPlatformSetupController's original fix for this).
    def build_new_platform_setup_draft(provisioning_community: nil)
      suffix = SecureRandom.hex(6)
      ::BetterTogether::Platform.new(
        name: "New Platform #{suffix}",
        host_url: "https://draft-#{suffix}.pending.invalid",
        time_zone: 'Etc/UTC',
        privacy: 'private',
        external: false,
        host: false,
        provisioning_community_id: provisioning_community&.id
      )
    end

    def provision_new_platform_setup_draft(draft)
      ActiveRecord::Base.transaction do
        draft.save!
        # success_message is stored statically on the Wizard row at kickoff time,
        # before the real platform_identity step has run — draft.name is still a
        # placeholder here, so it must not be interpolated into the message.
        ::BetterTogether::NewPlatformSetupWizardBuilder.build(
          platform: draft,
          success_path: platform_path(draft, locale: I18n.locale),
          success_message: t('better_together.new_platform_setup_steps.success_message')
        )
      end
    end

    # Idempotency guard for repeat-click/prefetch/double-submit protection —
    # community-scoped callers (CommunityBillingsController#provision_platform)
    # can key a lookup off provisioning_community_id to avoid minting a second
    # draft Platform for the same community. Matches on the placeholder
    # host_url set by #build_new_platform_setup_draft: once the real
    # platform_identity step runs, host_url is overwritten with a real value,
    # so a still-placeholder host_url reliably means "in-progress draft."
    #
    # Not used by NewPlatformSetupController#start (the staff-facing entry
    # point) — that path has no natural per-caller dedupe key to scope the
    # lookup to, since any staff member with PlatformPolicy#create? may
    # legitimately want to start an unrelated new platform at any time.
    def existing_in_progress_draft_for(community)
      return if community.blank?

      platforms = ::BetterTogether::Platform.arel_table
      ::BetterTogether::Platform.where(provisioning_community_id: community.id)
                                .where(platforms[:host_url].matches('https://draft-%.pending.invalid'))
                                .order(created_at: :desc)
                                .first
    end
  end
end
