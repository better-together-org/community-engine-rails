# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Simple Test', type: :request do
  it 'should work' do
    expect(1 + 1).to eq(2)
  end
end
