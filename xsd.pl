#!/usr/bin/perl
#
use XML::Pastor;
my $pastor = XML::Pastor->new();
$pastor->generate(
        mode =>'offline',
        style => 'single',
        schema=>'InterTrackMessage.xsd',
        class_prefix=>'IPTB::',
        destination=>'./',
);
