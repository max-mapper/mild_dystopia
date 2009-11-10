class PowerTron
  def initialize(db=1)
    @r = Redis.new :db => db
  end
  
  def redis
    @r
  end
  
  def get_posts(number=20, start=0)
    posts   = @r.list_range("recent:entries", start, start+number-1)
    entries = []
    posts.each do |post|
      data   = {}
      parse  = post.match(/^(\w+)\:entries:(\d+)/)
      author = parse[1]
      id     = parse[2]
      data["post"]   = @r[post]
      data["author"] = author
      data["email"]  = get_email_for(author)
      data["id"]     = id
      image  = @r["#{author}:upload_for:#{id}"]
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
    @r["#{author}:#{id}:votes"] = "0"
    upvote(id, author, author)
    attach_upload(author, id, upload) if upload
    @r.push_head("recent:entries", "#{author}:entries:#{id}")
    @r.list_trim 'recent:entries', 0, 499
  end
  
  def update_post(author, id, content, upload=nil)
    @r["#{author}:entries:#{id}"] = content
    attach_upload(author, id, upload) if upload
  end
  
  def remove_post(content, author, upload=nil)
    @r.lrem("#{author}:entries", 1, id)
    @r.lrem("recent:entries", 1, "#{author}:entries:#{id}")
    @r.del("#{author}:entries:#{id}") 
  end
  
  def attach_upload(author, id, upload)
    @r["#{author}:upload_for:#{id}"] = upload
  end
  
  def get_user_for(sessionkey)
    @r[sessionkey]
  end
  
  def get_email_for(username)
    @r["#{username}:email"]
  end
  
  def save_user(username, sessionkey, email)
    if @r.set_member?('usernames', username)
      return true
    else
      @r[username]            = sessionkey
      @r.set_add "usernames", username
      @r[sessionkey]          = username
      @r[email]               = username
      @r["#{username}:email"] = email
      return false
    end
  end
  
  def get_vote_count_for(id, username)
    @r["#{username}:#{id}:votes"]
  end
  
  def upvote(id, username, current_user)
    count = @r["#{username}:#{id}:votes"]
    @r["#{username}:#{id}:votes"] = count.to_i + 1
    @r.set_add "#{username}:#{id}:upvoters", current_user
    if downvoted?(id, username, current_user)
      @r.set_delete "#{username}:#{id}:downvoters", current_user
    end
  end
  
  def downvote(id, username, current_user)
    count = @r["#{username}:#{id}:votes"]
    @r["#{username}:#{id}:votes"] = count.to_i - 1
    @r.set_add "#{username}:#{id}:downvoters", current_user
    if upvoted?(id, username, current_user)
      @r.set_delete "#{username}:#{id}:upvoters", current_user
    end
  end
  
  def upvoted?(id, username, current_user)
    @r.set_member?("#{username}:#{id}:upvoters", current_user) ? true : false
  end
  
  def downvoted?(id, username, current_user)
    @r.set_member?("#{username}:#{id}:downvoters", current_user) ? true : false
  end
  
  def vote_for(id, username, current_user)
    if upvoted?(id, username, current_user)
      return "up"
    elsif downvoted?(id, username, current_user)
      return "down"
    else
      return false
    end
  end
end