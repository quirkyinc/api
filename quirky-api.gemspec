# encoding: utf-8

$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'quirky-api/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'quirky-api'
  s.version     = QuirkyApi::VERSION
  s.authors     = ['Quirky Development', 'Michael Chittenden']
  s.email       = ['platform@quirky.com', 'mchittenden@quirky.com']
  s.homepage    = 'https://www.quirky.com'
  s.summary     = 'Quirky API is a set of tools to improve API responses.'
  s.description = 'Quirky API gem is a set of tools used to maintain API ' \
                  'response unity across Quirky services.'
  s.license     = 'MIT'

  s.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.rdoc']

  s.add_dependency 'active_model_serializers', '0.8.1'
  s.add_dependency 'will_paginate', '3.0.5'
  s.add_dependency 'newrelic_rpm'
  s.add_dependency 'hirb'
  s.add_dependency 'responders'

  s.add_development_dependency 'faker'
  s.add_development_dependency 'rails', '4.2'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'capybara'
  s.add_development_dependency 'factory_girl_rails'
end
