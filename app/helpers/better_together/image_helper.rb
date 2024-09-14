
module BetterTogether
  # helps with rendering images
  module ImageHelper
    def profile_image_tag(member, options = {})
      image_classes =  "profile-image rounded-circle #{options[:class]}"

      if member.profile_image.attached?
        image_tag(member.profile_image_variant(300).url, class: image_classes, alt: 'Profile Image')
      else
        image_tag(image_url("default_profile_image_person"), class: image_classes, alt: 'Default Profile Image')
      end
    end
  end
end