# frozen_string_literal: true

module BetterTogether
  # Gates ActiveStorage::DirectUploadsController#create through the CE auth model.
  #
  # Rails core's DirectUploadsController inherits from ActiveStorage::BaseController,
  # not the host app's ApplicationController, so no CE-gem or host-app auth check ever
  # applies to it -- it is reachable and functional with zero authentication by default.
  # No form or JS in this gem uses `direct_upload: true`, so there is no legitimate
  # anonymous use of this endpoint to preserve; the bar here is simply "require sign-in."
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
