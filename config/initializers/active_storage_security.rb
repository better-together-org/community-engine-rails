# frozen_string_literal: true

# Gate all ActiveStorage proxy and redirect blob/representation routes through
# BetterTogether::ActiveStorageSecurity.
#
# With proxy mode enabled (config.active_storage.resolve_model_to_route = :rails_storage_proxy),
# all blob URLs resolve through the proxy controllers. Both proxy AND redirect controllers are
# gated here so protection applies regardless of URL-helper configuration.
#
# Devise helpers (current_user, user_signed_in?) are available because Devise adds them to
# ActionController::Base via ActiveSupport.on_load(:action_controller) at boot.
Rails.application.config.to_prepare do
  [
    ActiveStorage::Blobs::ProxyController,
    ActiveStorage::Blobs::RedirectController,
    ActiveStorage::Representations::ProxyController,
    ActiveStorage::Representations::RedirectController
  ].each do |controller|
    controller.include(BetterTogether::ActiveStorageSecurity)
  end
end
