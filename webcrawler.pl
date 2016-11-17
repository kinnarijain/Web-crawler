#!/usr/bin/perl
use Encode;
use Encode::Locale;
use Getopt::Std;
use JSON;
use LWP::UserAgent;
use Web::Scraper;
use Data::Dumper;

getopt( 'hipcrfo', \%opt );
if ( $opt{h} ) {
    print <<__HTML__;
-i url or input html file
-p xpath
-c charset
-r return type of data, for example, HTML / TEXT / \@href
-f process or process_first
-o extract data write to file; otherwise, use stdout
-h help
__HTML__
    exit;
}

my $ret        = $opt{r} || 'HTML';
my $only_first = $opt{f} || 0;
my $path       = $opt{p};
my $charset    = $opt{c} || 'utf8';

my $c = $opt{i};
if ( ! $opt{i} or -f $opt{i}) {
    local $/ = undef;
    if($opt{i} and -f $opt{i}){
        open my $fh, "<:$charset", $opt{i};
        $c=<$fh>;
        close $fh;
    }else{
        $c = <STDIN>;
        $c = decode( locale => $c );
    }
    $c =~ s/\n+$//sg;
}

if ( $c =~ /^http/ ) {
    my $ua       = LWP::UserAgent->new;
    my $response = $ua->get($c);
    $c = $response->{_content};
    $c = decode( $charset, $c );
}


my ( $proc, $res ) =
  $only_first ? ( 'process_first', 'res' ) : ( 'process', 'res[]' );

my $s;
my $ret_s = $ret!~/=>/ ? qq['$ret'] : "{".$ret."}";
my $code = <<__CODE__;
\$s = scraper {
    $proc '$path', '$res' => $ret_s;
}
__CODE__

eval $code;

my $r     = $s->scrape($c);
my $res   = $r->{res};

my $final;
if($ret!~/=>/){
    $final = ref($res) eq 'ARRAY' ? join( "\n", map { s/\n/\\n/sg; $_ } @$res ) : $res=~s/\n/\\n/sgr;
}else{
    $final = encode_json($res);
    $final=~s/^\[/[\n/s;
    $final=~s/\]$/\n]/s;
    $final=~s/},{/},\n{/sg;
}

if($opt{o}){
    open my $fh, '>:utf8', $opt{o};
    print $fh $final;
    close $fh;
}else{
    $final = encode( locale => $final );
    print $final;
}