#!/usr/local/rvm/rubies/ruby-2.3.0/bin/ruby
require 'yaml'

conf = Hash[ ARGV.join(' ').scan(/--?([^=\s]+)(?:=(\S+))?/) ]
if conf['config'].nil?
  yaml_file = 'cmd_script.yml'
else
  yaml_file = conf['config']
end

CONF = YAML.load_file(yaml_file)
DEB = CONF['debug']
trap('SIGINT') {puts "\nGood bye!"; exit 0}

def init_command
  Command::ALL_COMMANDS.push(HelpCommand, UptimeCommand, DateCommand,
                             EchoCommand, PingCommand)
end

class Command
  @arg = 0
  ALL_COMMANDS = []
  def self.name
    'base'
  end
  def self.description
    'Base command description'
  end
  def self.command_by_name(name_command)
    begin
      exec_command = Command::ALL_COMMANDS.find { |i| i.name == name_command }
      raise MyError.msg(name_command) if exec_command.nil?
      return exec_command unless  exec_command.nil?
    end
  end
  protected
  def self.say(*param)
    puts '#' * 33
    p Time.now
    puts "Executed script: #{$0}"
    puts '#' * 33
    puts param
  end
end

class MyError < StandardError
  def self.msg(command)
    puts "Exeption: command #{command} is not found"
  end
end

class HelpCommand < Command
  class << self
  def name
    'help'
  end
  def description
    CONF['commands']['help']
  end
  def run
    say 'Available commands:'
    out = File.open(CONF['output'], 'a')
    out.write("#{Time.now.strftime('%H:%M:%S %d.%m.%y')}: command - #{self.name}\n")
    Command::ALL_COMMANDS.each { |i| puts "#{i.name} --- #{i.description}" }
    Command::ALL_COMMANDS.each { |i| out.write("       #{i.name} - #{i.description}\n") }
    out.close
  end
  end
end

class UptimeCommand < Command
  class << self
  def name
    'uptime'
  end
  def description
    CONF['commands']['uptime']
  end
  def run
    begin
      out = File.open(CONF['output'], 'a')
      out.write("#{Time.now.strftime('%H:%M:%S %d.%m.%y')}: command - #{self.name}\n")
      uptime = File.read('/proc/uptime').split[0].to_i
      uptime_h = Time.at(uptime).utc.strftime('%H')
      uptime_m = Time.at(uptime).utc.strftime('%M')
      uptime_s = Time.at(uptime).utc.strftime('%S')
      out.write("       Uptime is #{uptime_h}h #{uptime_m}m #{uptime_s}s\n")
      puts "Uptime is #{uptime_h}h #{uptime_m}m #{uptime_s}s "
    rescue Errno::ENOENT
      puts 'No such file /proc/uptime'
      out.close
    end
  end
  end
end

class DateCommand < Command
  class << self
  def name
    'date'
  end
  def description
    CONF['commands']['date']
  end
  def run
    out = File.open(CONF['output'], 'a')
    out.write("#{Time.now.strftime('%H:%M:%S %d.%m.%y')}: command - #{self.name}\n")
    puts "Current date:  #{Time.now}"
    out.close
  end
  end
end

class EchoCommand < Command
  class << self
  def name
    'echo'
  end
  def description
    CONF['commands']['echo']
  end
  def run_echo
    yield('Hi! Put something:', 'true')
  end

  def run(m = '')
    out = File.open(CONF['output'], 'a')
    out.write("#{Time.now.strftime('%H:%M:%S %d.%m.%y')}: command - #{self.name} - #{m}\n")
    if !m.empty?
      puts "Your first passed argument: #{m}"
      out.write("       #{m}\n")
    else
      run_echo do |message, wait_answer|
        puts message
        print '> '
        user_input = gets.chomp if wait_answer
        puts "Your first passed argument: #{user_input}"
        out.write("       #{user_input}\n")
      end
    end
    out.close
  end
  end
end

class PingCommand < Command
  class << self
  def name
   'ping'
  end
  def description
    CONF['commands']['ping']
  end
  def run(*servername, ping_count: 4)
    out = File.open(CONF['output'], 'a')
    out.write("#{Time.now.strftime('%H:%M:%S %d.%m.%y')}: command - #{self.name} - #{servername}\n")
    if @arg
      puts "Pinging now...\n"
      puts `ping -q -c #{ ping_count } #{ servername }`
      out.write("       #{$?.exitstatus}\n")
      if $?.exitstatus == 0
        puts "\n#{ servername } is up!\n\n"
        out.write("       #{ servername } is up!\n")
      end
    else
      puts 'Please enter servername: '
      servername = gets.chomp.split
      puts "Pinging now...\n"
      puts `ping -q -c #{ ping_count } #{ servername[0]}`
      out.write("       #{$?.exitstatus}\n")
      if $?.exitstatus == 0
        puts "\n#{servername[0]} is up!\n\n"
        out.write("       #{ servername[0] } is up!\n")
      end
    end
    out.close
  end
  end
end

init_command

def error_mode(exc)
  $stderr = File.open(CONF['error'], 'a')
  $stderr.puts "#{exc.class} - #{exc.exception} - #{exc.backtrace if DEB}"
  $stderr.close
  puts "#{exc.class} - #{exc.message} - #{exc.backtrace if DEB}"
end

loop do
  begin
    print '$ '
    cmd_input = gets.chomp.split
    next if cmd_input.empty?
    cmd_command = cmd_input.shift.downcase
    cmd_argument = cmd_input[0]
    abort('Good Bye!') if cmd_command == 'exit'
    begin
      current_command = Command.command_by_name(cmd_command)
    rescue => e
      File.write('/tmp/errors.log', e.inspect)
      next
    end
    if cmd_argument == 'help'
      p current_command.description
    elsif current_command == EchoCommand && cmd_argument
      current_command.run(cmd_argument)
    else
      current_command.run
    end
  rescue Interrupt, NoMethodError
    abort('Good Bye!')
  end
end
