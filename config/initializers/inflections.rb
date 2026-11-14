# frozen_string_literal: true

ActiveSupport::Inflector.inflections do |inflect|
  inflect.acronym 'DSL'
  inflect.acronym 'JSONAPI'
  inflect.irregular 'CallForInterest', 'CallsForInterest'
  inflect.irregular 'call_for_interest', 'calls_for_interest'
  inflect.irregular 'Call for interest', 'Calls for interest'
  # "quota" pluralizes regularly to "quotas" in English, but Rails' classical-Latin
  # rule (datum/data, quantum/quanta) also matches it by pattern, turning
  # .pluralize/.singularize/.classify on it into "quotum" nonsense. Pinned here
  # rather than left to fall through to that rule.
  inflect.irregular 'quota', 'quotas'
end
