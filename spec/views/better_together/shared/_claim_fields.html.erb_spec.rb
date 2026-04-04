# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/shared/_claim_fields', type: :view do
  it 'renders selector helper controls for media-capable records' do
    page = build(:better_together_page)
    claim = page.claims.build
    form_builder = ActionView::Helpers::FormBuilder.new(:claim, claim, view, {})

    render partial: 'better_together/shared/claim_fields',
           locals: {
             claim_fields: form_builder,
             record: page,
             selector_datalist_id: 'page_selectors',
             selector_options: [
               { value: 'block:image:hero:media', label: 'Image media: Hero image' },
               { value: 'block:video:intro:video', label: 'Video embed: Intro video' }
             ]
           }

    expect(rendered).to include('data-controller="better_together--claim-selector"')
    expect(rendered).to include('Video Source')
    expect(rendered).to include('Image Source')
    expect(rendered).to include('block:image:hero:media')
    expect(rendered).to include('block:video:intro:video')
  end
end
