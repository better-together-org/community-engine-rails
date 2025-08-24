# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'seeds/edit' do
  let(:seed) do
    create(:better_together_seed)
  end

  before do
    assign(:seed, seed)
  end

  it 'renders the edit seed form' do
    # render

    # assert_select "form[action=?][method=?]", seed_path(seed), "post" do
    # end
  end
end
