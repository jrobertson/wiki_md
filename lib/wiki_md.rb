#!/usr/bin/env ruby

# file: wiki_md.rb

require 'dxsectionx'



class WikiMd
  
  def initialize(wiki=nil)
    
    if wiki then
      s, _ = RXFHelper.read(wiki)
      @dxsx = DxSectionX.new s
    else
      
      new_md()
      
    end        
    
  end
  
  def create_section(s)
    @dxsx.create(x: s)
  end
  
  def delete_section(q)
    
    r = find()
    
    return false unless r
    
    r.delete 

  end
  
  def find(q)
    
    return @dxsx.dx.find q if q =~ /^\d+$/
    regex = q.is_a?(String) ? /#{q}/i : q
    @dxsx.dx.all.find {|section| section.x =~ regex }
  end  
  
  def new_md(x=nil)
    
    s = nil
    s, _ = RXFHelper.read(x) if x
    
s ||= <<EOF    
<?dynarex schema="sections[title]/section(x)" format_mask="[!x]"?>
title: MyWiki

--#

EOF
    
    @dxsx = DxSectionX.new s    

    
  end
  
  alias import new_md 
  
  def title()
    @dxsx.dx.title()
  end
  
  def title=(s)
    @dxsx.dx.title = s
  end
    
  def to_sections()
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
    
    val, raw_q = args.reverse
    
    q = raw_q ? raw_q : val.lines.first
    
    r = find(q)
    r.x = val =~ /# / ? val : r.x.lines.first + "\n" + val
  end    

end
