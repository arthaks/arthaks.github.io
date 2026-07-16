#!/usr/bin/env ruby
# frozen_string_literal: true

require 'date'
require 'json'
require 'yaml'
require 'fileutils'
require 'tempfile'
require 'time'

PROJECT_ROOT = File.expand_path('../../../..', __dir__)
DATA_FILE = ENV.fetch('ACTIVITY_LOG_FILE', File.join(PROJECT_ROOT, '_data', 'activity_log.yml'))
DRAFT_DIR = ENV.fetch('ACTIVITY_DRAFT_DIR', File.join(PROJECT_ROOT, '_drafts'))
POST_DIR = ENV.fetch('ACTIVITY_POST_DIR', File.join(PROJECT_ROOT, '_posts'))
YEAR_TEMPLATE = ENV.fetch('ACTIVITY_YEAR_TEMPLATE', File.expand_path('../assets/templates/year-post.md', __dir__))

TYPES = {
  'sport' => { 'name' => '运动', 'emoji' => '🏃' },
  'thought' => { 'name' => '思考', 'emoji' => '💭' },
  'reading' => { 'name' => '阅读', 'emoji' => '📖' },
  'entertainment' => { 'name' => '娱乐', 'emoji' => '🎬' }
}.freeze
TYPE_ORDER = TYPES.keys.freeze
READING_STATUSES = %w[reading completed].freeze
INPUT_FIELDS = %w[date kind title emoji metrics lead quote note book status].freeze
WEEKDAYS = %w[周日 周一 周二 周三 周四 周五 周六].freeze
MONTH_NAMES = %w[一月 二月 三月 四月 五月 六月 七月 八月 九月 十月 十一月 十二月].freeze
PROHIBITED_KEYS = %w[image thumbnail source source_file source_label device app tcx account_id route qr_code is_sample].freeze
HEADER = <<~TEXT.freeze
  # 长期活动记录的数据源。
  # 使用 .agents/skills/life-activity-journal/scripts/journal.rb 进行导入和校验。
  # 截图只作为临时输入，不在博客中保存或展示原图。

TEXT

def abort_with(message)
  warn "ERROR: #{message}"
  exit 1
end

def load_yaml(path = DATA_FILE)
  abort_with("data file not found: #{path}") unless File.file?(path)
  YAML.safe_load(File.read(path, encoding: 'UTF-8'), aliases: false) || {}
rescue Psych::SyntaxError => e
  abort_with("invalid YAML: #{e.message}")
end

def date_info(value)
  date = Date.iso8601(value.to_s)
  [date, format('%02d', date.month), WEEKDAYS[date.wday]]
rescue Date::Error
  abort_with("invalid ISO date: #{value.inspect}")
end

def current_time
  value = ENV['ACTIVITY_NOW']
  return Time.iso8601(value).getlocal('+08:00') if value && !value.empty?
  Time.now.getlocal('+08:00')
rescue ArgumentError
  abort_with("invalid ACTIVITY_NOW: #{value.inspect}")
end

def rebuild_labels!(day)
  keys = Array(day['items']).map { |item| item['type_key'] }.uniq
  keys.sort_by! { |key| TYPE_ORDER.index(key) || TYPE_ORDER.length }
  day['labels'] = keys.filter_map do |key|
    next unless TYPES.key?(key)
    { 'name' => TYPES.fetch(key).fetch('name'), 'key' => key }
  end
end

def prohibited_paths(value, prefix = '')
  case value
  when Hash
    value.flat_map do |key, child|
      path = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
      own = PROHIBITED_KEYS.include?(key.to_s) ? [path] : []
      own + prohibited_paths(child, path)
    end
  when Array
    value.each_with_index.flat_map { |child, index| prohibited_paths(child, "#{prefix}[#{index}]") }
  else
    []
  end
end

def normalize_record(record)
  abort_with('each record must be a JSON object') unless record.is_a?(Hash)
  bad = prohibited_paths(record)
  abort_with("prohibited input fields: #{bad.join(', ')}") unless bad.empty?
  unknown = record.keys.map(&:to_s) - INPUT_FIELDS
  abort_with("unknown input fields: #{unknown.join(', ')}") unless unknown.empty?

  date, month, weekday = date_info(record['date'])
  kind = record['kind'].to_s
  abort_with("unknown kind #{kind.inspect}; allowed: #{TYPE_ORDER.join(', ')}") unless TYPES.key?(kind)
  title = record['title'].to_s.strip
  abort_with("missing title for #{date}") if title.empty?

  metrics = Array(record['metrics'])
  abort_with("#{date} #{title}: at most 5 metrics are allowed") if metrics.length > 5
  metrics = metrics.map do |metric|
    abort_with("#{date} #{title}: metric must be an object") unless metric.is_a?(Hash)
    unknown_metric = metric.keys.map(&:to_s) - %w[value label]
    abort_with("#{date} #{title}: unknown metric fields #{unknown_metric.join(', ')}") unless unknown_metric.empty?
    value = metric['value'].to_s.strip
    label = metric['label'].to_s.strip
    abort_with("#{date} #{title}: metric value and label are required") if value.empty? || label.empty?
    { 'value' => value, 'label' => label }
  end

  item = {
    'type' => TYPES.fetch(kind).fetch('name'),
    'type_key' => kind,
    'emoji' => record['emoji'].to_s.strip.empty? ? TYPES.fetch(kind).fetch('emoji') : record['emoji'].to_s,
    'title' => title
  }
  %w[lead quote note].each do |field|
    value = record[field].to_s.strip
    item[field] = value unless value.empty?
  end
  item['metrics'] = metrics unless metrics.empty?

  if kind == 'reading'
    status = record['status'].to_s.strip
    status = 'reading' if status.empty?
    abort_with("#{date} #{title}: reading status must be reading or completed") unless READING_STATUSES.include?(status)
    book = record['book'].to_s.strip
    abort_with("#{date} #{title}: completed reading requires book") if status == 'completed' && book.empty?
    item['book'] = book unless book.empty?
    item['status'] = status
  elsif record.key?('book') || record.key?('status')
    abort_with("#{date} #{title}: book/status fields are only valid for reading")
  end

  {
    'year' => date.year,
    'date' => date.iso8601,
    'month' => month,
    'weekday' => weekday,
    'item' => item
  }
end

def year_record(data, year_number)
  Array(data['years']).find { |year| year['year'].to_i == year_number.to_i }
end

def ensure_month!(year, month_key)
  year['months'] ||= []
  return if year['months'].any? { |month| month['key'].to_s == month_key }

  number = month_key.to_i
  year['months'] << {
    'key' => month_key,
    'name' => MONTH_NAMES.fetch(number - 1),
    'subtitle' => "#{MONTH_NAMES.fetch(number - 1)}的生活记录"
  }
  year['months'].sort_by! { |month| month['key'].to_s }.reverse!
end

def distance_meters(item)
  metric = Array(item['metrics']).find { |entry| entry['label'].to_s == '距离' }
  return 0.0 unless metric
  text = metric['value'].to_s
  number = text.delete(',')[/\d+(?:\.\d+)?/].to_f
  text.match?(/公里|\bkm\b/i) ? number * 1000 : number
end

def compact_number(number)
  format('%.2f', number).sub(/\.00\z/, '').sub(/(\.\d)0\z/, '\\1')
end

def goal_progress(current, target)
  return 0 if target <= 0
  [((current.to_f / target) * 100).round, 100].min
end

def refresh_derived_fields!(year)
  pairs = Array(year['days']).flat_map { |day| Array(day['items']).map { |item| [day, item] } }
  sports = pairs.select { |_day, item| item['type_key'] == 'sport' }
  swims = sports.select { |_day, item| item['title'].to_s.include?('游泳') }
  runs = sports.select { |_day, item| item['title'].to_s.include?('跑步') }
  completed_books = pairs.filter_map do |_day, item|
    item['book'].to_s.strip if item['type_key'] == 'reading' && item['status'] == 'completed'
  end.reject(&:empty?).uniq
  recorded_days = pairs.map { |day, _item| day['date'] }.uniq.length

  year['summary_note'] = '年度概览根据真实记录自动统计。'
  year['summary'] = [
    { 'value' => sports.length.to_s, 'label' => '运动次数', 'icon' => '🏃' },
    { 'value' => swims.length.to_s, 'label' => '游泳次数', 'icon' => '🏊' },
    { 'value' => compact_number(swims.sum { |_day, item| distance_meters(item) } / 1000.0), 'unit' => 'km', 'label' => '游泳距离', 'icon' => '🌊' },
    { 'value' => compact_number(runs.sum { |_day, item| distance_meters(item) } / 1000.0), 'unit' => 'km', 'label' => '跑步距离', 'icon' => '👟' }
  ]

  Array(year['goals']).each do |goal|
    case goal['name']
    when /全年运动 (\d+) 次/
      target = Regexp.last_match(1).to_i
      goal['current'] = "#{sports.length} / #{target}"
      goal['progress'] = goal_progress(sports.length, target)
    when /全年读完 (\d+) 本书/
      target = Regexp.last_match(1).to_i
      goal['current'] = "#{completed_books.length} / #{target}"
      goal['progress'] = goal_progress(completed_books.length, target)
    when /记录 (\d+) 个生活切片/
      target = Regexp.last_match(1).to_i
      goal['current'] = "#{recorded_days} / #{target}"
      goal['progress'] = goal_progress(recorded_days, target)
    end
  end
end

def import_records!(data, payload)
  records = Array(payload['records'])
  abort_with('payload.records must contain at least one record') if records.empty?
  default_year = payload['year']&.to_i
  actions = []
  touched_years = []

  records.map { |record| normalize_record(record) }.each do |normalized|
    if default_year && default_year != normalized['year']
      abort_with("payload year #{default_year} does not match #{normalized['date']}")
    end
    year = year_record(data, normalized['year'])
    abort_with("year #{normalized['year']} is missing; run new-year first") unless year
    touched_years << year
    year['days'] ||= []
    day = year['days'].find { |candidate| candidate['date'].to_s == normalized['date'] }
    unless day
      day = {
        'date' => normalized['date'],
        'month' => normalized['month'],
        'weekday' => normalized['weekday'],
        'labels' => [],
        'items' => []
      }
      year['days'] << day
      actions << "CREATE DAY #{normalized['date']}"
    end

    existing = Array(day['items']).find do |item|
      item['type_key'] == normalized['item']['type_key'] && item['title'] == normalized['item']['title']
    end
    metric_preview = Array(normalized['item']['metrics']).map { |metric| "#{metric['label']}=#{metric['value']}" }.join(' · ')
    action_suffix = metric_preview.empty? ? '' : " | #{metric_preview}"
    if existing
      existing.replace(normalized['item'])
      actions << "UPDATE #{normalized['date']} #{normalized['item']['type']}: #{normalized['item']['title']}#{action_suffix}"
    else
      day['items'] ||= []
      day['items'] << normalized['item']
      actions << "ADD #{normalized['date']} #{normalized['item']['type']}: #{normalized['item']['title']}#{action_suffix}"
    end

    day['month'] = normalized['month']
    day['weekday'] = normalized['weekday']
    rebuild_labels!(day)
    ensure_month!(year, normalized['month'])
    year['days'].sort_by! { |candidate| candidate['date'].to_s }.reverse!
  end

  touched_years.uniq.each { |year| refresh_derived_fields!(year) }
  actions
end

def new_year_record(year_number)
  {
    'year' => year_number,
    'label' => '正在记录',
    'intro' => '认真生活不一定要做大事，也可以只是完成一次运动、读完几页书，或者记住一个普通但明亮的瞬间。',
    'summary_note' => '年度概览根据真实记录自动统计。',
    'months' => [],
    'summary' => [
      { 'value' => '0', 'label' => '运动次数', 'icon' => '🏃' },
      { 'value' => '0', 'label' => '游泳次数', 'icon' => '🏊' },
      { 'value' => '0', 'unit' => 'km', 'label' => '游泳距离', 'icon' => '🌊' },
      { 'value' => '0', 'unit' => 'km', 'label' => '跑步距离', 'icon' => '👟' }
    ],
    'goals' => [
      { 'name' => '全年运动 100 次', 'current' => '0 / 100', 'progress' => 0, 'color' => 'orange' },
      { 'name' => '全年读完 5 本书', 'current' => '0 / 5', 'progress' => 0, 'color' => 'blue' },
      { 'name' => '记录 100 个生活切片', 'current' => '0 / 100', 'progress' => 0, 'color' => 'green' }
    ],
    'days' => []
  }
end

def validate_data(data)
  errors = []
  years = Array(data['years'])
  errors << 'years must not be empty' if years.empty?
  seen_years = {}

  years.each do |year|
    year_number = year['year'].to_i
    errors << "duplicate year #{year_number}" if seen_years[year_number]
    seen_years[year_number] = true
    seen_dates = {}

    Array(year['days']).each do |day|
      date_value = day['date'].to_s
      begin
        date, month, weekday = date_info(date_value)
        errors << "#{date_value}: year mismatch" unless date.year == year_number
        errors << "#{date_value}: month must be #{month}" unless day['month'].to_s == month
        errors << "#{date_value}: weekday must be #{weekday}" unless day['weekday'].to_s == weekday
      rescue SystemExit
        errors << "invalid date #{date_value.inspect}"
      end
      errors << "duplicate day #{date_value}" if seen_dates[date_value]
      seen_dates[date_value] = true

      items = Array(day['items'])
      errors << "#{date_value}: items must not be empty" if items.empty?
      seen_items = {}
      items.each do |item|
        kind = item['type_key'].to_s
        title = item['title'].to_s.strip
        errors << "#{date_value}: invalid kind #{kind.inspect}" unless TYPES.key?(kind)
        errors << "#{date_value}: missing title" if title.empty?
        errors << "#{date_value} #{title}: more than 5 metrics" if Array(item['metrics']).length > 5
        bad = prohibited_paths(item)
        errors << "#{date_value} #{title}: prohibited fields #{bad.join(', ')}" unless bad.empty?
        if kind == 'reading'
          status = item['status'].to_s
          errors << "#{date_value} #{title}: invalid reading status #{status.inspect}" unless READING_STATUSES.include?(status)
          errors << "#{date_value} #{title}: completed reading requires book" if status == 'completed' && item['book'].to_s.strip.empty?
        elsif item.key?('book') || item.key?('status')
          errors << "#{date_value} #{title}: book/status fields only belong to reading"
        end
        key = [kind, title]
        errors << "#{date_value}: duplicate item #{key.join(' / ')}" if seen_items[key]
        seen_items[key] = true
      end

      expected = items.map { |item| item['type_key'] }.uniq.sort_by { |key| TYPE_ORDER.index(key) || 99 }
      actual = Array(day['labels']).map { |label| label['key'] }
      errors << "#{date_value}: labels #{actual.inspect} should be #{expected.inspect}" unless actual == expected
    end
  end
  errors
end

def stats(data, year_number)
  year = year_record(data, year_number)
  abort_with("year #{year_number} not found") unless year
  items = Array(year['days']).flat_map { |day| Array(day['items']).map { |item| [day, item] } }
  completed_books = items.filter_map do |_day, item|
    item['book'].to_s.strip if item['type_key'] == 'reading' && item['status'] == 'completed'
  end.reject(&:empty?).uniq
  puts "year=#{year_number} days=#{year['days'].length} items=#{items.length}"
  TYPE_ORDER.each { |kind| puts "#{kind}=#{items.count { |_day, item| item['type_key'] == kind }}" }
  puts "completed_books=#{completed_books.length}"
end

def yaml_body(data)
  body = YAML.dump(data, line_width: -1).sub(/\A---\s*\n/, '')
  body.gsub!(/^(\s+(?:icon|emoji):) "((?:\\U|\\u)[^"]*)"$/) do
    value = YAML.safe_load(%Q{"#{Regexp.last_match(2)}"})
    "#{Regexp.last_match(1)} #{value}"
  end
  HEADER + body
end

def atomic_write(path, content)
  directory = File.dirname(path)
  FileUtils.mkdir_p(directory)
  temp = Tempfile.new(['activity-journal', File.extname(path)], directory, encoding: 'UTF-8')
  begin
    temp.write(content)
    temp.flush
    temp.fsync
    temp.close
    File.rename(temp.path, path)
  ensure
    temp.close! if temp
  end
end

def write_data(path, data)
  atomic_write(path, yaml_body(data))
end

def draft_path(year_number)
  File.join(DRAFT_DIR, "#{year_number}-life-activity-journal.md")
end

def render_year_post(year_number, timestamp)
  abort_with("year template not found: #{YEAR_TEMPLATE}") unless File.file?(YEAR_TEMPLATE)
  File.read(YEAR_TEMPLATE, encoding: 'UTF-8')
      .gsub('__YEAR__', year_number.to_s)
      .gsub('__DATE__', timestamp.strftime('%Y-%m-%d %H:%M:%S %z'))
end

def validate_or_abort(data, context)
  errors = validate_data(data)
  return if errors.empty?
  errors.each { |error| warn "- #{error}" }
  abort_with("#{context} produced #{errors.length} validation error(s)")
end

command = ARGV.shift
case command
when 'validate'
  data = load_yaml
  errors = validate_data(data)
  if errors.empty?
    puts 'VALID'
    Array(data['years']).each { |year| stats(data, year['year']) }
  else
    errors.each { |error| warn "- #{error}" }
    abort_with("validation failed with #{errors.length} error(s)")
  end
when 'stats'
  data = load_yaml
  stats(data, (ARGV.shift || Date.today.year).to_i)
when 'import'
  payload_path = ARGV.shift || abort_with('usage: journal.rb import PAYLOAD.json [--apply]')
  apply = !ARGV.delete('--apply').nil?
  abort_with("unexpected arguments: #{ARGV.join(' ')}") unless ARGV.empty?
  payload = JSON.parse(File.read(payload_path, encoding: 'UTF-8'))
  data = load_yaml
  actions = import_records!(data, payload)
  validate_or_abort(data, 'import')
  puts actions.join("\n")
  stats(data, payload['year'] || Date.today.year)
  if apply
    write_data(DATA_FILE, data)
    puts "APPLIED #{DATA_FILE}"
  else
    puts 'DRY RUN (use --apply after review)'
  end
when 'new-year'
  year_number = Integer(ARGV.shift || abort_with('usage: journal.rb new-year YEAR [--apply]'))
  apply = !ARGV.delete('--apply').nil?
  abort_with("unexpected arguments: #{ARGV.join(' ')}") unless ARGV.empty?
  data = load_yaml
  abort_with("year #{year_number} already exists") if year_record(data, year_number)
  data['years'] ||= []
  data['years'] << new_year_record(year_number)
  data['years'].sort_by! { |year| year['year'].to_i }.reverse!
  target = draft_path(year_number)
  abort_with("draft already exists: #{target}") if File.exist?(target)
  now = current_time
  timestamp = now.year == year_number ? now : Time.new(year_number, 1, 1, 0, 0, 0, '+08:00')
  validate_or_abort(data, 'new-year')
  puts "CREATE YEAR #{year_number}"
  puts "CREATE DRAFT #{target}"
  if apply
    write_data(DATA_FILE, data)
    atomic_write(target, render_year_post(year_number, timestamp))
    puts "APPLIED year=#{year_number}"
  else
    puts 'DRY RUN (use --apply after review)'
  end
when 'publish'
  year_number = Integer(ARGV.shift || abort_with('usage: journal.rb publish YEAR [--apply]'))
  apply = !ARGV.delete('--apply').nil?
  abort_with("unexpected arguments: #{ARGV.join(' ')}") unless ARGV.empty?
  source = draft_path(year_number)
  abort_with("draft not found: #{source}") unless File.file?(source)
  now = current_time
  target = File.join(POST_DIR, "#{now.strftime('%Y-%m-%d')}-#{year_number}-life-activity-journal.md")
  abort_with("post already exists: #{target}") if File.exist?(target)
  content = File.read(source, encoding: 'UTF-8')
  content = content.sub(/^date:\s*.*$/, "date: #{now.strftime('%Y-%m-%d %H:%M:%S %z')}")
  puts "PUBLISH #{source} -> #{target}"
  puts "DATE #{now.strftime('%Y-%m-%d %H:%M:%S %z')}"
  if apply
    atomic_write(target, content)
    File.delete(source)
    puts "APPLIED #{target}"
  else
    puts 'DRY RUN (use --apply after review)'
  end
else
  abort_with('commands: validate | stats YEAR | import PAYLOAD.json [--apply] | new-year YEAR [--apply] | publish YEAR [--apply]')
end
