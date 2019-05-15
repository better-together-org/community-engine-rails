require 'rails_helper'

module BetterTogether
  module Community
    describe Identity do

      class TestClass < ApplicationRecord
        include Identity
      end

      before(:all) do
        create_table(:better_together_community_test_classes) do |t|
          t.string :name
        end
      end
      after(:all) { drop_table(:better_together_community_test_classes) }



      describe TestClass do
        # it_behaves_like 'an identity'
      end

      describe 'ActiveRecord associations' do

      end

      describe 'ActiveModel validations' do
      end

      describe 'callbacks' do
      end
    end
  end
end
