# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Api::V1::PageResource, '.creatable_fields' do
  let(:resource) { described_class }

  it 'accepts the feature image upload fields on create and update', :aggregate_failures do
    %i[feature_image_data feature_image_filename].each do |field|
      expect(resource.creatable_fields({})).to include(field)
      expect(resource.updatable_fields({})).to include(field)
    end
  end

  it 'exposes the url but never the write-only fields', :aggregate_failures do
    fields = resource.new(BetterTogether::Page.new, {}).fetchable_fields

    expect(fields).to include(:feature_image_url)
    expect(fields).not_to include(:feature_image_data, :feature_image_filename)
  end
end
