# frozen_string_literal: true

module BetterTogether
  # Kicks off a new_platform_setup wizard run: creates a draft Platform and its
  # paired, platform-scoped Wizard row, then redirects into step 1.
  #
  # Authorization mirrors PlatformsController#new/#create (PlatformPolicy#create?)
  # since this supersedes that bare CRUD form as the primary "add a platform"
  # surface for internally-hosted tenant platforms.
  class NewPlatformSetupController < ApplicationController
    include NewPlatformSetupKickoff

    skip_before_action :check_platform_setup
    skip_before_action :check_platform_privacy
    after_action :verify_authorized

    def start
      draft = build_new_platform_setup_draft
      authorize draft, :create?, policy_class: ::BetterTogether::PlatformPolicy

      provision_new_platform_setup_draft(draft)

      redirect_to new_platform_setup_step_welcome_path(platform_id: draft.to_param)
    rescue ActiveRecord::RecordInvalid => e
      flash[:alert] = e.record.errors.full_messages.to_sentence
      redirect_to platforms_path
    rescue Pundit::NotAuthorizedError
      render_not_found
    end
  end
end
