#!/usr/bin/perl
use strict;
use Getopt::Long;
use XML::LibXML;
use IPTB;

my $progname = 'anybed2intertrack.pl';

#
# Anybed assignment.xml
#
my ($anybed, %anybed_hash, $anybed_dat);

#
# Output Prefix
#
my ($output_dir);

#
# InterFace
#
my ($interface);

#
# ITM Port
#
my %iptb_port = ();


#
# Otehr
#
my %asnum_hash = ();
my %nbr_hash = ();
my %mac_hash = ();
my %nbrmac_hash = ();

#
# GetOpt
#
GetOptions(
  'anybed-assignment=s' => \$anybed_dat,
  'outputdirs=s' => \$output_dir,
  'interface=s' => \$interface
);

$| = 1;
&main;
exit;

sub main(){
	&init;
	&read_anybed();

	&write_intertrack("ITM");
	&write_intertrack("BTM");
	&write_intertrack("DP");
	&write_intertrack("TC");

	&write_bts();

	return 0;	
}

sub write_bts(){
	my ($asnum, $savefile);
	my ($mac, $nbr, $nbrmac, @nbr_list);
	my ($i);


	foreach $asnum ( sort keys %mac_hash ){
		$mac = $mac_hash{$asnum};	

		$savefile = $output_dir . "bts" . "-" . $asnum_hash{$asnum} . ".conf";
    open(OUT, "> $savefile") or die;
		@nbr_list = split(/,/, $nbr_hash{$asnum});
		for ($i = 0; $i <= $#nbr_list; $i++){
			$nbr = $nbr_list[$i];
			$nbrmac = $nbrmac_hash{$nbr};

			print OUT lc($mac) . "," . lc($nbrmac) . "," . $nbr . ",out\n";
			print OUT lc($nbrmac) . "," . lc($mac) . "," . $nbr . ",in\n";
		}
    close(OUT);
	}
}

sub generate_mystatus() {
	my ($asnum, $nodetype) = @_;
	my ($iptb_mystatus, $iptb_asnum);
	my ($iptb_coverareas, $iptb_coverarea);
	my ($iptb_lpitm, $iptb_lp, $iptb_lpdtm, $iptb_lpdp);
	my ($iptb_lptc, $iptb_lpcmd);
	my ($iptb_filterrules, $iptb_ratelimit, $iptb_desc);
	my ($cmdtype) = $nodetype . "CMD";

	#
	# MyStatus
	#
	$iptb_mystatus = IPTB::MyStatus->new;
	$iptb_mystatus->node($nodetype);

		#
		# MyStatus->ASNumber
		#
		$iptb_asnum = IPTB::ASNumber->new($asnum);
		$iptb_mystatus->ASNumber($iptb_asnum);

		#
		# MyStatus->CoverAreas->CoverArea
		#
		$iptb_coverareas = IPTB::CoverAreas->new;
			$iptb_coverarea = IPTB::CoverArea->new;
			$iptb_coverarea->ipversion("4");
			$iptb_coverarea->scope("global");
		$iptb_coverareas->CoverArea($iptb_coverarea);
		$iptb_mystatus->CoverAreas($iptb_coverareas);

		#
		# MyStatus->ListeningPort
		#
		if ($nodetype eq "ITM"){ 
			$iptb_lpitm = IPTB::ListeningPort->new;
			$iptb_lpitm->type("ITM");
			$iptb_lpitm->portnumber($iptb_port{"ITM"});
			$iptb_lp = IPTB::ListeningPort->new;
			$iptb_lp->type("BTM");
			$iptb_lp->portnumber($iptb_port{"BTM"});
			$iptb_lpdtm = IPTB::ListeningPort->new;
			$iptb_lpdtm->type("DTM");
			$iptb_lpdtm->portnumber($iptb_port{"DTM"});
			$iptb_lpdp = IPTB::ListeningPort->new;
			$iptb_lpdp->type("DP");
			$iptb_lpdp->portnumber($iptb_port{"DP"});
			$iptb_lptc = IPTB::ListeningPort->new;
			$iptb_lptc->type("TC");
			$iptb_lptc->portnumber($iptb_port{"TC"});
			$iptb_lpcmd = IPTB::ListeningPort->new;
			$iptb_lpcmd->type("CMD");
			$iptb_lpcmd->portnumber($iptb_port{$cmdtype});
			$iptb_mystatus->ListeningPort($iptb_lpitm, $iptb_lp, $iptb_lpdtm, $iptb_lpdp, $iptb_lpcmd);
		}
		elsif ($nodetype eq "DP"){
			$iptb_lpdp = IPTB::ListeningPort->new;
			$iptb_lpdp->type("DP");
			$iptb_lpdp->portnumber($iptb_port{"DP"});
			$iptb_lptc = IPTB::ListeningPort->new;
			$iptb_lptc->type("TC");
			$iptb_lptc->portnumber($iptb_port{"TC"});
			$iptb_lpcmd = IPTB::ListeningPort->new;
			$iptb_lpcmd->type("CMD");
			$iptb_lpcmd->portnumber($iptb_port{"$cmdtype"});
			$iptb_mystatus->ListeningPort($iptb_lpdp,$iptb_lptc,$iptb_lpcmd);
		}
		elsif ($nodetype eq "BTM") {
			$iptb_lpcmd = IPTB::ListeningPort->new;
			$iptb_lpcmd->type("CMD");
			$iptb_lpcmd->portnumber($iptb_port{"$cmdtype"});
			$iptb_mystatus->ListeningPort($iptb_lpcmd);
		}

		#
		# MyStatus->FilterRules->RateLimit
		#
		if ($nodetype eq "ITM" || $nodetype eq "BTM" || $nodetype eq "DP" ){
			$iptb_filterrules = IPTB::FilterRules->new;
				$iptb_ratelimit = IPTB::RateLimit->new;
				$iptb_ratelimit->mps("100");
			$iptb_filterrules->RateLimit($iptb_ratelimit);
			$iptb_mystatus->FilterRules($iptb_filterrules);
		}

		#
		# MyStatus->Description
		#
		$iptb_desc = IPTB::Description->new("$nodetype-AS$asnum");
	$iptb_mystatus->Description($iptb_desc);
	
	return $iptb_mystatus;
}

sub generate_itm_nodes() {
	my $asnum = @_[0];	
	my ($iptb_nodes, $iptb_node, $iptb_address);
	my ($iptb_nodeid, $iptb_itmid, $iptb_nbr_asnumber, $iptb_nbr_coverarea);
	my ($iptb_lpitm, $iptb_desc);
	my (@nbr_list, @iptb_node_list, $nbr_asnum);
	my ($btm_node, $dp_node, $cmd_node);
	my ($i);

	#
	# Nodes
	#
	$iptb_nodes = IPTB::Nodes->new;

	@nbr_list = split(/,/, $nbr_hash{$asnum});
	@iptb_node_list = ();

	for ($i = 0; $i <= $#nbr_list; $i++){
		$nbr_asnum = $nbr_list[$i];
		$iptb_node = IPTB::Node->new;
		$iptb_node->nodetype("ITM");

			#
			# Nodes->Node->NodeID->ITMID
			#
			$iptb_nodeid = IPTB::NodeID->new;
			$iptb_nodeid->idtype("ITMID");

				$iptb_itmid = IPTB::ITMID->new;
					$iptb_nbr_asnumber = IPTB::ASNumber->new($nbr_asnum);
				$iptb_itmid->ASNumber($iptb_nbr_asnumber);	

					$iptb_nbr_coverarea = IPTB::CoverArea->new;
					$iptb_nbr_coverarea->ipversion("4");
					$iptb_nbr_coverarea->scope("global");
				$iptb_itmid->CoverArea($iptb_nbr_coverarea);	
			$iptb_nodeid->ITMID($iptb_itmid);
		$iptb_node->NodeID($iptb_nodeid);

			#
			# Nodes->Node->IPAddress
			#
			$iptb_address = IPTB::IPAddress->new($asnum_hash{$nbr_asnum});
			$iptb_address->version("4");
			$iptb_address->mask("24");
			$iptb_address->block("private");

		$iptb_node->IPAddress($iptb_address);

			#
			# Nodes->Node->ListeningPort
			#
			$iptb_lpitm = IPTB::ListeningPort->new;
			$iptb_lpitm->type("ITM");
			$iptb_lpitm->portnumber($iptb_port{"ITM"});
		$iptb_node->ListeningPort($iptb_lpitm);

			#
			# Nodes->Node->Descrption
			#
			$iptb_desc = IPTB::Description->new("ITM-AS$nbr_asnum");
		$iptb_node->Description($iptb_desc);

		push(@iptb_node_list, $iptb_node);
	}

	$btm_node = &generate_node($asnum, "BTM", $iptb_port{"BTM"});
	$dp_node = &generate_node($asnum, "DP", $iptb_port{"DP"});
	$cmd_node = &generate_node($asnum, "CMD", $iptb_port{"ITMCMD"});

	$iptb_nodes->Node(@iptb_node_list,$btm_node,$dp_node,$cmd_node);

	return $iptb_nodes;
}

sub generate_node {
	my ($asnum, $nodetype, $nodeport) = @_;
	my ($node, $nodeid, $address, $lp, $desc);
	my ($itmid, $itmid_coverarea, $itmid_asnumber);

	$node = IPTB::Node->new;
	$node->nodetype($nodetype);
		$nodeid = IPTB::NodeID->new;

		$address = IPTB::IPAddress->new("127.0.0.1");
		$address->version("4");
		$address->mask("32");
		$address->block("loopback");

		if ($nodetype eq "ITM"){
			$nodeid->idtype("ITMID");
				$itmid = IPTB::ITMID->new;
				$itmid_asnumber = IPTB::ASNumber->new($asnum);
				$itmid->ASNumber($itmid_asnumber);	

				$itmid_coverarea = IPTB::CoverArea->new;
				$itmid_coverarea->ipversion("4");
				$itmid_coverarea->scope("global");
				$itmid->CoverArea($itmid_coverarea);	
			$nodeid->ITMID($itmid);
		}
		else {
			$nodeid->idtype("IP");
			$nodeid->IPAddress($address);
		}

	$node->NodeID($nodeid);	
	$node->IPAddress($address);

		$lp = IPTB::ListeningPort->new;
		$lp->type($nodetype);
		$lp->portnumber($nodeport);
	$node->ListeningPort($lp);

		$desc = IPTB::Description->new("$nodetype-AS$asnum");
	$node->Description($desc);

	return $node;	
}

sub write_intertrack(){
	my $nodetype = @_[0];
	my ($asnum);
	my ($iptb, $iptb_conf);
	my ($iptb_mystatus, $iptb_nodes);
	my ($itm_node, $tc_node, $dp_node, $btm_node, $cmd_node);
	my ($savefile, $prefix, $xml);

	$prefix = $nodetype;
	$prefix =~ tr/A-Z/a-z/;

	foreach $asnum ( sort keys %asnum_hash ){
		$iptb = IPTB::InterTrackMessage->new;
		$iptb->type("Config");

			$iptb_conf = IPTB::Config->new;

			$iptb_mystatus = &generate_mystatus($asnum, $nodetype);
			$iptb_conf->MyStatus($iptb_mystatus);

			if ($nodetype eq "ITM"){
				$iptb_nodes = &generate_itm_nodes($asnum);
			}
			else {
				$iptb_nodes = IPTB::Nodes->new;

				if ($nodetype eq "BTM"){
					$itm_node = &generate_node($asnum, "ITM", $iptb_port{"BTM"});
					$cmd_node = &generate_node($asnum, "CMD", $iptb_port{"BTMCMD"});
					$iptb_nodes->Node($itm_node,$cmd_node);
				}
				elsif ($nodetype eq "DP"){
					$itm_node = &generate_node($asnum, "ITM", $iptb_port{"DP"});
					$tc_node = &generate_node($asnum, "TC", $iptb_port{"TC"});
					$cmd_node = &generate_node($asnum, "CMD", $iptb_port{"DPCMD"});
					$iptb_nodes->Node($itm_node,$tc_node,$cmd_node);
				}
				elsif ($nodetype eq "TC"){
					$dp_node = &generate_node($asnum, "DP", $iptb_port{"TC"});
					$iptb_nodes->Node($dp_node);
				}
			}

			$iptb_conf->Nodes($iptb_nodes);

		$iptb->Config($iptb_conf);
		
		$xml = $iptb->to_xml_string();

		#
		# For InterTrack dtd (not supported in IPTB Class)
		#
		$xml =~ s/\<\?xml version="1.0" encoding="UTF-8"\?\>/\<\?xml version="1.0" encoding="UTF-8" standalone="no"\?\>/;
		$xml =~ s/\<InterTrackMessage type="Config"\>/\<InterTrackMessage type="Config" xmlns:xsi="http:\/\/www.w3.org\/2001\/XMLSchema-instance"\n  xsi:noNamespaceSchemaLocation="InterTrackMessage.xsd"\>/;


		$savefile = $output_dir . $prefix . "-" . $asnum_hash{$asnum} . ".conf";
		open(OUT, "> $savefile") or die;
		print OUT $xml;
		close(OUT);
	}
	return;
}

sub read_anybed() {
	my ($doc, $i, $j);
	my (@nodes, $node, $mgmtip, $asnum);
	my (@pinterfaces, $pinterface);
	my (@linterfaces, $linterface);
	my ($nbr, @nbr_list, $nbrmac, @nbrmac_list);

	$doc = $anybed->parse_file($anybed_dat) or die;
	@nodes = $doc->getElementsByTagName('node');

	#
	# 1st Loop: Obtain all mgmtip(s) and asnum(s);
	#
  for ($i = 0; $i <= $#nodes; $i++){
		$node = @nodes[$i];
		$mgmtip = $node->getAttribute('mgmtip');
		$asnum = $node->getAttribute('asnum');
		$asnum_hash{$asnum} = $mgmtip;

		@pinterfaces = $node->getElementsByTagName('pinterface');
		for ($j = 0; $j <= $#pinterfaces; $j++){
			$pinterface = $pinterfaces[$j];
			if ($pinterface->getAttribute('pname') eq $interface){
				$mac_hash{$asnum} = $pinterface->getAttribute('macaddr');
				last;
			}
		}
	}

	#
	# 2nd Loop: Obtain BGP Neighbor	
	#
	for ($i = 0; $i <= $#nodes; $i++){
		$node = @nodes[$i];
		$mgmtip = $node->getAttribute('mgmtip');
		$asnum = $node->getAttribute('asnum');

		@linterfaces = $node->getElementsByTagName('linterface');

		@nbr_list = ();

		for ($j = 0; $j <= $#linterfaces; $j++){
			$linterface = $linterfaces[$j];
			$nbr = $linterface->getAttribute('nbrasnum');
			$nbrmac = $linterface->getAttribute('nbrmacaddr');

			if ($nbr eq "" || $nbrmac eq "" | $nbr < 1 || $nbr > 65535){
				next;
			}

			if (! defined($asnum_hash{$nbr})){
				next;
			}

			push(@nbr_list, $nbr);
			$nbrmac_hash{$nbr} = $nbrmac;
		}
		$nbr_hash{$asnum} = join(',', @nbr_list);
	}
	return 0;	
}


sub init(){

	#
	# input Anybed dataset	
	#
	if ($anybed_dat eq "" || ! -f $anybed_dat){
    &usage();
  }
	else {
		$anybed = XML::LibXML->new;
	}

	#
	# output directory 
	#
	if ( $output_dir eq ""){
		$output_dir = "./";
	}

	$output_dir =~ s/\/$//g;
	$output_dir = $output_dir . "/";

	if ( ! -d $output_dir ){
		mkdir($output_dir) or die;
	}

	if ( $interface eq ""){
		$interface = "eth0";
	}

	#
	# InterTrack default settings
	#
	$iptb_port{"ITM"} = 9001;
	$iptb_port{"BTM"} = 9002;
	$iptb_port{"DTM"} = 9003;
	$iptb_port{"DP"} = 9004;
	$iptb_port{"TC"} = 9005;

	$iptb_port{"ITMCMD"} = 19101;
	$iptb_port{"BTMCMD"} = 19102;
	$iptb_port{"DTMCMD"} = 19103;
	$iptb_port{"DPCMD"} = 19103;
	$iptb_port{"TCCMD"} = 19105;

	return;
}

sub usage {
	print $progname . " : Converting AnyBed Assingment Log to InterTrack Config\n";
  print "\n";
  print $progname . "\n";
  print "   -a [ anybed-assignment file ] (must)\n";
  print "   -o [ output directory prefix ] (optional, default is \"./\" )\n";
  print "   -i [ experimental interface ] (optional, default is \"eth0\" )\n";
  print "\n";
  print "example) ./$progname -a assignment.xml -o /usr/local/etc/intertrack -i eth0\n";
  print "\n";

	exit;
}
  
