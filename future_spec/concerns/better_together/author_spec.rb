# frozen_string_literal: true

require 'rails_helper'

# Athor concern spec
module BetterTogether
  describe Author, type: :model do
    # rubocop:todo RSpec/LeakyConstantDeclaration
    class TestClass < ApplicationRecord # rubocop:todo Lint/ConstantDefinitionInBlock
      include Author
    end
    # rubocop:enable RSpec/LeakyConstantDeclaration

    before(:all) do # rubocop:todo RSpec/BeforeAfterAll
      create_table(:better_together_test_classes) do |t|
        t.string :name
      end
    end

    after(:all) { drop_table(:better_together_test_classes) } # rubocop:todo RSpec/BeforeAfterAll

    describe TestClass, type: :model do
      it_behaves_like 'an author model'
    end
  end
end
