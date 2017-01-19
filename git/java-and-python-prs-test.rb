#!/usr/bin/ruby

require 'octokit'
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
java_files = []
python_failure = false
java_context = "java-tests"
java_description = "java-lint-check"

client = Octokit::Client.new(netrc: true)

# fetch all PRS
prs = client.pull_requests(repo, state: 'open')
prs.each do |pr|
  puts '=================================='
  puts("TITLE_PR: #{pr.title}, NR: #{pr.number}")
  puts '=================================='
  pr_state = client.status(repo, pr.head.sha)
  begin
    puts pr_state.statuses[0]['state']
  rescue NoMethodError
    pr_com = client.commit(repo, pr.head.sha)
    pr_com.files.each do |file|
      pylint_files.push(file.filename) if file.filename.include? '.py'
    end
    pr_com.files.each do |file|
      java_files.push(file.filename) if file.filename.include? '.java'
    end
    next if java_files.any == true && pylint.files.any == true
    if java_files.any? != false
      client.create_status(repo, pr.head.sha, 'pending',
                         context: java_context, description: java_description,
                         target_url: target_url)
      # do tests
      Dir.chdir git_dir
     `git checkout #{pr.base.ref}`
     `git pull origin #{pr.base.ref}`
     `git checkout -b PR-#{pr.head.ref} origin/#{pr.head.ref}`
      # tests java-lint
     `cd /manager/java`
      `ant resolve-ivy`
      java_code = `ant -f manager-build.xml checkstyle`
     `git checkout #{pr.base.ref}`
     `git branch -D  PR-#{pr.head.ref}`
      j_status = 'failure' if java_code == 0 
      j_status = 'success' if java_code != 0
     `git checkout #{pr.base.ref}`
     `git branch -D  PR-#{pr.head.ref}`
      client.create_status(repo, pr.head.sha, j_status,
                         context: java_context, description: java_description,
                         target_url: target_url)
      break 
    end
    if pylint_files.any? != false
      client.create_status(repo, pr.head.sha, 'pending',
                         context: context, description: description,
                         target_url: target_url)
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
    ` git checkout #{pr.base.ref}`
    ` git branch -D  PR-#{pr.head.ref}`
      client.create_status(repo, pr.head.sha, status,
                         context: context, description: description,
                         target_url: target_url)
    # break, we want to execute one PR for a JOB on jenkins
      break
    end
  end
  puts '******************************'
  puts 'PR is already reviewed by bot'
  puts '******************************'
  # do some java test, if python check are fine.
  next if pr_state.statuses[0]['description']  == java_description
  if pr_state.statuses[0]['description'].include? description
     pr_com = client.commit(repo, pr.head.sha)
     pr_com.files.each do |file|
       java_files.push(file.filename) if file.filename.include? '.java'
     end
     next if java_files.any? == false
     client.create_status(repo, pr.head.sha, 'pending',
                         context: java_context, description: java_description,
                         target_url: target_url)
     # do tests
     Dir.chdir git_dir
    `git checkout #{pr.base.ref}`
    `git pull origin #{pr.base.ref}`
    `git checkout -b PR-#{pr.head.ref} origin/#{pr.head.ref}`
     # tests java-lint
    `cd /manager/java`
     `ant resolve-ivy`
     java_code = `ant -f manager-build.xml checkstyle`
    `git checkout #{pr.base.ref}`
    `git branch -D  PR-#{pr.head.ref}`
     j_status = 'failure' if java_code == 0 
     j_status = 'success' if java_code != 0
    `git checkout #{pr.base.ref}`
    `git branch -D  PR-#{pr.head.ref}`
     client.create_status(repo, pr.head.sha, j_status,
                         context: java_context, description: java_description,
                         target_url: target_url)
     break 
  end
end
# exit 1 for jenkins  if the test are not good.
exit 1 if python_failure == true
