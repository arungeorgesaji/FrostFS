Gem::Specification.new do |s|
  s.name        = 'frostfs'
  s.version     = '0.1.0'
  s.summary     = "A filesystem where unused files slowly 'freeze' over time"
  s.description = "FrostFS - A filesystem with automatic file freezing based on usage patterns"
  s.authors     = ["Arun George Saji"]
  s.email       = 'arungeorgesaji@gmail.com'
  s.files       = Dir['lib/**/*.rb'] + Dir['bin/*'] + ['README.md']
  s.homepage    = 'https://github.com/arungeorgesaji/frostfs'
  s.license     = 'GPL-3.0'
  
  s.add_dependency 'logging', '~> 2.3'
end
