require 'test_helper'
require 'user'
require 'authentication_option'
require 'policies/lti'

class Services::LtiTest < ActiveSupport::TestCase
  setup do
    @roles_key = Policies::Lti::LTI_ROLES_KEY
    @custom_claims_key = Policies::Lti::LTI_CUSTOM_CLAIMS
    @teacher_roles = [
      'http://purl.imsglobal.org/vocab/lis/v2/institution/person#Administrator',
      'http://purl.imsglobal.org/vocab/lis/v2/institution/person#Instructor',
      'http://purl.imsglobal.org/vocab/lis/v2/membership#Instructor',
      'http://purl.imsglobal.org/vocab/lis/v2/system/person#SysAdmin',
      'http://purl.imsglobal.org/vocab/lis/v2/system/person#User',
    ]

    @id_token = {
      sub: 'some-sub',
      aud: 'some-aud',
      iss: 'http://some-iss.com',
      @custom_claims_key => {
        display_name: 'hansolo',
        full_name: 'Han Solo',
        given_name: 'Han',
        family_name: 'Solo',
      }
    }
  end

  test 'initialize_lti_user should create User::TYPE_TEACHER when id_token contains teacher/admin roles' do
    @id_token[@roles_key] = @teacher_roles
    user = Services::Lti.initialize_lti_user(@id_token)
    assert user
    assert_equal user.user_type, User::TYPE_TEACHER
    assert_equal user.name, @id_token[@custom_claims_key][:display_name]

    @id_token[@custom_claims_key][:display_name] = nil
    user = Services::Lti.initialize_lti_user(@id_token)
    assert_equal user.name, @id_token[@custom_claims_key][:full_name]

    @id_token[@custom_claims_key][:full_name] = nil
    user = Services::Lti.initialize_lti_user(@id_token)
    assert_equal user.name, @id_token[@custom_claims_key][:family_name]

    @id_token[@custom_claims_key][:family_name] = nil
    user = Services::Lti.initialize_lti_user(@id_token)
    assert_equal user.name, @id_token[@custom_claims_key][:given_name]

    refute user.authentication_options.empty?
    assert_equal user.authentication_options[0].credential_type, AuthenticationOption::LTI_V1
    assert_equal user.authentication_options[0].authentication_id, Policies::Lti.generate_auth_id(@id_token)
  end

  test 'initialize_lti_user should create User::TYPE_STUDENT when id_token contains student roles' do
    @id_token[@roles_key] = ['not-a-teacher-role']
    student_user = Services::Lti.initialize_lti_user(@id_token)
    assert student_user
    assert_equal student_user.user_type, User::TYPE_STUDENT
    assert_equal student_user.name, @id_token[@custom_claims_key][:display_name]
    assert_equal student_user.family_name, @id_token[@custom_claims_key][:family_name]

    @id_token[@custom_claims_key][:display_name] = nil
    student_user = Services::Lti.initialize_lti_user(@id_token)
    assert_equal student_user.name, @id_token[@custom_claims_key][:full_name]

    @id_token[@custom_claims_key][:full_name] = nil
    student_user = Services::Lti.initialize_lti_user(@id_token)
    assert_equal student_user.name, @id_token[@custom_claims_key][:given_name]
  end
end
