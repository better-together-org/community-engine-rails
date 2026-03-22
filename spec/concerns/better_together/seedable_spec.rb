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
      # Create the test table inside before(:context) so it runs in the same
      # worker process and connection context as the examples. if_not_exists: true
      # makes it idempotent across parallel workers. reset_column_information
      # ensures AR picks up columns that may have been cached before table existed.
      before(:context) do # rubocop:disable RSpec/BeforeAfterAll
        ActiveRecord::Base.connection.create_table(
          :better_together_test_seedable_classes,
          if_not_exists: true
        ) do |t|
          t.string :name
          t.timestamps null: false
        end
        described_class.reset_column_information
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
