#/usr/bin/ruby

require 'json'
conf = JSON.parse(File.read('PR.json'))
puts conf['repo']
puts conf['context']
puts conf['description']
puts conf['target_url']
puts conf['git_dir']
