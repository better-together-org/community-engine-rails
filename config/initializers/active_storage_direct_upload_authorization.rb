# frozen_string_literal: true

# Gate ActiveStorage's direct-upload creation route through
# BetterTogether::DirectUploadAuthorization.
#
# Rails core's ActiveStorage::DirectUploadsController inherits from
# ActiveStorage::BaseController, not the host app's ApplicationController, so it is
# reachable and fully functional with zero authentication unless explicitly gated here.
# This endpoint has real, legitimate anonymous use (Trix image attachments on the
# sign-up form and host-setup wizard), so it is gated by a page-scoped signed token
# rather than requiring authentication -- see DirectUploadAuthorization for details.
Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.include(BetterTogether::DirectUploadAuthorization)
end
