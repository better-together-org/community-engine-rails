# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'seeds/index' do
  before do
    assign(:seeds, [
             create(:better_together_seed),
             create(:better_together_seed)
           ])
  end

  it 'renders a list of seeds' do # rubocop:todo RSpec/NoExpectationExample
    # render
    # cell_selector = 'div>p'
  end
end
