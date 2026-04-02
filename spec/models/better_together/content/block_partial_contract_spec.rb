# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content::Block, type: :model do
  before(:all) do
    described_class.load_all_subclasses
  end

  let(:engine_root) { BetterTogether::Engine.root }
  let(:block_classes) { described_class.descendants.select(&:content_addable?).sort_by(&:name) }

  def partial_candidates_for(prefix, block_name)
    Dir.glob(engine_root.join("app/views/#{prefix}/_#{block_name}.*").to_s)
  end

  it 'ships every required partial for each addable block type' do
    missing_partials = block_classes.each_with_object({}) do |klass, missing|
      block_name = klass.block_name
      missing_paths = {
        display: partial_candidates_for('better_together/content/blocks', block_name),
        fields: partial_candidates_for('better_together/content/blocks/fields', block_name),
        new_picker: partial_candidates_for('better_together/content/blocks/new', block_name),
        page_block_picker: partial_candidates_for('better_together/content/page_blocks/block_types', block_name)
      }.select { |_kind, candidates| candidates.empty? }

      missing[klass.name] = missing_paths.keys if missing_paths.any?
    end

    expect(missing_partials).to eq({})
  end
end
