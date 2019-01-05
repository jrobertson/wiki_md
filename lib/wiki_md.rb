#!/usr/bin/env ruby

# file: wiki_md.rb

require 'dxsectionx'
require 'dynarex-tags'


class WikiMd
  include RXFHelperModule
  using ColouredText
  
  attr_reader :active_heading, :filename, :dx
  
  class Entry
    
    attr_reader :heading, :body, :footer, :tags, :x
    
    def initialize(rx)
      
      @rx = rx
      @x = @rx.x
      parse_x()
      
    end
    
    def body=(s)
      text_entry = "%s\n\n%s\n\n%s" % [self.heading, s, self.footer]
      self.x = text_entry
    end
    
    def footer=(s)
      a = @x.lines
      a[-1] = s
      self.x = a.join
    end    
    
    def x=(s)
      @rx.x = s
      parse_x()
    end
    
    private
    
    def parse_x()
      
      a = @rx.x.lines
      @heading, @footer, @body = a.shift.chomp[/(?<=# ).*/], a.pop, 
          a.join.strip
      @tags = @footer[1..-1].strip.split
      
    end
    
  end
  
  def initialize(wiki=nil, domain: nil, debug: false, base_url: '', 
                 tag_base_url: '/tag', order: 'ascending', title: 'MyWiki')
     
    @domain, @debug, @base_url = domain, debug, base_url
    @tag_base_url, @order, @title = tag_base_url, order, title
    
    if wiki then
      
      s, type = RXFHelper.read(wiki, auto: false)
      
      puts ('type: ' + type.inspect).debug if debug
      
      if debug then
        puts [
          's: ' + s.inspect,
          'type: ' + type.inspect,
          's.lines.length: ' + s.lines.length.inspect]\
          .join("\n").debug
        puts ('file exists? ' + FileX.exists?(File.dirname(s)).inspect).debug

      end      
      
      if type == :unknown and (s.lines.length == 1 and 
          FileX.exists?(File.dirname(s))) then
        puts 'before new_md()'.debug if debug
        new_md()
        @filename = wiki
        
      elsif type == :file or type == :dfs 
        
        @filename = wiki
        
        puts ('s: ' + s.inspect).debug if @debug
        @dxsx = DxSectionX.new s, debug: debug, autosave: true, 
            order: @order
        
        @filepath = File.dirname @filename

        indexfile = File.join(@filepath, 'index.xml')
        
        # check for the index.xml file      
        @dx = load_index(indexfile)        
        save()
        
      else
        
        @dxsx = DxSectionX.new s, autosave: false, debug: @debug, order: @order
        
      end      
      
    else
      
      new_md()
      
    end
    
    
    @filepath ||= '.'
    
    @dxtags = DynarexTags.new(@filepath, debug: debug)
            
  end

  
  def create_section(s)

    @active_heading = title = s[/(?<=^# ).*/]

    tagline = s.rstrip.lines.last[/(?<=^\+\s).*/]
    
    s2 = if tagline then
      s
    else
      a = title.split      
      tagline = a.length > 1 ? a.map(&:capitalize).join : a.first    
      s + "\n\n+ " + tagline
    end
    
    @dxsx.create(x: s2)

    puts ('@filename: ' + @filename.inspect).debug if @debug
    
    return unless @filename
    
    record = {title: title + ' #' + tagline.lstrip.split.join(' #'), 
        url: [@base_url, File.basename(@filename)[/.*(?=\.\w+)/],  
              URI.escape(title)].join('/')}
    
    @dx.create record
    

    FileX.write @filename, @dxsx.to_s
    @dxtags.add record
    
  end
  
  alias add_section create_section
  
  def delete_section(q)
        
    regex = q.is_a?(String) ? /#{q}/i : q
    r = @dxsx.dx.all.find {|section| section.x.lines.first =~ regex }
    
    return unless r
    
    r.delete
    
    rx = @dx.all.find {|x| x.title =~ regex}

    return unless rx    
    
    title = rx.title    
    rx.delete 
    @dxtags.delete title
    puts ('deleted title: ' + title.inspect).debug if @debug
    
    :section_deleted

  end
  

  def find(q)
    
    puts ('WikiMd::find q: ' + q.inspect).debug if @debug
    return Entry.new(@dxsx.dx.find q) if q =~ /^\d+$/
    regex = q.is_a?(String) ? /#{q}/i : q
    r = @dxsx.dx.all.find {|section| section.x.lines.first =~ regex }
    puts ('  r: ' + r.inspect).debug if @debug
    return unless r
    
    heading2 = r.x.lines.last[/(?<=redirect ).*/]
    heading2 ? find(heading2) : Entry.new(r)
    
  end


  def find_tag(tag)
    @dxtags.find tag
  end  
  
  def headings()
    @dxsx.dx.all.map {|section| section.x.lines.first.chomp[/(?<=# ).*/] }
  end
  
  def new_md(x=nil, title: @title, save: true)
    
    puts 'inside new_md'.debug if @debug
    
    s = nil
    s, _ = RXFHelper.read(x) if x
    
s ||= <<EOF    
<?dynarex schema="sections[title]/section(x)" format_mask="[!x]"?>
title: #{title}

--#

EOF
    
    @dxsx = DxSectionX.new s, autosave: save, debug: @debug, order: @order
    
  end
  
  alias import new_md 
  
  def read_section(heading)
    
    section = find heading
    
    if section then
      
      r = section.x 
      
      puts ('@domain: ' + @domain.inspect).debug if @debug
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
        
        html = Martile.new(content, ignore_domainlabel: @domain).to_html
        tags_html = Kramdown::Document.new(tags.join("\n")).to_html\
            .sub('<ul>','<ul id="tags">')
        html + "\n\n" + tags_html
        

      end
      
      r
    end
  end
  
  def save(filename=@filename || 'mywiki.md')
    
    @filename = filename
    @filepath = File.dirname(@filename)
    FileX.write @filename=filename, @dxsx.to_s
    
    puts ('before @dxsx save').debug if @debug
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
    
    puts 'inside update_section'.debug if @debug
    
    val, raw_q = args.reverse
    puts '  val: ' + val.inspect if @debug
    puts '  raw_q: '  + raw_q.inspect if @debug
    q = raw_q ? raw_q : val.lines.first[/(?<=^# ).*/]
    
    puts '  q: ' + q.inspect if @debug
    @section = r = find(q)
    return false unless r
    
    content = val =~ /# / ? val : r.x.lines.first + "\n" + val
    @active_heading = title = content[/(?<=^# ).*/]

    
    rx = @dx.all.find {|x| x.title =~ /#{q}/}
    tagline1 = content.lines.last[/^\+\s+(.*)/,1]    
    
    puts 'tagline1: ' + tagline1.inspect if @debug
    
    s2 = if tagline1 then
      content
    else
      a = title.split      
      tagline1 = a.length > 1 ? a.map(&:capitalize).join : a.first    
      content + "\n\n+ " + tagline1
    end    
    
    r.x = s2

    if rx then
      
      # update the index entry if the title or tags have been modified
      
      update_index(rx, tagline1, @active_heading)
      
      
    else
      
      # create a new index entry
      
      newtagline  = if tagline1 then
        tagline1.split.join(' #')
      else
        a = @active_heading.split(/ +/)
        a.length > 1 ? a.map(&:capitalize).join : a.first        
      end

      record = {title: @active_heading + ' #' + newtagline, 
          url: [@base_url, File.basename(@filename)[/.*(?=\.\w+)/],  
                URI.escape(@active_heading)].join('/')}
      @dx.create record
      @dxtags.add record
            
    end
    
  end
  
  protected
  
  def dxsx()
    @dxsx.dx
  end
  
  def save_files()
    @filepath = File.dirname(@filename)
    FileX.write @filename=filename, @dxsx.to_s    
    @dx.save
  end

  def update_index(rx, tagline1, active_heading=nil)
    
    title, tagline2 = rx.title.split(/\s+#/)      
    active_heading ||= title
    
    if title != active_heading or tagline2 != tagline1 then      
      
      record = {title: active_heading + ' #' + tagline1.split.join(' #'), 
          url: [@base_url, File.basename(@filename)[/.*(?=\.\w+)/],
              URI.escape(title.gsub(/ /,'_'))].join('/')}
      rx.update record
      @dxtags.add record
      
    end    
  end
  
  private
  
  def load_index(indexfile)
    
    if FileX.exists? indexfile then

      puts ('file found: ' + indexfile.inspect).debug if @debug
      Dynarex.new indexfile, autosave: true, debug: @debug, order: @order

    else

      # if it doesn't exist create it
      new_index(indexfile)

    end    
  end
  
  def new_index(indexfile)
    
    dx = Dynarex.new 'entries[doc]/entry(title, url)', autosave: true, 
        debug: @debug, order: @order
    dx.save indexfile    
    dx
    
  end
end
