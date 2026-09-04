# frozen_string_literal: true

module BetterTogether
  module Seeds
    # Safe read access for Mobility ActionText-backed rich text attributes
    # (models using `translates :name, backend: :action_text`, e.g.
    # `Post#content`, `Page#content`, `Event#description`).
    #
    # `ActionText::RichText#to_s`, `#to_plain_text`, `#empty?`, `#present?`,
    # and `#blank?` all funnel through `ActionText::PlainTextConversion`'s
    # mutually recursive DOM walk, which has no nesting-depth limit. A rich
    # text body that has been repeatedly (and non-idempotently) re-wrapped in
    # its own render output -- `ActionText::Content#to_s` always adds one more
    # `<div class="trix-content">` layer around whatever body it's given, so a
    # read-then-save round trip via `#to_s` compounds every time -- can blow
    # the Ruby call stack (`SystemStackError`) the moment ANY of those methods
    # is called. Mobility's own attribute reader calls `#present?` internally,
    # so even `record.description`/`record.content` alone can crash before a
    # caller gets to choose how to serialize it.
    #
    # This module reads the raw, pre-deserialized column value first (a plain
    # string -- can't recurse) via the association Mobility itself generates,
    # bounds it with a cheap size/pattern check, and only builds/walks the
    # real `ActionText::Content` once that raw value has passed.
    module SafeRichText
      module_function

      # Bytes beyond which a rich text body is treated as untrustworthy for a
      # full recursive walk, regardless of wrapper pattern.
      MAX_BYTESIZE = 65_536
      # A render-wrapper string repeated more than this many times back to
      # back is itself the pathology (see the 381x <div class="trix-content">
      # incident this module exists to guard against) -- legitimate authored
      # content never contains its own render wrapper at all.
      MAX_WRAPPER_REPEATS = 5
      WRAPPER_NEEDLE = 'trix-content'
      TRUNCATED_MARKER = '[content omitted: exceeds safe export size]'

      # @param record [ActiveRecord::Base] a model with
      #   `translates :attribute, backend: :action_text`
      # @param attribute [Symbol, String] the translated attribute name
      #   (e.g. :description, :content)
      # @return [ActionText::Content, nil] the deserialized rich text body if
      #   present in the current locale AND within the safety bound;
      #   otherwise nil. Never triggers the Mobility reader or any recursive
      #   ActionText method.
      def safe_body(record, attribute)
        translation = translation_for(record, attribute)
        return unless translation

        raw = translation.body_before_type_cast.to_s
        return if raw.blank? || !safe_raw?(raw)

        translation.body
      end

      # @return [Boolean] true if `record` has a translation for `attribute`
      #   in the current locale whose raw body exists but failed the safety
      #   bound (content exists but was skipped, as opposed to not existing).
      def unsafe_body?(record, attribute)
        translation = translation_for(record, attribute)
        return false unless translation

        translation.body_before_type_cast.to_s.then { |raw| raw.present? && !safe_raw?(raw) }
      end

      # Clean HTML via `ActionText::Content#to_trix_html` (renders attachments
      # without going through `#to_s`'s wrapping-by-render-layout path), or
      # `unsafe_marker` if a body exists but failed the safety bound, or nil
      # if there's no body at all.
      def trix_html_for(record, attribute, unsafe_marker: TRUNCATED_MARKER)
        body = safe_body(record, attribute)
        return body.to_trix_html if body

        unsafe_marker if unsafe_body?(record, attribute)
      end

      # Same fallback shape as `trix_html_for`, for plain-text excerpts.
      def plain_text_for(record, attribute, unsafe_marker: TRUNCATED_MARKER)
        body = safe_body(record, attribute)
        return body.to_plain_text if body

        unsafe_marker if unsafe_body?(record, attribute)
      end

      def safe_raw?(raw_html)
        raw_html.bytesize <= MAX_BYTESIZE && raw_html.scan(WRAPPER_NEEDLE).size <= MAX_WRAPPER_REPEATS
      end

      # Deliberately NOT `record.public_send(:"rich_text_#{attribute}")` (the
      # has_one reader Mobility's ActionText backend generates). ActionText::
      # RichText overrides `#nil?` (delegates it to `#body`,
      # `app/models/action_text/rich_text.rb`) for the ergonomic convenience
      # of `record.description.nil?` meaning "no content" -- but Rails'
      # OWN association-reader internals call `.nil?` on a loaded singular
      # association's target as part of normal target resolution, before a
      # caller gets anything back at all. So the has_one reader itself is
      # unsafe on a pathological row: this is what actually crashed in
      # testing, from *inside* Rails' association machinery, before any of
      # this module's own guard code ran.
      #
      # A plain class-level query bypasses that machinery entirely -- no
      # association target-tracking, so nothing calls `.nil?` during the
      # query itself.
      def translation_for(record, attribute)
        ::ActionText::RichText.where(
          record_type: record.class.polymorphic_name,
          record_id: record.id,
          name: attribute.to_s,
          locale: ::Mobility.locale.to_s
        ).first
      end
    end
  end
end
