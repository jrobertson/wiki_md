# Introducing the wiki_md gem

    require 'wiki_md'


    s=<<EOF
    <?dynarex schema="sections[title]/section(x)" format_mask="[!x]"?>
    title: MyWiki

    --#

    # Garden

    The garden has potatoes, raspberries, strawberries, brocolli, and more.

    # Kitchen

    The kitchen includes a cooker, cupboard, fridge, washing machine, and sink.

    # Fixing things

    What can we fix today?

    EOF

    wmd = WikiMd.new s
    puts wmd.to_s

<pre>
&lt;?dynarex schema="sections[title]/section(x)" format_mask="[!x]"?&gt;
title: MyWiki
--#
# Garden

The garden has potatoes, raspberries, strawberries, brocolli, and more.

# Kitchen

The kitchen includes a cooker, cupboard, fridge, washing machine, and sink.

# Fixing things

What can we fix today?
</pre>

    wmd.create_section "# Working\n\nThis works just fine."
    r = wmd.find 'kitchen'
    #=> #<RecordX:47042485135240 @h={:x=>"# Kitchen\n\nThe kitchen includes a cooker, cupboard, fridge, washing machine, sink, and a kettle."}> 

    wmd.update_section 'kitchen', "The kitchen includes a cooker, cupboard, fridge, washing machine, sink, and a kettle."
    wmd.title = 'My Personal Wiki'
    puts wmd.to_s

<pre>
&lt;?dynarex schema="sections[title]/section(x)" format_mask="[!x]"?&gt;
title: My Personal Wiki
--#
# Garden

The garden has potatoes, raspberries, strawberries, brocolli, and more.

# Kitchen

The kitchen includes a cooker, cupboard, fridge, washing machine, sink, and a kettle.

# Fixing things

What can we fix today?

# Working

This works just fine.
</pre>

    puts wmd.to_sections

<pre>
&lt;section id='1' created='2018-09-15 20:34:41 +0100' last_modified=''&gt;
  &lt;details open='open'&gt;
    &lt;summary&gt;
      &lt;h1 id='garden'&gt;Garden&lt;/h1&gt;
    &lt;/summary&gt;
    &lt;p&gt;The garden has potatoes, raspberries, strawberries, brocolli, and more.&lt;/p&gt;
  &lt;/details&gt;
&lt;/section&gt;
&lt;section id='2' created='2018-09-15 20:34:41 +0100' last_modified='2018-09-15 20:34:57 +0100'&gt;
  &lt;details open='open'&gt;
    &lt;summary&gt;
      &lt;h1 id='kitchen'&gt;Kitchen&lt;/h1&gt;
    &lt;/summary&gt;
    &lt;p&gt;The kitchen includes a cooker, cupboard, fridge, washing machine, and sink.&lt;/p&gt;
  &lt;/details&gt;
&lt;/section&gt;
&lt;section id='3' created='2018-09-15 20:34:41 +0100' last_modified=''&gt;
  &lt;details open='open'&gt;
    &lt;summary&gt;
      &lt;h1 id='fixing-things'&gt;Fixing things&lt;/h1&gt;
    &lt;/summary&gt;
    &lt;p&gt;What can we fix today?&lt;/p&gt;
  &lt;/details&gt;
&lt;/section&gt;
</pre>

Note: Instead of a string pattern, a section id can be passed to the *find* method to return an entry.

## Resources

* wiki_md https://rubygems.org/gems/wiki_md

wiki md wiki_md gem dxsectionx sectionx
