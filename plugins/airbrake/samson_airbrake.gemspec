# frozen_string_literal: true
Gem::Specification.new 'samson_airbrake', '0.0.0' do |s|
  s.summary = 'Samson airbrake plugin'
  s.authors = ['Michael Grosser']
  s.email = ['michael@grosser.it']
  s.files = Dir['{app,config,db,lib}/**/*']
  s.add_runtime_dependency 'airbrake'
end
