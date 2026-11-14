# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seeds::SafeRichText do
  let(:event) { create(:better_together_event, description: '<p>Tree party details.</p>') }

  describe '.safe_body / .trix_html_for / .plain_text_for' do
    it 'returns the rendered body for well-formed content' do
      expect(described_class.safe_body(event, :description)).to be_a(ActionText::Content)
      expect(described_class.trix_html_for(event, :description)).to include('Tree party details')
      expect(described_class.plain_text_for(event, :description)).to include('Tree party details')
    end

    it 'returns nil for all three when there is no rich text at all' do
      blank_event = create(:better_together_event, description: nil)

      expect(described_class.safe_body(blank_event, :description)).to be_nil
      expect(described_class.trix_html_for(blank_event, :description)).to be_nil
      expect(described_class.plain_text_for(blank_event, :description)).to be_nil
    end

    context 'with a pathologically wrapped body (production incident shape)' do
      let(:wrapped_event) { create(:better_together_event, :with_pathologically_wrapped_description) }

      it 'never calls a recursive ActionText method -- returns nil from #safe_body without raising' do
        expect { described_class.safe_body(wrapped_event, :description) }.not_to raise_error
        expect(described_class.safe_body(wrapped_event, :description)).to be_nil
      end

      it 'flags the body as unsafe rather than absent' do
        expect(described_class.unsafe_body?(wrapped_event, :description)).to be true
      end

      it 'returns the truncation marker from trix_html_for and plain_text_for instead of raising' do
        expect { described_class.trix_html_for(wrapped_event, :description) }.not_to raise_error
        expect(described_class.trix_html_for(wrapped_event, :description)).to eq(described_class::TRUNCATED_MARKER)
        expect(described_class.plain_text_for(wrapped_event, :description)).to eq(described_class::TRUNCATED_MARKER)
      end

      it 'accepts a custom unsafe_marker' do
        expect(described_class.trix_html_for(wrapped_event, :description, unsafe_marker: 'nope')).to eq('nope')
      end
    end

    context 'with a body just past the wrapper-repeat threshold' do
      let(:borderline_event) do
        create(:better_together_event, :with_pathologically_wrapped_description,
               wrapper_repeats: described_class::MAX_WRAPPER_REPEATS + 1)
      end

      it 'is treated as unsafe' do
        expect(described_class.safe_body(borderline_event, :description)).to be_nil
        expect(described_class.unsafe_body?(borderline_event, :description)).to be true
      end
    end

    context 'with a body at or below the wrapper-repeat threshold' do
      let(:within_bound_event) do
        create(:better_together_event, :with_pathologically_wrapped_description,
               wrapper_repeats: described_class::MAX_WRAPPER_REPEATS)
      end

      it 'is treated as safe' do
        expect(described_class.safe_body(within_bound_event, :description)).to be_a(ActionText::Content)
        expect(described_class.unsafe_body?(within_bound_event, :description)).to be false
      end
    end

    it 'treats an oversized (but not wrapper-repeating) body as unsafe' do
      oversized_event = create(:better_together_event, description: '<p>filler</p>')
      oversized_event.rich_text_description.update_column(
        :body, "<p>#{'x' * (described_class::MAX_BYTESIZE + 1)}</p>"
      )

      expect(described_class.safe_body(oversized_event, :description)).to be_nil
      expect(described_class.unsafe_body?(oversized_event, :description)).to be true
    end
  end
end
