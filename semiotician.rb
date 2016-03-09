require 'net/http'
require 'rvg/rvg'
require 'hpricot'
require 'yaml'
require 'mail'
include Magick


# Infrastructure
class SemioticSquare
  attr_accessor :semes, :seme1, :seme2, :contradictory_seme1, :contradictory_seme2

  def initialize semes
     @semes = semes
  end

  def generate_semes
    until @seme1
      @seme1, @contradictory_seme1 = generate_seme_pair
    end

    until @seme2
      @seme2, @contradictory_seme2 = generate_seme_pair
    end
  end

private
  def generate_seme_pair
    seme = @semes[rand() * @semes.length]

    not_seme = get_an_antonym seme

    @semes.delete(seme) unless not_seme
    (return seme, not_seme) if not_seme
  end

  def get_an_antonym word
    p "Look for antonym for #{word}"
    url = "http://www.thesaurus.com/browse/#{word}?s=t"

    uri = URI.parse(url)

    result = Net::HTTP.start(uri.host, uri.port) { |http| http.read_timeout = 60; http.get(uri.path) }

    return nil if result.code.to_i > 400

    doc = Hpricot(result.body)
    antonyms = doc.search("//section[@class='container-info antonyms']/div/ul/li/a/span/text()")

    return (antonyms[rand() * antonyms.length]) if antonyms
    nil
  end
end

def draw_square square, path

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

    canvas.text(60, 75, square.seme1).styles(:font_size=>14, :font_family=>'helvetica', :fill=>'black')
    canvas.text(360, 75, square.seme2).styles(:font_size=>14, :font_family=>'helvetica', :fill=>'black')
    canvas.text(60, 325, square.contradictory_seme2).styles(:font_size=>14, :font_family=>'helvetica', :fill=>'black')
    canvas.text(360, 325, square.contradictory_seme1).styles(:font_size=>14, :font_family=>'helvetica', :fill=>'black')
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

SQUARE_PATH = "#{base_path}square_#{Time.now.strftime("%Y%m%d%H")}.png"

# Ok, so if there is already a square waiting for me to fill in, just die
exit if File.exists?(SQUARE_PATH)

# Still here? Ok, load our adjectives

adjectives = []
File.open(config["semes"], "r") do |f|
   adjectives = f.read.split("\n")
end
p "#{adjectives.length} words to chose from"

# Create a square, generate the semes, and draw it out.
square = SemioticSquare.new adjectives
square.generate_semes
draw_square square, SQUARE_PATH

# And write the semes back out after all the semes that failed to have antonyms are removed
File.open(config["semes"], "w") do |f|
   f << square.semes.join("\n")
end

# And email it to me
Mail.defaults do
  delivery_method :smtp, Hash[config["smtp"].map{|k,v| [k.to_sym, v]}]
end

Mail.deliver do
   from 'avocadia@fastmail.fm'
   to 'avocadia@fastmail.fm'
   subject 'Another Semiotic Square'
   body 'Enjoy'
   add_file SQUARE_PATH
 end
