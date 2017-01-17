#!/usr/bin/ruby
    
require 'octokit'
require 'optparse'
require 'json'
  
# some doc for accessing the prs attributes.
# https://developer.github.com/v3/pulls/#list-pull-requests


## logic of the programm:

# 1)get executed each 2-3 min.  (jenkins)
# 2) FIND OUT  IF a PR is in a unreviewed status, 
# 3) When the codition happens, then clone the pr src code, i
# 4 )and then execute the tests.
# 5) update the PR with the results of tests, (failure, or success)



$repo = 'MalloZup/spacewalk'
$context = "python-test"
$description = "automated tests-sexy"
# TODO: we should get for the jenkins job, the specific number of the build in jenkins.
$target_url = "https://ci.suse.de/view/Manager/view/Manager-Head/job/manager-Head-test-github-pr/"
# like this: https://ci.suse.de/view/Manager/view/Manager-Head/job/manager-Head-test-github-pr/61/

 
# is only on of some login methods
client = Octokit::Client.new(:netrc => true)
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
          puts pr_state.statuses[0]["state"]
        rescue NoMethodError
            puts "The PR is not reviewed by the bot"
            puts " GOTTA TO WORK ON THIS PR! SKIPPING THE OTHERS"
            puts "set to pending"
        # TODO clone the repo, checkout the sha github commit and schedule some stuf
            puts "clone repo, go to sha commit of the PR"
        # TODO: execute some tests 
           puts "execute some tests"
        # TODO
           puts "set the status of pr according to the results of tests"
	   client.create_status($repo, pr.head.sha, "pending"  ,
                                     { :context => $context,
        			       :description => $description,
        			       :target_url => $target_url} )
           break
        end
        puts "PR is already reviewed by bot" 
end
