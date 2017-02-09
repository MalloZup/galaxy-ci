#! /usr/bin/ruby

class GitOp
  attr_reader :git_dir
  def initialize(git_dir)
    @git_dir = git_dir
  end

  # this function merge the pr branch  into target branch,
  # where the author of pr wanted to submit
  def goto_prj_dir(repo)
    # chech that dir exist, otherwise clone it
    if File.directory?(@git_dir) == false
      Dir.chdir '/tmp'
      puts 'cloning the project in tmp'
      `git clone git@github.com:#{repo}.git`
    end
    Dir.chdir @git_dir
  end
  
  # merge pr_branch into upstream targeted branch
  def merge_pr_totarget(upstream, pr_branch, repo)
    goto_prj_dir(repo)
    `git checkout #{upstream}`
    `git fetch origin`
    `git pull origin #{upstream}`
    `git checkout -b PR-#{pr_branch} origin/#{pr_branch}`
  end
  
  # cleanup the pr_branch(delete it)
  def del_pr_branch(upstream, pr)
    `git checkout #{upstream}`
    `git branch -D  PR-#{pr}`
  end

end
