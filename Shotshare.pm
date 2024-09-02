#! /usr/bin/env perl
###################################################
#
#  Copyright (C) 2024 B Tasker
#
#  This file is part of Shutter.
#
#  Shutter is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  Shutter is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with Shutter; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
#
###################################################

package Shotshare;

use lib $ENV{'SHUTTER_ROOT'} . '/share/shutter/resources/modules';

use utf8;
use strict;
use POSIX qw/setlocale/;
use Locale::gettext;
use Glib qw/TRUE FALSE/;
use MIME::Base64;

use Shutter::Upload::Shared;
our @ISA = qw(Shutter::Upload::Shared);

my $d = Locale::gettext->domain("shutter-upload-plugins");
$d->dir($ENV{'SHUTTER_INTL'});

my %upload_plugin_info = (
	'module'                     => "Shotshare",
	'url'                        => "https://github.com/bentasker/shutter-shotshare/",
	'registration'               => "",
	'description'                => $d->get("Copy images into a ShotShare installation. Set user to shotshare domain and password to API key"),
	'supports_anonymous_upload'  => FALSE,
	'supports_authorized_upload' => TRUE,
	'supports_oauth_upload'      => FALSE,
);

binmode(STDOUT, ":utf8");
if (exists $upload_plugin_info{$ARGV[0]}) {
	print $upload_plugin_info{$ARGV[0]};
	exit;
}

###################################################

sub new {
	my $class = shift;

	#call constructor of super class (host, debug_cparam, shutter_root, gettext_object, main_gtk_window, ua)
	my $self = $class->SUPER::new(shift, shift, shift, shift, shift, shift);

	bless $self, $class;
	return $self;
}

sub init {
	my $self     = shift;

	#do custom stuff here
	use JSON::MaybeXS;
	use LWP::UserAgent;
	use HTTP::Request::Common;
	use Path::Class;

	return TRUE;
}

sub upload {
	my ($self, $upload_filename, $username, $password) = @_;

	#store as object vars
	$self->{_filename} = $upload_filename;
	$self->{_url} = $username;
	$self->{_key} = $password;

	utf8::encode $upload_filename;
	utf8::encode $password;
	utf8::encode $username;

	my $client = LWP::UserAgent->new(
		'timeout'    => 20,
		'keep_alive' => 10,
		'env_proxy'  => 1,
	);

	eval {

		my $json = JSON::MaybeXS->new();

		open(IMAGE, $upload_filename) or die "$!";
		my $binary_data = do { local $/ = undef; <IMAGE>; };
		close IMAGE;
		my $encoded_image = encode_base64($binary_data);


		my $req;

        $req = HTTP::Request::Common::POST(
            $self->{_url} . "/api/upload",
            'Authorization' => 'Bearer ' . $self->{_key},
            "Accept" => "application/json",
            Content_Type => 'form-data',
            Content => [
                'images[0]' => [$upload_filename]
            ]
            
            );
		my $rsp = $client->request($req);

		#print Dumper $json->decode( $rsp->content );

		my $json_rsp = $json->decode($rsp->content);
		
		

		if (!exists $json_rsp->{'data'}) {
			$self->{_links}{'status'} .=
				$d->get("Failed to upload image. Check your credentials are correct");
			return %{$self->{_links}};
		}
		
        $self->{_links}{'status'}  = 200;
		$self->{_links}->{'direct_link'}   = $json_rsp->{'data'}->{'link'};

	};
	if ($@) {
		$self->{_links}{'status'} = $@;

		#~ print "$@\n";
	}

	#and return links
	return %{$self->{_links}};
}

1;
