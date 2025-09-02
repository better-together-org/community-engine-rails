# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  describe FriendlySlug do
    # rubocop:todo RSpec/LeakyConstantDeclaration
    class TestClass < ApplicationRecord # rubocop:todo Lint/ConstantDefinitionInBlock
      include FriendlySlug
    end
    # rubocop:enable RSpec/LeakyConstantDeclaration

    describe TestClass do
      it_behaves_like 'a friendly slugged record'
      # it_behaves_like 'a translatable record'
    end
  end
end
