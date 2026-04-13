# frozen_string_literal: true

module BetterTogether
  module Elasticsearch
    DEFAULT_MODEL_DOCUMENTS = {
      'BetterTogether::CallForInterest' => 'BetterTogether::Elasticsearch::Documents::CallForInterest',
      'BetterTogether::Checklist' => 'BetterTogether::Elasticsearch::Documents::Checklist',
      'BetterTogether::Community' => 'BetterTogether::Elasticsearch::Documents::Community',
      'BetterTogether::Content::Markdown' => 'BetterTogether::Elasticsearch::Documents::Content::Markdown',
      'BetterTogether::Content::RichText' => 'BetterTogether::Elasticsearch::Documents::Content::RichText',
      'BetterTogether::Content::Template' => 'BetterTogether::Elasticsearch::Documents::Content::Template',
      'BetterTogether::Event' => 'BetterTogether::Elasticsearch::Documents::Event',
      'BetterTogether::Joatu::Offer' => 'BetterTogether::Elasticsearch::Documents::Joatu::Offer',
      'BetterTogether::Joatu::Request' => 'BetterTogether::Elasticsearch::Documents::Joatu::Request',
      'BetterTogether::Page' => 'BetterTogether::Elasticsearch::Documents::Page',
      'BetterTogether::Post' => 'BetterTogether::Elasticsearch::Documents::Post'
    }.freeze

    mattr_accessor :model_documents, default: {}

    module_function

    def register_default_documents!
      DEFAULT_MODEL_DOCUMENTS.each do |model_name, concern_name|
        register_model_document(model_name:, concern_name:)
      end
    end

    def register_model_document(model_name:, concern_name:)
      self.model_documents = self.model_documents.merge(model_name => concern_name)
    end

    def apply_model_documents!
      model_documents.each do |model_name, concern_name|
        model = model_name.constantize
        concern = concern_name.constantize
        model.include(concern) unless model < concern
      end
    end

    def integrated_model?(model)
      model.respond_to?(:__elasticsearch__)
    end
  end
end
