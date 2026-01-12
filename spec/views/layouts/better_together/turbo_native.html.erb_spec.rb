# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'layouts/better_together/turbo_native' do
  before do
    view.extend BetterTogether::ApplicationHelper

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
      host_platform: double(name: 'Platform', cache_key_with_version: '1', css_block: nil),
      open_graph_meta_tags: '',
      seo_meta_tags: '',
      javascript_importmap_tags: '',
      stylesheet_link_tag: '',
      csrf_meta_tags: '',
      csp_meta_tag: '',
      hreflang_links: '<link rel="alternate" hreflang="en" href="/en" />'.html_safe
    )
    allow(view).to receive(:url_for).with(only_path: false).and_return('http://test.host/current')
  end

  it 'renders canonical and hreflang links by default' do
    render template: 'layouts/better_together/turbo_native'

    expect(rendered).to match(%r{<link[^>]+rel="canonical"[^>]+href="http://test.host/current"[^>]*>})
    expect(rendered).to include('<link rel="alternate" hreflang="en" href="/en" />')
  end

  it 'renders custom hreflang links when content_for provided' do
    view.content_for :hreflang_links, '<link rel="alternate" hreflang="fr" href="/fr" />'.html_safe

    render template: 'layouts/better_together/turbo_native'

    expect(rendered).to include('<link rel="alternate" hreflang="fr" href="/fr" />')
    expect(rendered).not_to include('<link rel="alternate" hreflang="en" href="/en" />')
  end
end
