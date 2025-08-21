person = FactoryBot.create(:better_together_person)
puts "Person email: #{person.email}"
puts "Email addresses count: #{person.email_addresses.count}"
person.email_addresses.each { |ea| puts "  - #{ea.email} (primary: #{ea.primary_flag})" }
puts "Contact detail: #{person.contact_detail}"
puts "Contact detail email addresses: #{person.contact_detail.email_addresses.count}" if person.contact_detail
