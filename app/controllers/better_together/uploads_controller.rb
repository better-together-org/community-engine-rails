# frozen_string_literal: true

module BetterTogether
  # CRUD for Uploads
  class UploadsController < FriendlyResourceController
    include Metrics::PlatformContext

    before_action :set_resource_instance, only: %i[show edit update destroy download]
    before_action :authorize_resource, only: %i[new show edit update destroy download]

    def download # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
      unless resource_instance.content_security_releasable?
        redirect_to (request.referrer || helpers.base_url), alert: t('resources.download_failed')
        return
      end

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

    # The scope lists a person's own files. An invoice or receipt is also fetched by the stewards of the sale, so for
    # the download alone an order document's upload is looked up too; the policy still decides who may have it.
    def handle_resource_not_found
      upload = Upload.where(id: Billing::OrderDocument.select(:upload_id)).find_by(id: id_param) if action_name == 'download'
      return super unless upload

      @resource = upload
      instance_variable_set("@#{resource_name}", upload)
    end

    def resource_class
      Upload
    end

    def resource_collection
      @resources ||= policy_scope(resource_class)
                     .includes(:content_security_subjects, file_attachment: :blob)

      instance_variable_set("@#{resource_name(plural: true)}", @resources)
    end

    def apply_download_cache_headers(upload)
      policy = BetterTogether::MediaCachePolicy.for_upload(upload)
      response.set_header('X-BTS-Cache-Scope', policy.cache_scope)
      return if policy.public?

      response.headers['Cache-Control'] = BetterTogether::MediaCachePolicy::PRIVATE_CACHE_CONTROL
    end
  end
end
