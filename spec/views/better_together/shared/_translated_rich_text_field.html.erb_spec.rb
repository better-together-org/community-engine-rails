# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'better_together/shared/_translated_rich_text_field', type: :view do
  it 'passes citation and selector options through to the trix editor data attributes' do
    post = build(:better_together_post)
    form_builder = ActionView::Helpers::FormBuilder.new(:better_together_post, post, view, {})
    view.singleton_class.define_method(:translation_tab_button) do |**_args|
      '<button type="button">English</button>'.html_safe
    end

    render partial: 'better_together/shared/translated_rich_text_field',
           locals: {
             model: post,
             form: form_builder,
             attribute: 'content',
             citation_options: [{ referenceKey: 'shared_reality', label: 'shared_reality: Shared Reality Source' }],
             selector_options: [{ value: 'block:markdown:intro', label: 'Block: markdown - intro' }]
           }

    expect(rendered).to include('data-citation-options="[{&quot;referenceKey&quot;:&quot;shared_reality&quot;,&quot;label&quot;:&quot;shared_reality: Shared Reality Source&quot;}]"')
    expect(rendered).to include('data-selector-options="[{&quot;value&quot;:&quot;block:markdown:intro&quot;,&quot;label&quot;:&quot;Block: markdown - intro&quot;}]"')
  end
end
