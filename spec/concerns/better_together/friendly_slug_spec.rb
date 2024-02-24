# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  describe FriendlySlug do
    class TestClass < ApplicationRecord # rubocop:todo Lint/ConstantDefinitionInBlock
      include FriendlySlug
    end

    describe TestClass do
      it_behaves_like 'a friendly slugged record'
      # it_behaves_like 'a translatable record'
    end

    describe 'ActiveRecord associations' do # rubocop:todo Lint/EmptyBlock
    end

    describe 'ActiveModel validations' do # rubocop:todo Lint/EmptyBlock
    end

    describe 'callbacks' do # rubocop:todo Lint/EmptyBlock
    end
  end
end
