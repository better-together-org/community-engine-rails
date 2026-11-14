# frozen_string_literal: true

module BetterTogether
  module Storage
    # Chooses the Active Storage service for a new blob from the current platform. A platform with an
    # active StorageConfiguration stamps its blobs with that config's service name; any other platform
    # gets nil, which leaves Active Storage's process default in place.
    module TenantService
      module_function

      def service_name_for(platform)
        platform&.active_storage_configuration&.storage_key
      end

      def current_service_name
        service_name_for(::Current.platform)
      end

      # Prepended to ActiveStorage::Blob's singleton: every creation path (io uploads, attachments and
      # direct uploads) goes through one of these two, and an explicit service_name always wins.
      module BlobStamping
        def build_after_unfurling(service_name: nil, **)
          super(service_name: service_name || TenantService.current_service_name, **)
        end

        def create_before_direct_upload!(service_name: nil, **)
          super(service_name: service_name || TenantService.current_service_name, **)
        end
      end

      def install!
        configurations = Rails.application.config.active_storage.service_configurations || {}
        ActiveStorage::Blob.services = TenantRegistry.new(configurations)
        ActiveStorage::Blob.singleton_class.prepend(BlobStamping) unless
          ActiveStorage::Blob.singleton_class.include?(BlobStamping)
      end
    end
  end
end
