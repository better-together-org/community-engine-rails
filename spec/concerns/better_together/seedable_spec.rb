# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  describe Seedable, type: :model do
    # Define a test ActiveRecord model inline for this spec
    # rubocop:todo RSpec/LeakyConstantDeclaration
    class TestSeedableClass < ApplicationRecord # rubocop:todo Lint/ConstantDefinitionInBlock
      include Seedable
    end
    # rubocop:enable RSpec/LeakyConstantDeclaration

    describe TestSeedableClass, type: :model do
      # Create the test table before each example with a table_exists? guard so
      # it is idempotent. before(:context) is unreliable in parallel workers
      # because the connection used there may differ from the example's connection.
      before do
        unless ActiveRecord::Base.connection.table_exists?(:better_together_test_seedable_classes)
          ActiveRecord::Base.connection.create_table(
            :better_together_test_seedable_classes
          ) do |t|
            t.string :name
            t.timestamps null: false
          end
          described_class.reset_column_information
        end
      end

      FactoryBot.define do
        factory 'better_together/test_seedable_class', class: '::BetterTogether::TestSeedableClass' do
          sequence(:name) { |n| "Test seedable #{n}" }
        end
      end
      it_behaves_like 'a seedable model'
    end
  end
end
