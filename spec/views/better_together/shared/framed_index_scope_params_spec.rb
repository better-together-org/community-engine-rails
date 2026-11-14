# frozen_string_literal: true

require 'rails_helper'

# A host scopes a framed index by something other than a community through two hooks on the controller
# (FramedIndex#index_scope_params and #index_heading); the filter forms must keep those params.
RSpec.describe 'Framed index scope params' do # rubocop:disable RSpec/DescribeClass
  let(:scope_params) { { settlement: 'corner-brook' } }

  before do
    params = scope_params
    view.extend(Module.new do
      define_method(:index_scope_params) { params }
      define_method(:index_frame_id) { nil }
      define_method(:scoped_community) { nil }
      define_method(:events_path) { |**query| "/events?#{query.to_query}" }
      define_method(:posts_path) { |**query| "/posts?#{query.to_query}" }
    end)
  end

  {
    'events' => 'events-filter-sidebar',
    'posts' => 'posts-filter-sidebar'
  }.each do |resource, form_class|
    context "with the #{resource} filter form" do
      it 'keeps the scope params in the form action and as hidden fields', :aggregate_failures do
        render partial: "better_together/#{resource}/list_form"

        form = Capybara.string(rendered).find("form.#{form_class}")
        expect(form[:action]).to eq("/#{resource}?settlement=corner-brook")
        expect(form).to have_field('settlement', type: :hidden, with: 'corner-brook')
      end

      it 'adds nothing when the host sets no scope params', :aggregate_failures do
        view.extend(Module.new { def index_scope_params = {} })
        render partial: "better_together/#{resource}/list_form"

        form = Capybara.string(rendered).find("form.#{form_class}")
        expect(form[:action]).to eq("/#{resource}?")
        expect(form).not_to have_field('settlement', type: :hidden)
      end
    end
  end
end
