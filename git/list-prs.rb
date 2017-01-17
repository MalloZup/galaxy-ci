#!/usr/bin/ruby

require 'octokit'
require 'optparse'
require 'json'

# some doc for accessing the prs attributes.
# https://developer.github.com/v3/pulls/#list-pull-requests


#  create a ~/.netrc file, like this:
# machine api.github.com
#   login MYBOT_USER
#  password MYPASSWORD

# is only on of some login methods
client = Octokit::Client.new(:netrc => true)

client.auto_paginate = true

prs = client.pull_requests('MalloZup/spacewalk', :state => 'open')
prs.each do |pr|
        puts(pr.number)
        puts(pr.head.sha)
        # branch
        puts(pr.base.ref)
        puts(pr.state)
        puts(pr.title)
        puts(pr.body)
end
