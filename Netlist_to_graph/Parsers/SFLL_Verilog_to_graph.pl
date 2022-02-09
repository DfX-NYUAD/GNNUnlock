#! /bin/env perl
########Convert Verilog netlist to adj matrix
require 5.004;
use FindBin;    # New in Perl5.004
use Data::Dumper;
use List::Util qw/shuffle/;
#TODO Change the next line
require "/home/lalrahis/Perl_codes/theCircuit.pm";
use File::Path qw( make_path );
use File::Spec;


#Global Variables
my $assign_count=0;
my $count_file=0;
my $substr="keyinput";
my $substr2="KEY_INPUTS";
my $dump=0;
my $ml_count=0;
my @tr=();
my @va=();
my @te=();
my $one_module=0;
my @functions=();
my %features_map=();
my %module_map=();
my $top_module="";
$module_map{"restore"}=0;
$module_map{"perturb"}=1;
$features_map{"PI"}=0;
$features_map{"PO"}=1;
$features_map{"KEY"}=2;
$features_map{"XOR"}=3;
$features_map{"XNOR"}=4;
$features_map{"AND"}=5;
$features_map{"OR"}=6;
$features_map{"NAND"}=7;
$features_map{"NOR"}=8;
$features_map{"INV"}=9;
$features_map{"BUF"}=10;
$features_map{"ADDF"}=11;
$features_map{"AOI"}=12;
$features_map{"OAI"}=13;
$features_map{"BUFH"}=10;
$features_map{"BUFZ"}=10;
$features_map{"MXIT"}=14;
$features_map{"AO1B"}=15;
$features_map{"AOI2XB"}=16;
$features_map{"AO"}=17;
$features_map{"OA"}=18;
$features_map{"OAI2XB"}=19;
$features_map{"in_degree"}=20;
$features_map{"out_degree"}=21;
$features_map{"TIELO"}=22;
$features_map{"TIEHI"}=23;
$features_map{"RF2R"}=24;
$features_map{"RF1R"}=25;
$features_map{"PREICG"}=26;
$features_map{"POSTICG"}=27;
$features_map{"M"}=28;
$features_map{"A"}=29;
$features_map{"FRICG"}=30;
$features_map{"MXT"}=31;
$features_map{"MX"}=32; 
$features_map{"ADDH"}=33;
my $start_time               = time;

my ($rel_num)                = '$Revision: 1.7 $' =~ /\: ([\w\.\-]+) \$$/;
my ($rel_date) = '$Date: 2021/05/14 20:38:38 $' =~ /\: ([\d\/]+) /;
my $prog_name = $FindBin::Script;

my $hc_version = '0.1';

my $help_msg = <<HELP_MSG;
This program converts circuits locked using SFLL-HD to undirected graphs. It extracts features and labels each gate in the dataset. Usage: perl $prog_name [options] dataset_folder

    Options:	-h | -help		Display this info

		-v | -version		Display version & release date


                -i input_directory      Gate-level netlists in Verilog

    Example:

    UNIX-SHELL> perl $prog_name  -i ../Circuits_datasets/SFLL_DATASET_c5315 > log_file.txt


HELP_MSG

format INFO_MSG =
     @|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
     $prog_name
     @|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
     "Version $rel_num  Released on $rel_date"
     @|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
     'Lilas Alrahis <lma387@nyu.com>'
     @|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
     'NYUAD, Abu Dhabi, UAE'

     @|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
     "\'$prog_name -help\' for help"

.

# Allow operator/bareword style usage of these subroutines.
use subs
  qw(PrintWarning PrintError PrintFatalError PrintInternalError PrintDebug);

my $error            = 0;
my $input_file;
my $input_dir;
my $comment = 0;
while ( $_ = $ARGV[0], /^-/ ) {              # Get command line options
    shift;
    if (/^-h(elp)?$/) { $~ = "INFO_MSG"; write; print $help_msg; exit 0 }
    elsif (/^-v(ersion)?$/) { print "$prog_name $rel_num $rel_date\n"; exit 0 }
    elsif (/^-c(omment)?$/)   { $comment          = 1; }
    elsif (/^-dum(p)?$/)     { $dump       = 1; }
    elsif (/^-i(nput)?$/)     { $input_dir       = shift; }
    elsif (/^-debug$/)        { $debug            = 1 }        # Hidden option
    else                      { PrintError "Unknown option: '$_'!" }
}

if ( !( defined($input_dir) ) ) {
    PrintError "Expect an input Verilog files!";
}



if ( $error > 0 ) {
    warn "\n$help_msg";
    exit 1;
}

select( ( select(STDERR), $~ = "INFO_MSG" )[0] ), write STDERR;

###################################################
#################### Started Here
###################################################

my $status = 0;
my $filename_row = 'row.txt';
my $filename_col = 'col.txt';
my $filename_label = 'label.txt';
my $filename_cell = 'cell.txt';
my $filename_count="count.txt";
open(FH_ROW, '>', $filename_row) or die $!;
open(FH_CELL, '>', $filename_cell) or die $!;
open(FH_LABEL, '>', $filename_label) or die $!;
open(FH_COUNT, '>', $filename_count) or die $!;
open(FH_COL, '>', $filename_col) or die $!;
my $filename_feat = 'feat.txt';
open(FH_FEAT, '>', $filename_feat) or die $!;
open(FH_VA, '>', 'va.txt') or die $!;
open(FH_TE, '>', 'te.txt') or die $!;
open(FH_TR, '>', 'tr.txt') or die $!;

open(FH_COL_TR, '>', 'col_tr.txt') or die $!;
open(FH_ROW_TR, '>', 'row_tr.txt') or die $!;
opendir my $dh, $input_dir or die "Cannot open $input_dir: $!";
my @input_files = sort grep { ! -d } readdir $dh;
closedir $dh;
foreach my $input_file (@input_files) {


next if ($input_file=~m/^\./);
my $trial=0;
if ($input_file=~m/^Valid/)
{
$trial=1;
} 
elsif ($input_file=~m/^Test/)
{
$trial=2;
}
elsif($input_file=~m/^Train/)
{
$trial=3;
}
$count_file++;
my %the_circuit              = ();
my @module_ids=();
my $module_id="";  
my @list_of_gates=();
my %Netlist_Outputs_Hash =();
my %Netlist_Inputs_Hash=();
    my $directives          = "";
    my $module_started      = 0;
    my $modules_count       = 0;
    
    my $cell_name           = "";
   
    my $instance_name       = "";
  
    my @ports               = ();
    my %ports               = ();
    my $multi_line_statment = "";
    my $connect_this_line   = 0;
    my $a                   = "";
    my $line                = "";
  
    my @Netlist_Inputs      = ();
    my @Netlist_Outputs     = ();
    my @Module_Inputs      = ();
    my @Module_Outputs     = ();


    local *INPUT_FH;     # Only way to declare a non-global filehandler.

    open INPUT_FH, "${input_dir}/${input_file}"
      or PrintFatalError "Can't open input file '$input_file': $!!";
   
print "input file is $input_file\n";
 while (<INPUT_FH>) {
        $line = $_;
                if ( $line =~ /^\s*(module)\s+(\w+)\b/ ) {
             $module_id             = $2;
			 $top_module=$module_id;

             
				}
			 elsif ($line =~ /^\s*(endmodule)\b/) {
 print "The outputs of the module are @Module_Outputs\n"  ;    ###############Initializing the circuit with the outputs
 print "The inputs of the module are @Module_Inputs\n" ;    ###############Initializing the circuit with the inputs

   
			 $modules_count++;
@Netlist_Inputs=@Module_Inputs  ;   
@Netlist_Outputs= @Module_Outputs ;  

	   @Module_Inputs      = ();
       @Module_Outputs     = ();
			 
			 }
        elsif ( $line =~ /^\s*(input)\s+.*/ ) {    #############check inputs


            if ( $line =~ /^.*?\;\s*$/ ) {
                $line =~ s/input\s+//;             #remove the input word
                $line =~ tr/;//d;               #remove semicolomn
                for ($line) {
                    s/^\s+//;

                }

                $line =~ s/\R//g;
                my @found_inputs = split( /,/, $line ); #it was \s+
                push @Module_Inputs, @found_inputs;
                next;    # port is defined on single line so exit
            }
            else {       #port is defined on more than one line
                until ( $line =~ /^.*?\;\s*$/ ) {



                  $line =~ s/input\s+//g;     #remove the input word
                    $line =~ tr/;//d;       #remove semicolomn

                    for ($line) {
                        s/^\s+//;

                    }

                    $line =~
                      s/\R//g;   #remove new lines and replace with white spcaes
                    my @found_inputs = split( /,/, $line );
                    push @Module_Inputs, @found_inputs;
                    $line = <INPUT_FH>;

                }                       #End of multiline detection
                $line =~ s/input\s+//g;     #remove the input word
                $line =~ tr/;//d;       #remove semicolomn

                for ($line) {
                    s/^\s+//;
                }

                $line =~
                  s/\R//g;    #remove new lines and replace with white spcaes
                my @found_inputs = split( /,/, $line );
                push @Module_Inputs, @found_inputs;

                next;
            }
        }    #### end of input detection

        if ( $line =~ /^\s*(output)\s+.*/ ) {    #############check outputs


            if ( $line =~ /^.*?\;\s*$/ ) {
                $line =~ s/output//;             #remove the output word
                $line =~ tr/;//d;                #remove semicolomn

                for ($line) {
                    s/^\s+//;
                }

                $line =~ s/\R//g;                #remove new lines
                my @found_outputs = split( /,/, $line );   ### take one by one
                push @Module_Outputs,   @found_outputs;
                next;    # port is defined on single line so exit
            }
            else {       #port is defined on more than one line
                until ( $line =~ /^.*?\;\s*$/ ) {



                    $line =~ s/output//g;    #remove the input word
                    $line =~ tr/;//d;        #remove semicolomn

                    for ($line) {
                        s/^\s+//;

                    }

                    $line =~
                      s/\R//g;   #remove new lines and replace with white spcaes
                    my @found_outputs = split( /,/, $line );
                    push @Module_Outputs,   @found_outputs;
                    $line = <INPUT_FH>;

                }                        #End of multiline detection
                $line =~ s/output//g;    #remove the output word
                $line =~ tr/;//d;        #remove semicolomn

                for ($line) {
                    s/^\s+//;
                }

                $line =~
                  s/\R//g;    #remove new lines and replace with white spcaes
                my @found_outputs = split( /,/, $line );
                push @Module_Outputs,   @found_outputs;

                next;
            }
        } 

        
    }
$one_module=1;
    close INPUT_FH;
my @tempp=();
foreach my $inn (@Netlist_Inputs){
$inn=~ s/^\s+|\s+$//g; 

if ($inn=~m/\s*\[(\d+)\:(\d+)\]\s+(\S+)/){
my $start=$1;
my $end=$2;
my $name=$3;

my $i=$start;
if ($start>$end){
$i=$end;
$end=$start;
print "start is now $i and end is now $end\n";
}
while ($i<=$end)
{
push @tempp, "$name\[$i\]";
$i++;
}

}
else{
push @tempp, $inn;
}
}
 @Netlist_Inputs=@tempp;
  @tempp=();
foreach my $inn (@Netlist_Outputs){
$inn=~ s/^\s+|\s+$//g; 

if ($inn=~m/\s*\[(\d+)\:(\d+)\]\s+(\S+)/){
my $start=$1;
my $end=$2;
my $name=$3;

my $i=$start;

if ($start>$end){
$i=$end;
$end=$start;

}
while ($i<=$end)
{
push @tempp, "$name\[$i\]";
$i++;
}

}
else{
push @tempp, $inn;
}
}
 @Netlist_Outputs=@tempp;
 

 print "The outputs of the netlist are @Netlist_Outputs\n"  ;    ###############Initializing the circuit with the outputs
 print "The inputs of the netlist are @Netlist_Inputs\n" ;    ###############Initializing the circuit with the inputs
my %wire_params=();
   
    %Netlist_Outputs_Hash = map { $_ => 1 } @Netlist_Outputs;
     %Netlist_Inputs_Hash  = map { $_ => 1 } @Netlist_Inputs;
    #######################open file again to initialize the circuit
    
	my @Module_Wires=();
	open INPUT_FH, "${input_dir}/${input_file}"
      or PrintFatalError "Can't open input file '$input_file': $!!";
    while (<INPUT_FH>) {
        @ports = ();
        %ports = ();
        $line  = $_;

	if ( $line =~ /^\s*(wire)\s+.*/ ) {    #############check wires


            if ( $line =~ /^.*?\;\s*$/ ) {
                $line =~ s/wire\s+//;             #remove the wire word
                $line =~ tr/;//d;               #remove semicolomn
                for ($line) {
                    s/^\s+//;


                }
                $line =~ tr/,//d;               #remove coma
                $line =~ s/\R//g;
                my @found_wires = split( /\s+/, $line ); #it was \s+
                push @Module_Wires, @found_wires;
#				print "Those are the module wires @Module_Wires\n";
%wire_params = map { $_ => 1 } @Module_Wires;
                next;    # port is defined on single line so exit
            }
            else {       #port is defined on more than one line
                until ( $line =~ /^.*?\;\s*$/ ) {


                  $line =~ s/wire\s+//g;     #remove the wire word
                    $line =~ tr/;//d;       #remove semicolomn

                    for ($line) {
                        s/^\s+//;

                    }
                    $line =~ tr/,//d;       #remove coma
                    $line =~
                      s/\R//g;   #remove new lines and replace with white spcaes
                    my @found_wires = split( /\s+/, $line );
                    push @Module_Wires, @found_wires;
                    $line = <INPUT_FH>;

                }                       #End of multiline detection
                $line =~ s/wire\s+//g;     #remove the wire word
                $line =~ tr/;//d;       #remove semicolomn

                for ($line) {
                    s/^\s+//;
                }
               $line =~ tr/,//d;       #remove coma
                $line =~
                  s/\R//g;    #remove new lines and replace with white spcaes
                my @found_wires = split( /\s+/, $line );
                push @Module_Wires, @found_wires;
%wire_params = map { $_ => 1 } @Module_Wires;
                next;
            }


        }    #### end of wire detection

if ($line=~m/^\s*assign\s+(\S*)\s+=\s+(\S*)\;/){
my $out=$1;
my $in=$2;

my $modified_name="assign_${assign_count}";

push @list_of_gates, $modified_name;
my $current_object;
my @current_gate_inputs=();
push @current_gate_inputs, $in;
my @current_gate_outputs=();
push @current_gate_outputs, $out;
					if ($trial==3 ){
						  push @tr, $ml_count;
						  print FH_TR "$ml_count\n";
						  }
						  elsif ($trial==1){
						  push @va, $ml_count;
						  print FH_VA "$ml_count\n";
						  }
						  else {
						  push @te, $ml_count;
						  print FH_TE "$ml_count\n";  
						  }	
                    $current_object = theCircuit->new(
                        {	
                            name          => $modified_name, #$instance_name,
                            bool_func     => "BUF",
                            inputs        => \@current_gate_inputs,
                            outputs        => \@current_gate_outputs,
                            fwdgates => [undef],
			    processed => $module_id,
                            fwdgates_inst => [undef],
                            count =>$ml_count,
                        }
                    );
			my $indicator=0;
	 	foreach my $current_gate_output (@current_gate_outputs){
                    if ( exists( $Netlist_Outputs_Hash{$current_gate_output} ) )
                    { 
					my @temp=();
					my @temp_inst=();
					if ($indicator==0){
					
                    push @temp, "PO";
                    
                    push @temp_inst, $current_gate_output;
					}
					else{
					@temp=$current_object->get_fwdgates();
					@temp_inst=$current_object->get_fwdgates_inst();
					push @temp, "PO";
                    
                    push @temp_inst, $current_gate_output;
					}
					$indicator++;
					
					
                      $current_object->set_fwdgates(\@temp);
                      $current_object->set_fwdgates_inst(\@temp_inst);
                    }
					}
                                    $the_circuit{$modified_name} = $current_object;
$ml_count++;
$assign_count++;
}
elsif ($line  =~ m/

	^\s*
	(\S*)  # Cell name
	\s+
	(\S*)  #Instance Name
	\s*
	\(
	.+   #ports list
	$/x
       ){
	
      if ( $line =~ /\;/ )
	{
	  
	} else {
	  until ( $line =~ /\;\s*$/ )
	    {
	  
$line =~ s/^\s+|\s+$//g;
    chomp($line);
	      $multi_line_statment .= $line;
	      $line = <INPUT_FH>;
	    }

	  $line =~ s/^\s+//g;
	  $line = $multi_line_statment.$line;
	  $multi_line_statment = "";
	  
	}

    }
    if ( $line =~ /^\s*(module)\s+(\w+)\b/ ) {
             $module_id             = $2;
			 
			 
             }
		
	elsif ($line =~ /^\s*(endmodule)\b/) {
	print "end of module with count $ml_count\n";
			 @Module_Wires=();
			 %wire_params=();
			 }
    if (!($line =~m/module/)){
    if ($line =~ m/
	^\s*
	(\S*)  # Cell name
	\s+
	(\S*)  #Instance Name
	\s*
	\(
	(.+)   #ports list
	\)
	\s*
	\;
	\s*
	$
	/x
       ) {
      $cell_name = $1;
      $instance_name = $2;

      @ports = split/,/, $3;

                foreach $a (@ports) {
                    $a =~ /\s*\.([A-Za-z0-9]*?)\(\s*(\S*)\s*\)/;
                    $ports{$1} = $2;
                }
                my $hash_ref = \%ports;

           
				
               my $current_object;
my @current_gate_inputs=();
if ( defined( $$hash_ref{"A"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"A"};

                    }

  if ( defined( $$hash_ref{"D"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"D"};

                    }
                                     if ( defined( $$hash_ref{"B"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"B"};

                    }
  if ( defined( $$hash_ref{"A1N"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"A1N"};

                    }

  if ( defined( $$hash_ref{"B0N"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"B0N"};

                    }
                                     if ( defined( $$hash_ref{"B1N"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"B1N"};

                    }
  if ( defined( $$hash_ref{"A0N"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"A0N"};

                    }

  if ( defined( $$hash_ref{"E"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"E"};

                    }
                                     if ( defined( $$hash_ref{"F"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"F"};

                    }


  if ( defined( $$hash_ref{"S0"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"S0"};

                    }

  if ( defined( $$hash_ref{"S1"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"S1"};

                    }
                            
 if ( defined( $$hash_ref{"BN"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"BN"};

                    }
 if ( defined( $$hash_ref{"AN"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"AN"};

                    }
 if ( defined( $$hash_ref{"DN"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"DN"};

                    }
 if ( defined( $$hash_ref{"C"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"C"};

                    }
 if ( defined( $$hash_ref{"C1"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"C1"};

                    }
                    
                    if ( defined( $$hash_ref{"C2"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"C2"};

                    }
 if ( defined( $$hash_ref{"CI"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"CI"};

                    }
                    
                    if ( defined( $$hash_ref{"B2"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"B2"};

                    }
 if ( defined( $$hash_ref{"B1"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"B1"};

                    }
                    
 if ( defined( $$hash_ref{"B0"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"B0"};

                    }

 if ( defined( $$hash_ref{"B0N"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"B0N"};

                    }

 if ( defined( $$hash_ref{"C0"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"C0"};

                    }
                    if ( defined( $$hash_ref{"A"} ) &&  defined( $$hash_ref{"B"} )&& defined( $$hash_ref{"S"} ) && defined( $$hash_ref{"Z"} )){
                        push @current_gate_inputs, $$hash_ref{"S"};

                    }

 if ( defined( $$hash_ref{"A3"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"A3"};

                    }
                    
 if ( defined( $$hash_ref{"A0"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"A0"};

                    }
                    if ( defined( $$hash_ref{"A4"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"A4"};

                    }

 if ( defined( $$hash_ref{"A1"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"A1"};

                    }
                    
                    if ( defined( $$hash_ref{"A2"} ) ) {
                        push @current_gate_inputs, $$hash_ref{"A2"};

                    }
my @current_gate_outputs=();
   
                 
                    
if (   defined($$hash_ref{"D"}) && defined($$hash_ref{"Q"})  ){

push @current_gate_outputs , $$hash_ref{"Q"};

}

elsif (   defined($$hash_ref{"CO"}) && defined($$hash_ref{"S"})  ){


push @current_gate_outputs,$$hash_ref{"S"};
push @current_gate_outputs, $$hash_ref{"CO"};
}
elsif(defined($$hash_ref{"CO"})){

push @current_gate_outputs , $$hash_ref{"CO"};


}
elsif (defined($$hash_ref{"D"}) && !(defined($$hash_ref{"Q"})) && !(defined($$hash_ref{"Y"}))){
if (defined($$hash_ref{"QN"})){
push @current_gate_outputs , $$hash_ref{"QN"};
}
}
		    elsif (defined $$hash_ref{"Y"}){
 push @current_gate_outputs , $$hash_ref{"Y"};

                   }



                    elsif (defined $$hash_ref{"ZN"}){
                    push @current_gate_outputs , $$hash_ref{"ZN"};
                    }
                    elsif (defined $$hash_ref{"Z"}){
                    push @current_gate_outputs , $$hash_ref{"Z"};
                    }
					my $bool_fun=$cell_name;
					$bool_fun=~s/\_\S+//g;
					$bool_fun=~s/\d+\D*$//g;
					push @functions, $bool_fun;
					@functions=uniq(@functions);
					my @updates=();

					my $modified_name="${instance_name}";
						  push @list_of_gates, $modified_name;
						 if ($trial==3 ){
						  push @tr, $ml_count;
						  print FH_TR "$ml_count\n";
						  }
						  elsif ($trial==1){
						  push @va, $ml_count;
						  print FH_VA "$ml_count\n";
						  }
						  else {
						  push @te, $ml_count;
						  print FH_TE "$ml_count\n";  
						  }
						  if ($modified_name=~m/perturb/){$module_id="perturb";}
						  elsif ($modified_name=~m/restore/){$module_id="restore";}
else{$module_id=$top_module;}
print "This is obtained module_id $module_id\n";
                    $current_object = theCircuit->new(
                        {	
                            name          => $modified_name, #$instance_name,
                            bool_func     => $bool_fun,
                            inputs        => \@current_gate_inputs,
                            outputs        => \@current_gate_outputs,
                            fwdgates => [undef],
							processed => $module_id,
                            fwdgates_inst => [undef],
                            count =>$ml_count,
                        }
                    );
					my $indicator=0;
					foreach my $current_gate_output (@current_gate_outputs){
                    if ( exists( $Netlist_Outputs_Hash{$current_gate_output} ) )
                    { 
					my @temp=();
					my @temp_inst=();
					if ($indicator==0){
					
                    push @temp, "PO";
                    
                    push @temp_inst, $current_gate_output;
					}
					else{
					@temp=$current_object->get_fwdgates();
					@temp_inst=$current_object->get_fwdgates_inst();
					push @temp, "PO";
                    
                    push @temp_inst, $current_gate_output;
					}
					$indicator++;
					
					
                      $current_object->set_fwdgates(\@temp);
                      $current_object->set_fwdgates_inst(\@temp_inst);
                    }
					}
                                    $the_circuit{$modified_name} = $current_object;
		if ($ml_count==50673){
print "cell name is $modified_name and file is $input_file \n"
}
                $ml_count++;
               
                    
             }       
                

}
      }


        #######end of opening file again
    close INPUT_FH;
    ############################

 
foreach my $object ( values %the_circuit ) {  ##### loop through the gates
my $name="";
$name= $object->get_name();

my @current_inputss=$object->get_inputs();


my $limit=0;
$limit=@current_inputss;
my @current_inputs=();
my @current_gate_inputs=();
my @current_gate_inputs_inst=();
my $outer_gate_type=$object->get_bool_func();

for my $i_index (0 .. $#current_inputss)
{
my $in=   $current_inputss[$i_index];

if ( exists( $Netlist_Inputs_Hash{$in} ) )
 {	
  if (index($in, $substr) != -1)
 {
 push @current_gate_inputs, "KI";
 push @current_gate_inputs_inst,$in;
 $limit--;
 }
   elsif (index($in, $substr2) != -1)
 {
 push @current_gate_inputs, "KI";
 push @current_gate_inputs_inst,$in;
 $limit--;
 }
 else{
 push @current_gate_inputs, "PI";
 push @current_gate_inputs_inst,$in;
 $limit--;
	 
 }
	
	
}#end if it is a PI
else{
	
push @current_inputs, $in;	
}#end if it is not a PI
}# end of looping through the inputs


 if ($limit!=0){ #if my input array is not empty
OUTER: 
##I wanna loop through all the gates, and check if any gate's output is actually one of the inputs
foreach my $instance (@list_of_gates)
  {
		   my $current_objectt ="";
		   my @current_outputs=();
	
                   $current_objectt = $the_circuit{$instance};
	  @current_outputs= $current_objectt->get_outputs();
		   my $current_gate_type="";
		   
               
                   
                   $current_gate_type=$current_objectt->get_bool_func();

		   foreach my $current_output (@current_outputs){
		                      foreach my $input (@current_inputs)
                   {

                   if ($input eq $current_output)
                   { 
                   push @current_gate_inputs, $current_gate_type;
                   push @current_gate_inputs_inst, $instance;
                   my @temp=();
                   my @temp_inst=();
                    if ($current_objectt->get_fwdgates()){
                   @temp=$current_objectt->get_fwdgates();
                   @temp_inst=$current_objectt->get_fwdgates_inst();
                   }
                   push @temp, $outer_gate_type;
                   push @temp_inst, $name;
                   @temp = grep defined, @temp;
                   @temp_inst = grep defined, @temp_inst;
                    $current_objectt->set_fwdgates(\@temp);
                    $current_objectt->set_fwdgates_inst(\@temp_inst);
     
                       $the_circuit{ $instance } = $current_objectt;
                   }#the input is a primary output of a gate
                   
                   }
}
}
}#end if my input array is not empty
$object->set_fedbygates(\@current_gate_inputs);

$object->set_fedbygates_inst(\@current_gate_inputs_inst);
  $the_circuit{ $name } = $object;
  
}#end of the outer loop through the gates
my @data=();
print Dumper ( \%the_circuit );
	
my %params_tr = map { $_ => 1 } @tr;
foreach my $object ( values %the_circuit ) {  ##### loop through the gates

my @OUts=$object->get_fwdgates();

my @features_array=(0) x 34;
my $label="";
my $module_name=$object->get_processed();
print "This is module name $module_name\n";
if(exists($module_map{$module_name})){
$label=$module_map{$module_name};
}
elsif ($module_name=~m/restor/){
$label=0;
}
elsif ($module_name=~m/perturb/){
$label=1;
}
else {

	$label=2; #it is a design node
}
print "This is the label $label\n";
my $prev=$features_array[$features_map{$object->get_bool_func()}];
$features_array[$features_map{$object->get_bool_func()}]=($prev+1);

my @INputs=$object->get_fedbygates();
print "The inputs are @INputs\n";
my @current_fed_gates=();
@current_fed_gates=$object->get_fedbygates_inst();
foreach my $elem (@current_fed_gates){
   if (exists ($the_circuit{$elem}))  {
my $current_ob=$the_circuit{$elem};
my $inputt=$current_ob->get_bool_func();
if(exists($features_map{$inputt})){
my $prev=$features_array[$features_map{$inputt}];
$features_array[$features_map{$inputt}]=($prev+1);
}
my @INNputs=$current_ob->get_fedbygates();
foreach my $inputtt (@INNputs){
if(exists($features_map{$inputtt})){
if ($inputtt ne "PI" && $inputtt ne "PO" && $inputtt ne "KI"){
my $prev=$features_array[$features_map{$inputtt}];
$features_array[$features_map{$inputtt}]=($prev+1);	
}}
}
}
else{
#Do nothing
}

}
my $in_degree=@INputs;

my $nameo=$object->get_name();
if ($in_degree==0){
print "In degree is 0 for $nameo\n";

}
$features_array[$features_map{"in_degree"}]=$in_degree;
my %params = map { $_ => 1 } @INputs;
if(exists($params{"PI"})) { 
my $prev=0;
$features_array[$features_map{"PI"}]=($prev+1);


 }
if(exists($params{"KI"})) {
	my $prev=0;
$features_array[$features_map{"KEY"}]=($prev+1); 
print "This gate is connected to KI $nameo\n";
print "@features_array\n";
}
my $name="";
$name= $object->get_name();
my $count=$object->get_count();
my @current_fwd_gates=();
@current_fwd_gates=$object->get_fwdgates_inst();
my $out_degree=@current_fwd_gates;
$features_array[$features_map{"out_degree"}]=$out_degree;
foreach my $elem (@current_fwd_gates){
if (exists ($the_circuit{$elem}))  {
my $current_ob=$the_circuit{$elem};
my $current_count=$current_ob->get_count();
my $inputt=$current_ob->get_bool_func();
if(exists($features_map{$inputt})){
my $prev=$features_array[$features_map{$inputt}];
$features_array[$features_map{$inputt}]=($prev+1);
}
my @INNputs=$current_ob->get_fwdgates();
foreach my $inputtt (@INNputs){


if(exists($features_map{$inputtt})){
if ($inputtt ne "PI" && $inputtt ne "PO" && $inputtt ne "KI"){
my $prev=$features_array[$features_map{$inputtt}];
$features_array[$features_map{$inputtt}]=($prev+1);
	
}}

}
print FH_ROW "$count\n";
print FH_COL "$current_count\n";
print FH_COL "$count\n"; 
print FH_ROW "$current_count\n";
if(exists($params_tr{$count})) { 
if(exists($params_tr{$current_count})) {
print FH_ROW_TR "$count\n";
print FH_COL_TR "$current_count\n";
print FH_ROW_TR "$current_count\n";
print FH_COL_TR "$count\n";
}
}
}
}
%params=();
print "These are outs @OUts\n";
%params = map { $_ => 1 } @OUts;
my $check_flag=0;
if(exists($params{"PO"})) {
my $prev=0;
$features_array[$features_map{"PO"}]=($prev+1);
print "@features_array\n";

my $current_count=$object->get_count();
print FH_ROW "$count\n";
print FH_COL "$count\n";
if(exists($params_tr{$count})) { 
print FH_ROW_TR "$count\n";
print FH_COL_TR "$count\n";
}

}
print FH_CELL "$count $name from file $input_file\n";
print FH_COUNT "$count\n";
print FH_LABEL "$label\n";
my $size=@features_array;
print FH_FEAT "@features_array\n";
}


}
close(FH_ROW);
close(FH_FEAT);
close(FH_CELL);
close(FH_COUNT);
close(FH_LABEL);
close(FH_COL);
close(FH_COL_TR);
close(FH_ROW_TR);
close(FH_VA);
close(FH_TE);
close(FH_TR);
print "Those are the functions @functions\n";
my $run_time = time - $start_time;
print STDERR "\nProgram completed in $run_time sec ";

if ($error) {
    print STDERR "with total $error errors.\n\n" and $status = 1;
}
else {
    print STDERR "without error.\n\n";
}

exit $status;

sub PrintWarning {
    warn "WARNING: @_\a\n";
}

sub PrintError {
    ++$error;
    warn "ERROR: @_\a\n";
}

sub PrintFatalError {
    ++$error;
    die "FATAL ERROR: @_\a\n";
}

sub PrintInternalError {
    ++$error;
    die "INTERNAL ERROR: ", (caller)[2], ": @_\a\n";
}
sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}
sub PrintDebug {
    my $orig_list_separator = $";
    $" =
      ',';   
    warn "DEBUG: ", (caller)[2], ": @_\n" if ($debug);
    $" = $orig_list_separator;    # Dummy " for perl-mode in Emacs
}



__END__

