# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'seeds/index', type: :view do
  before(:each) do
    assign(:seeds, [
             create(:better_together_seed),
             create(:better_together_seed)
           ])
  end

  it 'renders a list of seeds' do
    # render
    # cell_selector = 'div>p'
  end
end
