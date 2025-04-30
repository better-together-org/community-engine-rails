# config/locales/defaults/uk.rb
{
  uk: {
    date: {
      # In Ukrainian month name with day and standalone day are different
      month_names: lambda do |key, options|
        if options[:format] && options[:format] =~ /%-?d %B/
          :'date.month_names_with_day'
        else
          :'date.month_names_standalone'
        end
      end
    }
  }
}