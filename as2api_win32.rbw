#!/usr/bin/env ruby

require 'fox'
require 'parse/lexer'
require 'parse/parser'
require 'parse/as_io'
require 'doc_comment'
require 'api_model'
require 'api_loader'

include Fox


OUTPUT_INITIAL = "..please select output directory.."


def create_ui(application, main)
  contents = FXVerticalFrame.new(main, LAYOUT_SIDE_LEFT|
                                       LAYOUT_FILL_Y|LAYOUT_FILL_X)

  sourcepath_group = FXGroupBox.new(contents, "Classpath",
                                    LAYOUT_SIDE_LEFT|GROUPBOX_TITLE_CENTER|FRAME_RIDGE|LAYOUT_FILL_X|LAYOUT_FILL_Y)

  sourcepath_buttons = FXHorizontalFrame.new(sourcepath_group,
                                             LAYOUT_SIDE_TOP|
					     PACK_UNIFORM_WIDTH)

  add_button = FXButton.new(sourcepath_buttons, "Add...")
  add_button.connect(SEL_COMMAND) do
    if 1 == $dir_chooser.execute
     add_sourcepath_item($dir_chooser.directory)
    end
  end
  remove_button = FXButton.new(sourcepath_buttons, "Remove")
  remove_button.connect(SEL_COMMAND) do
    unless $sourcepath_list.currentItem == -1
      remove_sourcepath_item($sourcepath_list.currentItem)
    end
  end

  $sourcepath_list = FXList.new(sourcepath_group, 7, nil, 0, LAYOUT_FILL_X|LAYOUT_FILL_Y)

  output_group = FXGroupBox.new(contents, "Output",
                                    GROUPBOX_TITLE_CENTER|FRAME_RIDGE|LAYOUT_FILL_X)
  
  $output_target = FXDataTarget.new()
  output_text = FXTextField.new(output_group, 40, $output_target,
                                FXDataTarget::ID_VALUE,
                                TEXTFIELD_READONLY|LAYOUT_SIDE_LEFT|LAYOUT_CENTER_Y|FRAME_SUNKEN)
  #$output_label = FXLabel.new(output_group, OUTPUT_INITIAL, nil, LABEL_NORMAL|LAYOUT_SIDE_LEFT|LAYOUT_CENTER_Y)
  source_button = FXButton.new(output_group, "Browse...", nil, nil, 0, BUTTON_NORMAL|LAYOUT_SIDE_RIGHT|LAYOUT_CENTER_Y)
  source_button.connect(SEL_COMMAND) do
    if 1 == $dir_chooser.execute
      set_output_dir($dir_chooser.directory)
    end
  end
  $dir_chooser = FXDirDialog.new(main, "Source Location")

  $create_button = FXButton.new(contents, "Generate Docs...", nil, nil, 0, BUTTON_NORMAL|LAYOUT_SIDE_BOTTOM|LAYOUT_CENTER_X|BUTTON_INITIAL)
  $create_button.disable()  # since we know initial config is invalid
  $create_button.connect(SEL_COMMAND) do
    save_settings
    start_generating_documentation
  end

  $progress_dialog = ProgressDialog.new(main)

  # yuk
  $main = main

  load_settings
  update_status
end

class ProgressDialog < FXDialogBox
  def initialize(owner)
    super(owner, "Progress", DECOR_TITLE|DECOR_BORDER)
    contents = FXVerticalFrame.new(self,
      LAYOUT_SIDE_TOP|FRAME_NONE|LAYOUT_FILL_X|LAYOUT_FILL_Y)

    $task_target = FXDataTarget.new("Examaning classpath for ActionScript sources...")
    $task_text = FXTextField.new(contents, 60, $task_target,
                                 FXDataTarget::ID_VALUE,
                                 LAYOUT_CENTER_Y|LAYOUT_FILL_X)
    $task_text.disable

#    $task_label = FXLabel.new(contents, "Examaning classpath for ActionScript sources...", nil,
#                              LABEL_NORMAL|LAYOUT_SIDE_TOP|LAYOUT_CENTER_Y|JUSTIFY_CENTER_X)

    $progress_target = FXDataTarget.new(0)
    $progress_bar = FXProgressBar.new(contents, $progress_target,
                                      FXDataTarget::ID_VALUE,
                                      LAYOUT_CENTER_Y|LAYOUT_FILL_X|
				      FRAME_SUNKEN)
  end
end

def update_status
  valid = true
  if $sourcepath_list.numItems < 1
    status = "Specify location of source packages"
    valid = false
  elsif $output_target.value == OUTPUT_INITIAL
    status = "Specify location for HTML output"
    valid = false
  end


  if valid
    $create_button.enable()
  else
    $create_button.disable()
  end
end


def add_sourcepath_item(path)
  $sourcepath_list.appendItem(path)
  update_status
end


def remove_sourcepath_item(item)
  $sourcepath_list.removeItem(item)
  update_status
end


def set_output_dir(dir)
  $output_target.value = dir
  update_status
end


def start_generating_documentation
  Thread.new do
    Thread.current.abort_on_exception = true
    $main.hide()
    $progress_dialog.show(PLACEMENT_OWNER)
    begin
      generate_docs
    rescue =>e
      puts "#{e.message}\n#{e.backtrace.join("\n")}"
    ensure
      $progress_dialog.hide
      $main.show()
    end
  end
end


def generate_docs
  sources = collect_sources
  $progress_bar.total = sources.length
  type_agregator = GlobalTypeAggregator.new
  count = 0
  sources.each do |src|
    $task_target.value = "Parsing #{src.source}"
    process_file(type_agregator, src)
    count = count + 1
    $progress_target.value = count
  end
  $task_target.value = "Writing API documentation"
  document_types($output_target.value, type_agregator)
end

class Source
  attr_accessor :path, :source
end

def collect_sources
  list = []
  $sourcepath_list.each do |item|
    path = item.text
puts "Examining #{path}..."
    $task_target.value = "Examining #{path}..."
    each_source(path) do |name|
      src = Source.new
      src.path = path
      src.source = name
      list << src
    end
  end
  list
end


def process_file(type_agregator, src)
  File.open(File.join(src.path, src.source)) do |io|
    begin
      is_utf8 = detect_bom?(io)
      type = simple_parse(io)
      type.input_filename = src.source
      type.sourcepath_location(File.dirname(src.source))
      type.source_utf8 = is_utf8
      type_agregator.add_type(type)
    rescue =>e
      $stderr.puts "#{src.source}: #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end
end


def save_settings
  reg = $app.reg
  unless $output_target.value == OUTPUT_INITIAL
    reg.writeStringEntry("Settings", "Output", $output_target.value)
  end
  count = 0
  $sourcepath_list.each do |item|
    reg.writeStringEntry("SourcePath", "entry_#{count}", item.text)
    count += 1
  end
end

def load_settings
  reg = $app.reg
  output = reg.readStringEntry("Settings", "Output", "")
  unless output == ""
    $output_target.value = output
  end

  count = 0
  until (entry = reg.readStringEntry("SourcePath", "entry_#{count}", "")) == ""
    $sourcepath_list.appendItem(entry)
    count += 1
  end
end

def run
  application = FXApp.new("as2api", "www.badgers-in-foil.co.uk")
  $app = application  # yuk!

  main = FXMainWindow.new(application, "as2api")

  create_ui(application, main)

  # Create the application
  application.create
  main.show(PLACEMENT_SCREEN)

  # Run it
  application.run
end







# ---- nicked from documenter.rb ----


def simple_parse(input)
  as_io = ASIO.new(input)
  lex = DocASLexer.new(ActionScript::Parse::ASLexer.new(as_io))
  parse = DocASParser.new(lex)
  handler = DocASHandler.new
  parse.handler = handler
  parse.parse_compilation_unit
  handler.defined_type
end


BOM = "\357\273\277"

# Look for a byte-order-marker in the first 3 bytes of io.
# Eats the BOM and returns true on finding one; rewinds the stream to its
# start and returns false if none is found.
def detect_bom?(io)
  return true if io.read(3) == BOM
  io.seek(0)
  false
end


def parse_options
  
end

# lists the .as files in 'path', and it's subdirectories
def each_source(path)
  require 'find'
  path = path.sub(/\/+$/, "")
  Find.find(path) do |f|
    base = File.basename(f)
    # Ignore anything named 'CVS', or starting with a dot
    Find.prune if base =~ /^\./ || base == "CVS"
    if base =~ /\.as$/
      yield f[path.length+1, f.length]
    end
  end
end

# Support for other kinds of output would be useful in the future.
# When the need arises, maybe the interface to 'output' subsystems will need
# more formalisation than just 'document_types()'
require 'html_output'



# --------



run
