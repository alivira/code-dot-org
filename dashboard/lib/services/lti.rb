require 'policies/lti'
require 'user'
require 'authentication_option'

class Services::Lti
  def self.initialize_lti_user(id_token)
    custom_claims = id_token[Policies::Lti::LTI_CUSTOM_CLAIMS]
    user_type = Policies::Lti.get_account_type(id_token)
    user = User.new
    user.provider = User::PROVIDER_MIGRATED
    user.user_type = user_type
    if user_type == User::TYPE_TEACHER
      user.age = '21+'
      user.name = custom_claims[:display_name] || custom_claims[:full_name] || custom_claims[:family_name] || custom_claims[:given_name]
    else
      user.name = custom_claims[:display_name] || custom_claims[:full_name] || custom_claims[:given_name]
      user.family_name = custom_claims[:family_name]
    end
    ao = AuthenticationOption.new(
      authentication_id: Policies::Lti.generate_auth_id(id_token),
      credential_type: AuthenticationOption::LTI_V1,
      email: custom_claims[:email],
    )
    user.authentication_options = [ao]
    user
  end

  def self.parse_nrps_response(nrps_response)
    sections = {}
    members = nrps_response[:members]
    members.each do |member|
      next if member[:status] == 'Inactive' || member[:roles].exclude?(Policies::Lti::CONTEXT_LEARNER_ROLE)
      # TODO: handle multiple messages. Shouldn't be needed until we support Deep Linking.
      message = member[:message].first

      # Important: These custom variables are proprietary to Canvas' implementation of LTI Advantage.
      custom_variables = message[Policies::Lti::LTI_CUSTOM_CLAIMS.to_sym]
      puts message.inspect
      puts 'custom variables:'
      puts custom_variables

      # Handles the possibility of the LMS not having sectionId variable substitution configured.
      member_section_ids = custom_variables[:section_ids]&.split(',') || [nil]
      # :section_names from Canvas is a stringified JSON array
      member_section_names = JSON.parse(custom_variables[:section_names])
      member_section_ids.each_with_index do |section_id, index|
        if sections[section_id].present?
          sections[section_id][:members] << member
        else
          sections[section_id] = {
            name: member_section_names[index],
            members: [member[:user_id]],
          }
        end
      end
    end
    sections
  end

  # Takes an LtiSection and an array of LMS user IDs and syncs the LtiSection's roster to match the LMS roster.
  def self.sync_roster(lti_section, nrps_user_ids)
    puts 'syncing'
  end
end
