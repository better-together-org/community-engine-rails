# frozen_string_literal: true

require 'rails_helper'

# Authorable conern specs
module BetterTogether
  describe Authorable, type: :model do
    class TestClass < ApplicationRecord # rubocop:todo Lint/ConstantDefinitionInBlock
      include Authorable
    end

    before(:all) do
      create_table(:better_together_test_classes) do |t|
        t.string :name
      end
    end

    after(:all) { drop_table(:better_together_test_classes) }

    describe TestClass, type: :model do
      it_behaves_like 'an authorable model'
    end
  end
end
