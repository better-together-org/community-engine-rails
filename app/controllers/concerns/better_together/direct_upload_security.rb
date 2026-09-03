# frozen_string_literal: true

module BetterTogether
  # Gates ActiveStorage::DirectUploadsController#create through the CE auth model.
  #
  # Rails core's DirectUploadsController inherits from ActiveStorage::BaseController,
  # not the host app's ApplicationController, so no CE-gem or host-app auth check ever
  # applies to it -- it is reachable and functional with zero authentication by default.
  #
  # Unlike the equivalent fix on release/0.11.0-notes (which had to avoid gating create
  # entirely because rich_text_area is used on the anonymous sign-up form there), this
  # codebase's registration form uses a plain text_area for the person description
  # (app/views/devise/registrations/new.html.erb) and no wizard-step view uses
  # rich_text_area either -- confirmed via repo-wide grep. Every rich_text_area usage
  # here (messages, conversations, checklist_items, content blocks, platform_invitations)
  # is behind an authenticated-only page, so a blanket auth requirement is safe: no
  # legitimate anonymous use of this endpoint exists in this codebase state.
  #
  # Included into ActiveStorage::DirectUploadsController via the
  # active_storage_direct_upload_security initializer.
  module DirectUploadSecurity
    extend ActiveSupport::Concern

    included do
      before_action :require_authentication_for_direct_upload
    end

    private

    def require_authentication_for_direct_upload
      return if user_signed_in?

      head :unauthorized
    end
  end
end
