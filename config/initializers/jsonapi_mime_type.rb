# frozen_string_literal: true

Mime::Type.register('application/vnd.api+json', :jsonapi) unless Mime::Type.lookup_by_extension(:jsonapi)
