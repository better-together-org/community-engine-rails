# frozen_string_literal: true

# Converts stored Rails timezone names on platforms to IANA identifiers for consistency
class ConvertPlatformTimezonesToIana < ActiveRecord::Migration[7.2] # rubocop:disable Metrics/ClassLength
  # Maps Rails timezone names to IANA timezone identifiers
  TIMEZONE_MAPPING = {
    'Newfoundland' => 'America/St_Johns',
    'Atlantic Time (Canada)' => 'America/Halifax',
    'Eastern Time (US & Canada)' => 'America/New_York',
    'Indiana (East)' => 'America/Indiana/Indianapolis',
    'Central Time (US & Canada)' => 'America/Chicago',
    'Mountain Time (US & Canada)' => 'America/Denver',
    'Arizona' => 'America/Phoenix',
    'Pacific Time (US & Canada)' => 'America/Los_Angeles',
    'Alaska' => 'America/Anchorage',
    'Hawaii' => 'Pacific/Honolulu',
    'Saskatchewan' => 'America/Regina',
    'Central America' => 'America/Guatemala',
    'Mexico City' => 'America/Mexico_City',
    'Monterrey' => 'America/Monterrey',
    'Guadalajara' => 'America/Mexico_City',
    'Chihuahua' => 'America/Chihuahua',
    'Tijuana' => 'America/Tijuana',
    'Bogota' => 'America/Bogota',
    'Lima' => 'America/Lima',
    'Quito' => 'America/Lima',
    'Santiago' => 'America/Santiago',
    'Caracas' => 'America/Caracas',
    'Georgetown' => 'America/Guyana',
    'La Paz' => 'America/La_Paz',
    'Buenos Aires' => 'America/Argentina/Buenos_Aires',
    'Montevideo' => 'America/Montevideo',
    'Brasilia' => 'America/Sao_Paulo',
    'Greenland' => 'America/Godthab',
    'Mid-Atlantic' => 'Atlantic/South_Georgia',
    'Azores' => 'Atlantic/Azores',
    'Cape Verde Is.' => 'Atlantic/Cape_Verde',
    'Dublin' => 'Europe/Dublin',
    'Edinburgh' => 'Europe/London',
    'Lisbon' => 'Europe/Lisbon',
    'London' => 'Europe/London',
    'Casablanca' => 'Africa/Casablanca',
    'Monrovia' => 'Africa/Monrovia',
    'UTC' => 'UTC',
    'Belgrade' => 'Europe/Belgrade',
    'Bratislava' => 'Europe/Bratislava',
    'Budapest' => 'Europe/Budapest',
    'Ljubljana' => 'Europe/Ljubljana',
    'Prague' => 'Europe/Prague',
    'Sarajevo' => 'Europe/Sarajevo',
    'Skopje' => 'Europe/Skopje',
    'Warsaw' => 'Europe/Warsaw',
    'Zagreb' => 'Europe/Zagreb',
    'Brussels' => 'Europe/Brussels',
    'Copenhagen' => 'Europe/Copenhagen',
    'Madrid' => 'Europe/Madrid',
    'Paris' => 'Europe/Paris',
    'Amsterdam' => 'Europe/Amsterdam',
    'Berlin' => 'Europe/Berlin',
    'Bern' => 'Europe/Zurich',
    'Zurich' => 'Europe/Zurich',
    'Rome' => 'Europe/Rome',
    'Stockholm' => 'Europe/Stockholm',
    'Vienna' => 'Europe/Vienna',
    'West Central Africa' => 'Africa/Algiers',
    'Bucharest' => 'Europe/Bucharest',
    'Cairo' => 'Africa/Cairo',
    'Helsinki' => 'Europe/Helsinki',
    'Kyiv' => 'Europe/Kiev',
    'Riga' => 'Europe/Riga',
    'Sofia' => 'Europe/Sofia',
    'Tallinn' => 'Europe/Tallinn',
    'Vilnius' => 'Europe/Vilnius',
    'Athens' => 'Europe/Athens',
    'Istanbul' => 'Europe/Istanbul',
    'Minsk' => 'Europe/Minsk',
    'Jerusalem' => 'Asia/Jerusalem',
    'Harare' => 'Africa/Harare',
    'Pretoria' => 'Africa/Johannesburg',
    'Kaliningrad' => 'Europe/Kaliningrad',
    'Moscow' => 'Europe/Moscow',
    'St. Petersburg' => 'Europe/Moscow',
    'Volgograd' => 'Europe/Volgograd',
    'Samara' => 'Europe/Samara',
    'Kuwait' => 'Asia/Kuwait',
    'Riyadh' => 'Asia/Riyadh',
    'Nairobi' => 'Africa/Nairobi',
    'Baghdad' => 'Asia/Baghdad',
    'Tehran' => 'Asia/Tehran',
    'Abu Dhabi' => 'Asia/Muscat',
    'Muscat' => 'Asia/Muscat',
    'Baku' => 'Asia/Baku',
    'Tbilisi' => 'Asia/Tbilisi',
    'Yerevan' => 'Asia/Yerevan',
    'Kabul' => 'Asia/Kabul',
    'Ekaterinburg' => 'Asia/Yekaterinburg',
    'Islamabad' => 'Asia/Karachi',
    'Karachi' => 'Asia/Karachi',
    'Tashkent' => 'Asia/Tashkent',
    'Chennai' => 'Asia/Kolkata',
    'Kolkata' => 'Asia/Kolkata',
    'Mumbai' => 'Asia/Kolkata',
    'New Delhi' => 'Asia/Kolkata',
    'Kathmandu' => 'Asia/Kathmandu',
    'Astana' => 'Asia/Dhaka',
    'Dhaka' => 'Asia/Dhaka',
    'Sri Jayawardenepura' => 'Asia/Colombo',
    'Almaty' => 'Asia/Almaty',
    'Novosibirsk' => 'Asia/Novosibirsk',
    'Rangoon' => 'Asia/Rangoon',
    'Bangkok' => 'Asia/Bangkok',
    'Hanoi' => 'Asia/Bangkok',
    'Jakarta' => 'Asia/Jakarta',
    'Krasnoyarsk' => 'Asia/Krasnoyarsk',
    'Beijing' => 'Asia/Shanghai',
    'Chongqing' => 'Asia/Chongqing',
    'Hong Kong' => 'Asia/Hong_Kong',
    'Urumqi' => 'Asia/Urumqi',
    'Kuala Lumpur' => 'Asia/Kuala_Lumpur',
    'Singapore' => 'Asia/Singapore',
    'Taipei' => 'Asia/Taipei',
    'Perth' => 'Australia/Perth',
    'Irkutsk' => 'Asia/Irkutsk',
    'Ulaanbaatar' => 'Asia/Ulaanbaatar',
    'Seoul' => 'Asia/Seoul',
    'Osaka' => 'Asia/Tokyo',
    'Sapporo' => 'Asia/Tokyo',
    'Tokyo' => 'Asia/Tokyo',
    'Yakutsk' => 'Asia/Yakutsk',
    'Darwin' => 'Australia/Darwin',
    'Adelaide' => 'Australia/Adelaide',
    'Canberra' => 'Australia/Melbourne',
    'Melbourne' => 'Australia/Melbourne',
    'Sydney' => 'Australia/Sydney',
    'Brisbane' => 'Australia/Brisbane',
    'Hobart' => 'Australia/Hobart',
    'Vladivostok' => 'Asia/Vladivostok',
    'Guam' => 'Pacific/Guam',
    'Port Moresby' => 'Pacific/Port_Moresby',
    'Magadan' => 'Asia/Magadan',
    'Srednekolymsk' => 'Asia/Srednekolymsk',
    'Solomon Is.' => 'Pacific/Guadalcanal',
    'New Caledonia' => 'Pacific/Noumea',
    'Fiji' => 'Pacific/Fiji',
    'Kamchatka' => 'Asia/Kamchatka',
    'Marshall Is.' => 'Pacific/Majuro',
    'Auckland' => 'Pacific/Auckland',
    'Wellington' => 'Pacific/Auckland',
    "Nuku'alofa" => 'Pacific/Tongatapu',
    'Tokelau Is.' => 'Pacific/Fakaofo',
    'Chatham Is.' => 'Pacific/Chatham',
    'Samoa' => 'Pacific/Apia'
  }.freeze

  def up # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    say 'Converting Platform timezones from Rails names to IANA identifiers...'

    # Track conversions for reporting
    conversions = Hash.new(0)
    unknown_timezones = []

    BetterTogether::Platform.find_each do |platform|
      current_tz = platform.time_zone

      # Skip if already an IANA identifier (contains a slash)
      next if current_tz.include?('/')

      # Map Rails timezone name to IANA identifier
      iana_tz = TIMEZONE_MAPPING[current_tz]

      if iana_tz
        platform.update_column(:time_zone, iana_tz)
        conversions[current_tz] += 1
      else
        # Track unknown timezones for manual review
        unknown_timezones << "Platform #{platform.id}: '#{current_tz}'"
      end
    end

    # Report results
    if conversions.any?
      say "Converted #{conversions.values.sum} platform(s):"
      conversions.each do |old_tz, count|
        say "  #{old_tz} -> #{TIMEZONE_MAPPING[old_tz]} (#{count} platform#{'s' if count > 1})"
      end
    else
      say 'No platforms needed timezone conversion.'
    end

    return unless unknown_timezones.any?

    say "\nWARNING: Found platforms with unknown timezone formats:"
    unknown_timezones.each { |msg| say "  #{msg}" }
    say "\nThese platforms may need manual timezone updates to valid IANA identifiers."
  end

  def down
    # Intentionally left blank - cannot reliably reverse IANA -> Rails mapping
    # as multiple Rails timezone names can map to the same IANA identifier
    say 'Cannot automatically reverse IANA timezone identifiers to Rails names.'
    say 'Manual update required if rollback is needed.'
  end
end
