require 'rvg/rvg'
require 'yaml'
require 'mail'
require 'twitter'
require 'fileutils'
require './thesaurusDotCom'

include Magick



include ThesaurusDotCom

def get_an_antonym word
  p "Look for antonym for #{word}"

  antonyms = ThesaurusDotCom::get_antonyms word

  if antonyms

    antonym = antonyms[rand() * antonyms.length]

    return antonym, antonyms
  end
  nil
end

def generate_semes adjectives
  seme = nil
  contradictory_seme = nil
  failed_words = []

  until contradictory_seme
    index = rand() * adjectives.length
    seme = adjectives[index]

    contradictory_seme, new_words = get_an_antonym seme

    (failed_words << seme) unless contradictory_seme
  end

  return seme, contradictory_seme, new_words, failed_words
end

def draw_square seme1,contradictory_seme1, seme2, contradictory_seme2, path

  rvg = RVG.new(7.in, 7.in).viewbox(0,0,500,400) do |canvas|
    canvas.background_fill = 'white'

    # Draw Contrary Lines
    canvas.line(125, 90, 350, 90).styles(:stroke_width=>2, :stroke=>'black', :stroke_dasharray=>[4,4])
    canvas.line(125, 290, 350, 290).styles(:stroke_width=>2, :stroke=>'black', :stroke_dasharray=>[4,4])

    # Draw contradictory lines
    canvas.line(125, 95, 350, 285).styles(:stroke_width=>2, :stroke=>'black')
    canvas.line(350, 95, 125, 285).styles(:stroke_width=>2, :stroke=>'black')

    # Draw implication lines
    canvas.line(125, 110, 125, 280).styles(:stroke_width=>2, :stroke=>'black', :stroke_dasharray=>[4,4,1,4])
    canvas.line(350, 110, 350, 280).styles(:stroke_width=>2, :stroke=>'black', :stroke_dasharray=>[4,4,1,4])

    canvas.polygon(120,110, 125,100, 130,110).styles(:stroke_width=>1, :stroke=>'black')
    canvas.polygon(345,110, 350,100, 355,110).styles(:stroke_width=>1, :stroke=>'black')

    canvas.text(60, 75, seme1).styles(:font_size=>14, :fill=>'black')
    canvas.text(360, 75, seme2).styles(:font_size=>14, :fill=>'black')
    canvas.text(60, 325, contradictory_seme2).styles(:font_size=>14, :fill=>'black')
    canvas.text(360, 325, contradictory_seme1).styles(:font_size=>14, :fill=>'black')
  end

  rvg.draw.write(path)
end


# Let's start

# One day I really should find out what a non-72 DPI implies
RVG::dpi = 72

# Loading config, and dying if no config
config_file = File.expand_path(File.dirname(__FILE__)) + '/.config'

if File.exists? config_file
  config = File.open(config_file, 'r') do|f|
    config = YAML.load(f.read)
  end
end

if !config
  p "Missing config file"
  exit
end

base_path = config["squares"]

square_path = "#{base_path}square_#{Time.now.strftime("%Y%m%d%H")}.png"

# Ok, so if there is already a square waiting for me to fill in, just die
#exit if File.exists?(SQUARE_PATH)

# Still here? Ok, load our adjectives

adjectives = []
File.open(config["semes"], "r") do |f|
   adjectives = f.read.split("\n")
end
p "#{adjectives.length} words to chose from"

words_to_add = []
words_to_remove = []

# Create a square, generate the semes, and draw it out.
seme, not_seme, new_words, failed_words = generate_semes adjectives
words_to_add += new_words if new_words
words_to_remove += failed_words if failed_words

seme2, not_seme2, new_words, failed_words = generate_semes adjectives
words_to_add += new_words if new_words
words_to_remove += failed_words if failed_words

draw_square seme, not_seme, seme2, not_seme2, square_path

adjectives += new_words
adjectives -= failed_words

# # And write the semes back out after all the semes that failed to have antonyms are removed
File.open(config["semes"], "w") do |f|
   f << adjectives.join("\n")
end

if config["twitter"]
  client = Twitter::REST::Client.new do |twitter|
    twitter.consumer_key = config["twitter"]["CONSUMER_KEY"]
    twitter.consumer_secret = config["twitter"]["CONSUMER_SECRET"]
    twitter.access_token = config["twitter"]["OAUTH_TOKEN"]
    twitter.access_token_secret = config["twitter"]["OAUTH_TOKEN_SECRET"]
  end

  File.open(square_path, "r") do |file|
    client.update_with_media("", file)
  end
end

if config["smtp"]
  Mail.defaults do
    delivery_method :smtp, Hash[config["smtp"].map{|k,v| [k.to_sym, v]}]
  end

  Mail.deliver do
    from 'avocadia@fastmail.fm'
    to 'avocadia@fastmail.fm'
    subject 'Another Semiotic Square'
    body 'Enjoy'
    add_file square_path
  end
end

FileUtils.rm(square_path)
