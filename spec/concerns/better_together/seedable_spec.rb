# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  describe Seedable, type: :model do
    # Define a test ActiveRecord model inline for this spec
    class TestSeedableClass < ApplicationRecord # rubocop:todo Lint/ConstantDefinitionInBlock
      include Seedable
    end

    before(:all) do
      create_table(:better_together_test_seedable_classes) do |t|
        t.string :name
      end
    end

    after(:all) do
      drop_table(:better_together_test_seedable_classes)
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
