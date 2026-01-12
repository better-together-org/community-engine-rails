# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  describe Identity, type: :model do
    # rubocop:todo RSpec/LeakyConstantDeclaration
    class TestClass < ApplicationRecord # rubocop:todo Lint/ConstantDefinitionInBlock
      include Identity
    end
    # rubocop:enable RSpec/LeakyConstantDeclaration

    before do
      # Create test table for each example to ensure parallel_tests compatibility
      unless ActiveRecord::Base.connection.table_exists?(:better_together_test_classes)
        create_table(:better_together_test_classes) do |t|
          t.string :name
        end
      end
      # Reset the table connection to ensure ActiveRecord recognizes the new table
      TestClass.reset_column_information
    end

    after do
      # Clean up test table after each example
      drop_table(:better_together_test_classes) if ActiveRecord::Base.connection.table_exists?(:better_together_test_classes)
    end

    describe TestClass, type: :model do
      it_behaves_like 'an identity'
    end
  end
end
