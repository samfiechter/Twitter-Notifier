#!/usr/bin/perl

use NET::SSL;
use LWP::UserAgent;
use Crypt::SSLeay;
use URI::Encode;
use MIME::Base64;
use URI;
use JSON;
use Try::Tiny;

my $uri = URI::Encode->new( { encode_reserved => 0 } );
my $cred;

open ( FH, "<" . shift) || die "NEED SECRET FILE with KEY:SECRET";
if ($cred = <FH>) {
    $cred =~ s/(\n|\s)//gi;
    $cred = $uri->encode($cred);
    close(FH);
} else {  die "NEED SECRET FILE with KEY:SECRET"; }


my $ua = LWP::UserAgent->new(
    "agent"=> "Twitter Notification script",
    "timeout" => 20 ,
    "ssl_opts" => { verify_hostname => 0 },
    "protocols_allowed" => ["http", "https"],
    "keep_alive" => 1
    );
my $resp= $ua->post("https://api.twitter.com/oauth2/token",( 'Content-Type' => "application/x-www-form-urlencoded;charset=UTF-8" ,
                                                             'Authorization' => "Basic " . encode_base64($cred),
                                                             Content => $uri->encode("grant_type=client_credentials")
                    ));
$resp->is_success || die $resp->request->as_string . "\n---\n" .$resp->content ."\n";
my $tokresp = decode_json $resp->content;

my $sresp =  $ua->get( "https://api.twitter.com/1.1/statuses/user_timeline.json?count=1&screen_name=briefingcom",
                       ('Authorization' =>  "Bearer " . $tokresp->{'access_token'})
    );
$sresp->is_success || die $sresp->request->as_string . "\n---\n" .$sresp->content ."\n";
# die $sresp->content;		
my $lastid, $jsresp;
while ($sresp->is_success){
    try {
        $jsresp = decode_json $sresp->content;
        foreach my $zz (@{$jsresp}) {

            my $text =  $zz->{'text'};
            $text =~ s/\$/\\\$/gi;
            $text =~ s/"//gi;
            $text =~ s/&amp;/&/gi;
            my $url = $text;
	    $url =~ s%.*(?=http://)%%i; 
	    if( $lastid < $zz->{'id'}) { $lastid = $zz->{'id'}; }
	    $cmd  = "/usr/local/bin/terminal-notifier -message \"" . $text . "\" -open \"". $url ."\" -title \"Briefing.com\" -appIcon \"http://www.briefing.com/favicon.ico\"";
	    system $cmd;
        }
    } catch {
	print "ERROR : " . $_;
    };
    sleep 61;
    $sresp =  $ua->get( "https://api.twitter.com/1.1/statuses/user_timeline.json?screen_name=briefingcom&since_id=" .$lastid,
                        ('Authorization' =>  "Bearer " . $tokresp->{'access_token'})
        );
    $sresp->is_success || die $sresp->request->as_string . "\n---\n" .$sresp->content ."\n";
}
exit;
# osascript -e 'display notification "Lorem ipsum dolor sit amet" with title "Title"'
