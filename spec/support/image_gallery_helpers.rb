# frozen_string_literal: true

# Builds a public page that renders the shared image gallery helper through a Template block.
module ImageGalleryHelpers
  GALLERY_TEMPLATE = 'better_together/test_support/gallery'
  GALLERY_FILES = %w[unsplash-community-1.jpeg unsplash-community-2.jpeg unsplash-collaborate-1.jpeg
                     unsplash-collaborate-2.jpeg].freeze

  # Identifiers and slugs carry a per-call token because feature specs leave committed rows behind.
  def build_gallery_page(files: GALLERY_FILES)
    @gallery_token = SecureRandom.hex(4)
    unless BetterTogether::Content::Template.available_templates.include?(GALLERY_TEMPLATE)
      BetterTogether::Content::Template.available_templates += [GALLERY_TEMPLATE]
    end
    create_gallery_images(files)
    page = create(:better_together_page, slug: "gallery-spec-page-#{@gallery_token}", title: 'Harbour gallery', privacy: 'public',
                                         published_at: 1.day.ago, show_title: true)
    block = BetterTogether::Content::Template.create!(template_path: GALLERY_TEMPLATE, privacy: 'public')
    page.page_blocks.create!(block:, position: 0)
    page
  end

  def gallery_params(layout = 'grid')
    { gallery_token: @gallery_token, gallery_layout: layout }
  end

  def create_gallery_images(files)
    root = BetterTogether::Engine.root.join('app/assets/images/better_together')
    files.each_with_index do |file, index|
      image = build(:better_together_content_image, identifier: "gallery-spec-#{@gallery_token}-#{index}",
                                                    alt_text: "Harbour view #{index + 1}",
                                                    caption: "Harbour caption #{index + 1}")
      image.media.attach(io: File.open(root.join(file)), filename: file, content_type: 'image/jpeg')
      image.save!
      image.media.blob.analyze
    end
  end
end
