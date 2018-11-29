Gem::Specification.new do |s|
  s.name        = 'capistrano-scm-maven'
  s.version     = '0.0.1'
  s.date        = '2018-08-16'
  s.summary     = 'A Custom SCM for Maven artifacts'
  s.description = 'Used much like the Capistrano Git SCM plugin but for when the source is contanined in a binary distribution hosted by an artifact manager instead of source control'
  s.authors     = ['Andrew Goodnough']
  s.email       = 'agoodno@gmail.com'
  s.files       = Dir['lib/**/*', 'Rakefile', 'README.md']
  s.homepage    = 'http://rubygems.org/gems/capistrano-scm-maven'
  s.license     = 'MIT'
  s.add_runtime_dependency 'nokogiri', '~> 1.8', '>= 1.8.5'
end
