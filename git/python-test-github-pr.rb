#!/usr/bin/ruby
    
require 'octokit'
  
# some doc for accessing the prs attributes.
# https://developer.github.com/v3/pulls/#list-pull-requests


# PREREQUISITES: 
# 1) you need octokit, and netrc gems
# 1) you need to put the cred. in a ~/.netrc file on the jenkins-worker,
#  or where you run the tests
# 2) you need your github prject $git_dir, to be cloned there.
#  --> /tmp/spacewalk need to be a git dir
# 3) you need to run this script in a jenkins 
##
## 4) you need a user (the netrc user) that can read to the repo that you want to test the prs-automatically
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
$context = "python-tests"
# description PR made by the bot on github
$description = "pylint checks"

# where the actual job will referenced in github
$target_url = "https://ci.suse.de/view/Manager/view/Manager-Head/job/manager-Head-test-github-pr/#{ENV['JOB_NUMBER']}"
puts $target_url
 
# git_dir is where we have the github repo in our machine
$git_dir = '/tmp/spacewalk/'

## python specific variables for running a lint test (pylint)
pylint_files = Array.new
$python_failure = false

# is only on of some login methods
client = Octokit::Client.new(:netrc => true)
prs = client.pull_requests($repo, :state => 'open')
prs.each do |pr|
        # branchii
        puts "=================================="
        puts(pr.title  + " :" + pr.number.to_s)
        puts "=================================="
        #puts(pr.body) 
        
        # get status 
        pr_state = client.status($repo, pr.head.sha)
        begin
          # if this array give the ex. then the PR is not reviewed yet.
          puts pr_state.statuses[0]["state"]
        rescue NoMethodError
          puts "The PR is not reviewed by the bot"
          puts 
          pr_com = client.commit($repo, pr.head.sha)
          # search all files for .py extension, if empty go to next PR
          pr_com.files.each do |file|
            pylint_files.push(file.filename) if file.filename.include? ".py"
          end 
          if pylint_files.any? == false
            puts "___________________________________________________________"
            puts " NO PYTHON FILES FOUND ON THE PR, ANALYZE THE NEXT ONE !!!"
            puts "___________________________________________________________"
            puts
            next
          end
          puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
          puts " GOTTA TO WORK ON THIS PR! FOUND PYTHON! SKIPPING THE OTHERS"
          puts "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
          puts "set to pending"
          client.create_status($repo, pr.head.sha, "pending"  ,
                    { :context => $context,
                      :description => $description,
                      :target_url => $target_url} )

          puts 
          # 1) check which branch the pr targets
          Dir.chdir $git_dir
          check = `git checkout #{pr.base.ref}` 
          update = `git pull origin #{pr.base.ref}` 
          mk_branch = `git checkout -b PR-#{pr.head.ref} origin/#{pr.head.ref}` 
          puts "execute some tests"
          pylint_files.each do |pyfile|
            pylint_code = `pylint #{pyfile}` 
            puts pylint_code 
            $python_failure = true if pylint_code != 0
          end       
          puts "set the status of pr according to the results of tests"
          $status = 'failure' if $python_failure == true
          $status = 'success' if $python_failure == false
          back_orgin = `git checkout #{pr.base.ref}`
          delete_branch = `git branch -D  PR-#{pr.head.ref}`
          client.create_status($repo, pr.head.sha, $status,
                    { :context => $context,
                      :description => $description,
                      :target_url => $target_url} )
           
          # break, we want to execute one PR for a JOB on jenkins
          break
        end
        puts "PR is already reviewed by bot" 
        puts "******************************"
end
# exit 1 for jenkins  if the test are not good.
exit 1 if $python_failure == true
