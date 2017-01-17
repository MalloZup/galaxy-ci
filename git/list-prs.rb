#!/usr/bin/ruby

require 'octokit'
require 'optparse'
require 'json'

# some doc for accessing the prs attributes.
# https://developer.github.com/v3/pulls/#list-pull-requests


# is only on of some login methods
client = Octokit::Client.new(:netrc => true)
$repo = 'SUSE/spacewalk'

prs = client.pull_requests($repo, :state => 'open')
prs.each do |pr|
        puts(pr.number)
        puts(pr.head.sha)
        # branch
        puts(pr.base.ref)
        puts(pr.title)
        puts(pr.head.title)
        puts(pr.body)
        # get status
        pr_state = client.status($repo, pr.head.sha)
        puts "STATUS OF PR IS:  " + pr_state.state
        puts
        puts "****************************************************************************"
        puts "****************************************************************************"
        #  pending, success, error, or failure.
        #status = client.create_status($repo, "14ccc24fd574eafac203a3dc8d77da790c6321fa","failure")
      #  status = client.create_status($repo, pr.head.sha, "pending")
end
