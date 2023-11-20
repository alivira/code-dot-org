require 'policies/lti'
require 'queries/lti'
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

  def self.initialize_lti_student_from_nrps(client_id:, issuer:, nrps_member:)
    # TODO DAYNE don't do [0]
    puts "nrps_member\n#{nrps_member.pretty_inspect}"
    puts "nrps_member[:message][0]\n#{nrps_member[:message][0].pretty_inspect}"
    custom_claims = nrps_member[:message][0][Policies::Lti::LTI_CUSTOM_CLAIMS.to_sym]
    user = User.new
    user.provider = User::PROVIDER_MIGRATED
    user.user_type = User::TYPE_STUDENT
    user.name = custom_claims[:display_name] || custom_claims[:full_name] || custom_claims[:given_name]
    user.family_name = custom_claims[:family_name]
    id_token = {
      sub: nrps_member[:user_id],
      aud: client_id,
      iss: issuer,
    }
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
            members: [member],
          }
        end
      end
    end
    sections
  end

  # Takes an LtiSection and an array of LMS user IDs and syncs the LtiSection's roster to match the LMS roster.
  def self.sync_section_roster(lti_integration, lti_section, nrps_members)
    #{:id=>
    #   "https://codeorg.instructure.com/api/lti/courses/114/names_and_roles?rlid=a08b7778-6c8f-4360-a6db-8b12584f9911",
    #  :context=>
    #   {:id=>"d46f2064afc5a725985c04db0400c3b8fb0126c6",
    #    :label=>"Dayne's 2023",
    #    :title=>"Dayne's Canvas CSD Fall 2023"},
    #  :members=>
    #   [{:status=>"Active",
    #     :user_id=>"39e0a277-c84e-4dc0-8e38-6376fbb18d73",
    #     :lti11_legacy_user_id=>"87ecf3b50d6717d7d6387a5afaf090b31d7bf645",
    #     :roles=>["http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor"],
    #     :message=>
    #      [{:"https://purl.imsglobal.org/spec/lti/claim/message_type"=>
    #         "LtiResourceLinkRequest",
    #        :locale=>"en",
    #        :"https://purl.imsglobal.org/spec/lti/claim/custom"=>
    #         {:email=>"dayne@code.org",
    #          :course_id=>"114",
    #          :full_name=>"Dayne Wagner",
    #          :given_name=>"Dayne",
    #          :family_name=>"Wagner",
    #          :section_ids=>"116,118",
    #          :display_name=>"Dayne Wagner",
    #          :section_names=>"[\"Sunrise CS\",\"Dayne's Canvas CSD Fall 2023\"]"},
    #        :"https://purl.imsglobal.org/spec/lti/claim/lti11_legacy_user_id"=>
    #         "87ecf3b50d6717d7d6387a5afaf090b31d7bf645",
    #        :"https://purl.imsglobal.org/spec/lti/claim/lti1p1"=>
    #         {:user_id=>"87ecf3b50d6717d7d6387a5afaf090b31d7bf645"}}]},
    #    {:status=>"Active",
    #     :user_id=>"ff95cb1d-75b2-441e-a8bc-c80345080085",
    #     :lti11_legacy_user_id=>"26fbc7d095cdadac5775bb9ca484a204e91f9ca8",
    #     :roles=>["http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"],
    #     :message=>
    #      [{:"https://purl.imsglobal.org/spec/lti/claim/message_type"=>
    #         "LtiResourceLinkRequest",
    #        :locale=>"en",
    #        :"https://purl.imsglobal.org/spec/lti/claim/custom"=>
    #         {:email=>"dayne+student1@code.org",
    #          :course_id=>"114",
    #          :full_name=>"dayne_s_1",
    #          :given_name=>"dayne_s_1",
    #          :family_name=>"",
    #          :section_ids=>"116",
    #          :display_name=>"dayne_s_1",
    #          :section_names=>"[\"Dayne's Canvas CSD Fall 2023\"]"},
    #        :"https://purl.imsglobal.org/spec/lti/claim/lti11_legacy_user_id"=>
    #         "26fbc7d095cdadac5775bb9ca484a204e91f9ca8",
    #        :"https://purl.imsglobal.org/spec/lti/claim/lti1p1"=>
    #         {:user_id=>"26fbc7d095cdadac5775bb9ca484a204e91f9ca8"}}]},
    #    {:status=>"Active",
    #     :user_id=>"e36b3d02-c343-49ef-9052-681d559416a7",
    #     :lti11_legacy_user_id=>"cde79bac4ce496ba03d6911963aa7cb8981d0990",
    #     :roles=>["http://purl.imsglobal.org/vocab/lis/v2/membership#Learner"],
    #     :message=>
    #      [{:"https://purl.imsglobal.org/spec/lti/claim/message_type"=>
    #         "LtiResourceLinkRequest",
    #        :locale=>"en",
    #        :"https://purl.imsglobal.org/spec/lti/claim/custom"=>
    #         {:email=>"dayne+student2@code.org",
    #          :course_id=>"114",
    #          :full_name=>"dayne_s_2",
    #          :given_name=>"dayne_s_2",
    #          :family_name=>"",
    #          :section_ids=>"118",
    #          :display_name=>"dayne_s_2",
    #          :section_names=>"[\"Sunrise CS\"]"},
    #        :"https://purl.imsglobal.org/spec/lti/claim/lti11_legacy_user_id"=>
    #         "cde79bac4ce496ba03d6911963aa7cb8981d0990",
    #        :"https://purl.imsglobal.org/spec/lti/claim/lti1p1"=>
    #         {:user_id=>"cde79bac4ce496ba03d6911963aa7cb8981d0990"}}]}]}
    client_id = lti_integration.client_id
    issuer = lti_integration.issuer
    # TODO DAYNE save the follower list before we add the new students
    nrps_members.each do |nrps_member|
      student = Queries::Lti.get_user_from_nrps(
        client_id: client_id,
        issuer: issuer,
        nrps_member: nrps_member
      )
      student ||= initialize_lti_student_from_nrps(
        client_id: client_id,
        issuer: issuer,
        nrps_member: nrps_member
      )
      student.save!
      lti_section.section.add_student(student)
    end
  end
end
