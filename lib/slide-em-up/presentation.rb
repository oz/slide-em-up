require "nolate"
require "redcarpet"
require "yajl"


module SlideEmUp
  class Presentation
    Meta    = Struct.new(:title, :dir, :css, :js)
    Theme   = Struct.new(:title, :dir, :css, :js)
    Section = Struct.new(:number, :title, :slides)
    Slide   = Struct.new(:number, :classes, :markdown, :html)

    attr_accessor :meta, :theme

    def initialize(dir)
      infos   = extract_normal_infos(dir) || extract_infos_from_showoff(dir) || {}
      infos   = { :title => "No title", :theme => "default" }.merge(infos)
      @meta   = build_meta(infos[:title], dir)
      @theme  = build_theme(infos[:theme])
      @titles = infos[:sections]
    end

    def html
      str = File.read("#{theme.dir}/index.nlt")
      nolate str, :meta => meta, :theme => theme, :sections => sections
    end

    def path_for_asset(asset)
      try = "#{theme.dir}/#{asset}"
      return try if File.exists? try
      Dir["#{meta.dir}/**/#{asset}"].first
    end

  protected

    def extract_normal_infos(dir)
      filename = "#{dir}/presentation.json"
      return unless File.exists?(filename)
      Yajl::Parser.parse(File.read filename)
    end

    def extract_infos_from_showoff(dir)
      filename = "#{dir}/showoff.json"
      return unless File.exists?(filename)
      infos = Yajl::Parser.parse(File.read filename)
      sections = infos["sections"].map {|s| s["section"] }
      { :title => infos["name"], :theme => "showoff", :sections => sections }
    end

    def build_meta(title, dir)
      Meta.new.tap do |m|
        m.title = title
        m.dir   = dir
        Dir.chdir(m.dir) do
          m.css = Dir["**/*.css"]
          m.js  = Dir["**/*.js"]
        end
      end
    end

    def build_theme(title)
      Theme.new.tap do |t|
        t.title = title
        t.dir   = File.expand_path("../../../themes/#{title}", __FILE__)
        Dir.chdir(t.dir) do
          t.css = Dir["**/*.css"]
          t.js  = Dir["**/*.js"]
        end
      end
    end

    def sections
      @titles.map.with_index do |title,i|
        raw = Dir["#{meta.dir}/#{title}/**/*.md"].sort.map { |f| File.read(f) }.join("\n\n")
        parts = raw.split(/!SLIDE */)
        parts.delete('')
        slides = parts.map.with_index do |slide,j|
          classes, md = slide.split("\n", 2)
          html = Redcarpet.new(md).to_html
          Slide.new(j, classes, md, html)
        end
        Section.new(i, title, slides)
      end
    end
  end
end