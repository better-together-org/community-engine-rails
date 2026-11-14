# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Api::V1::PostResource, '.creatable_fields' do
  let(:resource) { described_class }

  it 'accepts the cover image and attachment fields on create', :aggregate_failures do
    %i[cover_image_data cover_image_filename attachment_block_ids video_block_id].each do |field|
      expect(resource.creatable_fields({})).to include(field)
    end
  end

  it 'accepts the cover image on update but the featured video only on create', :aggregate_failures do
    expect(resource.updatable_fields({})).to include(:cover_image_data, :cover_image_filename, :attachment_block_ids)
    expect(resource.updatable_fields({})).not_to include(:video_block_id)
  end

  it 'never returns the write-only fields' do
    fields = resource.new(BetterTogether::Post.new, {}).fetchable_fields

    expect(fields).not_to include(:cover_image_data, :cover_image_filename, :attachment_block_ids, :video_block_id)
  end
end
