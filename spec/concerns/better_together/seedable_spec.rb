# frozen_string_literal: true

require 'rails_helper'

# Create the test table before defining TestSeedableClass so that
# ActiveRecord column introspection (triggered at class-definition time
# in Rails 7+) does not raise PG::UndefinedTable.
ActiveRecord::Base.connection.create_table(:better_together_test_seedable_classes, force: :cascade) do |t|
  t.string :name
  t.timestamps null: false
end

module BetterTogether
  describe Seedable, type: :model do
    # Define a test ActiveRecord model inline for this spec
    # rubocop:todo RSpec/LeakyConstantDeclaration
    class TestSeedableClass < ApplicationRecord # rubocop:todo Lint/ConstantDefinitionInBlock
      include Seedable
    end
    # rubocop:enable RSpec/LeakyConstantDeclaration

    after(:all) do # rubocop:todo RSpec/BeforeAfterAll
      ActiveRecord::Base.connection.drop_table(:better_together_test_seedable_classes, if_exists: true)
    end

    describe TestSeedableClass, type: :model do
      FactoryBot.define do
        factory 'better_together/test_seedable_class', class: '::BetterTogether::TestSeedableClass' do
          sequence(:name) { |n| "Test seedable #{n}" }
        end
      end
      it_behaves_like 'a seedable model'
    end
  end
end
