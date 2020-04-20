#!/usr/bin/env ruby

# file: wiki_md.rb

require 'dxsectionx'
require 'dynarex-tags'


class WikiMdReadError < Exception
end

class WikiMd
  include RXFHelperModule
  using ColouredText
  
  attr_reader :active_heading, :filename, :dx, :dxsx
  
  class Entry
    
    attr_reader :heading, :body, :footer, :tags, :x
    
    def initialize(rx, debug: false)
      
      @rx, @debug = rx, debug
      @x = @rx.x
      parse_x()
      
    end
    
    def body=(s)
      text_entry = "# %s\n\n%s\n\n%s" % [self.heading, s, self.footer]
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
    
    def to_s(compact: false)
      
      if !compact then
        
        @x.clone + "\n\n"
        
      else
        '# ' + @heading + ' #' + @tags.join(' #') + "\n\n" + @body
      end

    end
    
    private
    
    def parse_x()
      
      a = @rx.x.lines
      puts 'a: ' + a.inspect if @debug
      
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
      
      if wiki.lines.length > 1 and wiki.lstrip[0] != '<' then
        wiki = "<?wikimd  version='1.0'?>\ntitle: Untitled\n\n" + wiki
      end
      
      puts 'before rxfhelper wiki: ' + wiki.inspect if @debug
      raw_s, type = RXFHelper.read(wiki, auto: false)
      s = raw_s.strip
      
      puts 'after rxfhelper s: ' + s.inspect if @debug
      
      puts ('type: ' + type.inspect).debug if debug
      
      if debug then
        puts [
          's: ' + s.inspect,
          'type: ' + type.inspect,
          's.lines.length: ' + s.lines.length.inspect]\
          .join("\n").debug
        puts ('file exists? ' + FileX.exists?(File.dirname(s)).inspect).debug

      end                 
      
      if type == :unknown and s.lines.length == 1 then 
          
        #if FileX.exists?(File.dirname(s)) then
        puts 'before new_md()'.debug if debug
        new_md()
        @filename = wiki
        
        
        @filepath = File.dirname @filename

        indexfile = File.join(@filepath, 'index.xml')
        
        # check for the index.xml file      
        @dx = load_index(indexfile)        
        
        save()
        
      elsif type == :file or type == :dfs 
        
        @filename = wiki

        valid, msg = if s =~ /^<\?wikimd\b/ then
          true
        else
          validate(s)
        end
        
      
        raise WikiMdReadError, msg unless valid
        
        puts ('s: ' + s.inspect).debug if @debug
        
        @dxsx = read_raw_document s
        
        @filepath = File.dirname @filename

        indexfile = File.join(@filepath, 'index.xml')
        puts 'indexfile: ' + indexfile.inspect if @debug
        
        if s != FileX.read(wiki) then
          
          puts '*** file changed! ***'.info if @debug
          FileX.rm indexfile if FileX.exists? indexfile
          
          dxtagsfile = File.join(@filepath, 'dxtags.xml')
          FileX.rm dxtagsfile if FileX.exists? dxtagsfile
          save()
          
        end        
        
        # check for the index.xml file      
        @dx = load_index(indexfile) if FileX.exists? indexfile
        
      else
        
        @dxsx = read_raw_document s
        
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
              URI.escape(title.gsub(/ /,'_'))].join('/')}
    
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
  
  def entries()
    
    @dxsx.dx.all.map do |x| 
      
      puts 'x: ' + x.inspect if @debug
      Entry.new(x, debug: @debug)
      
    end
    
  end

  def find(q, exact_match: false)
    
    puts ('WikiMd::find q: ' + q.inspect).debug if @debug
    return Entry.new(@dxsx.dx.find(q), debug: @debug) if q =~ /^\d+$/
    
    regex = if q.is_a?(String) then      
      q.gsub!(/_/,' ')
      exact_match ? /#{q}$/i : /#{q}/i
    else
      q
    end
    
    r = @dxsx.dx.all.find do |section|
      
      section.x.lines.first =~ regex
      
    end
    
    puts ('  r: ' + r.inspect).debug if @debug
    return unless r
    
    heading2 = r.x.lines.last[/(?<=redirect ).*/]
    heading2 ? find(heading2) : Entry.new(r, debug: @debug)
    
  end
  
  def find_all(q, exact_match: false)
        
    regex = if q.is_a?(String) then      
      q.gsub!(/_/,' ')
      exact_match ? /#{q}$/i : /#{q}/i
    else
      q
    end
    
    r = @dxsx.dx.all.select do |section|
      
      puts 'first: ' + section.x.lines.first.inspect if @debug
      section.x.lines.first =~ regex
      
    end
    
    puts ('  r: ' + r.inspect).debug if @debug
    return unless r    
        
    r.map {|x| Entry.new x }
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
  
  def read_section(heading, exact_match: false)
    
    section = find heading, exact_match: exact_match
    
    if section then

      # find any newly created links which now have a destination page
      
      sectionx = section.x.lines.map do |x|

        link = x[/\?([^\?]+)\?/,1]

        if link then

          a = link.split
          r = a.last =~ /\// 

          if not r then
            
            heading = a[0..2].join
            
            if find heading then
              x.sub!(/\?[^\?]+\?/, "[%s](%s)" % [heading, a.last])
            end
          end

        end

        x
      end.join
      
      puts ('sectionx: ' + sectionx.inspect).debug if @debug

      section.x = sectionx unless section.x == sectionx

      r = section 
      
      puts ('@domain: ' + @domain.inspect).debug if @debug
      r.instance_variable_set(:@domain, @domain)
      r.instance_variable_set(:@tag_url, "%s/%s" % [@tag_base_url, 
                                File.basename(@filename)[/.*(?=\.\w+$)/]])
      
      def r.to_html()
        
        lines = self.x.lines
        last_line = lines.last
        
        content, tags = if last_line[0] == '+' then
        
          raw_tags = last_line[/(?<=\+).*/].chomp.split
          [lines[0..-2].join, raw_tags\
            .map {|x| "+ [%s](%s/%s)" % [x, @tag_url, x]}]
          
        else
          
          [self.x, []]
          
        end
        
        s = block_given? ? yield(content) : content
        
        html = Martile.new(s, ignore_domainlabel: @domain).to_html
        tags_html = Kramdown::Document.new(tags.join("\n")).to_html\
            .sub('<ul>','<ul id="tags">')
        html + "\n\n" + tags_html
        

      end
      
      r
    end
  end
  
  def save(filename=@filename || 'mywiki.md')
    
    @filename = filename
    puts '@filename: ' + @filename.inspect if @debug
    
    @filepath = File.expand_path(File.dirname(@filename).to_s)
    puts '@filepath: ' + @filepath.inspect if @debug
    
    puts 'dx_to_wmd: ' + dx_to_wmd(@dxsx.to_dx) if @debug
    
    contents = dx_to_wmd(@dxsx.to_dx)
    FileX.write @filename=filename, contents
    
    # make a backup file
    FileX.write @filename.sub(/\.\w+$/,'.bak'), contents
    
    puts ('before @dxsx save').debug if @debug
    @dxsx.save filename.sub(/\.md$/, '.xml')
    @dx = new_index(File.join(@filepath, 'index.xml')) unless @dx
    
  end
  
  def sort!()
    
    @dxsx.dx.sort_by! do |rec|
      rec.element('x').value.lines.first.chomp[/(?<=^# ).*/]
    end
    
  end
  
  def tags()
    @dxtags.tags
  end
  
  def title()
    @dxsx.dx.title()
  end
  
  def title=(s)
    @dxsx.dx.title = s
  end
  
  def to_aztoc(base_url: '')
    Yatoc.new(self.entries.map(&:to_s).join).to_aztoc.gsub(/(?<=href=')([^']+)/, base_url + '\1')
  end
  
  # generates an accordion menu in XML format. It can be rendered to 
  # HTML using the Martile gem
  #
  def to_accordion(ascending: true, includetags: false, navbar: false)
    
    doc = Rexle.new("<accordion navbar='#{navbar.to_s}'/>")
    
    unsortedrows = entries
    
    if includetags then
      
      unsortedrows += tags().map do |key, value|

        body = value.map do |x|

          title = x[:title][/^[^#]+/].rstrip
          "* [%s](#%s)" % [title, title.downcase.gsub(/\W/,'-')\
                        .gsub(/-{2,}/,'-').gsub(/^-|-$/,'')]
        end

        OpenStruct.new(heading: key + " (#{value.length})", 
                       body: body.join("\n"), tag_goto: true)
        
      end            
      
    end
    
    puts 'ascending: ' + ascending.inspect if @debug
    
    rows = ascending ? unsortedrows.sort_by {|x| x.heading.downcase} \
        : unsortedrows
    
    puts 'rows: ' + rows.inspect if @debug

    rows.each do |x|

      e = Rexle::Element.new('panel')
      e.add_attribute(title: x.heading)
      e.add_attribute(class: 'entry') unless x.respond_to? :tag_goto
      puts 'x.body: ' + x.body.inspect if @debug
      body = "<body>%s</body>" % \
          Martile.new(x.body, ignore_domainlabel: @domain).to_html
      Rexle.new(body).root.elements.each {|element| e.add element }
      
      doc.root.add e      

    end

    doc.root.xml pretty: true
    
  end
    
  def to_sections()
    
    sort!()
    
    @dxsx.to_doc.root.xpath('records/section')\
        .map {|x| x.xml(pretty: true)}.join("\n")
    
  end
  
  def to_xml()
    @dxsx.to_doc.xml(declaration: false, pretty: true)    
  end
  
  def to_rawdx()
    @dxsx.to_s
  end
  
  def to_s()
    dx_to_wmd(@dxsx.to_dx)
  end
  
  def to_toc()
    y = Yatoc.new(Kramdown::Document.new(self.to_sections).to_html)
    puts y.to_html    
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
    puts 'r: ' + r.inspect if @debug
    
    return false unless r
    
    content = val =~ /# / ? val : r.x.lines.first + "\n" + val
    @active_heading = title = content.lines.first[/(?<=^# )[^#]+/].rstrip
    
    if content.lines.last[/^\+/] then
      tagline1 = content.lines.last[/^\+\s+(.*)/,1]    
    else
      tagline1 = content.lines.first[/(?<=# )[^#]+(.*)/]\
          .scan(/(?<=#)\w+/).join(' ')
      content = title + "\n" + content.lines[1..-1].join + "\n\n+ " +  tagline1
    end
    
    rx = @dx.all.find {|x| x.title =~ /#{q}/}

    
    puts 'tagline1: ' + tagline1.inspect if @debug
    
    s2 = if tagline1 then
      content
    else
      a = title.split      
      tagline1 = a.length > 1 ? a.map(&:capitalize).join : a.first    
      content + "\n\n+ " + tagline1
    end    
    
    puts 's2: ' + s2.inspect if @debug
    r.x = s2

    if rx then
      
      # update the index entry if the title or tags have been modified
      
      puts 'before update_index' if @debug
      update_index(rx, tagline1, @active_heading)
      
      
    else
      
      # create a new index entry
      
      puts 'before new index entry' if @debug
      
      newtagline  = if tagline1 then
        tagline1.split.join(' #')
      else
        a = @active_heading.split(/ +/)
        a.length > 1 ? a.map(&:capitalize).join : a.first        
      end

      record = {title: @active_heading + ' #' + newtagline, 
          url: [@base_url, File.basename(@filename)[/.*(?=\.\w+)/],  
                URI.escape(@active_heading.gsub(/ /, '_'))].join('/')}
      @dx.create record
      @dxtags.add record
            
    end
    
  end
  
  protected
  
  
  def save_files()
    @filepath = File.dirname(@filename)
    FileX.write @filename=filename, dx_to_wmd(@dxsx.to_dx)
    @dx.save
  end

  def update_index(rx, tagline1, active_heading=nil)
    
    puts ('rx: ' + rx.inspect).debug if @debug
    
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
      Dynarex.new indexfile, autosave: true, debug: @debug

    else

      # if it doesn't exist create it
      new_index(indexfile)

    end    
  end
  
  def new_index(indexfile)
    
    dx = Dynarex.new 'entries[doc]/entry(title, url)', autosave: true, 
        debug: @debug, order: 'title ascending', filepath: indexfile

    @dxtags = DynarexTags.new(@filepath, debug: @debug) 
    
    entries.each do |entry|

      record = {title: entry.heading + ' #' + entry.tags.join(' #'), 
          url: [@base_url, File.basename(@filename)[/.*(?=\.\w+)/],  
                URI.escape(entry.heading.gsub(/ /,'_'))].join('/')}
                
      dx.create record    
      @dxtags.add record

    end
    
    puts ('indexfile: ' + indexfile.inspect).debug if @debug
    dx.save indexfile
    dx
    
  end
  
  def read_raw_document(s)
    
    s2 = s.lines.first =~ /^<\?wikimd\b/ ? wmd_to_dx(s) : s

    DxSectionX.new s2, debug: @debug, autosave: true, 
        order: @order
    
  end
  
  def validate(s)
    
    puts 'validate s:'  + s.inspect if @debug
    
    a = s[/(?<=--#\n).*/m].split(/(?=\n# )/)
    valid = a.all? {|x| x.lines.last[0] == '+'}
    return true if valid
    
    r =  a.detect {|x| x.lines.last[0] != '+'}
    
    heading = r[/(?<=# ).*/]    

    [false, 'Tagline missing from heading # ' + heading]
  end
  
  def wmd_to_dx(s)
    
    puts 's: ' + s.inspect if @debug
    
    header, body = s.split(/.*(?=^#)/,2)
    
    puts 'body: ' + body.inspect if @debug
    
    title = header[/title: +(.*)/,1]
        
raw_dx_header = "
<?dynarex schema='sections[title]/section(x)' format_mask='[!x]'?>
title: #{title}

--#\n\n"
    
    puts 'raw_dx_header: ' + raw_dx_header.inspect if @debug#
    
    rawdx = raw_dx_header + body
    puts 'rawdx: ' + rawdx.inspect if @debug
    
    dx = Dynarex.new(rawdx)
    
    rows = dx.all.map do |record|
      
      a = record.x.lines
      puts 'a: ' + a.inspect if @debug

      raw_heading = a.shift.chomp
      puts 'raw_heading: ' + raw_heading.inspect if @debug
      heading = raw_heading[/^#[^#]+/].rstrip

      tags = raw_heading =~ /#/ ? raw_heading[/(?<=# ).*/].scan(/#(\w+)/).flatten : ''
      puts ('tags: ' + tags.inspect).debug if @debug

      if a.last =~ /^\+/ then
        
        footer = a.pop
        tags += footer[1..-1].strip.split  
        
      else

        if tags.empty? then
          tags = heading.downcase.gsub(/['\.\(\)]/,'').split
        end
        
        footer = '+ ' + tags.join(' ')
        
      end

      body =  a.join.strip

      [heading, body, footer].join("\n\n")

    end
    
    raw_dx_header + rows.join("\n\n")
    
  end
  
  def dx_to_wmd(dx)
    
    rows = dx.all.map do |record|
      
      a = record.x.strip.lines
      puts 'a: ' + a.inspect if @debug
      
      raw_heading = a.shift.chomp
      footer = a.pop
      body = a.join.strip

      tags = footer[2..-1].split.map {|x| '#' + x }.join(' ')
      heading = raw_heading + ' ' + tags
      
      [heading, body].join("\n\n")
      
    end
    
    "<?wikimd  version='1.0'?>
title: " + dx.title + "\n\n" + rows.join("\n\n")
    
  end  
end
