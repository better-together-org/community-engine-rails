# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Api::V1::CommunityResource, '.creatable_fields' do
  let(:resource) { described_class }
  let(:fields) do
    %i[logo_data logo_filename cover_image_data cover_image_filename profile_image_data profile_image_filename
       address_spec contact_spec]
  end

  it 'accepts the image and contact fields on create and update', :aggregate_failures do
    expect(resource.creatable_fields({})).to include(*fields)
    expect(resource.updatable_fields({})).to include(*fields)
  end

  it 'never returns the write-only fields', :aggregate_failures do
    expect(resource.new(BetterTogether::Community.new, {}).fetchable_fields).not_to include(*fields)
  end

  describe 'attaching images' do
    let(:png) do
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
    end

    it 'attaches a logo and a cover from base64', :aggregate_failures do
      community = create(:better_together_community, logo_data: png, cover_image_data: png)

      expect(community.logo).to be_attached
      expect(community.cover_image).to be_attached
      expect(community.logo_data).to be_nil
    end

    it 'rejects data that is not an image', :aggregate_failures do
      community = build(:better_together_community, logo_data: Base64.strict_encode64('not an image'))

      expect(community).not_to be_valid
      expect(community.errors[:logo_data]).to be_present
    end
  end
end
