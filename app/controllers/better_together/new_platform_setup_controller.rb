# frozen_string_literal: true

module BetterTogether
  # Kicks off a new_platform_setup wizard run: creates a draft Platform and its
  # paired, platform-scoped Wizard row, then redirects into step 1.
  #
  # Authorization mirrors PlatformsController#new/#create (PlatformPolicy#create?)
  # since this supersedes that bare CRUD form as the primary "add a platform"
  # surface for internally-hosted tenant platforms.
  class NewPlatformSetupController < ApplicationController
    skip_before_action :check_platform_setup
    skip_before_action :check_platform_privacy
    after_action :verify_authorized

    def start
      draft = build_draft_platform
      authorize draft, :create?, policy_class: ::BetterTogether::PlatformPolicy

      provision_draft(draft)

      redirect_to new_platform_setup_step_welcome_path(platform_id: draft.to_param)
    rescue ActiveRecord::RecordInvalid => e
      flash[:alert] = e.record.errors.full_messages.to_sentence
      redirect_to platforms_path
    rescue Pundit::NotAuthorizedError
      render_not_found
    end

    private

    def provision_draft(draft)
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

    def build_draft_platform
      suffix = SecureRandom.hex(6)
      ::BetterTogether::Platform.new(
        name: "New Platform #{suffix}",
        host_url: "https://draft-#{suffix}.pending.invalid",
        time_zone: 'UTC',
        privacy: 'private',
        external: false,
        host: false
      )
    end
  end
end
