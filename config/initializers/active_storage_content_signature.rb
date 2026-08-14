# frozen_string_literal: true

# Gate all ActiveStorage proxy and redirect blob/representation routes through
# BetterTogether::ActiveStorageContentSignature.
#
# With proxy mode enabled (config.active_storage.resolve_model_to_route =
# :rails_storage_proxy), all blob URLs resolve through the proxy controllers. Both proxy
# AND redirect controllers are gated here so protection applies regardless of URL-helper
# configuration.
Rails.application.config.to_prepare do
  [
    ActiveStorage::Blobs::ProxyController,
    ActiveStorage::Blobs::RedirectController,
    ActiveStorage::Representations::ProxyController,
    ActiveStorage::Representations::RedirectController
  ].each do |controller|
    controller.include(BetterTogether::ActiveStorageContentSignature)
  end
end
