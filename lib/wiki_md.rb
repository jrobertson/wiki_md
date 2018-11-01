#!/usr/bin/env ruby

# file: wiki_md.rb

require 'dxsectionx'


class WikiMd
  include RXFHelperModule
  
  attr_reader :active_heading, :filename
  
  def initialize(wiki=nil, domain: nil, debug: false, base_url: '/', 
                 tag_base_url: '/tag')
     
    @domain, @debug, @base_url, @tag_base_url = domain, debug, base_url, 
        tag_base_url
    
    if wiki then
      
      s, type = RXFHelper.read(wiki, auto: false)
      @filename = wiki if type == :file or type == :dfs
      puts 's: ' + s.inspect if @debug
      @dxsx = DxSectionX.new s, debug: debug, autosave: true
      
      @filepath = File.dirname @filename

      indexfile = File.join(@filepath, 'index.xml')
      
      # check for the index.xml file      
      @dx = load_index(indexfile)
      
    else
      
      new_md()
      
    end
            
  end
  
  
  def create_section(s)
    
    @active_heading = title = s[/(?<=^# ).*/]
    tag = title.split(/ +/).map(&:capitalize).join

    @dxsx.create(x: s + "\n\n+ " + tag)
    @dx.create title: title + ' #' + tag, 
        url: [@base_url, File.basename(@filename),  
              URI.escape(title)].join('/')
    FileX.write @filename, @dxsx.to_s if @filename
  end
  
  alias add_section create_section
  
  def delete_section(q)
    
    r = find()
    
    return false unless r
    
    r.delete 

  end
  
  def find(q)
    
    puts 'WikiMd::find q: ' + q.inspect if @debug
    return @dxsx.dx.find q if q =~ /^\d+$/
    regex = q.is_a?(String) ? /#{q}/i : q
    r = @dxsx.dx.all.find {|section| section.x.lines.first =~ regex }
    puts '  r: ' + r.inspect if @debug
    return unless r
    
    heading2 = r.x.lines.last[/(?<=redirect ).*/]
    heading2 ? find(heading2) : r
    
  end  
  
  def headings()
    @dxsx.dx.all.map {|section| section.x.lines.first.chomp[/(?<=# ).*/] }
  end
  
  def new_md(x=nil, title: 'MyWiki')
    
    s = nil
    s, _ = RXFHelper.read(x) if x
    
s ||= <<EOF    
<?dynarex schema="sections[title]/section(x)" format_mask="[!x]"?>
title: #{title}

--#

EOF
    
    @dxsx = DxSectionX.new s, autosave: true, debug: @debug 

    
  end
  
  alias import new_md 
  
  def read_section(heading)
    
    section = find heading
    
    if section then
      
      r = section.x 
      
      puts '@domain: ' + @domain.inspect if @debug
      r.instance_variable_set(:@domain, @domain)
      r.instance_variable_set(:@tag_url, "%s/%s" % [@tag_base_url, 
                                File.basename(@filename)[/.*(?=\.\w+$)/]])
      
      def r.to_html()
        
        lines = self.lines
        last_line = lines.last
        
        content, tags = if last_line[0] == '+' then
        
          raw_tags = last_line[/(?<=\+).*/].chomp.split
          [lines[0..-2].join, raw_tags\
            .map {|x| "+ [%s](%s/%s)" % [x, @tag_url, x]}]
          
        else
          
          [self, []]
          
        end
        
        pre_html = Martile.new(content, ignore_domainlabel: @domain).to_s
        tags_html = Kramdown::Document.new(tags.join("\n")).to_html\
            .sub('<ul>','<ul id="tags">')
        Kramdown::Document.new(pre_html + "\n\n" + tags_html).to_html
        

      end
      
      r
    end
  end
  
  def save(filename=@filename)
    
    @filename = filename
    @filepath = File.dirname(@filename)
    FileX.write @filename=filename, @dxsx.to_s
    
    puts 'before @dxsx save' if @debug
    @dxsx.save filename.sub(/\.md$/, '.xml')
    @dx = new_index(File.join(@filepath, 'index.xml')) unless @dx
    
  end
  
  def title()
    @dxsx.dx.title()
  end
  
  def title=(s)
    @dxsx.dx.title = s
  end
    
  def to_sections()
    
    @dxsx.dx.sort_by! do |rec|
      rec.element('x').value.lines.first.chomp[/(?<=^# ).*/]
    end
    
    @dxsx.to_doc.root.xpath('records/section')\
        .map {|x| x.xml(pretty: true)}.join("\n")
    
  end
  
  def to_xml()
    @dxsx.to_doc.xml(declaration: false, pretty: true)    
  end
  
  def to_s()
    @dxsx.to_s
  end
  
  def update(val)
    self.method(val[/^<\?dynarex/] ? :import : :update_section).call val
  end
  
  def update_section(*args)
    
    puts 'inside update_section' if @debug
    
    val, raw_q = args.reverse
    puts '  val: ' + val.inspect if @debug
    puts '  raw_q: '  + raw_q.inspect if @debug
    q = raw_q ? raw_q : val.lines.first[/(?<=^# ).*/]
    
    puts '  q: ' + q.inspect if @debug
    @section = r = find(q)
    return false unless r
    
    content = val =~ /# / ? val : r.x.lines.first + "\n" + val
    @active_heading = content[/(?<=^# ).*/]
    r.x = content
  end    
  
  private
  
  def load_index(indexfile)
    
    if FileX.exists? indexfile then

      puts 'file found: ' + indexfile.inspect if @debug
      Dynarex.new indexfile, autosave: true

    else

      # if it doesn't exist create it
      new_index(indexfile)

    end    
  end
  
  def new_index(indexfile)
    
    dx = Dynarex.new 'entries[doc]/entry(title, url)', autosave: true, 
        debug: @debug
    dx.save indexfile    
    dx
    
  end
end
