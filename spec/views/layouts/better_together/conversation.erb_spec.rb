# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'layouts/better_together/conversation' do
  before do
    view.extend BetterTogether::ApplicationHelper
    host_platform = double(name: 'Platform', url: 'http://test.host', cache_key_with_version: '1', css_block: nil)
    host_community = double(
      name: 'Community',
      description: nil,
      logo: double(attached?: false),
      persisted?: false
    )

    allow(view).to receive(:metrics_body_tag).and_yield
    allow(view).to receive(:render).and_call_original
    allow(view).to receive(:render).with('layouts/better_together/custom_head_javascript').and_return('')
    allow(view).to receive(:render).with('layouts/better_together/custom_stylesheets').and_return('')
    allow(view).to receive(:render).with('layouts/better_together/header').and_return('')
    allow(view).to receive(:render).with('layouts/better_together/flash_messages').and_return('')
    allow(view).to receive(:render).with('layouts/better_together/extra_page_content_bottom').and_return('')
    allow(view).to receive(:render).with('layouts/better_together/footer').and_return('')
    allow(view).to receive(:render).with('layouts/better_together/custom_body_javascript').and_return('')
    allow(view).to receive_messages(
      host_platform: host_platform,
      host_community: host_community,
      open_graph_meta_tags: '',
      seo_meta_tags: '',
      javascript_importmap_tags: '',
      stylesheet_link_tag: '',
      csrf_meta_tags: '',
      csp_meta_tag: '',
      hreflang_links: '<link rel="alternate" hreflang="en" href="/en" />'.html_safe,
      request: double(original_url: 'http://test.host/current')
    )
    allow(view).to receive(:url_for).with(only_path: false).and_return('http://test.host/current')
    allow(view).to receive(:base_url).and_return('http://test.host')
    allow(view).to receive_messages(stimulus_debug_enabled?: false, robots_meta_tag: '', sitemap_index_path: '/sitemap.xml',
                                    sitemap_path: '/sitemap.xml')
  end

  it 'does not include remote CDN stylesheet links' do
    render template: 'layouts/better_together/conversation'

    expect(rendered).not_to include('https://unpkg.com/trix')
    expect(rendered).not_to include('https://cdnjs.cloudflare.com/ajax/libs/slim-select')
    expect(rendered).not_to include('https://unpkg.com/leaflet')
  end
end
