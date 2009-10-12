$(document).ready(function() {
  $("#postToggle").click(function(){
      if ($("#messagebox").is(":hidden")){
          $("#messagebox").slideDown("slow");
          // $("#toggletext").html("Hide postbox");
          $("#toggleimage").attr("src", "contract.png");
      }
      else{
          $("#messagebox").slideUp("slow");
          // $("#toggletext").html("Add a post");
          $("#toggleimage").attr("src", "expand.png");
          }
  });
  
  $('textarea').addClass("idleField");
  $('textarea').focus(function() {
    $(this).removeClass("idleField").addClass("focusField");
    if (this.value == this.defaultValue){ 
      this.value = '';
      }
      if(this.value != this.defaultValue){
        this.select();
      }
  });
  $('textarea').blur(function() {
      $(this).removeClass("focusField").addClass("idleField");
        if ($.trim(this.value) == ''){
          this.value = (this.defaultValue ? this.defaultValue : '');
    }
  });
    
  $('#messagebox > ul').tabs({ fx: { height: 'toggle', opacity: 'toggle' } });
  $('#featuredvid > ul').tabs();
  
  $("#usernameForm").validate({
     rules: {
       username: {
         required : true,
         alphanumeric: true,
         maxlength: 20
       }
     }
  });
});