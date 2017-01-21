#/usr/bin/ruby

require 'yaml'

conf = YAML.load_file('PR.yml')
puts conf.inspect

