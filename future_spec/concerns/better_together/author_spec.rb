# frozen_string_literal: true

require 'rails_helper'

# Athor concern spec
module BetterTogether
  describe AuthorConcern, type: :model do
    class TestClass < ApplicationRecord # rubocop:todo Lint/ConstantDefinitionInBlock
      include AuthorConcern
    end

    before(:all) do
      create_table(:better_together_test_classes) do |t|
        t.string :name
      end
    end
    after(:all) { drop_table(:better_together_test_classes) }

    describe TestClass, type: :model do
      it_behaves_like 'an author model'
    end
  end
end
