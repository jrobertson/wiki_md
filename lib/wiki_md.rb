#!/usr/bin/env ruby

# file: wiki_md.rb

require 'dxsectionx'


class WikiMd
  include RXFHelperModule
  
  attr_reader :active_heading, :filename
  
  def initialize(wiki=nil, debug: false)
    
    @debug = debug
    
    if wiki then
      s, type = RXFHelper.read(wiki, auto: false)
      @filename = wiki if type == :file or type == :dfs
      puts 's: ' + s.inspect if @debug
      @dxsx = DxSectionX.new s, debug: debug
    else
      
      new_md()
      
    end
            
  end
  
  
  def create_section(s)
    @active_heading = s[/(?<=^# ).*/]
    @dxsx.create(x: s)
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
    
    @dxsx = DxSectionX.new s    

    
  end
  
  alias import new_md 
  
  def read_section(heading)
    
    section = find heading
    
    if section then
      
      r = section.x 
      
      def r.to_html()
         Kramdown::Document\
          .new(Martile.new(self, ignore_domainlabel: @domain).to_s).to_html
      end
      
      r
    end
  end
  
  def save(filename=@filename)
    FileX.write @filename=filename, @dxsx.to_s
    @dxsx.dx.save filename.sub(/\.md$/, '.xml')
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

end
