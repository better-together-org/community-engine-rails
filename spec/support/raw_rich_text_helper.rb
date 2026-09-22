# frozen_string_literal: true

module BetterTogether
  module TestSupport
    # Writes a rich text body directly via raw SQL, bypassing ActiveRecord's
    # attribute type system entirely.
    #
    # This exists to reproduce pathologically-nested `action_text_rich_texts`
    # rows (the 2026-09 production incident: a body non-idempotently
    # re-wrapped hundreds of times in its own render output) for specs.
    #
    # Two separate things make this harder than a normal fixture write:
    #
    # 1. `ActionText::RichText#body`'s `serialize :body, coder:
    #    ActionText::Content` means EVERY ActiveRecord write path --
    #    `update!`, `update_column`, and even `update_all` -- routes the
    #    given value through `ActionText::Content.new`, which parses it with
    #    Nokogiri HTML5. Nokogiri enforces its own document-tree depth limit
    #    and raises `ArgumentError: Document tree depth limit exceeded` on
    #    content this deeply nested, so no ORM-level write can construct this
    #    fixture -- only a raw SQL UPDATE avoids the ORM's type system
    #    entirely.
    # 2. `ActionText::RichText` delegates `#nil?` (and `#to_s`) to `#body`
    #    (`app/models/action_text/rich_text.rb`), so merely holding a loaded
    #    Ruby reference to the translation row and later letting anything --
    #    including Rails' OWN association-reload internals -- call `.nil?`
    #    on it triggers the same crash. This module therefore never
    #    instantiates the translation as an AR object at all: it resolves the
    #    row's id with `.pick` (a plain scalar, no model instantiated) and
    #    writes by id, so callers get a clean, never-before-loaded read the
    #    first time they touch the association.
    module RawRichText
      module_function

      # @param record [ActiveRecord::Base] a model with
      #   `translates :attribute, backend: :action_text`
      # @param attribute [Symbol, String] the translated attribute name
      # @param raw_body [String] the exact HTML to store
      # @param locale [Symbol, String] defaults to the current Mobility locale
      def write!(record, attribute, raw_body, locale: Mobility.locale)
        translation_id = ::ActionText::RichText
                         .where(record_type: record.class.polymorphic_name, record_id: record.id,
                                name: attribute.to_s, locale: locale.to_s)
                         .pick(:id)
        raise ActiveRecord::RecordNotFound, "no rich text translation for #{record.class}##{attribute}" unless translation_id

        sql = ActiveRecord::Base.sanitize_sql_array(
          ['UPDATE action_text_rich_texts SET body = ? WHERE id = ?', raw_body, translation_id]
        )
        ActiveRecord::Base.connection.exec_update(sql)
      end
    end
  end
end
