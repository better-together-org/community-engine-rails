# frozen_string_literal: true

module BetterTogether
  module Content
    # Links an Upload as a titled download with its type and size.
    class FileDownloadBlock < Block
      include Translatable

      translates :label, type: :string
      translates :description, type: :text

      store_attributes :content_data do
        upload_id String, default: ''
        open_inline String, default: 'false'
      end

      validates :upload_id, presence: true

      def self.extra_permitted_attributes
        super + %i[upload_id open_inline label description]
      end

      def open_inline?
        open_inline.to_s == 'true'
      end

      def upload
        return nil if upload_id.blank?

        BetterTogether::Upload.find_by(id: upload_id)
      end

      # Block label, falling back to the upload's own name, then its filename.
      def display_label
        label.presence || upload&.name.presence || upload&.filename.to_s
      end
    end
  end
end
