# == Schema Information
#
# Table name: sections
#
#  id                   :integer          not null, primary key
#  user_id              :integer          not null
#  name                 :string(255)
#  created_at           :datetime
#  updated_at           :datetime
#  code                 :string(255)
#  script_id            :integer
#  course_id            :integer
#  grade                :string(255)
#  login_type           :string(255)      default("email"), not null
#  deleted_at           :datetime
#  stage_extras         :boolean          default(FALSE), not null
#  section_type         :string(255)
#  first_activity_at    :datetime
#  pairing_allowed      :boolean          default(TRUE), not null
#  sharing_disabled     :boolean          default(FALSE), not null
#  hidden               :boolean          default(FALSE), not null
#  tts_autoplay_enabled :boolean          default(FALSE), not null
#  restrict_section     :boolean          default(FALSE)
#  properties           :text(65535)
#  participant_type     :string(255)      default("student"), not null
#  lti_integration_id   :bigint
#
# Indexes
#
#  fk_rails_20b1e5de46        (course_id)
#  fk_rails_f0d4df9901        (lti_integration_id)
#  index_sections_on_code     (code) UNIQUE
#  index_sections_on_user_id  (user_id)
#
class LtiSection < Section
  serialized_attrs %w(lti_resource_link_id lti_resource_link_id)

  def self.from_lti_launch(user_id:, lti_integration_id:, resource_link_id:, section_name: I18n.t('sections.default_name', default: 'Untitled Section'))
    lti_section = LtiSection.where(user_id: user_id, lti_integration_id: lti_integration_id, lti_resource_link_id: resource_link_id).first_or_create do |section|
      section.user_id = user_id
      section.name = section_name
      section.lti_integration_id = lti_integration_id
      section.lti_resource_link_id = resource_link_id
    end
    lti_section.save!
    lti_section
  end

  def provider_managed?
    true
  end
end
