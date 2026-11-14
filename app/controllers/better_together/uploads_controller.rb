# frozen_string_literal: true

module BetterTogether
  # CRUD for Uploads
  class UploadsController < FriendlyResourceController
    include Metrics::PlatformContext

    SERVING_ACTIONS = %i[download inline].freeze
    # Types a browser can render without executing active content. Anything else
    # (HTML, SVG, scripts) is always sent as an attachment.
    INLINE_CONTENT_TYPES = %w[
      application/pdf image/png image/jpeg image/gif image/webp image/avif text/plain
    ].freeze

    before_action :set_resource_instance, only: %i[show edit update destroy download inline]
    before_action :authorize_resource, only: %i[new show edit update destroy download inline]

    def download
      serve_file(disposition: 'attachment')
    end

    # Renders the file in the browser (for example a PDF in the viewer) instead of forcing a download.
    def inline
      serve_file(disposition: 'inline')
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

    # Serving actions look the file up on the current platform and leave the
    # privacy decision to UploadPolicy#download?, so public files reach guests.
    def set_resource_instance
      return super unless SERVING_ACTIONS.include?(action_name.to_sym)

      platform = BetterTogether::PlatformRecordPolicy.resolve_current_platform
      @resource ||= platform && Upload.where(platform_id: platform.id).find_by(id: id_param)
      @resource.nil? ? handle_resource_not_found : @resource
    end

    def serve_file(disposition:)
      return redirect_with_serving_alert unless resource_instance.content_security_releasable?
      return redirect_with_serving_alert(:download_failed) unless resource_instance.attached?

      blob = resource_instance.file.blob
      apply_serving_headers(blob)
      return if performed?

      track_download
      stream_blob(blob, disposition)
    end

    # Sets cache headers; a public file also answers conditional requests with 304.
    def apply_serving_headers(blob)
      response.headers['X-Content-Type-Options'] = 'nosniff'
      return unless public_file?

      expires_in 1.day, public: true, stale_while_revalidate: 1.week
      head :not_modified if validators_fresh?(blob)
    end

    # Not fresh_when: its etag also mixes in per-request controller etaggers, so it never matches.
    def validators_fresh?(blob)
      response.etag = blob.checksum
      response.last_modified = blob.created_at
      request.fresh?(response)
    end

    def content_disposition(blob, disposition)
      disposition = 'attachment' unless disposition == 'inline' && INLINE_CONTENT_TYPES.include?(blob.content_type)
      ActionDispatch::Http::ContentDisposition.format(disposition:, filename: blob.filename.sanitized)
    end

    def stream_blob(blob, disposition)
      response.headers.merge!(
        'Content-Disposition' => content_disposition(blob, disposition), 'Content-Type' => blob.content_type,
        'Content-Length' => blob.byte_size.to_s, 'Accept-Ranges' => 'none'
      )
      self.response_body = Enumerator.new { |yielder| blob.download { |chunk| yielder << chunk } }
    end

    def track_download
      BetterTogether::Metrics::TrackDownloadJob.perform_later(
        resource_instance, resource_instance.filename.to_s, resource_instance.content_type,
        resource_instance.byte_size, I18n.locale.to_s, metrics_platform.id, metrics_logged_in?
      )
    end

    def redirect_with_serving_alert(key = nil)
      key ||= resource_instance.file_content_security_held? ? :download_held : :download_failed
      redirect_to (request.referrer || helpers.base_url), alert: t("resources.#{key}")
    end

    def resource_collection
      @resources ||= policy_scope(resource_class)
                     .includes(:content_security_subjects, file_attachment: :blob)

      instance_variable_set("@#{resource_name(plural: true)}", @resources)
    end

    def public_file?
      policy = BetterTogether::MediaCachePolicy.for_upload(resource_instance)
      response.set_header('X-BTS-Cache-Scope', policy.cache_scope)
      response.headers['Cache-Control'] = BetterTogether::MediaCachePolicy::PRIVATE_CACHE_CONTROL unless policy.public?
      policy.public?
    end
  end
end
