require_relative '../test_helper'
require_relative '../../i18n/metrics'
require 'cdo/aws/metrics'
require 'benchmark'

class I18nMetricsTest < Minitest::Test
  def setup
    Cdo::Metrics.client = Aws::CloudWatch::Client.new(stub_responses: true)
    I18n::Metrics.stubs(:machine_id).returns('local_machine')
  end

  def expect_metric(name, value, dimensions, unit)
    Cdo::Metrics.expects(:put_metric).with('I18n', {metric_name: name, value: value, dimensions: dimensions, unit: unit}).once
  end

  def test_report_runtime
    expect_metric(:Runtime, 1, [{name: 'MethodName', value: 'method'}, {name: 'SyncStep', value: 'step'}, {name: 'Environment', value: :test}, {name: 'MachineId', value: 'local_machine'}], 'Milliseconds')
    I18n::Metrics.report_runtime('method', 'step') {sleep 0.001.second}
  end

  def test_report_filesize
    fixture_path = CDO.dir('bin/test/fixtures/filesize_metrics_test.txt')
    expect_metric(:FileSize, 8, [{name: 'SyncStep', value: 'step'}, {name: 'FileName', value: 'filesize_metrics_test.txt'}, {name: 'FileDir', value: CDO.dir('bin/test/fixtures')}, {name: 'Environment', value: :test}, {name: 'MachineId', value: 'local_machine'}], 'Bytes')
    I18n::Metrics.report_filesize(fixture_path, 'step')
  end

  def test_report_success
    expect_metric(:Status, 1, [{name: 'SyncStep', value: 'step'}, {name: 'SyncComponent', value: 'None'}, {name: 'Message', value: 'message'}, {name: 'Environment', value: :test}, {name: 'MachineId', value: 'local_machine'}], 'None')
    I18n::Metrics.report_status(true, 'step', 'message')
  end

  def test_report_failure
    expect_metric(:Status, 0, [{name: 'SyncStep', value: 'step'}, {name: 'SyncComponent', value: 'component'}, {name: 'Message', value: 'error'}, {name: 'Environment', value: :test}, {name: 'MachineId', value: 'local_machine'}], 'None')
    I18n::Metrics.report_status(false, 'step', 'error', 'component')
  end

  def test_report_success_no_options
    expect_metric(:Status, 1, [{name: 'SyncStep', value: 'step'}, {name: 'SyncComponent', value: 'None'}, {name: 'Message', value: 'None'}, {name: 'Environment', value: :test}, {name: 'MachineId', value: 'local_machine'}], 'None')
    I18n::Metrics.report_status(true, 'step')
  end
end
