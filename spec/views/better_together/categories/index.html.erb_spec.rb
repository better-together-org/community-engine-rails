# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'categories/index', type: :view do
  before(:each) do
    assign(:categories, [
             Category.create!,
             Category.create!
           ])
  end

  it 'renders a list of categories' do
    render
    'div>p'
  end
end
