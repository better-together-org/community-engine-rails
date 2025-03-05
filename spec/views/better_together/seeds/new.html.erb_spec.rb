# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'seeds/new', type: :view do
  before(:each) do
    assign(:seed, build(:better_together_seed))
  end

  it 'renders new seed form' do
    # render

    # assert_select "form[action=?][method=?]", seeds_path, "post" do
    # end
  end
end
