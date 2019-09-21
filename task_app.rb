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
    # TODO: this is duplicated, you should add a "list index view" where have I heard that before?
    store.lists.each_with_index do |list, list_index|
      puts "#{list_index}) #{list.name}"
    end
    puts "\n\n\n\n#: manage a list\t b: back to menu"
    list_selection = STDIN.getch
    if list_selection =~ /[0-9]/
      list = store.lists[list_selection.to_i]
      puts list.to_s
      list.tasks.each_with_index do |task, task_index|
        puts "#{task_index}) #{task.to_s}"
      end

      puts "\n\n\n\n#: manage a task\t b: back to menu"
      task_selection = STDIN.getch
      if task_selection =~ /[0-9]/
        puts list.tasks[task_selection.to_i].to_s
        puts "\n\n\n\nd:done\t c: cancel"

        task_commmand = STDIN.getch

        case task_commmand
        when 'd'
          list.tasks.delete_at task_selection.to_i
        end
      else
        # Return to menu
      end
    else
      # Return to menu
    end
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
end
