# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Positioned do # rubocop:disable RSpec/SpecFilePathFormat
  before do
    # Create a temporary table for testing with minimal columns we need
    ActiveRecord::Base.connection.create_table :positioned_tests, force: true do |t|
      t.integer :position
      t.integer :parent_id
      t.timestamps null: false
    end

    Object.const_set(:PositionedTest, Class.new(ActiveRecord::Base) do
      self.table_name = 'positioned_tests'
      include BetterTogether::Positioned

      # pretend this model uses a parent_id scope for positions
      def position_scope
        :parent_id
      end
    end)
  end

  after do
    ActiveRecord::Base.connection.drop_table :positioned_tests, if_exists: true
    # rubocop:todo RSpec/RemoveConst
    Object.send(:remove_const, :PositionedTest) if Object.const_defined?(:PositionedTest)
    # rubocop:enable RSpec/RemoveConst
  end

  it 'treats blank scope values as nil when computing max position' do # rubocop:disable RSpec/ExampleLength
    # Ensure there are two existing top-level records (parent_id = nil)
    PositionedTest.create!(position: 0)
    PositionedTest.create!(position: 1)

    # New record with blank string parent_id (as from a form) should be treated as top-level
    new_rec = PositionedTest.new
    new_rec['parent_id'] = ''
    # set_position should place it after existing top-level items (position 2)
    new_rec.set_position
    expect(new_rec.position).to eq(2)
  end

  it 'uses the exact scope value when provided (non-blank)' do # rubocop:disable RSpec/ExampleLength
    # Create items under parent_id = 5
    PositionedTest.create!(parent_id: 5, position: 0)
    PositionedTest.create!(parent_id: 5, position: 1)

    new_child = PositionedTest.new
    new_child.parent_id = 5
    new_child.set_position
    expect(new_child.position).to eq(2)
  end
end
