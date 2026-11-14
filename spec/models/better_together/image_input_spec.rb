# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ImageInput do
  let(:png) do
    Base64.strict_decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
  end

  it 'decodes an image and takes the type from the bytes', :aggregate_failures do
    result = described_class.decode(Base64.strict_encode64(png))

    expect(result.error).to be_nil
    expect(result.type).to eq('image/png')
    expect(result.bytes).to eq(png)
  end

  it 'rejects data that is not an allowed image' do
    expect(described_class.decode(Base64.strict_encode64('not an image')).error).to eq('must be a JPEG, PNG or WebP image')
  end

  it 'rejects invalid base64' do
    expect(described_class.decode('***').error).to eq('is not valid base64')
  end

  it 'rejects oversized images' do
    data = Base64.strict_encode64(png + ('0' * (described_class::MAX_BYTES + 1)))

    expect(described_class.decode(data).error).to include('too large')
  end

  it 'builds a safe filename' do
    expect(described_class.filename('../my ship!.png', 'image/png', 'image')).to eq('my_ship_.png')
    expect(described_class.filename(nil, 'image/png', 'image')).to eq('image.png')
  end
end
