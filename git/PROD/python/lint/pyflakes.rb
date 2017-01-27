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
$python_files = []
context = "python-tests"
description = "pyflakes-checkstyle"
$client = Octokit::Client.new(netrc: true)
$j_status = 'success'

def pyflakes_test(upstream, pr, repo)
  # get author:
  pr_com = $client.commit(repo, pr)
  author_pr = pr_com.author.login
  $comment = "@#{author_pr}\n"
  $comment << "```console\n"
  output = []
  Dir.chdir $git_dir
  `git checkout #{upstream}`
  `git pull origin #{upstream}`
  `git checkout -b PR-#{pr} origin/#{pr}`
   $python_files.each do |pyfile|
     puts pyfile
     out = `pyflakes #{pyfile}`
     $j_status = 'failure' if  $?.exitstatus != 0
     puts out
     output.push(out)
   end
  `git checkout #{upstream}`
  `git branch -D  PR-#{pr}`
   output.each do | out | 
     $comment << out
   end
   $comment << "great job, no pyflakes failures" if $j_status == 'success'
   $comment << " ```"
end

def check_for_files(repo, pr, type)
  pr_com = $client.commit(repo, pr)
  pr_com.files.each do |file|
    $python_files.push(file.filename) if file.filename.include? type
  end
end

def create_comment(repo, pr, comment)
  $client.create_commit_comment(repo, pr, comment)
end

# fetch all PRS
prs = $client.pull_requests(repo, state: 'open')
prs.each do |pr|
  puts '=================================='
  puts("TITLE_PR: #{pr.title}, NR: #{pr.number}")
  puts '=================================='
  pr_state = $client.status(repo, pr.head.sha)
  begin
    puts pr_state.statuses[0]['state']
  rescue NoMethodError
    check_for_files(repo, pr.head.sha, '.py')
    next if $python_files.any? == false
    if $python_files.any? == true
      # pending
      $client.create_status(repo, pr.head.sha, 'pending', context: context, description: description)
      # do tests
      pyflakes_test(pr.base.ref, pr.head.sha, repo)
      # set status
      $client.create_status(repo, pr.head.sha, $j_status,  context: context, description: description)
      # create comment
      create_comment(repo, pr.head.sha, $comment)
      break 
    end
  end
  puts '******************************'
  puts 'PR is already reviewed by bot'
  puts '******************************'
  if pr_state.statuses[0]['description'] != description || pr_state.statuses[0]['state'] == 'pending' || 
     pr_state.statuses[0]['state'] == 'failure'
     check_for_files(repo, pr.head.sha, '.py')
     next if $python_files.any? == false
     $client.create_status(repo, pr.head.sha, 'pending', context: context, description: description)
     pyflakes_test(pr.base.ref, pr.head.sha, repo)
     $client.create_status(repo, pr.head.sha, $j_status,
                         context: context, description: description)
     create_comment(repo, pr.head.sha, $comment)
     break 
  end
  next if pr_state.statuses[0]['description']  == description
end

# jenkins 
exit 1 if $j_status == 'failure'
