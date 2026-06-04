# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'layouts/better_together/application' do
  before do
    view.extend BetterTogether::ApplicationHelper
    host_platform = double(name: 'Platform', url: 'http://test.host', cache_key_with_version: '1', css_block: nil)
    host_community = double(
      name: 'Community',
      description: nil,
      logo: double(attached?: false),
      persisted?: false
    )

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
      request: double(original_url: 'http://test.host/current', user_agent: 'RSpec')
    )
    allow(view).to receive(:metrics_body_tag).and_yield
    allow(view).to receive(:url_for).with(only_path: false).and_return('http://test.host/current')
    allow(view).to receive(:render).and_call_original
    allow(view).to receive(:render).with('layouts/better_together/custom_head_javascript').and_return('')
    allow(view).to receive(:render).with('layouts/better_together/custom_stylesheets').and_return('')
    allow(view).to receive(:render).with('layouts/better_together/header').and_return('')
    allow(view).to receive(:render).with('layouts/better_together/flash_messages').and_return('')
    allow(view).to receive(:render).with('layouts/better_together/extra_page_content_bottom').and_return('')
    allow(view).to receive(:render).with('layouts/better_together/footer').and_return('')
    allow(view).to receive(:render).with('layouts/better_together/mobile_bar').and_return('')
    allow(view).to receive(:render).with('layouts/better_together/custom_body_javascript').and_return('')
    # Helpers / routes added to the layout on this branch:
    allow(view).to receive_messages(stimulus_debug_enabled?: false, robots_meta_tag: '', sitemap_index_path: '/sitemap.xml',
                                    sitemap_path: '/sitemap.xml')
    allow(view).to receive_messages(current_user: nil, base_url: 'http://test.host', e2ee_messaging_enabled?: false)
  end

  it 'renders canonical and hreflang links by default' do
    render template: 'layouts/better_together/application'

    expect(rendered).to match(%r{<link[^>]+rel="canonical"[^>]+href="http://test.host/current"[^>]*>})
    expect(rendered).to include('<link rel="alternate" hreflang="en" href="/en" />')
  end

  it 'renders custom hreflang links when content_for provided' do
    view.content_for :hreflang_links, '<link rel="alternate" hreflang="fr" href="/fr" />'.html_safe

    render template: 'layouts/better_together/application'

    expect(rendered).to include('<link rel="alternate" hreflang="fr" href="/fr" />')
    expect(rendered).not_to include('<link rel="alternate" hreflang="en" href="/en" />')
  end

  it 'does not mount E2EE bootstrap or modal in the global layout' do
    person = build_stubbed(:person)
    user = build_stubbed(:user, person: person)
    allow(view).to receive_messages(current_user: user, e2ee_messaging_enabled?: true, current_user_api_token: 'jwt-token')

    render template: 'layouts/better_together/application'

    expect(rendered).to include('meta name="current-user-token" content="jwt-token"')
    expect(rendered).not_to include('better-together--e2e-session')
    expect(rendered).not_to include('e2ePassphraseModal')
  end

  it 'does not include remote CDN stylesheet links' do
    render template: 'layouts/better_together/application'

    expect(rendered).not_to include('https://unpkg.com/trix')
    expect(rendered).not_to include('https://cdnjs.cloudflare.com/ajax/libs/slim-select')
    expect(rendered).not_to include('https://unpkg.com/leaflet')
  end
end
