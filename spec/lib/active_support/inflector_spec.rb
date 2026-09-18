# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActiveSupport::Inflector do
  it 'camelizes dsl to the DSL namespace' do
    expect(described_class.camelize('dsl')).to eq('DSL')
  end

  it 'camelizes jsonapi to the JSONAPI namespace' do
    expect(described_class.camelize('jsonapi')).to eq('JSONAPI')
  end
end
