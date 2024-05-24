# frozen_string_literal: true

module BetterTogether
  # A utility to automatically create seed data for geographic entities
  class GeographyBuilder < Builder
    class << self
      def seed_data
        seed_continents
        seed_countries
        seed_country_continents
        seed_provinces
        seed_regions
        seed_settlements
        seed_region_settlements
      end

      def clear_existing
        ::BetterTogether::Geography::RegionSettlement.delete_all
        ::BetterTogether::Geography::Settlement.delete_all
        ::BetterTogether::Geography::Region.delete_all
        ::BetterTogether::Geography::CountryContinent.delete_all
        ::BetterTogether::Geography::State.delete_all
        ::BetterTogether::Geography::Country.delete_all
        ::BetterTogether::Geography::Continent.delete_all
      end

      def seed_continents
        continent_records = continents.map do |continent|
          {
            identifier: continent[:name].parameterize,
            name: continent[:name],
            description: continent[:description],
            slug: continent[:name].parameterize,
            protected: true
          }
        end

        ::BetterTogether::Geography::Continent.create!(continent_records)
      end

      def seed_countries
        country_records = countries.flat_map do |country|
          {
            identifier: country[:name].parameterize,
            name: country[:name],
            description: country[:description],
            iso_code: country[:iso_code],
            slug: country[:name].parameterize,
            protected: true
          }
        end

        ::BetterTogether::Geography::Country.create!(country_records)
      end

      def seed_country_continents
        country_continent_records = countries.flat_map do |country|
          country_instance = ::BetterTogether::Geography::Country.find_by(identifier: country[:name].parameterize)
          country[:continents].map do |continent_name|
            continent_instance = ::BetterTogether::Geography::Continent.find_by(identifier: continent_name.parameterize)
            {
              country_id: country_instance.id,
              continent_id: continent_instance.id
            }
          end
        end

        ::BetterTogether::Geography::CountryContinent.create!(country_continent_records)
      end

      def seed_provinces
        canada = ::BetterTogether::Geography::Country.find_by(identifier: 'canada')

        province_records = provinces.map do |province|
          {
            identifier: province[:name].parameterize,
            name: province[:name],
            description: province[:description],
            iso_code: "CA-#{province[:iso_code]}",
            slug: province[:name].parameterize,
            country_id: canada.id,
            protected: true
          }
        end

        ::BetterTogether::Geography::State.create!(province_records)
      end

      def seed_regions
        region_records = regions.map do |region|
          {
            identifier: region[:name].parameterize,
            name: region[:name],
            description: region[:description],
            slug: region[:name].parameterize,
            protected: true
          }
        end

        ::BetterTogether::Geography::Region.create!(region_records)
      end

      def seed_region_settlements
        region_settlement_records = region_settlements.flat_map do |rs|
          settlement = ::BetterTogether::Geography::Settlement.find_by(identifier: rs[:settlement_identifier])
          region = ::BetterTogether::Geography::Region.find_by(identifier: rs[:region_identifier])
          {
            settlement_id: settlement.id,
            region_id: region.id
          }
        end

        ::BetterTogether::Geography::RegionSettlement.create!(region_settlement_records)
      end

      def seed_settlements
        settlement_records = settlements.flat_map do |settlement|
          state = ::BetterTogether::Geography::State.find_by(identifier: settlement[:state_identifier])
          country = state.country
          {
            identifier: settlement[:name].parameterize,
            name: settlement[:name],
            description: settlement[:description],
            slug: settlement[:name].parameterize,
            state_id: state.id,
            country_id: country.id,
            protected: true
          }
        end

        ::BetterTogether::Geography::Settlement.create!(settlement_records)
      end

      private

      def continents
        [
          { name: 'Africa', description: 'Continent in the Southern Hemisphere' },
          { name: 'Antarctica', description: 'Continent in the Southern Hemisphere' },
          { name: 'Asia', description: 'Continent in the Eastern Hemisphere' },
          { name: 'Europe', description: 'Continent in the Northern Hemisphere' },
          {
            name: 'North America',
            description: 'Continent in the Northern Hemisphere, consisting of countries such as ' \
                         'the United States, Canada, and Mexico'
          },
          { name: 'Oceania', description: 'Continent in the Southern Hemisphere' },
          { name: 'South America', description: 'Continent in the Southern Hemisphere' }
        ]
      end

      def countries
        [
          { name: 'Algeria', description: 'Country in Africa', iso_code: 'DZ', continents: ['Africa'] },
          { name: 'Angola', description: 'Country in Africa', iso_code: 'AO', continents: ['Africa'] },
          { name: 'Benin', description: 'Country in Africa', iso_code: 'BJ', continents: ['Africa'] },
          { name: 'Botswana', description: 'Country in Africa', iso_code: 'BW', continents: ['Africa'] },
          { name: 'Burkina Faso', description: 'Country in Africa', iso_code: 'BF', continents: ['Africa'] },
          { name: 'Burundi', description: 'Country in Africa', iso_code: 'BI', continents: ['Africa'] },
          { name: 'Cape Verde', description: 'Country in Africa', iso_code: 'CV', continents: ['Africa'] },
          { name: 'Cameroon', description: 'Country in Africa', iso_code: 'CM', continents: ['Africa'] },
          { name: 'Central African Republic', description: 'Country in Africa', iso_code: 'CF',
            continents: ['Africa'] },
          { name: 'Chad', description: 'Country in Africa', iso_code: 'TD', continents: ['Africa'] },
          { name: 'Comoros', description: 'Country in Africa', iso_code: 'KM', continents: ['Africa'] },
          { name: 'Congo', description: 'Country in Africa', iso_code: 'CG', continents: ['Africa'] },
          { name: 'Democratic Republic of the Congo', description: 'Country in Africa', iso_code: 'CD',
            continents: ['Africa'] },
          { name: 'Djibouti', description: 'Country in Africa', iso_code: 'DJ', continents: ['Africa'] },
          { name: 'Egypt', description: 'Country in both Africa and Asia', iso_code: 'EG',
            continents: %w[Africa Asia] },
          { name: 'Equatorial Guinea', description: 'Country in Africa', iso_code: 'GQ', continents: ['Africa'] },
          { name: 'Eritrea', description: 'Country in Africa', iso_code: 'ER', continents: ['Africa'] },
          { name: 'Eswatini', description: 'Country in Africa', iso_code: 'SZ', continents: ['Africa'] },
          { name: 'Ethiopia', description: 'Country in Africa', iso_code: 'ET', continents: ['Africa'] },
          { name: 'Gabon', description: 'Country in Africa', iso_code: 'GA', continents: ['Africa'] },
          { name: 'Gambia', description: 'Country in Africa', iso_code: 'GM', continents: ['Africa'] },
          { name: 'Ghana', description: 'Country in Africa', iso_code: 'GH', continents: ['Africa'] },
          { name: 'Guinea', description: 'Country in Africa', iso_code: 'GN', continents: ['Africa'] },
          { name: 'Guinea-Bissau', description: 'Country in Africa', iso_code: 'GW', continents: ['Africa'] },
          { name: 'Ivory Coast', description: 'Country in Africa', iso_code: 'CI', continents: ['Africa'] },
          { name: 'Kenya', description: 'Country in Africa', iso_code: 'KE', continents: ['Africa'] },
          { name: 'Lesotho', description: 'Country in Africa', iso_code: 'LS', continents: ['Africa'] },
          { name: 'Liberia', description: 'Country in Africa', iso_code: 'LR', continents: ['Africa'] },
          { name: 'Libya', description: 'Country in Africa', iso_code: 'LY', continents: ['Africa'] },
          { name: 'Madagascar', description: 'Country in Africa', iso_code: 'MG', continents: ['Africa'] },
          { name: 'Malawi', description: 'Country in Africa', iso_code: 'MW', continents: ['Africa'] },
          { name: 'Mali', description: 'Country in Africa', iso_code: 'ML', continents: ['Africa'] },
          { name: 'Mauritania', description: 'Country in Africa', iso_code: 'MR', continents: ['Africa'] },
          { name: 'Mauritius', description: 'Country in Africa', iso_code: 'MU', continents: ['Africa'] },
          { name: 'Morocco', description: 'Country in Africa', iso_code: 'MA', continents: ['Africa'] },
          { name: 'Mozambique', description: 'Country in Africa', iso_code: 'MZ', continents: ['Africa'] },
          { name: 'Namibia', description: 'Country in Africa', iso_code: 'NA', continents: ['Africa'] },
          { name: 'Niger', description: 'Country in Africa', iso_code: 'NE', continents: ['Africa'] },
          { name: 'Nigeria', description: 'Country in Africa', iso_code: 'NG', continents: ['Africa'] },
          { name: 'Rwanda', description: 'Country in Africa', iso_code: 'RW', continents: ['Africa'] },
          { name: 'Sao Tome and Principe', description: 'Country in Africa', iso_code: 'ST', continents: ['Africa'] },
          { name: 'Senegal', description: 'Country in Africa', iso_code: 'SN', continents: ['Africa'] },
          { name: 'Seychelles', description: 'Country in Africa', iso_code: 'SC', continents: ['Africa'] },
          { name: 'Sierra Leone', description: 'Country in Africa', iso_code: 'SL', continents: ['Africa'] },
          { name: 'Somalia', description: 'Country in Africa', iso_code: 'SO', continents: ['Africa'] },
          { name: 'South Africa', description: 'Country in Africa', iso_code: 'ZA', continents: ['Africa'] },
          { name: 'South Sudan', description: 'Country in Africa', iso_code: 'SS', continents: ['Africa'] },
          { name: 'Sudan', description: 'Country in Africa', iso_code: 'SD', continents: ['Africa'] },
          { name: 'Tanzania', description: 'Country in Africa', iso_code: 'TZ', continents: ['Africa'] },
          { name: 'Togo', description: 'Country in Africa', iso_code: 'TG', continents: ['Africa'] },
          { name: 'Tunisia', description: 'Country in Africa', iso_code: 'TN', continents: ['Africa'] },
          { name: 'Uganda', description: 'Country in Africa', iso_code: 'UG', continents: ['Africa'] },
          { name: 'Zambia', description: 'Country in Africa', iso_code: 'ZM', continents: ['Africa'] },
          { name: 'Zimbabwe', description: 'Country in Africa', iso_code: 'ZW', continents: ['Africa'] },
          { name: 'Afghanistan', description: 'Country in Asia', iso_code: 'AF', continents: ['Asia'] },
          { name: 'Armenia', description: 'Country in Asia', iso_code: 'AM', continents: %w[Asia Europe] },
          { name: 'Azerbaijan', description: 'Country in Asia', iso_code: 'AZ', continents: %w[Asia Europe] },
          { name: 'Bahrain', description: 'Country in Asia', iso_code: 'BH', continents: ['Asia'] },
          { name: 'Bangladesh', description: 'Country in Asia', iso_code: 'BD', continents: ['Asia'] },
          { name: 'Bhutan', description: 'Country in Asia', iso_code: 'BT', continents: ['Asia'] },
          { name: 'Brunei', description: 'Country in Asia', iso_code: 'BN', continents: ['Asia'] },
          { name: 'Cambodia', description: 'Country in Asia', iso_code: 'KH', continents: ['Asia'] },
          { name: 'China', description: 'Country in Asia', iso_code: 'CN', continents: ['Asia'] },
          { name: 'Cyprus', description: 'Country in Asia', iso_code: 'CY', continents: %w[Asia Europe] },
          { name: 'Georgia', description: 'Country in Asia', iso_code: 'GE', continents: %w[Asia Europe] },
          { name: 'India', description: 'Country in Asia', iso_code: 'IN', continents: ['Asia'] },
          { name: 'Indonesia', description: 'Country in Asia', iso_code: 'ID', continents: ['Asia'] },
          { name: 'Iran', description: 'Country in Asia', iso_code: 'IR', continents: ['Asia'] },
          { name: 'Iraq', description: 'Country in Asia', iso_code: 'IQ', continents: ['Asia'] },
          { name: 'Israel', description: 'Country in Asia', iso_code: 'IL', continents: ['Asia'] },
          { name: 'Japan', description: 'Country in Asia', iso_code: 'JP', continents: ['Asia'] },
          { name: 'Jordan', description: 'Country in Asia', iso_code: 'JO', continents: ['Asia'] },
          { name: 'Kazakhstan', description: 'Country in Asia', iso_code: 'KZ', continents: %w[Asia Europe] },
          { name: 'Kuwait', description: 'Country in Asia', iso_code: 'KW', continents: ['Asia'] },
          { name: 'Kyrgyzstan', description: 'Country in Asia', iso_code: 'KG', continents: ['Asia'] },
          { name: 'Laos', description: 'Country in Asia', iso_code: 'LA', continents: ['Asia'] },
          { name: 'Lebanon', description: 'Country in Asia', iso_code: 'LB', continents: ['Asia'] },
          { name: 'Malaysia', description: 'Country in Asia', iso_code: 'MY', continents: ['Asia'] },
          { name: 'Maldives', description: 'Country in Asia', iso_code: 'MV', continents: ['Asia'] },
          { name: 'Mongolia', description: 'Country in Asia', iso_code: 'MN', continents: ['Asia'] },
          { name: 'Myanmar', description: 'Country in Asia', iso_code: 'MM', continents: ['Asia'] },
          { name: 'Nepal', description: 'Country in Asia', iso_code: 'NP', continents: ['Asia'] },
          { name: 'North Korea', description: 'Country in Asia', iso_code: 'KP', continents: ['Asia'] },
          { name: 'Oman', description: 'Country in Asia', iso_code: 'OM', continents: ['Asia'] },
          { name: 'Pakistan', description: 'Country in Asia', iso_code: 'PK', continents: ['Asia'] },
          { name: 'Palestine', description: 'Country in Asia', iso_code: 'PS', continents: ['Asia'] },
          { name: 'Philippines', description: 'Country in Asia', iso_code: 'PH', continents: ['Asia'] },
          { name: 'Qatar', description: 'Country in Asia', iso_code: 'QA', continents: ['Asia'] },
          { name: 'Saudi Arabia', description: 'Country in Asia', iso_code: 'SA', continents: ['Asia'] },
          { name: 'Singapore', description: 'Country in Asia', iso_code: 'SG', continents: ['Asia'] },
          { name: 'South Korea', description: 'Country in Asia', iso_code: 'KR', continents: ['Asia'] },
          { name: 'Sri Lanka', description: 'Country in Asia', iso_code: 'LK', continents: ['Asia'] },
          { name: 'Syria', description: 'Country in Asia', iso_code: 'SY', continents: ['Asia'] },
          { name: 'Tajikistan', description: 'Country in Asia', iso_code: 'TJ', continents: ['Asia'] },
          { name: 'Thailand', description: 'Country in Asia', iso_code: 'TH', continents: ['Asia'] },
          { name: 'Timor-Leste', description: 'Country in Asia', iso_code: 'TL', continents: ['Asia'] },
          { name: 'Turkey', description: 'Country in both Europe and Asia', iso_code: 'TR',
            continents: %w[Europe Asia] },
          { name: 'Turkmenistan', description: 'Country in Asia', iso_code: 'TM', continents: ['Asia'] },
          { name: 'United Arab Emirates', description: 'Country in Asia', iso_code: 'AE', continents: ['Asia'] },
          { name: 'Uzbekistan', description: 'Country in Asia', iso_code: 'UZ', continents: ['Asia'] },
          { name: 'Vietnam', description: 'Country in Asia', iso_code: 'VN', continents: ['Asia'] },
          { name: 'Yemen', description: 'Country in Asia', iso_code: 'YE', continents: ['Asia'] },
          { name: 'Albania', description: 'Country in Europe', iso_code: 'AL', continents: ['Europe'] },
          { name: 'Andorra', description: 'Country in Europe', iso_code: 'AD', continents: ['Europe'] },
          { name: 'Austria', description: 'Country in Europe', iso_code: 'AT', continents: ['Europe'] },
          { name: 'Belarus', description: 'Country in Europe', iso_code: 'BY', continents: ['Europe'] },
          { name: 'Belgium', description: 'Country in Europe', iso_code: 'BE', continents: ['Europe'] },
          { name: 'Bosnia and Herzegovina', description: 'Country in Europe', iso_code: 'BA', continents: ['Europe'] },
          { name: 'Bulgaria', description: 'Country in Europe', iso_code: 'BG', continents: ['Europe'] },
          { name: 'Croatia', description: 'Country in Europe', iso_code: 'HR', continents: ['Europe'] },
          { name: 'Czech Republic', description: 'Country in Europe', iso_code: 'CZ', continents: ['Europe'] },
          { name: 'Denmark', description: 'Country in Europe', iso_code: 'DK', continents: ['Europe'] },
          { name: 'Estonia', description: 'Country in Europe', iso_code: 'EE', continents: ['Europe'] },
          { name: 'Finland', description: 'Country in Europe', iso_code: 'FI', continents: ['Europe'] },
          { name: 'France', description: 'Country in Europe', iso_code: 'FR', continents: ['Europe'] },
          { name: 'Germany', description: 'Country in Europe', iso_code: 'DE', continents: ['Europe'] },
          { name: 'Greece', description: 'Country in Europe', iso_code: 'GR', continents: ['Europe'] },
          { name: 'Hungary', description: 'Country in Europe', iso_code: 'HU', continents: ['Europe'] },
          { name: 'Iceland', description: 'Country in Europe', iso_code: 'IS', continents: ['Europe'] },
          { name: 'Ireland', description: 'Country in Europe', iso_code: 'IE', continents: ['Europe'] },
          { name: 'Italy', description: 'Country in Europe', iso_code: 'IT', continents: ['Europe'] },
          { name: 'Kosovo', description: 'Country in Europe', iso_code: 'XK', continents: ['Europe'] },
          { name: 'Latvia', description: 'Country in Europe', iso_code: 'LV', continents: ['Europe'] },
          { name: 'Liechtenstein', description: 'Country in Europe', iso_code: 'LI', continents: ['Europe'] },
          { name: 'Lithuania', description: 'Country in Europe', iso_code: 'LT', continents: ['Europe'] },
          { name: 'Luxembourg', description: 'Country in Europe', iso_code: 'LU', continents: ['Europe'] },
          { name: 'Malta', description: 'Country in Europe', iso_code: 'MT', continents: ['Europe'] },
          { name: 'Moldova', description: 'Country in Europe', iso_code: 'MD', continents: ['Europe'] },
          { name: 'Monaco', description: 'Country in Europe', iso_code: 'MC', continents: ['Europe'] },
          { name: 'Montenegro', description: 'Country in Europe', iso_code: 'ME', continents: ['Europe'] },
          { name: 'Netherlands', description: 'Country in Europe', iso_code: 'NL', continents: ['Europe'] },
          { name: 'North Macedonia', description: 'Country in Europe', iso_code: 'MK', continents: ['Europe'] },
          { name: 'Norway', description: 'Country in Europe', iso_code: 'NO', continents: ['Europe'] },
          { name: 'Poland', description: 'Country in Europe', iso_code: 'PL', continents: ['Europe'] },
          { name: 'Portugal', description: 'Country in Europe', iso_code: 'PT', continents: ['Europe'] },
          { name: 'Romania', description: 'Country in Europe', iso_code: 'RO', continents: ['Europe'] },
          { name: 'Russia', description: 'Country in both Europe and Asia', iso_code: 'RU',
            continents: %w[Europe Asia] },
          { name: 'San Marino', description: 'Country in Europe', iso_code: 'SM', continents: ['Europe'] },
          { name: 'Serbia', description: 'Country in Europe', iso_code: 'RS', continents: ['Europe'] },
          { name: 'Slovakia', description: 'Country in Europe', iso_code: 'SK', continents: ['Europe'] },
          { name: 'Slovenia', description: 'Country in Europe', iso_code: 'SI', continents: ['Europe'] },
          { name: 'Spain', description: 'Country in Europe', iso_code: 'ES', continents: ['Europe'] },
          { name: 'Sweden', description: 'Country in Europe', iso_code: 'SE', continents: ['Europe'] },
          { name: 'Switzerland', description: 'Country in Europe', iso_code: 'CH', continents: ['Europe'] },
          { name: 'Ukraine', description: 'Country in Europe', iso_code: 'UA', continents: ['Europe'] },
          { name: 'United Kingdom', description: 'Country in Europe', iso_code: 'GB', continents: ['Europe'] },
          { name: 'Vatican City', description: 'Country in Europe', iso_code: 'VA', continents: ['Europe'] },
          { name: 'Antigua and Barbuda', description: 'Country in North America', iso_code: 'AG',
            continents: ['North America'] },
          { name: 'Bahamas', description: 'Country in North America', iso_code: 'BS', continents: ['North America'] },
          { name: 'Barbados', description: 'Country in North America', iso_code: 'BB', continents: ['North America'] },
          { name: 'Belize', description: 'Country in North America', iso_code: 'BZ', continents: ['North America'] },
          { name: 'Canada', description: 'Country in North America', iso_code: 'CA', continents: ['North America'] },
          { name: 'Costa Rica', description: 'Country in North America', iso_code: 'CR',
            continents: ['North America'] },
          { name: 'Cuba', description: 'Country in North America', iso_code: 'CU', continents: ['North America'] },
          { name: 'Dominica', description: 'Country in North America', iso_code: 'DM', continents: ['North America'] },
          { name: 'Dominican Republic', description: 'Country in North America', iso_code: 'DO',
            continents: ['North America'] },
          { name: 'El Salvador', description: 'Country in North America', iso_code: 'SV',
            continents: ['North America'] },
          { name: 'Grenada', description: 'Country in North America', iso_code: 'GD', continents: ['North America'] },
          { name: 'Guatemala', description: 'Country in North America', iso_code: 'GT', continents: ['North America'] },
          { name: 'Haiti', description: 'Country in North America', iso_code: 'HT', continents: ['North America'] },
          { name: 'Honduras', description: 'Country in North America', iso_code: 'HN', continents: ['North America'] },
          { name: 'Jamaica', description: 'Country in North America', iso_code: 'JM', continents: ['North America'] },
          { name: 'Mexico', description: 'Country in North America', iso_code: 'MX', continents: ['North America'] },
          { name: 'Nicaragua', description: 'Country in North America', iso_code: 'NI', continents: ['North America'] },
          { name: 'Panama', description: 'Country in North America', iso_code: 'PA', continents: ['North America'] },
          { name: 'Saint Kitts and Nevis', description: 'Country in North America', iso_code: 'KN',
            continents: ['North America'] },
          { name: 'Saint Lucia', description: 'Country in North America', iso_code: 'LC',
            continents: ['North America'] },
          { name: 'Saint Vincent and the Grenadines', description: 'Country in North America', iso_code: 'VC',
            continents: ['North America'] },
          { name: 'Trinidad and Tobago', description: 'Country in North America', iso_code: 'TT',
            continents: ['North America'] },
          { name: 'United States', description: 'Country in North America', iso_code: 'US',
            continents: ['North America'] },
          { name: 'Australia', description: 'Country in Oceania', iso_code: 'AU', continents: ['Oceania'] },
          { name: 'Fiji', description: 'Country in Oceania', iso_code: 'FJ', continents: ['Oceania'] },
          { name: 'Kiribati', description: 'Country in Oceania', iso_code: 'KI', continents: ['Oceania'] },
          { name: 'Marshall Islands', description: 'Country in Oceania', iso_code: 'MH', continents: ['Oceania'] },
          { name: 'Micronesia', description: 'Country in Oceania', iso_code: 'FM', continents: ['Oceania'] },
          { name: 'Nauru', description: 'Country in Oceania', iso_code: 'NR', continents: ['Oceania'] },
          { name: 'New Zealand', description: 'Country in Oceania', iso_code: 'NZ', continents: ['Oceania'] },
          { name: 'Palau', description: 'Country in Oceania', iso_code: 'PW', continents: ['Oceania'] },
          { name: 'Papua New Guinea', description: 'Country in Oceania', iso_code: 'PG', continents: ['Oceania'] },
          { name: 'Samoa', description: 'Country in Oceania', iso_code: 'WS', continents: ['Oceania'] },
          { name: 'Solomon Islands', description: 'Country in Oceania', iso_code: 'SB', continents: ['Oceania'] },
          { name: 'Tonga', description: 'Country in Oceania', iso_code: 'TO', continents: ['Oceania'] },
          { name: 'Tuvalu', description: 'Country in Oceania', iso_code: 'TV', continents: ['Oceania'] },
          { name: 'Vanuatu', description: 'Country in Oceania', iso_code: 'VU', continents: ['Oceania'] },
          { name: 'Argentina', description: 'Country in South America', iso_code: 'AR', continents: ['South America'] },
          { name: 'Bolivia', description: 'Country in South America', iso_code: 'BO', continents: ['South America'] },
          { name: 'Brazil', description: 'Country in South America', iso_code: 'BR', continents: ['South America'] },
          { name: 'Chile', description: 'Country in South America', iso_code: 'CL', continents: ['South America'] },
          { name: 'Colombia', description: 'Country in South America', iso_code: 'CO', continents: ['South America'] },
          { name: 'Ecuador', description: 'Country in South America', iso_code: 'EC', continents: ['South America'] },
          { name: 'Guyana', description: 'Country in South America', iso_code: 'GY', continents: ['South America'] },
          { name: 'Paraguay', description: 'Country in South America', iso_code: 'PY', continents: ['South America'] },
          { name: 'Peru', description: 'Country in South America', iso_code: 'PE', continents: ['South America'] },
          { name: 'Suriname', description: 'Country in South America', iso_code: 'SR', continents: ['South America'] },
          { name: 'Uruguay', description: 'Country in South America', iso_code: 'UY', continents: ['South America'] },
          { name: 'Venezuela', description: 'Country in South America', iso_code: 'VE', continents: ['South America'] }
        ]
      end

      def provinces
        [
          { name: 'Alberta', description: 'Province in Western Canada', iso_code: 'AB' },
          { name: 'British Columbia', description: 'Province in Western Canada', iso_code: 'BC' },
          { name: 'Manitoba', description: 'Province in Central Canada', iso_code: 'MB' },
          { name: 'New Brunswick', description: 'Province in Eastern Canada', iso_code: 'NB' },
          { name: 'Newfoundland and Labrador', description: 'Province in Eastern Canada', iso_code: 'NL' },
          { name: 'Nova Scotia', description: 'Province in Eastern Canada', iso_code: 'NS' },
          { name: 'Ontario', description: 'Province in Central Canada', iso_code: 'ON' },
          { name: 'Prince Edward Island', description: 'Province in Eastern Canada', iso_code: 'PE' },
          { name: 'Quebec', description: 'Province in Eastern Canada', iso_code: 'QC' },
          { name: 'Saskatchewan', description: 'Province in Central Canada', iso_code: 'SK' },
          { name: 'Northwest Territories', description: 'Territory in Northern Canada', iso_code: 'NT' },
          { name: 'Nunavut', description: 'Territory in Northern Canada', iso_code: 'NU' },
          { name: 'Yukon', description: 'Territory in Northern Canada', iso_code: 'YT' }
        ]
      end

      def regions
        [
          { name: 'Avalon Peninsula', description: 'Region in Newfoundland and Labrador' },
          { name: 'Eastern Newfoundland', description: 'Region in Newfoundland and Labrador' },
          { name: 'Central Newfoundland', description: 'Region in Newfoundland and Labrador' },
          { name: 'Western Newfoundland', description: 'Region in Newfoundland and Labrador' },
          { name: 'Northern Newfoundland', description: 'Region in Newfoundland and Labrador' },
          { name: 'Labrador West', description: 'Sub-region in Labrador, Newfoundland and Labrador' },
          { name: 'Central Labrador', description: 'Sub-region in Labrador, Newfoundland and Labrador' },
          { name: 'Coastal Labrador South', description: 'Sub-region in Labrador, Newfoundland and Labrador' },
          { name: 'Coastal Labrador North', description: 'Sub-region in Labrador, Newfoundland and Labrador' }
        ]
      end

      def region_settlements
        [
          { settlement_identifier: 'st-john-s', region_identifier: 'avalon-peninsula' },
          { settlement_identifier: 'corner-brook', region_identifier: 'western-newfoundland' }
          # Add more region-settlement associations as needed...
        ]
      end

      def settlements
        [
          { name: 'St. John\'s', description: 'City in Newfoundland and Labrador',
            state_identifier: 'newfoundland-and-labrador' },
          { name: 'Corner Brook', description: 'City in Newfoundland and Labrador',
            state_identifier: 'newfoundland-and-labrador' }
          # Add more settlements as needed...
        ]
      end
    end
  end
end
