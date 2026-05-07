# frozen_string_literal: true

module BetterTogether
  # CRUD for Uploads
  class UploadsController < FriendlyResourceController
    include Metrics::PlatformContext

    before_action :set_resource_instance, only: %i[show edit update destroy download]
    before_action :authorize_resource, only: %i[new show edit update destroy download]

    def download # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      if resource_instance.attached?
        apply_download_cache_headers(resource_instance)

        # Trigger the background job to log the download
        BetterTogether::Metrics::TrackDownloadJob.perform_later(
          resource_instance,                                # Polymorphic resource model
          resource_instance.filename.to_s,                  # Filename
          resource_instance.content_type,                   # File type (content type)
          resource_instance.byte_size,                      # File size
          I18n.locale.to_s,                                 # Locale
          metrics_platform.id,
          metrics_logged_in?
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

<<<<<<< bugfix/release-0.11.0-notes-2026-05-06
    def resource_collection
      @resources ||= policy_scope(resource_class)
                     .includes(:content_security_subjects, file_attachment: :blob)

      instance_variable_set("@#{resource_name(plural: true)}", @resources)
=======
    def apply_download_cache_headers(upload)
      policy = BetterTogether::MediaCachePolicy.for_upload(upload)
      response.set_header('X-BTS-Cache-Scope', policy.cache_scope)
      return if policy.public?

      response.headers['Cache-Control'] = BetterTogether::MediaCachePolicy::PRIVATE_CACHE_CONTROL
>>>>>>> release/0.11.0-notes
    end
  end
end
