# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ApplicationHelper, type: :helper do
  around do |example|
    original_providers = BetterTogether.head_tag_providers.dup
    BetterTogether.head_tag_providers = {}
    example.run
  ensure
    BetterTogether.head_tag_providers = original_providers
  end

  it 'renders registered provider fragments in order' do
    BetterTogether.register_head_tag_provider(:first, ->(_view_context) { '<meta name="first" />'.html_safe })
    BetterTogether.register_head_tag_provider(:second, ->(_view_context) { '<script src="/test.js"></script>'.html_safe })

    rendered = helper.render_provider_head_tags

    expect(rendered).to include('<meta name="first" />')
    expect(rendered).to include('<script src="/test.js"></script>')
  end

  it 'returns an empty safe buffer when no providers are registered' do
    rendered = helper.render_provider_head_tags

    expect(rendered).to eq('')
    expect(rendered).to be_html_safe
  end
end
