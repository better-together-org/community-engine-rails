require 'rails_helper'

module BetterTogether
  describe AuthorableConcern, type: :model do

    class TestClass < ApplicationRecord
      include AuthorableConcern
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
