require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc "Run all tests"
task test: :spec

desc "Start interactive console"
task :console do
  exec "irb -r ./lib/frostfs.rb"
end
