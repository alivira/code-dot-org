require 'test_helper'
require 'time'

class HomeControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  test "teacher without progress or assigned course/script redirected to index" do
    teacher = create :teacher
    sign_in teacher
    assert_nil teacher.user_script_with_most_recent_progress
    assert_nil teacher.most_recently_assigned_user_script
    get :index

    assert_redirected_to '/home'
  end

  test "teacher with assigned course/script redirected to index" do
    teacher = create :teacher
    script = create :script
    sign_in teacher
    teacher.assign_script(script)
    assert_equal script, teacher.most_recently_assigned_script
    get :index

    assert_redirected_to '/home'
  end

  test "student without progress or assigned course/script redirected to index" do
    student = create :student
    sign_in student
    assert_nil student.user_script_with_most_recent_progress
    assert_nil student.most_recently_assigned_user_script
    get :index

    assert_redirected_to '/home'
  end

  test "student with progress but not an assigned script will go to index" do
    student = create :student
    script = create :script
    sign_in student
    User.any_instance.stubs(:script_with_most_recent_progress).returns(script)
    assert_equal script, student.script_with_most_recent_progress
    assert_nil student.most_recently_assigned_user_script
    get :index

    assert_redirected_to '/home'
  end

  test "student with assigned script and no progress is redirected to course overview" do
    script = create :script
    section = create :section, script: script
    student = create(:follower, section: section).student_user
    sign_in student
    assert_equal script, student.most_recently_assigned_script
    assert_nil student.user_script_with_most_recent_progress

    get :index

    assert_redirected_to script_path(script)
  end

  test "student with assigned script then recent progress in a different script will go to index" do
    student = create :student
    sign_in student
    assigned_user_script = create :user_script, user: student, assigned_at: 2.days.ago
    user_script_with_progress = create :user_script, user: student, last_progress_at: 1.day.ago
    User.any_instance.stubs(:user_script_with_most_recent_progress).returns(user_script_with_progress)
    User.any_instance.stubs(:most_recently_assigned_user_script).returns(assigned_user_script)
    assert_equal assigned_user_script, student.most_recently_assigned_user_script
    assert_equal user_script_with_progress, student.user_script_with_most_recent_progress

    get :index

    assert_redirected_to '/home'
  end

  test "student with recent progress then an assigned script should go to the assigned script overview" do
    assigned_script = create :script
    assigned_section = create :section, script: assigned_script
    student = create(:follower, section: assigned_section).student_user
    user_script_with_progress = create :user_script, user: student, last_progress_at: 2.days.ago
    sign_in student

    student.most_recently_assigned_user_script
    assert_equal user_script_with_progress, student.user_script_with_most_recent_progress

    get :index

    assert_redirected_to script_path(assigned_script)
  end

  test "student with assigned script then recent progress in that script will go to script overview" do
    script = create :script
    section = create :section, script: script
    student = create(:follower, section: section).student_user
    sign_in student

    User.any_instance.stubs(:script_with_most_recent_progress).returns(script)
    assert_equal script, student.most_recently_assigned_script
    assert_equal script, student.script_with_most_recent_progress

    get :index

    assert_redirected_to script_path(script)
  end

  test "student with assigned course or script and no age is still redirected to course overview" do
    script = create :script
    section = create :section, script: script
    student = create(:follower, section: section).student_user
    student.birthday = nil
    student.age = nil
    student.save(validate: false)
    sign_in student
    get :index

    assert_redirected_to script_path(script)
  end

  test "student with most recent assigned script only associated with archived sections they are enrolled in will go to index" do
    script = create :script
    section = create :section, script: script
    student = create(:follower, section: section).student_user
    section.hidden = 1
    section.save(validate: false)
    sign_in student

    assert_equal script, student.most_recently_assigned_script

    get :index

    assert_redirected_to '/home'
  end

  test "student with most recent assigned script only associated with archived sections they are enrolled in then recent progress in that script will go to index" do
    script = create :script
    section = create :section, script: script
    student = create(:follower, section: section).student_user
    section.hidden = 1
    section.save(validate: false)
    sign_in student

    User.any_instance.stubs(:script_with_most_recent_progress).returns(script)
    assert_equal script, student.most_recently_assigned_script
    assert_equal script, student.script_with_most_recent_progress

    get :index

    assert_redirected_to '/home'
  end

  test "student without pilot access will go to index" do
    pilot_script = create :script, pilot_experiment: 'pilot-experiment'
    section = create :section, script: pilot_script
    student = create(:follower, section: section).student_user
    sign_in student
    get :index

    assert_redirected_to '/home'
  end

  test "student with pilot access will go to pilot script" do
    pilot_script = create :script, pilot_experiment: 'pilot-experiment'
    pilot_teacher = create :teacher, pilot_experiment: 'pilot-experiment'
    section = create :section, script: pilot_script, user: pilot_teacher
    student = create(:follower, section: section).student_user
    sign_in student
    get :index

    assert_redirected_to script_path(pilot_script)
  end

  test "redirect index when signed out" do
    assert_queries 0 do
      get :index
    end

    assert_redirected_to '/courses'
  end

  test "language is determined from cdo.locale" do
    skip 'TODO: get :home, and look for a div that still exists'

    @request.env['cdo.locale'] = "es-ES"

    get :index

    assert_select 'div.description', 'Code Studio es la página principal de los cursos en línea creados por Code.org'
  end

  test "language is set with cookies" do
    sign_in User.new # devise uses an empty user instead of nil? Hm

    request.host = "studio.code.org"

    get :set_locale, params: {user_return_to: "/blahblah", locale: "es-ES"}

    assert_equal "es-ES", cookies[:language_]
    assert_match "language_=es-ES; domain=.code.org; path=/; expires=#{10.years.from_now.rfc2822}"[0..-15], @response.headers["Set-Cookie"]
    assert_redirected_to 'http://studio.code.org/blahblah?lang=es-ES'
  end

  test "handle nonsense in user_return_to by returning to home" do
    sign_in User.new # devise uses an empty user instead of nil? Hm

    request.host = "studio.code.org"

    get :set_locale, params: {user_return_to: ["blah"], locale: "es-ES"}

    assert_redirected_to 'http://studio.code.org/'
  end

  test "user_return_to should not redirect off-site" do
    request.host = "studio.code.org"
    get :set_locale, params: {
      user_return_to: "http://blah.com/blerg",
      locale: "es-ES"
    }
    assert_redirected_to 'http://studio.code.org/blerg?lang=es-ES'
  end

  test "if user_return_to in set_locale is nil redirects to homepage" do
    request.host = "studio.code.org"
    get :set_locale, params: {user_return_to: nil, locale: "es-ES"}
    assert_redirected_to 'http://studio.code.org?lang=es-ES'
  end

  test "should get index with edmodo header" do
    skip 'TODO: get :home'

    @request.headers["Accept"] = "image/*"
    @request.headers["User-Agent"] = "Edmodo/14 CFNetwork/672.0.2 Darwin/14.0.0"
    get :index
    assert_response :success
  end

  test "should get index with weebly header" do
    skip 'TODO: get :home'

    @request.headers["Accept"] = "image/*"
    @request.headers["User-Agent"] = "weebly-agent"
    get :index
    assert_response :success
  end

  test "do not show admin links when not admin" do
    sign_in create(:user)
    get :index
    assert_select 'a[href="/admin"]', 0
  end

  test "do show admin links when admin" do
    skip 'TODO: get :home'

    sign_in create(:admin)
    get :index
    assert_select 'a[href="/admin"]'
  end

  test 'do not show levelbuilder links when not levelbuilder' do
    skip 'TODO: look into bringing levelbuilder links to /home'

    sign_in create(:user)

    get :index
    assert_select 'a[href="/levels/new"]', 0
  end

  test 'do show levelbuilder links when levelbuilder' do
    skip 'TODO: look into bringing levelbuilder links to /home'

    user = create(:user)
    UserPermission.create(user_id: user.id, permission: 'levelbuilder')
    sign_in user

    get :index
    assert_select 'a[href="/levels/new"]'
  end

  test 'user without age gets age prompt' do
    skip 'TODO: get :home'

    user = create(:user)
    user.update_attribute(:birthday, nil) # bypasses validations
    user = user.reload
    refute user.age, "user should not have age, but value was #{user.age}"

    sign_in user
    get :index

    assert_select '#age-modal'
  end

  test 'user with age does not get age prompt' do
    user = create(:user)
    assert user.age

    sign_in user

    get :index

    assert_select '#age-modal', false
  end

  test 'anonymous does not get age prompt' do
    get :index

    assert_select '#age-modal', false
  end

  test "teacher visiting homepage gets expected cookies set" do
    teacher = create :teacher
    sign_in teacher
    get :home

    cookie_header = @response.header['Set-Cookie']
    assert_includes(cookie_header, "teacher_account_age_in_years")
    assert_includes(cookie_header, "teacher_within_us")
    assert_includes(cookie_header, "teacher_has_attended_pd")
  end

  # This exception is actually annoying to handle because it never gets to
  # ActionController (so we can't use the rescue in ApplicationController).
  # test "bad http methods are rejected" do
  #   process :index, 'APOST' # use an APOST instead of get/post/etc
  #
  #   assert_response 400
  # end

  test 'health_check sets no cookies' do
    get :health_check
    # this stuff is not really a hash but it pretends to be
    assert_equal "{}", @response.cookies.inspect
    assert_equal "{}", session.inspect
  end

  test 'no more debug' do
    # this action is now in AdminReportsController and requires admin privileges
    assert_raises ActionController::UrlGenerationError do
      get :debug
    end
  end

  test 'workshop organizers see dashboard links' do
    sign_in create(:workshop_organizer, :with_terms_of_service, :not_first_sign_in)
    query_count = 17
    assert_queries query_count do
      get :home
    end
    assert_select 'h1', count: 1, text: 'Workshop Dashboard'
  end

  test 'program managers see dashboard links' do
    sign_in create(:program_manager, :with_terms_of_service, :not_first_sign_in)
    query_count = 18
    assert_queries query_count do
      get :home
    end
    assert_select 'h1', count: 1, text: 'Workshop Dashboard'
  end

  test 'workshop admins see dashboard links' do
    sign_in create(:workshop_admin, :with_terms_of_service, :not_first_sign_in)
    query_count = 16
    assert_queries query_count do
      get :home
    end
    assert_select 'h1', count: 1, text: 'Workshop Dashboard'
  end

  test 'facilitators see dashboard links' do
    facilitator = create(:facilitator, :with_terms_of_service, :not_first_sign_in)
    sign_in facilitator
    query_count = 17
    assert_queries query_count do
      get :home
    end
    assert_select 'h1', count: 1, text: 'Workshop Dashboard'
  end

  test 'teachers cannot see dashboard links' do
    sign_in create(:terms_of_service_teacher, :not_first_sign_in)
    query_count = 15
    assert_queries query_count do
      get :home
    end
    assert_select 'h1', count: 0, text: 'Workshop Dashboard'
  end

  test 'workshop admins see application dashboard links' do
    sign_in create(:workshop_admin, :with_terms_of_service, :not_first_sign_in)
    query_count = 16
    assert_queries query_count do
      get :home
    end
    assert_select 'h1', count: 1, text: 'Application Dashboard'
    assert_select 'h3', count: 1, text: 'Manage Applications'
  end

  test 'workshop organizers who are regional partner program managers see application dashboard links' do
    sign_in create(:workshop_organizer, :as_regional_partner_program_manager, :with_terms_of_service, :not_first_sign_in)
    query_count = 18
    assert_queries query_count do
      get :home
    end
    assert_select 'h1', count: 1, text: 'Application Dashboard'
    assert_select 'h3', count: 1, text: 'Manage Applications'
  end

  test 'program managers see application dashboard links' do
    sign_in create(:program_manager, :with_terms_of_service, :not_first_sign_in)
    query_count = 18
    assert_queries query_count do
      get :home
    end
    assert_select 'h1', count: 1, text: 'Application Dashboard'
    assert_select 'h3', count: 1, text: 'Manage Applications'
  end

  test 'workshop organizers who are not regional partner program managers do not see application dashboard links' do
    sign_in create(:workshop_organizer, :with_terms_of_service, :not_first_sign_in)
    query_count = 17
    assert_queries query_count do
      get :home
    end
    assert_select 'h1', count: 0, text: 'Application Dashboard'
    assert_select 'h3', count: 0, text: 'Manage Applications'
  end
end
