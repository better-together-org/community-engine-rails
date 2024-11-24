namespace :better_together do
  namespace :qa do
    namespace :rich_text do
      namespace :links do
        desc 'Generates report of status of RichText links'
        task check: :environment do
          require 'json'
          require 'uri'
          require 'net/http'

          host_platform = BetterTogether::Platform.host.first
          platform_uri = URI(host_platform.url)

          rich_texts = ActionText::RichText.includes(:record).where.not(body: nil)

          rich_text_links = {}

          valid_rich_text_links = []
          invalid_rich_text_links = []

          rich_texts.each do |rt|
            links = rt.body.links

            next unless links.any?

            rt_sgid = rt.to_sgid(expires_in: nil)
            rt_record_sgid = rt.record.to_sgid(expires_in: nil)

            rich_text_links[rt.id] = {
              record: {
                id: rt.record_id,
                type: rt.record_type
              },
              links: links.map do |link|
                link_type = 'undetermined'
                valid = false
                external = false
                link_struct = nil

                begin
                  link_uri = URI(link)
                  valid = true

                  if link_uri.host == platform_uri.host
                    link_type = if link.include?('http://')
                      'valid:uri:http:internal'
                    elsif link.include?('https://')
                      'valid:uri:https:internal'
                    else
                      'valid:uri:internal'
                    end
                  else
                    if link.include?('tel:')
                      link_type = 'valid:phone'
                    elsif link.include?('mailto:')
                      link_type = 'valid:email'
                    elsif link.include?('http://')
                      link_type = 'valid:uri:http:external'
                      external = true
                    elsif link.include?('https://')
                      link_type = 'valid:uri:https:external'
                      external = true
                    else
                      link_type = 'valid:undetermined'
                    end
                  end

                  link_struct = OpenStruct.new({
                    rt_sgid: rt_sgid,
                    rt_record_sgid: rt_record_sgid,
                    link: ,
                    link_type:,
                    external:,
                    rich_text_id: rt.id,
                    record: {
                      id: rt.record_id,
                      type: rt.record_type
                    },
                    uri: (link_uri if valid)
                  })
                rescue URI::InvalidURIError => each
                  link_type = if link.include?('tel:')
                    'invalid:phone'
                  elsif link.include?('mailto:')
                    'invalid:email'
                  elsif link.include?('http://')
                    'invalid:uri:http:undetermined'
                  elsif link.include?('https://')
                    'invalid:uri:https:undetermined'
                  else
                    'invalid:undetermined'
                  end

                  link_struct = OpenStruct.new({
                    rt_sgid: rt_sgid,
                    rt_record_sgid: rt_record_sgid,
                    link:,
                    link_type:,
                    external:,
                    valid:,
                    rich_text_id: rt.id,
                    record: {
                      id: rt.record_id,
                      type: rt.record_type
                    }
                  })
                end

                if valid
                  valid_rich_text_links << link_struct
                else
                  invalid_rich_text_links << link_struct
                end

                link_struct
              end
            }
          end

          sorted_valid_links = valid_rich_text_links.sort_by(&:link)
          sorted_invalid_links = invalid_rich_text_links.sort_by(&:link)

          puts 'valid links:', sorted_valid_links.size
          puts 'invalid links:', sorted_invalid_links.size

          # puts invalid_rich_text_links.map(&:link)

          valid_uri_links = sorted_valid_links.select do |link|
            link.link_type.include?('valid:uri')
          end

          valid_internal_uri_links = valid_uri_links.select do |link|
            link.external == false
          end

          valid_external_uri_links = valid_uri_links - valid_internal_uri_links

          puts 'valid URI links:', valid_uri_links.size
          puts 'valid internal URI links:', valid_internal_uri_links.size
          puts 'valid external URI links:', valid_external_uri_links.size

          uri_link_hosts = valid_uri_links.group_by do |link|
            link.uri.host
          end

          mapped_link_hosts = uri_link_hosts.transform_values do |values|
            values.sort_by(&:link).group_by(&:link)
          end

          # sorted_mapped_link_hosts = mapped_link_hosts.sort_by(&:first)

          unique_link_hosts = mapped_link_hosts.transform_values do |values|
            { unique_host_links: values.keys.size, total_host_link_uses: values.map {|k, v| v.size}.sum, links: values.map {|k, v| { uri: k, code: nil, size: v.size, links: v } }}
          end

          potential_bad_locale_internal_links = valid_internal_uri_links.select do |link|
            link.link.include?('/es/en/') or link.link.include?('/en/es/')
          end

          # puts 'mapped_link_hosts', mapped_link_hosts
          # puts 'sorted_mapped_link_hosts', sorted_mapped_link_hosts.to_h
          # puts 'uri_link_hosts', JSON.pretty_generate(uri_link_hosts)
          # puts 'sorted_mapped_link_hosts', JSON.pretty_generate(sorted_mapped_link_hosts.to_h)
          # puts 'unique_host_links', JSON.pretty_generate(unique_link_hosts)
          puts 'unique host count', unique_link_hosts.keys.size
          puts 'unique link count', unique_link_hosts.map {|k, v| v[:unique_host_links]}.sum
          puts 'total link uses', unique_link_hosts.map {|k, v| v[:total_host_link_uses]}.sum

          # puts 'valid internal links', valid_internal_uri_links.map(&:link)

          puts 'potential bad locale internal links', potential_bad_locale_internal_links.map(&:link), potential_bad_locale_internal_links.size

          bad_locale_link_record_gids = potential_bad_locale_internal_links.map(&:rt_record_sgid)

          records = GlobalID::Locator.locate_many bad_locale_link_record_gids

          puts 'records:', records.size

          puts 'page_urls', records.map { |record| record.pages.map(&:url).map {|url| url.gsub(BetterTogether.base_url, platform_uri)} if record.respond_to? :pages }
        end
      end
    end
  end
end