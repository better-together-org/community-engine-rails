# frozen_string_literal: true

module BetterTogether
  module Content
    # Shows an ordered set of Content::Image blocks as a gallery, optionally with a lightbox.
    class ImageGalleryBlock < Block
      include Translatable

      LAYOUTS = %w[grid masonry].freeze

      translates :heading, type: :string

      store_attributes :content_data do
        image_ids String, default: ''
        layout String, default: 'grid'
        lightbox String, default: 'true'
      end

      validates :layout, inclusion: { in: LAYOUTS }

      def self.extra_permitted_attributes
        super + %i[image_ids layout lightbox heading]
      end

      def lightbox?
        lightbox.to_s == 'true'
      end

      # Ordered image ids, from a JSON array or a comma separated list.
      def parsed_image_ids
        return [] if image_ids.blank?

        Array(JSON.parse(image_ids)).map(&:to_s)
      rescue JSON::ParserError
        image_ids.split(',').map(&:strip).compact_blank
      end

      # Images in the configured order; ids that no longer resolve are skipped.
      def images
        ids = parsed_image_ids
        return [] if ids.empty?

        found = BetterTogether::Content::Image.where(id: ids).includes(media_attachment: :blob).index_by(&:id)
        ids.filter_map { |id| found[id] }
      end
    end
  end
end
