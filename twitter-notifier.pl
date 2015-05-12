#!/usr/local/Cellar/perl/5.20.1/bin/perl

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

my @names = ('briefingcom','WDEL','zerohedge','WSJbreakingnews',"DRUDGE_REPORT","EIAgov","Chris451mobile");
my @lastids = map(0, @names);
my @counts = map(1, @names);

my $nme = 0;

while (1){

    for ($nme=0;$nme < scalar @names; $nme++){
        my $cmd;
        my $posts = 0;
        if (0 < @counts[$nme]){
            if (0 == @lastids[$nme] ) {
                $cmd =  "https://api.twitter.com/1.1/statuses/user_timeline.json?count=1&screen_name=" . @names[$nme];
                #       system "logger \'$cmd\'";
            } else {
                $cmd =  "https://api.twitter.com/1.1/statuses/user_timeline.json?screen_name=" . @names[$nme] . "&since_id=" .@lastids[$nme];
                #   system "logger \'$cmd\'";
            }
            my $sresp =  $ua->get( $cmd ,('Authorization' =>  "Bearer " . $tokresp->{'access_token'}));
            $sresp->is_success || die $sresp->request->as_string . "\n---\n" .$sresp->content ."\n";
            try {
                my $jsresp = decode_json $sresp->content;
                system "logger ". $sresp->content;
                foreach my $tweets (@{$jsresp}) {
                    my $url = "";
                    my $text =  $tweets->{'text'};
                    $text =~ s/\$/\\\$/gi;
                    $text =~ s/"//gi;
                    $text =~ s/&amp;/&/gi;
                    if ($tweets->{'entities'}->{'urls'}->[0]->{'url'} ne ""){
                        $url = $tweets->{'entities'}->{'urls'}->[0]->{'url'};
                    } else {
                        if ($text =~ m@((http|ftp|https):\/\/(\S+))@gi){
                            $url = $1;
                        }
                    }
                    if( (1 * @lastids[$nme]) < (1 * $tweets->{'id'} )) { @lastids[$nme] = $tweets->{'id'}; }
                    $cmd  = "/usr/local/bin/terminal-notifier -message \"" . $text . "\" -open \"". $url ."\" -title \"@"
                        . @names[$nme]. "\" -appIcon \"http://www.twitter.com/favicon.ico\"";
                    system $cmd;
                    sleep 5;
                }
                $posts = scalar @{$jsresp};
            } catch {
                print "ERROR : " . $_;
            };
            if ( $posts < 13 ){
                sleep ( 61  - ( 5 * $posts));
            };
            @counts[$nme] = $posts;
        } else {
            @counts[$nme] = 1;	# only skip one!
        }

    }
}
exit;
# osascript -e 'display notification "Lorem ipsum dolor sit amet" with title "Title"'
