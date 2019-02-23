require 'rails_helper'

module BetterTogether
  module Core
    describe FriendlySlug do
      class TestClass < ApplicationRecord
        include FriendlySlug
      end

      describe TestClass do
        it_behaves_like 'a friendly slugged record'
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
