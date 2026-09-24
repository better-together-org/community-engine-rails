# frozen_string_literal: true

# Gate ActiveStorage's direct-upload creation route through
# BetterTogether::DirectUploadSecurity.
#
# Rails core's ActiveStorage::DirectUploadsController inherits from
# ActiveStorage::BaseController, not the host app's ApplicationController, so it is
# reachable and fully functional with zero authentication unless explicitly gated here.
#
# Devise helpers (current_user, user_signed_in?) are available because Devise adds them to
# ActionController::Base via ActiveSupport.on_load(:action_controller) at boot.
Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.include(BetterTogether::DirectUploadSecurity)
end
