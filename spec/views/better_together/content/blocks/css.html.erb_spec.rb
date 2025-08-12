# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/blocks/css', type: :view do
  it 'renders whitelisted properties' do
    css = BetterTogether::Content::Css.new(content: 'h1 { color: red; position: relative; z-index: 1; }')

    render partial: 'better_together/content/blocks/css', locals: { css: css }

    expect(rendered).to include('color: red')
    expect(rendered).to include('position: relative')
    expect(rendered).to include('z-index: 1')
    expect(rendered).not_to include('<style></style>')
  end

  it 'strips disallowed properties' do
    css = BetterTogether::Content::Css.new(content: 'h1 { color: red; float: left; }')

    render partial: 'better_together/content/blocks/css', locals: { css: css }

    expect(rendered).to include('color: red')
    expect(rendered).not_to include('float: left')
  end

  it 'rejects block when all rules disallowed' do
    css = BetterTogether::Content::Css.new(content: 'h1 { float: left; }')

    render partial: 'better_together/content/blocks/css', locals: { css: css }

    expect(rendered.strip).to be_empty
  end

  it 'preserves media queries while filtering properties' do
    css = BetterTogether::Content::Css.new(
      content: '@media only screen and (min-width: 768px) { h1 { font-size: 3em; float: left; } }'
    )

    render partial: 'better_together/content/blocks/css', locals: { css: css }

    expect(rendered).to include('@media only screen and (min-width: 768px)')
    expect(rendered).to include('font-size: 3em')
    expect(rendered).not_to include('float: left')
  end

  it 'allows custom properties' do
    css = BetterTogether::Content::Css.new(
      content: '.navbar { --bs-navbar-toggler-padding-x: 0.25rem; }'
    )

    render partial: 'better_together/content/blocks/css', locals: { css: css }

    expect(rendered).to include('--bs-navbar-toggler-padding-x: 0.25rem')
  end
end
