#!/usr/bin/ruby
    
require 'octokit'
  
# some doc for accessing the prs attributes.
# https://developer.github.com/v3/pulls/#list-pull-requests


## HOW IT WORKS:

# 1) run this ruby script on jenkins,  get executed each 2-3 min.  
# 2) FIND OUT  IF a PR is in a unreviewed status, 
# 3) When the codition happens, then clone the pr src code, i
# 4 )and then execute the tests.
# 5) update the PR with the results of tests, (failure, or success)

$repo = 'SUSE/spacewalk'
# project var is used for building the pr 
$project = 'spacewalk'
# context is the label put by the bot into github
$context = "python-test"
# description PR made by the bot on github
$description = "testing the galxy-bot"
# TODO: we should get for the jenkins job, the specific number of the build in jenkins.
$target_url = "https://ci.suse.de/view/Manager/view/Manager-Head/job/manager-Head-test-github-pr/"
# like this: https://ci.suse.de/view/Manager/view/Manager-Head/job/manager-Head-test-github-pr/61/
 
# spacewalk_dir is where we have the github repo in our machine
$spacewalk_dir = '/tmp/spacewalk/'

## python specific variables for running a lint test (pylint)
pylint_files = Array.new
$python_failure = false

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
          pr_com = client.commit($repo, pr.head.sha)
          pr_com.files.each do |file|
            pylint_files.push(file.filename) if file.filename.include? ".py"
          end 
          puts " GOTTA TO WORK ON THIS PR! SKIPPING THE OTHERS"
          puts "set to pending"
#            client.create_status($repo, pr.head.sha, "pending"  ,
#                    { :context => $context,
#                      :description => $description,
#                      :target_url => $target_url} )

          puts 
          $pr_nickname = pr_com.author.login 
          $pr_head_branch = pr.head.ref
          # 1) check which branch the pr targets
          Dir.chdir $spacewalk_dir
          check = `git checkout #{pr.base.ref}` 
          update = `git pull origin #{pr.base.ref}` 
          mk_branch = `git checkout -b PR-#{pr.head.ref} origin/#{pr.head.ref}` 
          # git checkout Manager-3.0  or Manager 
          # 2) update latest change : git pull origin $base_branch
          # 3) create repo from that to new PR-repo (head_branch)
          # git checkout -b PR-Manager-3.0-set-user-localtime-in-highstate Manager-3.0-set-user-localtime-in-highstate 
        # TODO: execute some tests 
           pylint_files.each do |pyfile|
             pylint_code = `pylint #{pyfile}` 
             puts pylint_code 
             $python_failure = true if pylint_code != 0
           puts "execute some tests"
        # TODO
           puts "set the status of pr according to the results of tests"
          break
        end
        puts "PR is already reviewed by bot" 
        puts "******************************"
end
