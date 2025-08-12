# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/content/blocks/css', type: :view do
  it 'renders whitelisted properties' do
    css = BetterTogether::Content::Css.new(content: 'h1 { color: red; }')

    render partial: 'better_together/content/blocks/css', locals: { css: css }

    expect(rendered).to include('color: red')
    expect(rendered).not_to include('<style></style>')
  end

  it 'strips disallowed properties' do
    css = BetterTogether::Content::Css.new(content: 'h1 { color: red; position: absolute; }')

    render partial: 'better_together/content/blocks/css', locals: { css: css }

    expect(rendered).to include('color: red')
    expect(rendered).not_to include('position: absolute')
  end

  it 'rejects block when all rules disallowed' do
    css = BetterTogether::Content::Css.new(content: 'h1 { position: absolute; }')

    render partial: 'better_together/content/blocks/css', locals: { css: css }

    expect(rendered.strip).to be_empty
  end

  it 'preserves media queries while filtering properties' do
    css = BetterTogether::Content::Css.new(
      content: '@media only screen and (min-width: 768px) { h1 { font-size: 3em; position: absolute; } }'
    )

    render partial: 'better_together/content/blocks/css', locals: { css: css }

    expect(rendered).to include('@media only screen and (min-width: 768px)')
    expect(rendered).to include('font-size: 3em')
    expect(rendered).not_to include('position: absolute')
  end
end
