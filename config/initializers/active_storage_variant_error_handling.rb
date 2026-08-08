# frozen_string_literal: true

# Gate all ActiveStorage proxy and redirect blob/representation routes through
# BetterTogether::ActiveStorageVariantErrorHandling so a variant/representation
# processing failure (e.g. libvips blocking an untrusted loader on an ambiguous
# file) degrades to a handled response instead of an unhandled 500.
Rails.application.config.to_prepare do
  [
    ActiveStorage::Blobs::ProxyController,
    ActiveStorage::Blobs::RedirectController,
    ActiveStorage::Representations::ProxyController,
    ActiveStorage::Representations::RedirectController
  ].each do |controller|
    controller.include(BetterTogether::ActiveStorageVariantErrorHandling)
  end
end
