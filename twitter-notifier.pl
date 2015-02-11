#!/usr/bin/perl


use LWP::Simple;
$contents = get("https://api.twitter.com/oauth/authorize?screen_name=samfiechter");
 
# osascript -e 'display notification "Lorem ipsum dolor sit amet" with title "Title"' 
