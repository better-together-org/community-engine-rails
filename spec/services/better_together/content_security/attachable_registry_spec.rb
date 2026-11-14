# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::AttachableRegistry do
  after { described_class.reset! }

  it 'allows only registered classes, once each', :aggregate_failures do
    described_class.register('BetterTogether::Content::Image', 'BetterTogether::Content::Image')
    image = BetterTogether::Content::Image.new

    expect(described_class.class_names).to eq(['BetterTogether::Content::Image'])
    expect(described_class.allowed?(image)).to be(true)
    expect(described_class.allowed?(BetterTogether::Content::Css.new)).to be(false)
  end

  it 'renders a registered block only while it is public and visible', :aggregate_failures do
    described_class.register('BetterTogether::Content::Image')
    block = instance_double(BetterTogether::Content::Image, privacy_public?: false, visible?: true)
    allow(block).to receive(:class).and_return(BetterTogether::Content::Image)

    expect(described_class.renderable?(block)).to be(false)
  end
end
