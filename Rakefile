require 'fileutils'
require 'bundler/setup'
require 'yaml'
require 'redis'
require 'resque/tasks'
require 'resque/scheduler/tasks'

ROOT_PATH = File.dirname(__FILE__) + '/../'

# Start a worker with proper env vars and output redirection
def run_worker(queue, count = 1)
  puts "Starting #{count} worker(s) with QUEUE: #{queue}"
  ops = {:pgroup => true, :err => [(ROOT_PATH + "log/resque.workers.error.log").to_s, "a"],
                          :out => [(ROOT_PATH + "log/resque.workers.log").to_s, "a"]}
  env_vars = {"QUEUE" => queue.to_s}
  count.times {
    ## Using Kernel.spawn and Process.detach because regular system() call would
    ## cause the processes to quit when capistrano finishes
    pid = spawn(env_vars, "rake resque:work", ops)
    Process.detach(pid)
  }
end

# Start a scheduler, requires resque_scheduler >= 2.0.0.f
def run_scheduler
  puts "Starting resque scheduler"
  env_vars = {
    "BACKGROUND" => "1",
    "PIDFILE" => (ROOT_PATH + "/pid/resque-scheduler.pid").to_s,
    "VERBOSE" => "1"
  }
  ops = {:pgroup => true, :err => [(ROOT_PATH + "log/resque.scheduler.error.log").to_s, "a"],
                          :out => [(ROOT_PATH + "log/resque.scheduler.log").to_s, "a"]}
  pid = spawn(env_vars, "rake resque:scheduler", ops)
  Process.detach(pid)
end

namespace :resque do
  task :environment do
    require 'resque'
    require 'resque_scheduler'
    require 'resque/scheduler'

    Resque.redis = 'localhost:6379'
    Resque.schedule = YAML.load_file('config/schedule.yml')
    require_relative 'jobs'
  end

  task :setup => :environment

  desc "Restart running workers"
  task :restart_workers => :environment do
    Rake::Task['resque:stop_workers'].invoke
    Rake::Task['resque:start_workers'].invoke
  end

  desc "Quit running workers"
  task :stop_workers => :environment do
    pids = Array.new
    Resque.workers.each do |worker|
      pids.concat(worker.worker_pids)
    end
    if pids.empty?
      puts "No workers to kill"
    else
      syscmd = "kill -s QUIT #{pids.join(' ')}"
      puts "Running syscmd: #{syscmd}"
      system(syscmd)
    end
  end

  desc "Start workers"
  task :start_workers => :environment do
    run_worker("*", 2)
    run_worker("high", 1)
  end

  desc "Restart scheduler"
  task :restart_scheduler => :environment do
    Rake::Task['resque:stop_scheduler'].invoke
    Rake::Task['resque:start_scheduler'].invoke
  end

  desc "Quit scheduler"
  task :stop_scheduler => :environment do
    pidfile = ROOT_PATH + "pid/resque-scheduler.pid"
    if !File.exists?(pidfile)
      puts "Scheduler not running"
    else
      pid = File.read(pidfile).to_i
      syscmd = "kill -s QUIT #{pid}"
      puts "Running syscmd: #{syscmd}"
      system(syscmd)
      FileUtils.rm_f(pidfile)
    end
  end

  desc "Start scheduler"
  task :start_scheduler => :environment do
    run_scheduler
  end

  desc "Reload schedule"
  task :reload_schedule => :environment do
    pidfile = ROOT_PATH + "pid/resque-scheduler.pid"

    if !File.exists?(pidfile)
      puts "Scheduler not running"
    else
      pid = File.read(pidfile).to_i
      syscmd = "kill -s USR2 #{pid}"
      puts "Running syscmd: #{syscmd}"
      system(syscmd)
    end
  end
end

# # #

def gemspec
  name = Dir['*.gemspec'].first
  @gemspec ||= eval(File.read(name), binding, name)
end

desc "Build the gem"
task :gem => :gemspec do
  sh "gem build #{gemspec.name}.gemspec"
  FileUtils.mkdir_p 'pkg'
  FileUtils.mv "#{gemspec.name}-#{gemspec.version}.gem", 'pkg'
end

desc "Install the gem locally"
task :install => :gem do
  sh %{gem install pkg/#{gemspec.name}-#{gemspec.version}.gem --no-doc}
end

desc "Generate the gemspec"
task :generate do
  puts gemspec.to_ruby
end

desc "Validate the gemspec"
task :gemspec do
  gemspec.validate
end

desc 'rspec specs'
task :spec do
  sh %[rspec spec]
end

task :default => :spec
task :test    => :spec

