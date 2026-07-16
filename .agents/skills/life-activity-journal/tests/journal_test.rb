# frozen_string_literal: true

require 'json'
require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'tmpdir'
require 'yaml'
require 'fileutils'

SKILL_ROOT = File.expand_path('..', __dir__)
SCRIPT = File.join(SKILL_ROOT, 'scripts', 'journal.rb')
YEAR_TEMPLATE = File.join(SKILL_ROOT, 'assets', 'templates', 'year-post.md')

class JournalCliTest < Minitest::Test
  def setup
    @tmp = Dir.mktmpdir('life-activity-journal-test')
    @data_file = File.join(@tmp, 'activity_log.yml')
    @draft_dir = File.join(@tmp, '_drafts')
    @post_dir = File.join(@tmp, '_posts')
    FileUtils.mkdir_p(@draft_dir)
    FileUtils.mkdir_p(@post_dir)
    File.write(@data_file, YAML.dump(base_data))
  end

  def teardown
    FileUtils.rm_rf(@tmp)
  end

  def test_same_day_merges_and_exact_title_updates
    payload = {
      'year' => 2026,
      'records' => [
        sport_record('2026-07-16', '33:23'),
        { 'date' => '2026-07-16', 'kind' => 'thought', 'title' => 'AI 是外骨骼', 'note' => '核心仍然是人。' }
      ]
    }
    result = import(payload, '--apply')
    assert result[:success], result[:stderr]

    data = load_data
    day = data['years'][0]['days'].first
    assert_equal 1, data['years'][0]['days'].length
    assert_equal 2, day['items'].length

    result = import({ 'year' => 2026, 'records' => [sport_record('2026-07-16', '32:00')] }, '--apply')
    assert result[:success], result[:stderr]
    day = load_data['years'][0]['days'].first
    assert_equal 2, day['items'].length
    sport = day['items'].find { |item| item['type_key'] == 'sport' }
    assert_equal '32:00', sport['metrics'].find { |metric| metric['label'] == '时长' }['value']
  end

  def test_more_than_five_metrics_is_rejected_without_mutation
    record = sport_record('2026-07-16', '33:23')
    record['metrics'] = 6.times.map { |index| { 'value' => index.to_s, 'label' => "指标#{index}" } }
    before = File.read(@data_file)
    result = import({ 'year' => 2026, 'records' => [record] }, '--apply')
    refute result[:success]
    assert_includes result[:stderr], 'at most 5 metrics'
    assert_equal before, File.read(@data_file)
  end

  def test_sample_field_is_rejected
    record = sport_record('2026-07-16', '33:23').merge('is_sample' => false)
    result = import({ 'year' => 2026, 'records' => [record] })
    refute result[:success]
    assert_includes result[:stderr], 'prohibited input fields'
  end

  def test_completed_books_count_unique_titles
    payload = {
      'year' => 2026,
      'records' => [
        { 'date' => '2026-06-01', 'kind' => 'reading', 'title' => '读完第一遍', 'book' => '原则', 'status' => 'completed' },
        { 'date' => '2026-06-02', 'kind' => 'reading', 'title' => '补充笔记', 'book' => '原则', 'status' => 'completed' }
      ]
    }
    result = import(payload, '--apply')
    assert result[:success], result[:stderr]
    goal = load_data['years'][0]['goals'].find { |item| item['name'] == '全年读完 5 本书' }
    assert_equal '1 / 5', goal['current']
    assert_equal 20, goal['progress']
  end

  def test_new_year_and_publish_are_dry_run_by_default
    dry = run_cli('new-year', '2027')
    assert dry[:success], dry[:stderr]
    refute File.exist?(File.join(@draft_dir, '2027-life-activity-journal.md'))

    applied = run_cli('new-year', '2027', '--apply')
    assert applied[:success], applied[:stderr]
    draft = File.join(@draft_dir, '2027-life-activity-journal.md')
    assert File.exist?(draft)
    assert load_data['years'].any? { |year| year['year'] == 2027 }

    publish_dry = run_cli('publish', '2027')
    assert publish_dry[:success], publish_dry[:stderr]
    assert File.exist?(draft)

    published = run_cli('publish', '2027', '--apply')
    assert published[:success], published[:stderr]
    refute File.exist?(draft)
    assert File.exist?(File.join(@post_dir, '2027-01-02-2027-life-activity-journal.md'))
  end

  private

  def base_data
    {
      'years' => [
        {
          'year' => 2026,
          'label' => '正在记录',
          'intro' => '测试',
          'summary_note' => '年度概览根据真实记录自动统计。',
          'months' => [],
          'summary' => [],
          'goals' => [
            { 'name' => '全年运动 100 次', 'current' => '0 / 100', 'progress' => 0, 'color' => 'orange' },
            { 'name' => '全年读完 5 本书', 'current' => '0 / 5', 'progress' => 0, 'color' => 'blue' },
            { 'name' => '记录 100 个生活切片', 'current' => '0 / 100', 'progress' => 0, 'color' => 'green' }
          ],
          'days' => []
        }
      ]
    }
  end

  def sport_record(date, duration)
    {
      'date' => date,
      'kind' => 'sport',
      'title' => '泳池游泳',
      'metrics' => [
        { 'value' => '1,000 米', 'label' => '距离' },
        { 'value' => duration, 'label' => '时长' },
        { 'value' => '蛙泳', 'label' => '泳姿' }
      ]
    }
  end

  def import(payload, *args)
    path = File.join(@tmp, 'payload.json')
    File.write(path, JSON.pretty_generate(payload))
    run_cli('import', path, *args)
  end

  def run_cli(*args)
    env = {
      'ACTIVITY_LOG_FILE' => @data_file,
      'ACTIVITY_DRAFT_DIR' => @draft_dir,
      'ACTIVITY_POST_DIR' => @post_dir,
      'ACTIVITY_YEAR_TEMPLATE' => YEAR_TEMPLATE,
      'ACTIVITY_NOW' => '2027-01-02T10:30:00+08:00'
    }
    stdout, stderr, status = Open3.capture3(env, RbConfig.ruby, SCRIPT, *args)
    { success: status.success?, stdout: stdout, stderr: stderr }
  end

  def load_data
    YAML.safe_load_file(@data_file)
  end
end
