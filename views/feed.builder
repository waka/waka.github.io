xml.instruct!
xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do
  xml.title config[:title]
  xml.subtitle config[:description]
  xml.id config[:site_url]
  xml.link "href" => config[:site_url]
  xml.updated posts.first.iso_date unless posts.empty?
  xml.author { xml.name config[:author] }

  posts[0..5].each do |post|
    xml.entry do
      xml.title post.title
      xml.link "rel" => "alternate", "href" => URI.join(config[:site_url], post.url)
      xml.id URI.join(config[:site_url], post.url)
      xml.published post.iso_date
      xml.updated File.mtime(post.path).strftime("%FT%T%z")
      xml.author { xml.name config[:author] }
      xml.content post.html, "type" => "html"
    end
  end
end
