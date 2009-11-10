require File.dirname(__FILE__) + '/spec_helper'
require 'redis/raketasks'

describe "redis database adapter" do
  include Rack::Test::Methods

  before(:all) do
    result = RedisRunner.start_detached
    raise("Could not start redis-server, aborting") unless result

    # yeah, this sucks, but it seems like sometimes we try to connect too quickly w/o it
    sleep 1

    # use database 15 for testing so we dont accidentally step on real data
    @db = PowerTron.new(15)
  end
  
  after(:each) do
    @db.redis.keys('*').each {|k| @db.redis.del k}
  end
  
  after(:all) do
    begin
      @db.redis.quit
    ensure
      RedisRunner.stop
    end
  end
  
  describe "#get_posts" do
    
    before(:each) do
      30.times {@db.add_post("I love the ocean!", "enamoreddolphin")}
    end
    
    it "should return no more than 20 posts" do
      @db.get_posts().length.should == 20
    end
    
    it "should return the most recent posts in date DESC order" do
      @db.add_post("hay guyz", "donkeyville")
      @db.get_posts().first["post"].should == ("hay guyz")
    end
    
    it "should return the content of the post" do
      @db.get_posts().first["post"].should == "I love the ocean!"
    end
    
    it "should return the author of the post" do
      @db.get_posts().first["author"].should == "enamoreddolphin"
    end
    
    it "should return the id of the post" do
      @db.get_posts().first["id"].should == "30"
    end
    
    it "should return the email of the author" do
      @db.redis["enamoreddolphin:email"] = "flipper@sandiegozoo.com"
      @db.get_posts().first["email"].should == "flipper@sandiegozoo.com"
    end
    
    it "should return the url for an image attachment" do
      @db.redis["enamoreddolphin:upload_for:30"] = "sweetpic.png"
      @db.get_posts().first["image"].should == "/uploads/sweetpic.png"
    end
  end
  
  describe "#add_post" do
    it "should add a post for the given user" do
      @db.add_post("hay guys", "mike_tyson_29")
      @db.redis["mike_tyson_29:entries:1"].should == "hay guys"
    end
    
    it "should push the post onto the head of the recent entries list" do
      @db.add_post("i invented the internet", "al_gore")
      @db.get_posts().first["post"].should == "i invented the internet"
    end
    
    it "should trim the recent entries list to 500" do
      666.times { @db.add_post("ds9 < tng", "brett_spiner_fan_23") }
      @db.get_posts(500).length.should == 500
    end
    
    it "should set the post vote count to 1 (authors vote)" do
      @db.add_post("the hundred years war ended in 1337", "nerd_history_buff")
      @db.get_vote_count_for(@db.get_posts().first["id"], "nerd_history_buff").should == "1"
    end
  end
  
  describe "#update_post" do
    it "should update the content of the given post" do
      @db.add_post("my social security number is 123-45-6789", "rad_grandma_1912")
      @db.update_post("rad_grandma_1912", @db.get_posts().first["id"], "my great grandson is a computer man and he says i should not share sensitive information on the intertubes!")
      @db.get_posts().first["post"].should == "my great grandson is a computer man and he says i should not share sensitive information on the intertubes!"
    end
  end
  
  describe "#attach_upload" do
    it "should attach any given uploads" do
      #add_post calls attach_upload
      @db.add_post("peep this sweet cat", "catsrule92", "catfacemeowmers.png")
      @db.get_posts().first["image"].should == "/uploads/catfacemeowmers.png"
    end
  end
    
  describe "#get_user_for" do
    it "should return the username that belongs to the given openid session key" do
      @db.save_user("bobvila", "8675309", "bobbyv@letsfixsomehouses.org")
      @db.get_user_for("8675309").should == "bobvila"
    end
  end
  
  describe "#get_email_for" do
    it "should return the email belonging to the given username" do
      @db.save_user("bobvila", "8675309", "bobbyv@letsfixsomehouses.org")
      @db.get_email_for("bobvila").should == "bobbyv@letsfixsomehouses.org"
    end
    
    it "should return nil if the user chose not the share their email address" do
      pending
      @db.save_user("stupid_user", "90210")
      @db.get_email_for("stupid_user").should == nil
    end
  end

  describe "#save_user" do
    it "should return true if username is already taken" do
      @db.save_user("dumphead", "20xd6", "dunner@muggins.com")
      @db.save_user("dumphead", "x86_64", "tenks@womobocorp.gov").should == true
    end
    
    it "should associate username with sessionkey" do
      @db.save_user("dumphead", "20xd6", "dunner@muggins.com")
      @db.redis["20xd6"].should == "dumphead"
    end
    
    it "should associate username with email" do
      @db.save_user("dumphead", "20xd6", "dunner@muggins.com")
      @db.redis["dunner@muggins.com"].should == "dumphead"
    end
    
    it "should associate sessionkey with username" do
      @db.save_user("dumphead", "20xd6", "dunner@muggins.com")
      @db.redis["dumphead"].should == "20xd6"
    end
    
    it "should associate email with username" do
      @db.save_user("dumphead", "20xd6", "dunner@muggins.com")
      @db.redis["dumphead:email"].should == "dunner@muggins.com"
    end
  end
  
  describe "#upvote" do
    it "should increment the total vote count for the post" do
      @db.add_post("sweet post!", "smartguy900")
      post = @db.get_posts().first["id"]
      @db.upvote(post, "smartguy900", "X_i_love_to_upvote_X")
      @db.get_vote_count_for(post, "smartguy900").should == "2"
    end
    
    it "should store the username of the person who voted to prevent duplicate votes" do
      @db.add_post("sweet post!", "smartguy900")
      post = @db.get_posts().first["id"]
      @db.upvote(post, "smartguy900", "X_i_love_to_upvote_X")
      @db.upvoted?(post, "smartguy900", "smartguy900").should be_true
      @db.upvoted?(post, "smartguy900", "X_i_love_to_upvote_X").should be_true
      @db.upvoted?(post, "smartguy900", "i_never_vote").should be_false
    end
    
    it "should remove the user from the downvote list if they had previously downvoted the post" do
      @db.add_post("sweet post!", "smartguy900")
      post = @db.get_posts().first["id"]
      @db.downvote(post, "smartguy900", "fickle_voter_66")
      @db.upvote(post, "smartguy900", "fickle_voter_66")
      @db.upvoted?(post, "smartguy900", "fickle_voter_66").should be_true
      @db.downvoted?(post, "smartguy900", "fickle_voter_66").should be_false
    end
  end
  
  describe "#downvote" do
    it "should decrement the total vote count for the post" do
      @db.add_post("sweet post!", "smartguy900")
      post = @db.get_posts().first["id"]
      @db.downvote(post, "smartguy900", "X_i_love_to_upvote_X")
      @db.get_vote_count_for(post, "smartguy900").should == "0"
    end
    
    it "should store the username of the person who downvoted to prevent duplicate votes" do
      @db.add_post("sweet post!", "smartguy900")
      post = @db.get_posts().first["id"]
      @db.downvote(post, "smartguy900", "X_i_love_to_upvote_X")
      @db.downvoted?(post, "smartguy900", "smartguy900").should be_false
      @db.downvoted?(post, "smartguy900", "X_i_love_to_upvote_X").should be_true
      @db.downvoted?(post, "smartguy900", "i_never_vote").should be_false
    end
    
    it "should remove the user from the upvote list if they had previously upvoted the post" do
      @db.add_post("sweet post!", "smartguy900")
      post = @db.get_posts().first["id"]
      @db.upvote(post, "smartguy900", "fickle_voter_66")
      @db.downvote(post, "smartguy900", "fickle_voter_66")
      @db.downvoted?(post, "smartguy900", "fickle_voter_66").should be_true
      @db.upvoted?(post, "smartguy900", "fickle_voter_66").should be_false
    end
  end
  
  describe "#vote_for" do
    it "should return 'up' if the user voted up the given post" do
      @db.add_post("sweet post!", "smartguy900")
      post = @db.get_posts().first["id"]
      @db.upvote(post, "smartguy900", "X_i_love_to_upvote_X")    
      @db.vote_for(post, "smartguy900", "X_i_love_to_upvote_X").should == "up"
    end
    
    it "should return 'down' if the user voted down the given post" do
      @db.add_post("sweet post!", "smartguy900")
      post = @db.get_posts().first["id"]
      @db.downvote(post, "smartguy900", "i_dislike_smartguy900")    
      @db.vote_for(post, "smartguy900", "i_dislike_smartguy900").should == "down"
    end
    
    it "should return false if the user hasn't voted on the given post" do
      @db.add_post("sweet post!", "smartguy900")
      post = @db.get_posts().first["id"]
      @db.vote_for(post, "smartguy900", "i_never_vote").should be_false
    end
  end
  
  describe "#get_vote_count_for" do
    it "should return the current vote count for the post" do
      @db.add_post("i am clammy", "sick_max")
      @db.get_vote_count_for(@db.get_posts().first["id"], "sick_max").should == "1"
    end
  end
end