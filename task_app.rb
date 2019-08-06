# Github as a persistence layer
# require 'octokit'
# access_token = "5281d93e310249f448eb22c545d6e6f34ed336a1"

# client = Octokit::Client.new(:access_token => access_token)
# store = Store.new(client.gist('2d466d9cb698446034fcc40138981175').files.first[1].content)

require 'pry'

class Task
  attr_accessor :title, :description

  def initialize(attrs)
    @title = attrs["title"]
    @description = attrs["description"]
  end

  def self.parse(string)
    title, description = string.split ': '
    self.new({ title: title, description: description })
  end

  def to_s
    "#{@title}: #{@description}"
  end

  def to_h
    {
      title: @title,
      description: @description
    }
  end
end

class Store
  require 'json'

  attr_accessor :tasks

  def initialize(json)
    task_json = JSON.parse(json)["tasks"] || []

    @tasks = task_json.map do |task_attrs|
      Task.new(task_attrs)
    end
  end

  def add(task)
    tasks << task
  end

  def serialize
    JSON.generate(self.to_h)
  end

  def to_h
    {
      tasks: tasks.map(&:to_h)
    }
  end
end

running = true
store = File.open("task_app.txt", 'r') do |persistence|
  Store.new(persistence.read)
end

require 'pry'

while running do
  system "clear"

  puts "1) Add Task"
  puts "2) List Unprocessed Tasks"
  puts "3) Get Next Task"
  puts "4) Save and Exit"

  command = gets.strip
  case command
  when '1'
    puts "========= ADD TASK ========"
    task = Task.parse(gets)
    store.add task
  when '2'
    puts "========== INBOX =========="
    store.tasks.each do |task|
      puts task.to_s
    end

    gets
  when '3'
    puts "======= NEXT ACTION ======="
    puts store.tasks.first.to_s
    gets
  when '4'
    File.open("task_app.txt", 'w') do |persistence|
      persistence << store.serialize
    end

    puts "Tasks Saved"
    running = false
  end
end
