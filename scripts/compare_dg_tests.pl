#!/usr/bin/env perl
use strict;
use warnings;

use File::Glob;
use Getopt::Long;
use Term::ANSIColor qw(:constants);
use File::Basename;
use Cwd;

my $app = $0;

sub read_sum($);
sub read_unstable($);
sub dump_result($);
sub compare_results($$);
sub usage();
sub print_compare_results_summary($$);
sub nothing($$$$);

  # OK
my $STILL_PASSES          = "Still passes              [PASS => PASS]";
my $STILL_FAILS           = "Still fails               [FAIL => FAIL]";

# TO BE CHECKED
my $XFAIL_APPEARS         = "Xfail appears             [PASS =>XFAIL]";
my $PASSED_NOW_TIMEOUTS   = "Timeout                   [PASS =>T.OUT]";
my $FAIL_DISAPPEARS	  = "Fail disappears           [FAIL =>     ]";
my $XFAIL_NOW_PASSES      = "Expected fail passes      [XFAIL=>XPASS]";
my $FAIL_NOW_PASSES       = "Fail now passes           [FAIL => PASS]";
my $NEW_PASSES		  = "New pass                  [     => PASS]";
my $UNHANDLED_CASES	  = "Unhandled cases           [   ..??..   ]";
my $UNSTABLE_CASES	  = "Unstable cases            [~RANDOM     ]";

# ERRORS
my $PASSED_NOW_FAILS      = "Passed now fails          [PASS => FAIL]";
my $PASS_DISAPPEARS       = "Pass disappears           [PASS =>     ]";
my $FAIL_APPEARS          = "Fail appears              [     => FAIL]";

my @handler_list = (
  {was=>"PASS",     is=>"PASS",     cat=>$STILL_PASSES},
  {was=>"PASS",     is=>"XPASS",    cat=>$STILL_PASSES},
  {was=>"XPASS",    is=>"PASS",     cat=>$STILL_PASSES},
  {was=>"XPASS",    is=>"XPASS",    cat=>$STILL_PASSES},
  {was=>"FAIL",     is=>"FAIL",     cat=>$STILL_FAILS},
  {was=>"FAIL",     is=>"XFAIL",    cat=>$STILL_FAILS},
  {was=>"XFAIL",    is=>"FAIL",     cat=>$STILL_FAILS},
  {was=>"XFAIL",    is=>"XFAIL",    cat=>$STILL_FAILS},

  {was=>"XPASS",    is=>"XFAIL",    cat=>$XFAIL_APPEARS},
  {was=>"PASS",     is=>"XFAIL",    cat=>$XFAIL_APPEARS},
  {was=>"FAIL",     is=>"NO_EXIST", cat=>$FAIL_DISAPPEARS},
  {was=>"XFAIL",    is=>"NO_EXIST", cat=>$FAIL_DISAPPEARS},
  {was=>"XFAIL",    is=>"PASS",     cat=>$XFAIL_NOW_PASSES},
  {was=>"XFAIL",    is=>"XPASS",    cat=>$XFAIL_NOW_PASSES},
  {was=>"FAIL",     is=>"PASS",     cat=>$FAIL_NOW_PASSES},
  {was=>"FAIL",     is=>"XPASS",    cat=>$FAIL_NOW_PASSES},
  {was=>"NO_EXIST", is=>"PASS",     cat=>$NEW_PASSES},
  {was=>"NO_EXIST", is=>"XPASS",    cat=>$NEW_PASSES},

  {was=>"PASS",     is=>"FAIL",     handler=>\&handle_pass_fail},
  {was=>"XPASS",    is=>"FAIL",     handler=>\&handle_pass_fail},
  {was=>"PASS",     is=>"NO_EXIST", cat=>$PASS_DISAPPEARS},
  {was=>"XPASS",    is=>"NO_EXIST", cat=>$PASS_DISAPPEARS},
  {was=>"NO_EXIST", is=>"FAIL",     cat=>$FAIL_APPEARS},
  {was=>"NO_EXIST", is=>"XFAIL",    cat=>$XFAIL_APPEARS},

#  {was=>"NO_EXIST", is=>"NO_EXIST", handler=>\&handle_not_yet_supported}
);

######################################################
# TREAT ARGUMENTS

my $verbose=0;
my $quiet=0;
my $long=0;
my $short=0;
my $debug=0;
my ($testroot, $basename);
my ($ref_file_name, $res_file_name);
my $nounstable=0;
my $unstablefile=0;

GetOptions ("l"           => \$long,
            "s"           => \$short,
            "q"           => \$quiet,
            "v"           => \$verbose,
            "dbg"         => \$debug,
            "testroot=s"  => \$testroot,
            "basename=s"  => \$basename,
            "no-unstable"  => \$nounstable,
            "unstable-tests=s" => \$unstablefile);

$ref_file_name = $ARGV[0] if ($#ARGV == 1);
$res_file_name = $ARGV[1] if ($#ARGV == 1);

$ref_file_name = $testroot."/expected_results/".$basename if ($testroot and $basename);
$res_file_name = $testroot."/testing/run/".$basename if ($testroot and $basename);
&usage if (not $ref_file_name or not $res_file_name);

my ($col_boldred, $col_red, $col_boldgreen, $col_green, $col_boldpink, $col_pink, $col_reset)
    = ("\033[31;1m","\033[31;3m","\033[32;1m","\033[32;3m","\033[35;1m","\033[35;2m","\033[0m");
($col_boldred, $col_red, $col_boldgreen, $col_green, $col_boldpink, $col_pink, $col_reset)
    = ("","","","","","","") if (not I_am_interactive());

######################################################
# MAIN PROGRAM
# print "comparing $ref_file_name $res_file_name\n";

# If none of the 2 .sum exists, nothing to compare: exit early.
exit 0 if ( (! -e $ref_file_name) && (! -e $res_file_name ));

my $ref = read_sum($ref_file_name) ;
my $res = read_sum($res_file_name) ;
my @unstablelist = ();

@unstablelist = read_unstable($unstablefile) if ($unstablefile ne 0);

compare_results($ref, $res);

my $final_result = print_compare_results_summary($ref, $res);

exit $final_result;

######################################################
# UTILITIES

sub empty_result()
{
   my %empty_result;# = {PASS=>0, FAIL=>0, XPASS=>0, XFAIL=>0, UNSUPPORTED=>0, UNTESTED=>0, UNRESOLVED=>0};
   $empty_result{PASS}=$empty_result{FAIL}=$empty_result{XPASS}=$empty_result{XFAIL}=0;
   $empty_result{UNSUPPORTED}=$empty_result{UNTESTED}=$empty_result{UNRESOLVED}=$empty_result{NO_EXIST}=0;
   return \%empty_result;
}
sub I_am_interactive {
  return -t STDIN && -t STDOUT;
}
sub usage()
{
	print "Usage : $app <ref_file.sum> <result_file.sum>\n";
	exit 1;
}


######################################################
# PARSING
sub read_sum($)
{
   my ($sum_file) = @_;
   my $res = empty_result();
   my %testcases;
   my %unsupported;
   $res->{testcases} = \%testcases;
   my $pending_timeout=0;

   open SUMFILE, $sum_file or die $!;
   while (<SUMFILE>)
   {
	  if (m/^(PASS|XPASS|FAIL|XFAIL|UNSUPPORTED|UNTESTED|UNRESOLVED): (.*)/)
	  {
	  	my ($diag,$tc) = ($1,$2);
		my %tcresult;
		$tc =~ s/==[0-9]+== Shadow memory range interleaves with an existing memory mapping. ASan cannot proceed correctly./==<pid>== Shadow memory range interleaves with an existing memory mapping. ASan cannot proceed correctly./;
		$testcases{$tc} = empty_result() if (not exists $testcases{$tc});
		$testcases{$tc}->{$diag}++;
		$testcases{$tc}->{HAS_TIMED_OUT} = $pending_timeout;
		$pending_timeout = 0;
		$res->{$diag}++;
	  }
	  elsif (m/WARNING: program timed out/) 
	  {
	  	$pending_timeout = 1;
	  }
	  elsif (m/^(# of expected passes|# of unexpected failures|# of expected failures|# of known failures|# of unsupported tests|# of untested testcases)\s+(.*)/)
	  {
	  	 $res->{"summary - "."$1"} = $2;
	  }
	  elsif (m/^\/.*\/([^\/]+)\s+version\s+(.*)/)
	  {
	  	 $res->{tool} = $1;
	  	 $res->{version} = $2;
		 $res->{version} =~ s/ [-(].*//;
	  }
   }
   close SUMFILE;
   return $res;
}

# Parse list on unstable tests
sub read_unstable($)
{
   my ($unstable_file) = @_;
   my @unstable_tests = ();

   open UNSTABLEFILE, $unstable_file or die $!;
   while (<UNSTABLEFILE>)
   {
       # Skip lines starting with '#'
       if (/^#/)
       {
       }
       else
       {
	   chomp;
	   push @unstable_tests, $_;
       }
   }
   close UNSTABLEFILE;
   return @unstable_tests;
}

######################################################
# DIFFING
sub handle_pass_fail($$$$)
{
   my ($ref, $res, $diag_diag, $tc) = @_;
   if ($res->{testcases}->{$tc}->{HAS_TIMED_OUT})
   {
     push @{$res->{$PASSED_NOW_TIMEOUTS}}, $tc;
   }
   else
   {
     push @{$res->{$PASSED_NOW_FAILS}}, $tc;
   }
}

sub compare_results($$)
{
   my ($ref, $res) = @_;

   @{$res->{$STILL_PASSES}} = ();
   @{$res->{$STILL_FAILS}} = ();
   @{$res->{$PASSED_NOW_FAILS}} = ();
   @{$res->{$PASS_DISAPPEARS}} = ();
   @{$res->{$FAIL_APPEARS}} = ();
   @{$res->{$NEW_PASSES}} = ();
   @{$res->{$FAIL_DISAPPEARS}} = ();
   @{$res->{$XFAIL_APPEARS}} = ();
   @{$res->{$XFAIL_NOW_PASSES}} = ();
   @{$res->{$FAIL_NOW_PASSES}} = ();
   @{$res->{$PASSED_NOW_TIMEOUTS}} = ();
   @{$res->{$UNHANDLED_CASES}} = ();
   @{$res->{$UNSTABLE_CASES}} = ();

   #### MERGE REF AND RES
   foreach my $key (sort (keys %{$res->{testcases}}))
   {
		if (not exists $ref->{testcases}->{$key}) {
		   $ref->{testcases}->{$key} = empty_result();
		   $ref->{testcases}->{$key}->{NO_EXIST} = 1;
		}
   }
   foreach my $key (keys %{$ref->{testcases}})
   {
   		if (not exists $res->{testcases}->{$key})
		{
		   $res->{testcases}->{$key} = empty_result();
		   $res->{testcases}->{$key}->{NO_EXIST} = 1;
		}
   }

   #### ACTIONS FOR EACH CASES
   foreach my $key (sort (keys %{$ref->{testcases}}))
   {
       # If testcase is listed as 'unstable' mark it as such and skip
       # other processing.
       if (grep { (index $key,$_)!=-1} @unstablelist)
       {
	   print "[unstable] $key\n" if ($debug);
	   push @{$res->{$UNSTABLE_CASES}}, $key if ($nounstable == 0);
       }
       else
       {
	   foreach my $diag_diag (@handler_list)
	   {
		  if ($ref->{testcases}->{$key}->{$diag_diag->{was}} != $res->{testcases}->{$key}->{$diag_diag->{was}}
		  and $res->{testcases}->{$key}->{$diag_diag->{is}})
		  {

			print "[$diag_diag->{was} => $diag_diag->{is}] $key\n" if ($debug);
			if ($diag_diag->{handler})
			{
			  $diag_diag->{handler} ($ref, $res, $diag_diag, $key);
			}
			else
			{
			  push @{$res->{$diag_diag->{cat}}}, $key;
			}
		  }
	   }
       }
   }
}

######################################################
# PRINTING
sub print_tclist($@)
{
   my ($cat, @tclist) = @_;
   print "  - ".$cat.":\n\n  ". join("\n  ",@tclist) . "\n\n" if (scalar(@tclist));
}

sub print_compare_results_summary($$)
{
   my ($ref, $res) = @_;
   my $return_value=0;
   my $total = 0;
   my $rtotal = 0;
   my $quiet_reg = $quiet;

   if (not $quiet)
   {
       printf "Comparing:\n";
       printf "REFERENCE:$ref_file_name\n";
       printf "CURRENT:  $res_file_name\n\n";
   }

   #### TESTS STATUS
   if (not $quiet and not $short)
   {
       printf "              `                              +---------+---------+\n";
       printf "o  RUN STATUS :                              |   REF   |   RES   |\n";
       printf "  +------------------------------------------+---------+---------+\n";
       printf "  | %-40s | %7d | %7d |\n", "Passes                      [PASS+XPASS]", $ref->{PASS} + $ref->{XPASS}, $res->{PASS} + $res->{XPASS};
       printf "  | %-40s | %7d | %7d |\n", "Unexpected fails                  [FAIL]", $ref->{FAIL}, $res->{FAIL};
       printf "  | %-40s | %7d | %7d |\n", "Expected fails                   [XFAIL]", $ref->{XFAIL}, $res->{XFAIL};
       printf "  | %-40s | %7d | %7d |\n", "Unresolved                  [UNRESOLVED]", $ref->{UNRESOLVED}, $res->{UNRESOLVED};
       printf "  | %-40s | %7d | %7d |\n", "Unsupported       [UNTESTED+UNSUPPORTED]", $ref->{UNTESTED}+$ref->{UNSUPPORTED}, $res->{UNTESTED}+$res->{UNSUPPORTED};
       printf "  +------------------------------------------+---------+---------+\n";
       printf "\n";
   }

   #### REGRESSIONS ?
   $quiet_reg=1 if ($short and not scalar(@{$res->{$PASSED_NOW_FAILS}})+scalar(@{$res->{$PASS_DISAPPEARS}})+scalar(@{$res->{$FAIL_APPEARS}})+scalar(@{$res->{$PASSED_NOW_TIMEOUTS}}));

   if (not $quiet_reg)
   {
       $rtotal = scalar(@{$res->{$PASSED_NOW_FAILS}})
	   +scalar(@{$res->{$PASS_DISAPPEARS}})
	   +scalar(@{$res->{$FAIL_APPEARS}})
	   +scalar(@{$res->{$PASSED_NOW_TIMEOUTS}});

       printf "\n$col_red"."o  REGRESSIONS : \n";
       printf "  +------------------------------------------+---------+\n";
       printf "  | %-40s | %7d |\n", $PASSED_NOW_FAILS, scalar(@{$res->{$PASSED_NOW_FAILS}}) if (scalar(@{$res->{$PASSED_NOW_FAILS}}));
       printf "  | %-40s | %7d |\n", $PASSED_NOW_TIMEOUTS, scalar(@{$res->{$PASSED_NOW_TIMEOUTS}}) if (scalar(@{$res->{$PASSED_NOW_TIMEOUTS}}));
       printf "  | %-40s | %7d |\n", $PASS_DISAPPEARS, scalar(@{$res->{$PASS_DISAPPEARS}}) if (scalar(@{$res->{$PASS_DISAPPEARS}}));
       printf "  | %-40s | %7d |\n", $FAIL_APPEARS, scalar(@{$res->{$FAIL_APPEARS}}) if (scalar(@{$res->{$FAIL_APPEARS}}));
       printf "  +------------------------------------------+---------+\n";
       printf "  | %-40s | %7d |\n", "TOTAL_REGRESSIONS", $rtotal;
       printf "  +------------------------------------------+---------+\n";
       printf "\n";

       if ($long)
       {
	      print_tclist($PASSED_NOW_FAILS, @{$res->{$PASSED_NOW_FAILS}});
	      print_tclist($PASSED_NOW_TIMEOUTS, @{$res->{$PASSED_NOW_TIMEOUTS}});
	      print_tclist($PASS_DISAPPEARS, @{$res->{$PASS_DISAPPEARS}});
	      print_tclist($FAIL_APPEARS, @{$res->{$FAIL_APPEARS}});
       }
       printf "$col_reset\n";
   }

   #### MINOR TO BE CHECKED ?
   if (not $quiet and not $short)
   {
       $total = scalar(@{$res->{$XFAIL_NOW_PASSES}})+
	   scalar(@{$res->{$FAIL_NOW_PASSES}})+
	   scalar(@{$res->{$NEW_PASSES}})+
	   scalar(@{$res->{$FAIL_DISAPPEARS}})+
	   scalar(@{$res->{$XFAIL_APPEARS}})+
	   scalar(@{$res->{$UNHANDLED_CASES}})+
	   scalar(@{$res->{$UNSTABLE_CASES}});

       printf "$col_pink"."o  MINOR TO BE CHECKED : \n";
       printf "  +------------------------------------------+---------+\n";
       printf "  | %-40s | %7d |\n", $XFAIL_APPEARS, scalar(@{$res->{$XFAIL_APPEARS}}) if (scalar(@{$res->{$XFAIL_APPEARS}}));

       printf "  | %-40s | %7d |\n", $FAIL_DISAPPEARS, scalar(@{$res->{$FAIL_DISAPPEARS}}) if (scalar(@{$res->{$FAIL_DISAPPEARS}}));

       printf "  | %-40s | %7d |\n", $XFAIL_NOW_PASSES, scalar(@{$res->{$XFAIL_NOW_PASSES}}) if (scalar(@{$res->{$XFAIL_NOW_PASSES}}));
       printf "  | %-40s | %7d |\n", $FAIL_NOW_PASSES, scalar(@{$res->{$FAIL_NOW_PASSES}}) if (scalar(@{$res->{$FAIL_NOW_PASSES}}));
       printf "  | %-40s | %7d |\n", $NEW_PASSES, scalar(@{$res->{$NEW_PASSES}}) if (scalar(@{$res->{$NEW_PASSES}}));
       printf "  | %-40s | %7d |\n", $UNHANDLED_CASES, scalar(@{$res->{$UNHANDLED_CASES}}) if (scalar(@{$res->{$UNHANDLED_CASES}}));
       printf "  | %-40s | %7d |\n", $UNSTABLE_CASES, scalar(@{$res->{$UNSTABLE_CASES}}) if (scalar(@{$res->{$UNSTABLE_CASES}}));
       printf "  +------------------------------------------+---------+\n";
       printf "  | %-40s | %7d |\n", "TOTAL_MINOR_TO_BE_CHECKED", $total;
       printf "  +------------------------------------------+---------+\n";
       printf "\n";

       if ($long)
       {
	      print_tclist($XFAIL_NOW_PASSES, @{$res->{$XFAIL_NOW_PASSES}});
	      print_tclist($FAIL_NOW_PASSES, @{$res->{$FAIL_NOW_PASSES}});
	      print_tclist($FAIL_DISAPPEARS, @{$res->{$FAIL_DISAPPEARS}});
	      print_tclist($XFAIL_APPEARS, @{$res->{$XFAIL_APPEARS}});
	      print_tclist($UNHANDLED_CASES, @{$res->{$UNHANDLED_CASES}});
	      print_tclist($UNSTABLE_CASES, @{$res->{$UNSTABLE_CASES}});
	      print_tclist($NEW_PASSES, @{$res->{$NEW_PASSES}});
       }
       printf "$col_reset\n";
   }

   $return_value = 1 if ($total);

   $return_value = 2 if ($rtotal);

   # Error if there was no PASS (eg when sth went wrong and no .sum was generated
   $return_value = 2 if (($res->{PASS} + $res->{XPASS}) == 0);

   return $return_value;
}
