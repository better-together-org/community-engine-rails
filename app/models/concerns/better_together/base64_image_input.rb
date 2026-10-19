# frozen_string_literal: true

module BetterTogether
  # Lets a model set an Active Storage image from a base64 string (see ImageInput):
  #
  #   accepts_base64_image :media_data, attachment: :media, filename_field: :media_filename, default_name: 'image'
  #
  # The data field is write-only. Attaching to a saved record saves it again, which would run the callback again, so
  # the data is cleared first and replacing an image on an existing record cannot recurse.
  module Base64ImageInput
    extend ActiveSupport::Concern

    class_methods do
      def accepts_base64_image(data_field, attachment:, filename_field:, default_name:)
        attr_accessor data_field, filename_field

        # true from the moment data arrives until the record is saved (the data field itself is cleared at once)
        define_method(:"#{data_field}_received?") { instance_variable_get(:"@#{data_field}_received") == true }

        before_validation(if: -> { public_send(data_field).present? }) do
          attach_base64_image(data_field, attachment, filename_field, default_name)
        end
        validate { report_base64_image_error(data_field) }
        after_save { finish_base64_image(data_field) }
      end
    end

    private

    def attach_base64_image(data_field, attachment, filename_field, default_name)
      data = public_send(data_field)
      public_send(:"#{data_field}=", nil)
      instance_variable_set(:"@#{data_field}_received", true)
      result = ImageInput.decode(data)
      instance_variable_set(:"@#{data_field}_error", result.error)
      return if result.error

      public_send(attachment).attach(
        io: StringIO.new(result.bytes), content_type: result.type,
        filename: ImageInput.filename(public_send(filename_field), result.type, default_name)
      )
    end

    def report_base64_image_error(data_field)
      error = instance_variable_get(:"@#{data_field}_error")
      errors.add(data_field, error) if error
    end

    def finish_base64_image(data_field)
      public_send(:"#{data_field}=", nil)
      instance_variable_set(:"@#{data_field}_received", false)
    end
  end
end
