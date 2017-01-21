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
#
# 4) you need a user (the netrc user) that can read to the repo,
#  that you want to test the prs-automatically

# HOW IT WORKS:
# 1) run this ruby script on jenkins,  get executed each 2-3 min.
# 2) Find out  If a PR is in a unreviewed status,
# 3) When the codition happens, then clone the pr src code, i
# 4) and then execute the tests.
# 5) update the PR with the results of tests, (failure, or success)

## INPUT:
# repo to fetch
repo = 'SUSE/spacewalk'
# context is the label printed by the bot into github, in the checks
context = 'python-tests'
# description PR made by the bot on github
description = 'pylint checks'
# where the actual job will referenced in github.
# ( i export in jenkins the var JOB_NUMBER that give the number of job
target_url = 'https://ci.suse.de/view/Manager/view/Manager-Head/job/' \
             "manager-Head-test-github-pr/#{ENV['JOB_NUMBER']}"
# git_dir is where we have the github repo in our machine
git_dir = '/tmp/spacewalk/'

## python specific variables for running a lint test (pylint)
pylint_files = []
python_failure = false

# This is only one of some login methods. (i found it the best one)
# it will look at ~/.netrc cred.
client = Octokit::Client.new(netrc: true)

# fetch all PRS
prs = client.pull_requests(repo, state: 'open')
prs.each do |pr|
  puts '=================================='
  puts("TITLE_PR: #{pr.title}, NR: #{pr.number}")
  puts '=================================='
  # puts(pr.body)
  # get status
  pr_state = client.status(repo, pr.head.sha)
  begin
    # if this array give the ex. then the PR is not reviewed yet.
    puts pr_state.statuses[0]['state']
  rescue NoMethodError
    puts 'The PR is not reviewed by the bot'
    puts
    pr_com = client.commit(repo, pr.head.sha)
    # search all files for .py extension, if empty go to next PR
    pr_com.files.each do |file|
      pylint_files.push(file.filename) if file.filename.include? '.py'
    end
    # check if we have in the changed file by the pr, some python files there
    if pylint_files.any? == false
      puts '___________________________________________________________'
      puts ' NO PYTHON FILES FOUND ON THE PR, ANALYZE THE NEXT ONE !!!'
      puts '___________________________________________________________'
      puts
      next
    end
    puts '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    puts 'GOTTA TO WORK ON THIS PR! FOUND PYTHON! SKIPPING THE OTHERS'
    puts '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!'
    puts 'set to pending'
    client.create_status(repo, pr.head.sha, 'pending',
                         context: context, description: description,
                         target_url: target_url)
    puts
    # there is a git library, but i didn't want to add some extra dep.
    # 1) check which branch the pr targets
    Dir.chdir git_dir
    `git checkout #{pr.base.ref}`
    `git pull origin #{pr.base.ref}`
    `git checkout -b PR-#{pr.head.ref} origin/#{pr.head.ref}`
    # execute some tests
    pylint_files.each do |pyfile|
      pylint_code = `pylint #{pyfile}`
      python_failure = true if pylint_code.nonzero?
      puts '=============================='
    end
    puts 'set the status of pr according to the results of tests'
    status = 'failure' if python_failure == true
    status = 'success' if python_failure == false
    `git checkout #{pr.base.ref}`
    `git branch -D  PR-#{pr.head.ref}`
    client.create_status(repo, pr.head.sha, status,
                         context: context, description: description,
                         target_url: target_url)
    # break, we want to execute one PR for a JOB on jenkins
    break
  end
  puts '******************************'
  puts 'PR is already reviewed by bot'
  puts '******************************'
end

# exit 1 for jenkins  if the test are not good.
exit 1 if python_failure == true
