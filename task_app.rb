require 'pry'
require 'pry-nav'
require 'octokit'
require 'io/console'

GITHUB_ACCESS_TOKEN = ENV["GITHUB_ACCESS_TOKEN"]
GIST_ID = '2d466d9cb698446034fcc40138981175'

class Store
  require 'json'

  attr_accessor :lists

  def initialize(json)
    list_json = JSON.parse(json)["lists"] || []
    @lists = list_json.map do |list_attrs|
      List.new(list_attrs)
    end
  end

  def delete_index(index)
    tasks.delete_at index
  end

  def serialize
    JSON.generate(self.to_h)
  end

  def to_h
    {
      lists: lists.map(&:to_h)
    }
  end

  def save!
    gist_persistence = $octokit.gist(GIST_ID)

    $octokit.edit_gist(GIST_ID,
                          files: {
                            "gistfile1.txt" => { "content" => serialize }
                          }
    )
  end

  def inbox
    lists.find { |list| list.name == 'inbox' }
  end
end

class List
  attr_accessor :name, :tasks

  def initialize(attrs)
    @name = attrs["name"]
    @tasks = attrs["tasks"].map do |task_attrs|
      Task.new(task_attrs)
    end
  end

  def self.parse(string)
    self.new({"name" => string, "tasks" => []})
  end

  def add_task(task)
    tasks << task
  end

  def to_s
    name
  end

  def to_h
    {
      name: @name,
      tasks: tasks.map(&:to_h)
    }
  end
end

class Task
  attr_accessor :title, :description

  def initialize(attrs)
    @title = attrs["title"]
    @description = attrs["description"]
  end

  def self.parse(string)
    title, description = string.split ': '
    self.new({ "title" => title, "description" => description })
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

running = true

# File persistence
# store = File.open("task_app.txt", 'r') do |persistence|
#   Store.new(persistence.read)
# end
$octokit = Octokit::Client.new(access_token: GITHUB_ACCESS_TOKEN)
store = Store.new($octokit.gist(GIST_ID).files.first[1].content)

while running do
  system "clear"
  puts "a: add task\np: process inbox\nl: list lists\nn: New List\ne: save & exit\nd: debug"

  command = STDIN.getch
  case command
  when 'a'
    puts 'Tasks are OTF: title: description'
    task = Task.parse(gets.strip)
    store.inbox.add_task task
  when 'n'
    puts 'Lists just require a name'
    store.lists << List.parse(gets.strip)
  when 'l'
    store.lists.each do |list|
      puts list.to_s
    end

    STDIN.getch
  when 'p'
    store.inbox.tasks.each_with_index do |task, task_index|
      puts task.to_s
      puts "\n\n\n\nm: move to list\td: do now\ts:skip for now"
      inbox_command = STDIN.getch
      case inbox_command
      when 'm'
        store.lists.each_with_index do |list, list_index|
          puts "#{list_index}) #{list.name}"
        end

        list_selection = STDIN.getch.to_i

        store.lists[list_selection].tasks << task
        store.inbox.tasks.delete_at task_index
      when 'd'
        puts "\n\n\n\nc: cancel\td: done"

        do_now_command = STDIN.getch
        case do_now_command
        when 'c'
          system 'clear'
          next
        when 'd'
          store.inbox.tasks.delete_at task_index
        end
      when 's'
        next
      end
    end
  when 'e'
    store.save!
    running = false
  when 'd'
    binding.pry
  end


  # puts "1) Add Task"
  # puts "2) Delete Task"
  # puts "3) List Unprocessed Tasks"
  # puts "4) Get Next Task"
  # puts "5) Save and Exit"
  # puts "0) Debug"

  # command = gets.strip
  # case command
  # when '1'
  #   puts "========= ADD TASK ========"
  #   task = Task.parse(gets.strip)
  #   store.add task
  # when '2'
  #   puts "======= DELETE TASK ======="
  #   index = gets.strip.to_i
  #   store.delete_index(index)
  # when '3'
  #   puts "========== INBOX =========="
  #   store.inbox.tasks.each_with_index do |task, index|
  #     puts "#{index}) #{task.to_s}"
  #   end
  #   gets
  # when '4'
  #   puts "======= NEXT ACTION ======="
  #   puts store.tasks.first.to_s
  #   gets
  # when '5'
  #   # File Persistence
  #   # File.open("task_app.txt", 'w') do |persistence|
  #   #   persistence << store.serialize
  #   # end

  #   store.save!

  #   puts "Tasks Saved"
  #   running = false
  # when '0'
  #   binding.pry
  # end
end
