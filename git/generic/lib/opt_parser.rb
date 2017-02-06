#! /usr/bin/ruby

# Opt_parser module, is for getting needed options
module OptParser
  @options = {}

  def OptParser.raise_verbose_help(msg)
    puts @opt_parser
    puts "************************************************\n"
    raise OptionParser::MissingArgument, msg
  end
 
  def OptParser.get_options
  name = './gitbot.rb'
   @opt_parser = OptionParser.new do |opt|
      opt.banner = "************************************************\n" \
        "Usage: gitbot [OPTIONS] \n" \
        "EXAMPLE: ======> #{name} -r MalloZup/galaxy-botkins -c \"python-test\" " \
        "-d \"pyflakes_linttest\" -t /home/mallozup/bin/tests.sh -f \".py\"\n\n"
      opt.separator 'Options'

      opt.on('-r', '--repo REPO', 'github repo you want to run test against' \
                              'EXAMPLE: USER/REPO  MalloZup/gitbot') do |repo|
        @options[:repo] = repo
      end

      opt.on('-c', '--context CONTEXT', 'context to set on comment' \
                                  'EXAMPLE: CONTEXT: python-test') do |context|
        @options[:context] = context
      end

      opt.on('-d', '--description DESCRIPTION', 'description to set on comment') do |description|
        @options[:description] = description
      end

      opt.on('-t', '--test TEST.SH', 'fullpath to the bash' \
             'script which contain test to be executed for pr') do |bash_file|
        @options[:bash_file] = bash_file
      end
      
      opt.on('-f', "--file \'.py\'", 'specify the file type of the pr which you want' \
                  'to run the test against ex .py, .java, .rb') do |file_type|
        @options[:file_type] = file_type
      end

      opt.on('-h', '--help', 'help') do
        puts @opt_parser
        puts "***************************************************************\n"
        exit 0
      end
    end
    @opt_parser.parse!
    OptParser.raise_verbose_help('REPO') if @options[:repo].nil?
    OptParser.raise_verbose_help('CONTEXT') if @options[:context].nil?
    OptParser.raise_verbose_help('DESCRIPTION') if @options[:description].nil?
    OptParser.raise_verbose_help('TEST.sh') if @options[:bash_file].nil?
    OptParser.raise_verbose_help('TYPE FILE') if @options[:file_type].nil? 
  end
end
