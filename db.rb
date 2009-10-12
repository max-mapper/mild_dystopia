class PowerTron
  def initialize()
    @r = Redis.new
  end
  
  def get_posts(number=20, start=0)
    posts = @r.list_range("recent:entries", start, start+number)
    entries = []
    posts.each do |post|
      data = {}
      author = post.match(/^(\w+)\:/)[1]
      id = post.match(/^(\w+)\:entries:(\d+)/)[2]
      data["post"] = @r[post]
      data["author"] = author
      data["email"] = get_email(author)
      image = @r["#{author}:upload_for:#{id}"]
      if image
        data["image"] = "/uploads/#{image}"
      end
      entries << data
    end
    entries
  end
  
  def add_post(content, author, upload=nil)
    id = @r.incr("entries")
    @r.push_tail("#{author}:entries", id)
    @r["#{author}:entries:#{id}"] = content
    
    if upload
      @r["#{author}:upload_for:#{id}"] = upload
    end

    @r.push_head("recent:entries", "#{author}:entries:#{id}")
    @r.list_trim 'recent:entries', 0, 50
  end
  
  def update_post(content, author)
    
  end
  
  def remove_post(content, author)
    
  end
  
  def get_user(sessionkey)
    puts @r[sessionkey]
    @r[sessionkey]
  end
  
  def get_email(username)
    @r["#{username}:email"]
  end
  
  def save_user(username, sessionkey, email)
    if @r.set_member?('usernames', username)
      return true
    else
      @r[username] = sessionkey
      @r.set_add "usernames", username
      @r[sessionkey] = username
      @r[email] = username
      @r["#{username}:email"] = email
      return false
    end
  end
  
  def to_s
    
  end
end