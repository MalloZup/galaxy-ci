#!/usr/bin/ruby

require 'octokit'
require 'optparse'
require_relative "lib/opt_parser" 
require_relative "lib/git_op" 

# run bash script to validate.
def run_bash(output)
    out = `sh #{@bash_file}`
    @comment << out
    @j_status = 'failure' if $?.exitstatus.nonzero?
    output.push(out) if $?.exitstatus.nonzero?
end

# main function for doing the test
def pr_test(upstream, pr_sha_com, repo, pr_branch)
  git = GitOp.new(@git_dir)
  # get author:
  pr_com = @client.commit(repo, pr_sha_com)
  author_pr = pr_com.author.login
  @comment = "##### files analyzed:\n #{@pr_files}\n"
  @comment << "@#{author_pr}\n```console\n"
  output = []
  git.merge_pr_totarget(upstream, pr_branch, repo)
  run_bash(output)
  git.del_pr_branch(upstream, pr_branch)
  output.each { |out| @comment << out }
  @comment << " ```\n"
  @comment << "#{@compliment_msg}\n" if @j_status == 'success'
end

# this function check only the file of a commit (latest)
# if we push 2 commits at once, the fist get untracked.
def check_for_files(repo, pr, type)
  pr_com = @client.commit(repo, pr)
  pr_com.files.each do |file|
    @pr_files.push(file.filename) if file.filename.include? type
  end
end

# this check all files for a pr_number
def check_for_all_files(repo, pr_number, type)
  files = @client.pull_request_files(repo, pr_number)
  files.each do |file|
    @pr_files.push(file.filename) if file.filename.include? type
  end
end

# we put the results on the comment.
def create_comment(repo, pr, comment)
  @client.create_commit_comment(repo, pr, comment)
end



@options = OptParser.get_options

# git_dir is where we have the github repo in our machine
@git_dir = "/tmp/#{@options[:repo].split('/')[1]}"
@pr_files = []
@file_type = @options[:file_type]
repo = @options[:repo]
context = @options[:context]
description = @options[:description]
@bash_file = @options[:bash_file]
@compliment_msg = "no failures found for #{@file_type}! Great job"


# optional
@target_url = 'https://JENKINS_URL:job/' \
             "MY_JOB/#{ENV['JOB_NUMBER']}"

@client = Octokit::Client.new(netrc: true)
@j_status = 'success'

# fetch all PRS
prs = @client.pull_requests(repo, state: 'open')
# exit if repo has no prs"
puts "no Pull request OPEN on the REPO!" if prs.any? == false
prs.each do |pr|
  puts '=================================='
  puts("TITLE_PR: #{pr.title}, NR: #{pr.number}")
  puts '=================================='
  # this check the last commit state, catch for review or not reviewd status.
  commit_state = @client.status(repo, pr.head.sha)
  begin
    puts commit_state.statuses[0]['state']
  rescue NoMethodError
    check_for_all_files(repo, pr.number, @file_type)
    next if @pr_files.any? == false
    if @pr_files.any? == true
      # pending
      @client.create_status(repo, pr.head.sha, 'pending',
                            context: context, description: description, target_url: @target_url)
      # do tests
      pr_test(pr.base.ref, pr.head.sha, repo, pr.head.ref)
      # set status
      @client.create_status(repo, pr.head.sha, @j_status,
                            context: context, description: description, target_url: @target_url)
      # create comment
      create_comment(repo, pr.head.sha, @comment)
      break
    end
  end
  puts '******************************'
  puts 'PR is already reviewed by bot'
  puts '******************************'
  if commit_state.statuses[0]['description'] != description ||
     commit_state.statuses[0]['state'] == 'pending'

    check_for_all_files(repo, pr.number, @file_type)
    next if @pr_files.any? == false
    @client.create_status(repo, pr.head.sha, 'pending',
                          context: context, description: description, target_url: @target_url)
    pr_test(pr.base.ref, pr.head.sha, repo, pr.head.ref)
    @client.create_status(repo, pr.head.sha, @j_status,
                          context: context, description: description, target_url: @target_url)
    create_comment(repo, pr.head.sha, @comment)
    break
  end
  next if commit_state.statuses[0]['description'] == description
end
# jenkins
exit 1 if @j_status == 'failure'
