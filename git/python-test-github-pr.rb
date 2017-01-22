#!/usr/bin/ruby

require 'octokit'
require 'json'

# some doc for accessing the prs attributes.
# https://developer.github.com/v3/pulls/#list-pull-requests

# PREREQUISITES:
# 1) you need octokit, and netrc gems
# 1) you need to put the cred. in a ~/.netrc file on the jenkins-worker,
#  or where you run the tests
# 2) you need your github prject $git_dir, to be cloned there.
#  --> /tmp/spacewalk need to be a git dir
# 3) you need a user (the netrc credentials) that can read to the repo,
#  this user will post mgs on prs-github.

# HOW IT WORKS:
# 1) run this ruby script on jenkins, execute this each 2-3 min.
# 2) Find out  If a PR is in a unreviewed status,
# 3) if yes execute tests (set PR to pending)
# 4) the  update the PR with the results of tests, (failure, or success)


conf = JSON.parse(File.read('PR.json'))
# repo to test prs
repo =  conf['repo']
# label for pr comment
context = conf['context']
# descr. set after the label
description = conf['description']
# target_url: this link is posted on the pr, jenkins_url
target_url = "conf['target_url']/#{ENV['JOB_NUMBER']}"
# where the git repo is stored on the worker of jenkins
git_dir = conf['git_dir']

## python specific variables for running a lint test (pylint)
pylint_files = []
# by default all test pass
python_failure = false

# This is only one of some login methods. (i found it the best one)
#  it need github credentials  ~/.netrc

client = Octokit::Client.new(netrc: true)
# fetch all open prs of a repo
prs = client.pull_requests(repo, state: 'open')
# analyze PR one by one
prs.each do |pr|
  puts '=================================='
  puts("TITLE_PR: #{pr.title}, NR: #{pr.number}")
  puts '=================================='
  # get status
  pr_state = client.status(repo, pr.head.sha)
  begin
    # if this array give the ex. then the PR is not reviewed yet.
    puts pr_state.statuses[0]['state']
  rescue NoMethodError
    puts 'The PR is not reviewed by the bot'
    # fetch commit info for this specific pr
    pr_com = client.commit(repo, pr.head.sha)
    # search all files for .py extension, if empty go to next PR
    pr_com.files.each do |file|
      pylint_files.push(file.filename) if file.filename.include? '.py'
    end
    # check if we have in the changed file by the pr, some python files there
    if pylint_files.any? == false
      puts ' NO PYTHON FILES FOUND ON THE PR, ANALYZE THE NEXT ONE !!!'
      next
    end
    puts 'Make test on the PR'
    # set to pending the PR on github. Yellow color
    client.create_status(repo, pr.head.sha, 'pending',
                         context: context, description: description,
                         target_url: target_url)
    puts
    # GIT: GET INFO OF PRS BRANCHES
    # base is the target branch, where the pr get merged
    # head is the pr branch
    Dir.chdir git_dir
    `git checkout #{pr.base.ref}`
    `git pull origin #{pr.base.ref}`
    `git checkout -b PR-#{pr.head.ref} origin/#{pr.head.ref}`
    pylint_files.each do |pyfile|
      pylint_code = `pylint #{pyfile}`
      python_failure = true if pylint_code.nonzero?
    end
    puts 'set the status of pr according to the results of tests'
    status = 'failure' if python_failure == true
    status = 'success' if python_failure == false
    `git checkout #{pr.base.ref}`
    `git branch -D  PR-#{pr.head.ref}`
    client.create_status(repo, pr.head.sha, status,
                         context: context, description: description,
                         target_url: target_url)
    # break, execute only one PR test for only a single JOB on jenkins
    # because we want to have different job links for diff. PR
    break
  end
  puts '******************************'
  puts 'PR is already reviewed by bot'
  puts '******************************'
end

# exit 1 for jenkins  if the test are not good.
exit 1 if python_failure == true
