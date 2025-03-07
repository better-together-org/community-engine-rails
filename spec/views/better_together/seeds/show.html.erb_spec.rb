# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'seeds/show', type: :view do
  before(:each) do
    assign(:seed, create(:better_together_seed))
  end

  it 'renders attributes in <p>' do
    # render
  end
end
