#!/usr/bin/perl -w
use strict;

use 5.010001;

use JSON;
use LWP::UserAgent;

use Data::Dumper;

my $handle = $ARGV[0];

unless ( $handle ) {
  say "No tumblr account name provided!";
  exit 1;
}

my $dir = $handle;
$dir =~ s/\W/_/g;
$dir =~ s/^https?_*(.*$)/$1/;
mkdir $dir or warn $!;

my $ua = LWP::UserAgent->new();

my $count = 0;
my $step = 50;

my $data = get_res( "http://$handle.tumblr.com/api/read/json" );

my $total_posts = $data->{'posts-total'};

my $offset = ( int( $total_posts / $step ) * $step );

do {
  $data = get_res( "http://$handle.tumblr.com/api/read/json?start=$offset&num=$step&type=photo&filter=text" );
  my $posts = $data->{posts};
  
  my @sort_posts = sort { $a->{'unix-timestamp'} <=> $b->{'unix-timestamp'} } @$posts;

  foreach my $post ( @sort_posts ) {
    if ( scalar @{ $post->{photos} } ) {
      my @sort_photos = sort { $a->{offset} cmp $b->{offset} } @{ $post->{photos} };
      foreach my $photo ( @sort_photos ) {
        get_photo( $photo );
      }
    }
    else {
      get_photo( $post );
    }
  }
  
  $offset -= $step;
} while ( $offset > 0 );


sub get_res {
  my ( $url ) = @_;
  my $res = $ua->get( $url );
  if ( $res->is_success ) {
    my $raw_data = $res->content;
    $raw_data =~ s/^.*?{/{/;
    $raw_data =~ s/;$//;

    return from_json( $raw_data );
  }

  die "Failed to get $url : $!";
}

sub get_photo {
  my ( $p ) = @_;
  
  #say '-' x 80;
  #say Dumper( $p );
  
  my $url = $p->{'photo-url-1280'};
  my ( $id, $ext ) = $url =~ m/tumblr_(\w+?)_\d+?(\.\w*?)$/;
  
  my $fn = sprintf( "%s-%0*i%s", $handle, length( $total_posts ) + 1, ++$count, $ext );
  if ( -e "$dir/$fn") {
    say "Skipping $dir/$fn - already exists";
  }
  else {
    say "$url -> $dir/$fn";
    my $res = $ua->get( $url, ':content_file' => "$dir/$fn" );
    unless ( $res->is_success ) {
      say "Failed: " . $res->status_line;
    }
  }
} 
