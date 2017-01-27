#!/usr/bin/ruby

require 'octokit'

## INPUT:
# repo to fetch
repo = 'SUSE/spacewalk'
# context is the label printed by the bot into github, in the checks
target_url = 'https://ci.suse.de/view/Manager/view/Manager-Head/job/' \
             "manager-Head-test-github-pr/#{ENV['JOB_NUMBER']}"
# git_dir is where we have the github repo in our machine
$git_dir = '/tmp/spacewalk/'

$java_files = []
context = "java-tests"
description = "java-checkstyle"
client = Octokit::Client.new(netrc: true)
$j_status = 'error'

def java_test(upstream, pr)
  Dir.chdir $git_dir
  `git checkout #{upstream}`
  `git pull origin #{upstream}`
  `git checkout -b PR-#{pr} origin/#{pr}`
   # tests java-lint
   Dir.chdir 'java'
   puts 'branch'
   puts `git branch`
   `ant resolve-ivy`
   $j_status = 'error' if  $?.exitstatus == false
   puts `ant -f manager-build.xml checkstyle`
   $j_status = 'failure' if  $?.exitstatus == false
   $j_status = 'success' if $?.exitstatus == true
   puts "finish test"
  `git checkout #{upstream}`
  `git branch -D  PR-#{pr}`
end

def check_for_files(repo, pr, type)
  pr_com = client.commit(repo, pr)
  pr_com.files.each do |file|
    $java_files.push(file.filename) if file.filename.include? type
  end
end

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
    check_for_files(repo, pr.head.sha, '.java')
    next if $java_files.any? == false
    if java_files.any? == true
      # pending
      client.create_status(repo, pr.head.sha, 'pending', context: context, description: description)
      # do tests
      java_test(pr.base.ref, pr.head.ref)
      # set status
      client.create_status(repo, pr.head.sha, $j_status,  context: context, description: description)
      break 
    end
  end
  puts '******************************'
  puts 'PR is already reviewed by bot'
  puts '******************************'
  # do some java test, if python check are fine.
  
  next if pr_state.statuses[0]['description']  == description

  if pr_state.statuses[0]['description'] != description || pr_state.statuses[0]['state'] == 'pending'
     check_for_files(repo, pr.head.sha, '.java')
     next if $java_files.any? == false
     client.create_status(repo, pr.head.sha, 'pending', context: context, description: description)
     java_test(pr.base.ref, pr.head.ref)
     client.create_status(repo, pr.head.sha, $j_status,
                         context: context, description: description)
     break 
  end
end
