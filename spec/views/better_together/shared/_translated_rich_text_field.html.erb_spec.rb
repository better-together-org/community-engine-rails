# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/shared/_translated_rich_text_field' do
  it 'renders a trix-enabled rich text area for each locale' do
    post = build(:better_together_post)
    form_builder = ActionView::Helpers::FormBuilder.new(:better_together_post, post, view, {})

    view.singleton_class.define_method(:translation_tab_button) do |**_args|
      '<button type="button">English</button>'.html_safe
    end

    render partial: 'better_together/shared/translated_rich_text_field',
           locals: {
             model: post,
             form: form_builder,
             attribute: 'content'
           }

    expect(rendered).to include(%(data-better_together-translation-target="trix"))
  end
end
