#!/usr/bin/ruby

require 'octokit'
require 'optparse'
require_relative 'lib/opt_parser'
require_relative 'lib/git_op'
# run bash script to validate.
def run_bash
  out = `#{@test_file}`
  @j_status = 'failure' if $?.exitstatus.nonzero?
  @j_status = 'success' if $?.exitstatus.zero?
  puts out
end

# main function for doing the test
def pr_test(upstream, pr_sha_com, repo, pr_branch)
  git = GitOp.new(@git_dir)
  # get author:
  pr_com = @client.commit(repo, pr_sha_com)
  _author_pr = pr_com.author.login
  @comment = "##### files analyzed:\n #{@pr_files}\n"
  git.merge_pr_totarget(upstream, pr_branch, repo)
  run_bash
  git.del_pr_branch(upstream, pr_branch)
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

def launch_test_and_setup_status(repo, pr_head_sha, pr_head_ref, pr_base_ref)
  # pending
  @client.create_status(repo, pr_head_sha, 'pending',
                        context: @context, description: @description,
                        target_url: @target_url)
  # do tests
  pr_test(pr_base_ref, pr_head_sha, repo, pr_head_ref)
  # set status
  @client.create_status(repo, pr_head_sha, @j_status,
                        context: @context, description: @description,
                        target_url: @target_url)
  # create comment
  create_comment(repo, pr_head_sha, @comment)
end
# *********************************************

@options = OptParser.get_options
# git_dir is where we have the github repo in our machine
@git_dir = "/tmp/#{@options[:repo].split('/')[1]}"
@pr_files = []
@file_type = @options[:file_type]
repo = @options[:repo]
@context = @options[:context]
@description = @options[:description]
@test_file = @options[:test_file]
f_not_exist_msg = "\'#{@test_file}\' doesn't exists.Enter valid file, -t option"
raise f_not_exist_msg if File.file?(@test_file) == false
@compliment_msg = "no failures found for #{@file_type} file type! Great job"
# optional, this url will be appended on github page.(usually a jenkins) 
@target_url = 'https://JENKINS_URL:job/' \
             "MY_JOB/#{ENV['JOB_NUMBER']}"

@client = Octokit::Client.new(netrc: true)
@j_status = ''

# fetch all PRS
prs = @client.pull_requests(repo, state: 'open')
# exit if repo has no prs"
puts 'no Pull request OPEN on the REPO!' if prs.any? == false
prs.each do |pr|
  puts '=' * 30 + "\n" + "TITLE_PR: #{pr.title}, NR: #{pr.number}\n" + '=' * 30
  # this check the last commit state, catch for review or not reviewd status.
  commit_state = @client.status(repo, pr.head.sha)
  begin
    puts commit_state.statuses[0]['state']
  rescue NoMethodError
    # in this situation we have no reviews-tests set at all.
    check_for_all_files(repo, pr.number, @file_type)
    if @pr_files.any? == false
      puts "no files of type #{@file_type} found! skipping"
      next
    else
      launch_test_and_setup_status(repo, pr.head.sha, pr.head.ref, pr.base.ref)
      break
    end
  end
  puts '*' * 30 + "\nPR is already reviewed by bot \n" + '*' * 30 + "\n"
  # we run the test in 2 conditions:
  # 1) the description "pylint-test" is not set, so we are in a situation
  # like we have already 3 tests runned against a pr, but not the current one.
  # 2) is like 1 but is when something went wrong and the pending status
  # was set, but the bot exited or was buggy, or unknown failures, we want to rerun the test.
  # pending status is not a good status, so we should always have only ok or not ok.
  # and repeat the test for the pending

  #1) context_present == false make trigger the test, means we don't have tagged the PR with context
  context_present = false
  for pr_status in (0..commit_state.statuses.size - 1) do 
    context_present = true if commit_state.statuses[pr_status]['context'] == @context
  end
  # 2) pending
  pending_on_context = false
  for pr_status in (0..commit_state.statuses.size - 1) do
    if commit_state.statuses[pr_status]['context'] == @context &&
       commit_state.statuses[pr_status]['state'] == 'pending'
      pending_on_context = true
    end
  end
  # check the conditions 1,2 and it they happens run_test
  if context_present == false || pending_on_context == true
    check_for_all_files(repo, pr.number, @file_type)
    next if @pr_files.any? == false
    launch_test_and_setup_status(repo, pr.head.sha, pr.head.ref, pr.base.ref)
    break
  end
end
# jenkins
exit 1 if @j_status == 'failure'
