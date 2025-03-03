require 'test_helper'

class RubricsControllerTest < ActionController::TestCase
  include Devise::Test::ControllerHelpers

  setup do
    @levelbuilder = create :levelbuilder
    @lesson = create(:lesson, :with_lesson_group)
    @level = create(:level)
    @script_level = create :script_level, script: @lesson.script, lesson: @lesson, levels: [@level]

    @teacher = create :teacher
    @student = create :student
    create :follower, student_user: @student, user: @teacher
    @rubric = create :rubric, lesson: @lesson, level: @level

    @fake_ip = '127.0.0.1'
    @storage_id = create_storage_id_for_user(@student.id)

    channel_token = ChannelToken.find_or_create_channel_token(@script_level.level, @fake_ip, @storage_id, @script_level.script_id)
    @channel_id = channel_token.channel

    # Don't actually talk to S3 when running SourceBucket.new
    AWS::S3.stubs :create_client
    stub_project_source_data(@channel_id)
    _, @project_id = storage_decrypt_channel_id(@channel_id)
    @version_id = "fake-version-id"
  end

  # new page is levelbuilder only
  test_user_gets_response_for :new, params: -> {{lessonId: @lesson.id}}, user: nil, response: :redirect, redirected_to: '/users/sign_in'
  test_user_gets_response_for :new, params: -> {{lessonId: @lesson.id}}, user: :student, response: :forbidden
  test_user_gets_response_for :new, params: -> {{lessonId: @lesson.id}}, user: :teacher, response: :forbidden
  test_user_gets_response_for :new, params: -> {{lessonId: @lesson.id}}, user: :levelbuilder, response: :success

  test "create Rubric and Learning Goals with valid params" do
    sign_in @levelbuilder
    @rubric.destroy

    File.stubs(:write).with do |filename, contents|
      filename == "#{Rails.root}/config/scripts_json/#{@lesson.script.name}.script_json" && contents.include?('learning goal example 1')
    end.once
    Rails.application.config.stubs(:levelbuilder_mode).returns true

    assert_creates(Rubric) do
      post :create, params: {
        level_id: @level.id,
        lesson_id: @lesson.id,
        learning_goals_attributes: [
          {learning_goal: 'learning goal example 1', ai_enabled: true, position: 1},
          {learning_goal: 'learning goal example 2', ai_enabled: false, position: 2}
        ]
      }
    end

    response_json = JSON.parse(response.body)
    rubric_id = response_json['rubricId']
    rubric = Rubric.find_by(id: rubric_id)
    learning_goals = LearningGoal.where(rubric_id: rubric.id)

    assert_equal @level.id, rubric.level_id
    assert_equal @lesson.id, rubric.lesson_id
    assert_equal 2, learning_goals.length
  end

  test 'updates rubric and learning goals with valid params' do
    sign_in @levelbuilder

    lesson = create :lesson, :with_lesson_group
    level = create :level
    create :script_level, script: lesson.script, lesson: lesson, levels: [level]
    rubric = create :rubric, lesson: lesson, level: level
    learning_goal = create :learning_goal, rubric: rubric
    unit_name = rubric.lesson.script.name
    File.stubs(:write).with do |filename, contents|
      filename == "#{Rails.root}/config/scripts_json/#{unit_name}.script_json" && contents.include?(learning_goal.key)
    end.once
    Rails.application.config.stubs(:levelbuilder_mode).returns true

    post :update, params: {
      id: rubric.id,
      learning_goals_attributes: [
        {id: learning_goal.id, learning_goal: 'updated learning goal', ai_enabled: true, position: 0},
      ]
    }
    learning_goal.reload
    assert_equal 'updated learning goal', learning_goal.learning_goal
  end

  test 'submits rubric evaluations of a student' do
    @rubric.destroy
    rubric = create :rubric, :with_teacher_evaluations, lesson: @lesson, level: @level, num_evaluations_per_goal: 2, teacher: @teacher, student: @student

    sign_in @teacher
    post :submit_evaluations, params: {id: rubric.id, student_id: @student.id}
    assert_response :success
    assert_equal 2, LearningGoalTeacherEvaluation.where(user: @student, teacher: @teacher).where.not(submitted_at: nil).count
  end

  test 'can only submit evaluations with same teacher_id as current_user' do
    another_teacher = create :teacher
    create :learning_goal, :with_teacher_evaluations, rubric: @rubric, teacher: @teacher, student: @student
    create :learning_goal, :with_teacher_evaluations, rubric: @rubric, teacher: another_teacher, student: @student

    sign_in @teacher
    post :submit_evaluations, params: {id: @rubric.id, student_id: @student.id}

    assert_response :success
    refute_nil LearningGoalTeacherEvaluation.find_by(user: @student, teacher: @teacher).submitted_at
    assert_nil LearningGoalTeacherEvaluation.find_by(user: @student, teacher: another_teacher).submitted_at
  end

  test "gets ai evaluations for student and learning goal" do
    student = create :student
    classmate = create :student
    create :follower, student_user: student, user: @teacher
    sign_in @teacher

    learning_goal1 = create :learning_goal, rubric: @rubric
    learning_goal2 = create :learning_goal, rubric: @rubric

    rubric_ai_evaluation = create(
      :rubric_ai_evaluation,
      rubric: @rubric,
      user: student,
      requester: @teacher,
      status: 1
    )
    ai_evaluation1 = create(
      :learning_goal_ai_evaluation,
      rubric_ai_evaluation: rubric_ai_evaluation,
      learning_goal: learning_goal1,
      understanding: 1
    )
    ai_evaluation2 = create(
      :learning_goal_ai_evaluation,
      rubric_ai_evaluation: rubric_ai_evaluation,
      learning_goal: learning_goal2,
      understanding: 2
    )

    # Create other records for another student
    travel 1.minute do
      rubric_ai_evaluation = create(
        :rubric_ai_evaluation,
        rubric: @rubric,
        user: classmate,
        requester: @teacher,
        status: 1
      )
      create(
        :learning_goal_ai_evaluation,
        rubric_ai_evaluation: rubric_ai_evaluation,
        learning_goal: learning_goal1,
        understanding: 3
      )
      create(
        :learning_goal_ai_evaluation,
        rubric_ai_evaluation: rubric_ai_evaluation,
        learning_goal: learning_goal2,
        understanding: 3
      )
    end

    get :get_ai_evaluations, params: {
      id: @rubric.id,
      studentId: student.id,
    }

    assert_response :success
    assert_equal 2, json_response.length

    # Check for the understanding to match what we created
    # Note: The order is not guaranteed
    id1 = json_response.map {|r| r['learning_goal_id']}.index(ai_evaluation1.learning_goal.id)
    id2 = json_response.map {|r| r['learning_goal_id']}.index(ai_evaluation2.learning_goal.id)
    assert_equal ai_evaluation1.understanding, json_response[id1]['understanding']
    assert_equal ai_evaluation2.understanding, json_response[id2]['understanding']
  end

  test "cannot get ai evaluations for student if not teacher of student" do
    student = create :student
    sign_in @teacher

    learning_goal = create :learning_goal
    rubric_ai_evaluation = create(
      :rubric_ai_evaluation,
      rubric: learning_goal.rubric,
      user: student,
      requester: @teacher,
      status: 1
    )
    create(
      :learning_goal_ai_evaluation,
      rubric_ai_evaluation: rubric_ai_evaluation,
      learning_goal: learning_goal,
      understanding: 1
    )

    get :get_ai_evaluations, params: {
      id: learning_goal.rubric.id,
      studentId: student.id,
    }

    assert_response :forbidden
  end

  test "only returns the most recent ai evaluation for student" do
    student = create :student
    create :follower, student_user: student, user: @teacher
    sign_in @teacher

    learning_goal = create :learning_goal

    rubric_ai_evaluation1 = create(
      :rubric_ai_evaluation,
      rubric: learning_goal.rubric,
      user: student,
      requester: @teacher,
      status: 1
    )
    create(
      :learning_goal_ai_evaluation,
      rubric_ai_evaluation: rubric_ai_evaluation1,
      learning_goal: learning_goal,
      understanding: 1
    )
    travel 1.minute do
      rubric_ai_evaluation2 = create(
        :rubric_ai_evaluation,
        rubric: learning_goal.rubric,
        user: student,
        requester: @teacher,
        status: 1
      )
      create(
        :learning_goal_ai_evaluation,
        rubric_ai_evaluation: rubric_ai_evaluation2,
        learning_goal: learning_goal,
        understanding: 2
      )
    end

    get :get_ai_evaluations, params: {
      id: learning_goal.rubric.id,
      studentId: student.id,
    }

    assert_response :success
    assert_equal 1, json_response.length
    assert_equal 2, json_response[0]['understanding']
  end

  test "returns no ai evaluations if evaluation has not been run" do
    student = create :student
    create :follower, student_user: student, user: @teacher
    sign_in @teacher

    learning_goal = create :learning_goal
    assert 0, RubricAiEvaluation.where(user: student).count

    get :get_ai_evaluations, params: {
      id: learning_goal.rubric.id,
      studentId: student.id,
    }

    assert_response :success
    assert_equal 0, json_response.length
  end

  test "gets teacher evaluations for current user" do
    student = create :student
    sign_in student

    learning_goal1 = create :learning_goal, rubric: @rubric
    learning_goal2 = create :learning_goal, rubric: @rubric
    teacher_evaluation1 = create :learning_goal_teacher_evaluation, learning_goal: learning_goal1, user: student, submitted_at: Time.now, feedback: 'feedback1'
    teacher_evaluation2 = create :learning_goal_teacher_evaluation, learning_goal: learning_goal2, user: student, submitted_at: Time.now, feedback: 'feedback2'

    get :get_teacher_evaluations, params: {
      id: @rubric.id,
    }

    assert_response :success
    assert_equal 2, json_response.length
    assert_equal teacher_evaluation1.feedback, json_response[0]['feedback']
    assert_equal teacher_evaluation2.feedback, json_response[1]['feedback']
  end

  test "does not get unsubmmitted teacher evaluations for current user" do
    student = create :student
    sign_in student

    learning_goal1 = create :learning_goal, rubric: @rubric
    learning_goal2 = create :learning_goal, rubric: @rubric
    create :learning_goal_teacher_evaluation, learning_goal: learning_goal1, user: student, submitted_at: nil, feedback: 'feedback1'
    submitted_teacher_evaluation = create :learning_goal_teacher_evaluation, learning_goal: learning_goal2, user: student, submitted_at: Time.now, feedback: 'feedback2'

    get :get_teacher_evaluations, params: {
      id: @rubric.id,
    }

    assert_response :success
    assert_equal 1, json_response.length
    assert_equal submitted_teacher_evaluation.feedback, json_response[0]['feedback']
  end

  test "run ai evaluations for user calls EvaluateRubricJob" do
    create :user_level, user: @student, script: @script_level.script, level: @level
    sign_in @teacher

    Experiment.stubs(:enabled?).with(user: @teacher, script: @script_level.script, experiment_name: 'ai-rubrics').returns(true)
    EvaluateRubricJob.stubs(:ai_enabled?).returns(true)
    EvaluateRubricJob.expects(:perform_later).with(user_id: @student.id, requester_id: @teacher.id, script_level_id: @script_level.id).once

    post :ai_evaluation_status_for_user, params: {
      id: @rubric.id,
      userId: @student.id,
    }
    assert_response :success
    response = JSON.parse(@response.body)
    assert response['attempted']
    refute response['lastAttemptEvaluated']

    post :run_ai_evaluations_for_user, params: {
      id: @rubric.id,
      userId: @student.id,
    }
    assert_response :success
  end

  test "run ai evaluations returns bad request if level not attempted" do
    sign_in @teacher

    Experiment.stubs(:enabled?).with(user: @teacher, script: @script_level.script, experiment_name: 'ai-rubrics').returns(true)
    EvaluateRubricJob.stubs(:ai_enabled?).returns(true)
    EvaluateRubricJob.expects(:perform_later).never

    post :ai_evaluation_status_for_user, params: {
      id: @rubric.id,
      userId: @student.id,
    }
    assert_response :success
    response = JSON.parse(@response.body)
    refute response['attempted']
    refute response['lastAttemptEvaluated']

    post :run_ai_evaluations_for_user, params: {
      id: @rubric.id,
      userId: @student.id,
    }
    assert_response :bad_request
  end

  test "run ai evaluations returns bad request if attempt already evaluated" do
    Timecop.freeze do
      learning_goal = create :learning_goal, rubric: @rubric
      # add an earlier evaluation to make sure we're covering the logic which tries to find the most recent evaluation
      rubric_ai_evaluation = create(
        :rubric_ai_evaluation,
        rubric: @rubric,
        user: @student,
        requester: @teacher,
        status: SharedConstants::RUBRIC_AI_EVALUATION_STATUS[:SUCCESS]
      )
      create(
        :learning_goal_ai_evaluation,
        rubric_ai_evaluation: rubric_ai_evaluation,
        user: @student,
        learning_goal: learning_goal,
        requester: @teacher
      )
      Timecop.travel 1.minute
      create :user_level, user: @student, script: @script_level.script, level: @level
      Timecop.travel 1.minute
      rubric_ai_evaluation2 = create(
        :rubric_ai_evaluation,
        rubric: @rubric,
        user: @student,
        requester: @teacher,
        status: SharedConstants::RUBRIC_AI_EVALUATION_STATUS[:SUCCESS]
      )
      create(
        :learning_goal_ai_evaluation,
        rubric_ai_evaluation: rubric_ai_evaluation2,
        user: @student,
        learning_goal: learning_goal,
        requester: @teacher
      )
      Timecop.travel 1.minute
      sign_in @teacher

      Experiment.stubs(:enabled?).with(user: @teacher, script: @script_level.script, experiment_name: 'ai-rubrics').returns(true)
      EvaluateRubricJob.stubs(:ai_enabled?).returns(true)
      EvaluateRubricJob.expects(:perform_later).never

      post :ai_evaluation_status_for_user, params: {
        id: @rubric.id,
        userId: @student.id,
      }
      assert_response :success
      response = JSON.parse(@response.body)
      assert response['attempted']
      assert response['lastAttemptEvaluated']

      post :run_ai_evaluations_for_user, params: {
        id: @rubric.id,
        userId: @student.id,
      }
      assert_response :bad_request
    end
  end

  test "run ai evaluations succeeds if attempt is more recent than evaluation" do
    Timecop.freeze do
      learning_goal = create :learning_goal, rubric: @rubric
      rubric_ai_evaluation = create(
        :rubric_ai_evaluation,
        rubric: @rubric,
        user: @student,
        requester: @teacher,
        status: 1
      )
      create(
        :learning_goal_ai_evaluation,
        rubric_ai_evaluation: rubric_ai_evaluation,
        user: @student,
        learning_goal: learning_goal,
        requester: @teacher
      )
      Timecop.travel 1.minute
      create :user_level, user: @student, script: @script_level.script, level: @level
      sign_in @teacher

      Experiment.stubs(:enabled?).with(user: @teacher, script: @script_level.script, experiment_name: 'ai-rubrics').returns(true)

      EvaluateRubricJob.stubs(:ai_enabled?).returns(true)
      EvaluateRubricJob.expects(:perform_later).with(user_id: @student.id, requester_id: @teacher.id, script_level_id: @script_level.id).once

      post :ai_evaluation_status_for_user, params: {
        id: @rubric.id,
        userId: @student.id,
      }
      assert_response :success
      response = JSON.parse(@response.body)
      assert response['attempted']
      refute response['lastAttemptEvaluated']

      post :run_ai_evaluations_for_user, params: {
        id: @rubric.id,
        userId: @student.id,
      }
      assert_response :success
    end
  end

  test "run ai evaluations for user does not call EvaluateRubricJob if ai experiment is disabled" do
    sign_in @teacher

    Experiment.stubs(:enabled?).with(user: @teacher, script: @script_level.script, experiment_name: 'ai-rubrics').returns(false)
    EvaluateRubricJob.expects(:perform_later).never

    post :run_ai_evaluations_for_user, params: {
      id: @rubric.id,
      userId: @student.id,
    }
    assert_response :forbidden
  end

  test "cannot run ai evaluations for user if not teacher of student" do
    teacher = create :teacher
    sign_in teacher

    post :run_ai_evaluations_for_user, params: {
      id: @rubric.id,
      userId: @student.id,
    }
    assert_response :forbidden
  end

  private def stub_project_source_data(channel_id, code: 'fake-code', version_id: 'fake-version-id')
    fake_main_json = {source: code}.to_json
    fake_source_data = {
      status: 'FOUND',
      body: StringIO.new(fake_main_json),
      version_id: version_id
    }
    SourceBucket.any_instance.stubs(:get).with(channel_id, "main.json").returns(fake_source_data)
  end
end
