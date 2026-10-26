# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::DefaultCoverImage do
  let(:probe_class) do
    Class.new(BetterTogether::Community) do
      self.inheritance_column = nil

      def self.name = 'DefaultCoverImageProbe'

      include BetterTogether::DefaultCoverImage
    end
  end

  let(:record) { probe_class.create!(attributes_for(:better_together_community)) }

  def attach_image(attachment, name, metadata: {})
    attachment.attach(io: StringIO.new("image-bytes-#{name}"), filename: "#{name}.jpg", content_type: 'image/jpeg',
                      metadata:)
  end

  it 'leaves the cover empty when no default is stored' do
    record.update!(remove_cover_image: '1')

    expect(record.reload.cover_image).not_to be_attached
  end

  it 'attaches a copy of the default as the cover once it is stored', :aggregate_failures do
    attach_image(record.default_cover_image, 'default')
    record.save!

    expect(record.reload.cover_image).to be_attached
    expect(record.cover_image.blob.id).not_to eq(record.default_cover_image.blob.id)
    expect(record.cover_image.download).to eq('image-bytes-default')
    expect(record).to be_generated_cover
  end

  it 'restores the default when an uploaded cover is detached', :aggregate_failures do
    attach_image(record.default_cover_image, 'default')
    attach_image(record.cover_image, 'upload')
    record.save!
    expect(record.reload).not_to be_generated_cover

    record.cover_image.detach
    record.save!

    expect(record.reload.cover_image.download).to eq('image-bytes-default')
    expect(record).to be_generated_cover
  end

  it 'does not replace an uploaded cover when saved again' do
    attach_image(record.default_cover_image, 'default')
    attach_image(record.cover_image, 'upload')
    record.save!
    blob_id = record.reload.cover_image.blob.id

    record.update!(name: 'Renamed community')

    expect(record.reload.cover_image.blob.id).to eq(blob_id)
  end
end
