# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Community
    describe Agent, type: :model do
      class TestClass < ApplicationRecord
        include Agent
      end

      before(:all) do
        create_table(:better_together_community_test_classes) do |t|
          t.string :name
        end
      end
      after(:all) { drop_table(:better_together_community_test_classes) }

      describe TestClass, type: :model do
        it_behaves_like 'an agent'
      end
    end
  end
end
