# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Infrastructure do
  it 'defines the expected table name prefix' do
    expect(described_class.table_name_prefix).to eq('better_together_infrastructure_')
  end
end
