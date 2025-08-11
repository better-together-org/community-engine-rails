# frozen_string_literal: true

module BetterTogether
  # CRUD for Uploads
  class UploadsController < FriendlyResourceController
    before_action :set_resource_instance, only: %i[show edit update destroy download]
    before_action :authorize_resource, only: %i[new show edit update destroy download]

    def index
      @total_size = policy_scope(Upload).sum(&:byte_size)
    end

    def download # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      if resource_instance.attached?
        # Trigger the background job to log the download
        BetterTogether::Metrics::TrackDownloadJob.perform_later(
          resource_instance,                                # Polymorphic resource model
          resource_instance.filename.to_s,                  # Filename
          resource_instance.content_type,                   # File type (content type)
          resource_instance.byte_size,                      # File size
          I18n.locale.to_s                                  # Locale
        )

        send_data resource_instance.download,
                  filename: resource_instance.filename.to_s,
                  type: resource_instance.content_type,
                  disposition: 'attachment'
      else
        redirect_to (request.referrer || helpers.base_url), alert: t('resources.download_failed')
      end
    end

    private

    def resource_class
      Upload
    end
  end
end
