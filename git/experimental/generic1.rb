#!/usr/bin/ruby

require 'octokit'
require 'optparse'
require_relative "lib/opt_parser" 

@options = {}
def parse_option()
  def raise_verbose_help(msg)
    puts @opt_parser 
    puts "***************************************************************\n"
    raise OptionParser::MissingArgument, msg
  end
  name = './gitbot.rb'
  @opt_parser = OptionParser.new do |opt|
    opt.banner = "***************************************************************\n" \
                 "Usage: gitbot [OPTIONS] \n" \
                 "EXAMPLE: ======> #{name} -r MalloZup/galaxy-botkins -c \"python-test\" -d \"pyflakes_linttest\" -t /home/mallozup/bin/tests.sh -f \".py\"\n\n"

    opt.separator  "Options"

    opt.on("-r","--repo REPO","which github repo you want to run test against " \
                               "EXAMPLE: USER/REPO  MalloZup/gitbot") do |repo|
      @options[:repo] = repo
    end

    opt.on("-c","--context CONTEXT","context to set on comment"\
                                "EXAMPLE: CONTEXT: python-test") do |context|
      @options[:context] = context
    end

    opt.on("-d","--description DESCRIPTION","description to set on comment"\
                                            ) do |description|
      @options[:description] = description
    end

    opt.on("-t","--test TEST.SH","fullpath to the bash script which contain test to be executed for pr") do |bash_file|
      @options[:bash_file] = bash_file
    end

    opt.on("-f","--file \'.py\'", "specify the file type of the pr which you want to run the test against (ex .py, .java, .rb  etc)") do |file_type|
      @options[:file_type] = file_type
    end

    opt.on("-h","--help","help") do
      puts @opt_parser 
      puts "***************************************************************\n"
      exit 0
    end
  end
  @opt_parser.parse!
  raise_verbose_help('REPO') if @options[:repo].nil?
  raise_verbose_help('CONTEXT') if @options[:context].nil?
  raise_verbose_help('DESCRIPTION') if @options[:description].nil?
  raise_verbose_help('TEST.sh') if @options[:bash_file].nil?
  raise_verbose_help('TYPE FILE') if @options[:file_type].nil?
end

# this function merge the pr branch  into target branch,
# where the author of pr wanted to submit
def git_goto_prj_dir(repo)
  # chech that dir exist, otherwise clone it
  if File.directory?(@git_dir) == false
    Dir.chdir '/tmp'
    puts 'cloning the project in tmp'
    `git clone git@github.com:#{repo}.git`
  end
  Dir.chdir @git_dir
end

# merge pr_branch into upstream targeted branch
def git_merge_pr_totarget(upstream, pr_branch, repo)
  git_goto_prj_dir(repo)
  `git checkout #{upstream}`
  `git fetch origin`
  `git pull origin #{upstream}`
  `git checkout -b PR-#{pr_branch} origin/#{pr_branch}`
end

# cleanup the pr_branch(delete it)
def git_del_pr_branch(upstream, pr)
  `git checkout #{upstream}`
  `git branch -D  PR-#{pr}`
end

# run bash script to validate.
def run_bash(output)
    out = `sh #{@bash_file}`
    @comment << out
    @j_status = 'failure' if $?.exitstatus.nonzero?
    output.push(out) if $?.exitstatus.nonzero?
end

# main function for doing the test
def pr_test(upstream, pr_sha_com, repo, pr_branch)
  # get author:
  pr_com = @client.commit(repo, pr_sha_com)
  author_pr = pr_com.author.login
  @comment = "##### files analyzed:\n #{@pr_files}\n"
  @comment << "@#{author_pr}\n```console\n"
  output = []
  git_merge_pr_totarget(upstream, pr_branch, repo)
  run_bash(output)
  git_del_pr_branch(upstream, pr_branch)
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

# get options
parse_option

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
