# frozen_string_literal: true

require 'rails_helper'

# Create the test table before defining TestSeedableClass so that
# ActiveRecord column introspection (triggered at class-definition time
# in Rails 7+) does not raise PG::UndefinedTable.
# Use if_not_exists: true so parallel workers don't fight over drop+recreate.
# The table is intentionally left in the DB after the suite runs — it is
# harmless and dropping it here would cause a race when multiple workers load
# this file simultaneously.
ActiveRecord::Base.connection.create_table(
  :better_together_test_seedable_classes,
  if_not_exists: true
) do |t|
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
