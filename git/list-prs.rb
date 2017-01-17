#!/usr/bin/ruby

require 'octokit'
require 'optparse'
require 'json'

# some doc for accessing the prs attributes.
# https://developer.github.com/v3/pulls/#list-pull-requests


# is only on of some other login methods
# you need the netrc file 
client = Octokit::Client.new(:netrc => true)
$repo = 'MalloZup/spacewalk'

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
        begin
          # when this happen, the pr contain a new unreviewd commit
          puts pr_state.statuses[0]["state"]
        rescue NoMethodError
            puts "The PR is not reviewed by the bot"
            next
        end
        puts "set to pending"
        # Set the PR to  pending.
        status = client.create_status($repo, pr.head.sha, "pending")

        # TODO clone the repo, checkout the sha github commit and schedule some stuf
        
        # TODO: set the result, failure or success.
end
