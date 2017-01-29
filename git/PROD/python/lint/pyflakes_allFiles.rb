#!/usr/bin/ruby

require 'octokit'
# repo to fetch
repo = 'SUSE/spacewalk'
# git_dir is where we have the github repo in our machine
@git_dir = '/tmp/spacewalk/'
@python_files = []
context = 'python-tests'
description = 'pyflakes-checkstyle'
@client = Octokit::Client.new(netrc: true)
@j_status = 'success'

# this function merge the pr branch  into target branch,
# where the author  of pr wanted to submit

def git_goto_prj_dir()
  # chech that dir exist, otherwise clone it
  if File.directory?(@git_dir) == false
    raise "nodir"
  end
  Dir.chdir @git_dir
end

def git_merge_pr_totarget(upstream, pr)
  git_goto_prj_dir(@git_dir)
  `git checkout #{upstream}`
  `git pull origin #{upstream}`
  `git checkout -b PR-#{pr} origin/#{pr}`
end

def git_del_pr_branch(upstream, pr)
  `git checkout #{upstream}`
  `git branch -D  PR-#{pr}`
end

# run pyflakes tests.
def run_pyflake(output)
  @python_files.each do |pyfile|
    puts pyfile
    out = `pyflakes #{pyfile}`
    @j_status = 'failure' if $CHILD_STATUS.exitstatus.nonzero?
    output.push(out)
  end
end

def pyflakes_t(upstream, pr, repo)
  # get author:
  pr_com = @client.commit(repo, pr)
  author_pr = pr_com.author.login
  @comment = "@#{author_pr}\n```console\n"
  output = []
  git_merge_pr_totarget(upstream, pr)
  run_pyflake(output)
  git_del_pr_branch(upstream, pr)
  output.each { |out| @comment << out }
  @comment << "great job, no pyflakes failures\n" if @j_status == 'success'
  @comment << ' ```'
end

# this function check only the file of a commit (latest)
# if we push 2 commits at once, the fist get untracked.
def check_for_files(repo, pr, type)
  pr_com = @client.commit(repo, pr)
  pr_com.files.each do |file|
    @python_files.push(file.filename) if file.filename.include? type
  end
end

# this check all files for a pr_number
def check_for_all_files(repo, pr_number, type)
  files = pull_request_files(repo, pr_number)
  files.each do |file|
    @python_files.push(file.filename) if file.filename.include? type
  end
end

# we put the results on the comment.
def create_comment(repo, pr, comment)
  @client.create_commit_comment(repo, pr, comment)
end

# fetch all PRS
prs = @client.pull_requests(repo, state: 'open')
prs.each do |pr|
  puts '=================================='
  puts("TITLE_PR: #{pr.title}, NR: #{pr.number}")
  puts '=================================='
  # this check the last commit state, catch for review or not reviewd status.
  commit_state = @client.status(repo, pr.head.sha)
  begin
    puts commit_state.statuses[0]['state']
  rescue NoMethodError
    check_for_all_files(repo, pr.number, '.py')
    next if @python_files.any? == false
    if @python_files.any? == true
      # pending
      @client.create_status(repo, pr.head.sha, 'pending',
                            context: context, description: description)
      # do tests
      pyflakes_t(pr.base.ref, pr.head.sha, repo)
      # set status
      @client.create_status(repo, pr.head.sha, @j_status,
                            context: context, description: description)
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
    check_for_all_files(repo, pr.number, '.py')
    next if @python_files.any? == false
    @client.create_status(repo, pr.head.sha, 'pending',
                          context: context, description: description)
    pyflakes_t(pr.base.ref, pr.head.sha, repo)
    @client.create_status(repo, pr.head.sha, @j_status,
                          context: context, description: description)
    create_comment(repo, pr.head.sha, @comment)
    break
  end
  next if commit_state.statuses[0]['description'] == description
end
# jenkins
exit 1 if @j_status == 'failure'
