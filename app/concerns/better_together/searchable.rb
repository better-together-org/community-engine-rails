# frozen_string_literal: true

# app/models/concerns/searchable.rb

module BetterTogether
  # Enables ElasticSearch
  module Searchable
    extend ActiveSupport::Concern

    included do
      include Elasticsearch::Model
      include Elasticsearch::Model::Callbacks

      after_commit :index_document, if: :persisted?
      after_commit on: [:destroy] do
        __elasticsearch__.delete_document
      end

      # Need to create another way to access elasticsearch import.
      # class.import is using by activerecord-import, I think
      def self.elastic_import args={}
        __elasticsearch__.import(args)
      end
    end

    private

    def index_document
      __elasticsearch__.index_document
    end
  end
end
