# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'seeds/new' do
  before do
    assign(:seed, build(:better_together_seed))
  end

  it 'renders new seed form' do # rubocop:todo RSpec/NoExpectationExample
    # render

    # assert_select "form[action=?][method=?]", seeds_path, "post" do
    # end
  end
end
