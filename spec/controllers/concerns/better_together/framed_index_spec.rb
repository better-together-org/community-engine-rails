# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FramedIndex do # rubocop:disable RSpec/SpecFilePathFormat
  concern = described_class

  controller(ActionController::Base) do
    include concern

    def resource_class = BetterTogether::Event
  end

  it 'defaults to no extra scope params and the plural model name as heading', :aggregate_failures do
    expect(controller.send(:index_scope_params)).to eq({})
    expect(controller.send(:index_heading)).to eq(BetterTogether::Event.model_name.human.pluralize)
  end

  it 'exposes the hooks to views' do
    expect(controller._helper_methods).to include(:index_scope_params, :index_heading)
  end
end
