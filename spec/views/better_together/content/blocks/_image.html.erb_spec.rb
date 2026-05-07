# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/blocks/_image.html.erb' do
  before do
    configure_host_platform
  end

  it 'uses the shared proxy helper for block media images' do
    image = create(:better_together_content_image, caption: nil, attribution: nil)

    view.define_singleton_method(:content_actions_visible_for?) do |_block|
      false
    end

    allow(view).to receive(:storage_proxy_url_for).with(image.media).and_return(
      'http://test.host/rails/active_storage/proxy/content-image'
    )

    render partial: 'better_together/content/blocks/image', locals: { image: }

    expect(rendered).to include('http://test.host/rails/active_storage/proxy/content-image')
  end
end
