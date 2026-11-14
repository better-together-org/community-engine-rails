# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/pages/_page.html.erb' do
  before do
    configure_host_platform
  end

  it 'uses the shared proxy helper for attached primary images' do
    page = create(:better_together_page, title: 'Proxy Page')
    primary_image = double(attached?: true)

    allow(page).to receive(:primary_image).and_return(primary_image)
    allow(view).to receive(:policy).with(page).and_return(double(show?: true))
    allow(view).to receive(:render_page_path).with(page).and_return('/pages/proxy-page')
    allow(view).to receive(:storage_proxy_url_for).with(primary_image).and_return(
      'http://test.host/rails/active_storage/proxy/page-primary-image'
    )

    render partial: 'better_together/pages/page', locals: { page: }

    expect(rendered).to include('http://test.host/rails/active_storage/proxy/page-primary-image')
  end
end
