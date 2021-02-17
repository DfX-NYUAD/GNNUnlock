#! /bin/env perl
require 5.004;
use FindBin;
use Data::Dumper;
use List::Util qw/shuffle/;
require "/Users/guest1/Desktop/GNNUnlock_Master/Netlist_to_graph/Parsers/theCircuit.pm";
use File::Path qw( make_path );
use File::Spec;

#Global Variables
my $assign_count = 0;
my $count_file   = 0;
my $substr       = "keyinput";
my $substr2      = "KEYINPUT";
my $dump         = 0;
my $ml_count     = 0;
my @tr           = ();
my @va           = ();
my @te           = ();
my @functions    = ();
my %features_map = ();
my %module_map   = ();
$module_map{"antisat"} = 0;
$module_map{"design"}  = 1;
my @modules = ();
$features_map{"PI"}         = 0;
$features_map{"PO"}         = 1;
$features_map{"KEY"}        = 2;
$features_map{"xor"}        = 3;
$features_map{"XOR"}        = 3;
$features_map{"xnor"}       = 4;
$features_map{"XNOR"}       = 4;
$features_map{"and"}        = 5;
$features_map{"AND"}        = 5;
$features_map{"or"}         = 6;
$features_map{"OR"}         = 6;
$features_map{"nand"}       = 7;
$features_map{"NAND"}       = 7;
$features_map{"nor"}        = 8;
$features_map{"NOR"}        = 8;
$features_map{"not"}        = 9;
$features_map{"NOT"}        = 9;
$features_map{"buf"}        = 10;
$features_map{"BUF"}        = 10;
$features_map{"in_degree"}  = 11;
$features_map{"out_degree"} = 12;

my $start_time = time;
my ($rel_num)  = '$Revision: 1.7 $' =~ /\: ([\w\.\-]+) \$$/;
my ($rel_date) = '$Date: 2021/02/09 20:38:38 $' =~ /\: ([\d\/]+) /;
my $prog_name  = $FindBin::Script;

my $hc_version = '0.1';

my $help_msg = <<HELP_MSG;
This program converts circuits locked using Anti-SAT to undirected graphs. It extracts features and labels each gate in the dataset. 
Usage: perl $prog_name [options] dataset_folder 

    Options:	-h | -help		Display this info

		-v | -version		Display version & release date


                -i input_directory      Circuits in bench format locked using Anti-SAT 

    Example:

    UNIX-SHELL> perl $prog_name -i ../Circuits_datasets/ANTI_SAT_DATASET_c7552  > log_file.txt


HELP_MSG

format INFO_MSG =
     @|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
     $prog_name
     @|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
     "Version $rel_num  Released on $rel_date"
     @|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
     'Lilas Alrahis <lilasrahis@gmail.com>'
     @|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
     'Khalifa University/NYU, Abu Dhabi, UAE'

     @|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
     "\'perl $prog_name -help\' for help"

.

# Allow operator/bareword style usage of these subroutines.
use subs
  qw(PrintWarning PrintError PrintFatalError PrintInternalError PrintDebug);

my $error = 0;
my $input_file;
my $input_dir;
my $comment = 0;
while ( $_ = $ARGV[0], /^-/ ) {    # Get command line options
    shift;
    if (/^-h(elp)?$/) { $~ = "INFO_MSG"; write; print $help_msg; exit 0 }
    elsif (/^-v(ersion)?$/) { print "$prog_name $rel_num $rel_date\n"; exit 0 }
    elsif (/^-dum(p)?$/)  { $dump      = 1; }
    elsif (/^-i(nput)?$/) { $input_dir = shift; }
    elsif (/^-debug$/)    { $debug     = 1 }        # Hidden option
    else                  { PrintError "Unknown option: '$_'!" }
}

if ( !( defined($input_dir) ) ) {
    PrintError "Expecting an input directory with locked files!";
}

if ( $error > 0 ) {
    warn "\n$help_msg";
    exit 1;
}

select( ( select(STDERR), $~ = "INFO_MSG" )[0] ), write STDERR;

###################################################
#################### Started Here
###################################################

my $status         = 0;
my $filename_row   = 'row.txt';
my $filename_col   = 'col.txt';
my $filename_label = 'label.txt';
my $filename_cell  = 'cell.txt';
my $filename_count = "count.txt";
my $filename_feat  = 'feat.txt';
open( FH_ROW,    '>', $filename_row )   or die $!;
open( FH_CELL,   '>', $filename_cell )  or die $!;
open( FH_LABEL,  '>', $filename_label ) or die $!;
open( FH_COUNT,  '>', $filename_count ) or die $!;
open( FH_COL,    '>', $filename_col )   or die $!;
open( FH_FEAT,   '>', $filename_feat )  or die $!;
open( FH_VA,     '>', 'va.txt' )        or die $!;
open( FH_TE,     '>', 'te.txt' )        or die $!;
open( FH_TR,     '>', 'tr.txt' )        or die $!;
open( FH_COL_TR, '>', 'col_tr.txt' )    or die $!;
open( FH_ROW_TR, '>', 'row_tr.txt' )    or die $!;

#Get the list of locked files
opendir my $dh, $input_dir or die "Cannot open $input_dir: $!";
my @input_files = sort grep { !-d } readdir $dh;
closedir $dh;
foreach my $input_file (@input_files) {
    next if ( $input_file =~ m/^\./ );

    #Seperate the files to Train/Valid/Test
    #This wil depend on the name of the file.
    my $split_dataset = 0;
    if ( $input_file =~ m/^Valid/ ) {
        $split_dataset = 1;
    }
    elsif ( $input_file =~ m/^Test/ ) {
        $split_dataset = 2;
    }
    elsif ( $input_file =~ m/^Train/ ) {
        $split_dataset = 3;
    }
    $count_file++;
    my %the_circuit = ();
    my $module_id   = "design"; # Default class for nodes. Will be later updated
    my @list_of_gates        = ();
    my %Netlist_Outputs_Hash = ();
    my %Netlist_Inputs_Hash  = ();
    my @ports                = ();
    my %ports                = ();
    my $multi_line_statment  = "";
    my $line                 = "";
    my @Netlist_Inputs       = ();
    my @Netlist_Outputs      = ();
    my @Module_Inputs        = ();
    my @Module_Outputs       = ();
    local *INPUT_FH;           

    open INPUT_FH, "${input_dir}/${input_file}"
      or PrintFatalError "Can't open input file '$input_file': $!!";

    #Open the locked file
    while (<INPUT_FH>) {
        $line = $_;

        if ( $line =~ /^\s*INPUT\((\w*)\)\s?$/ ) {    ####check inputs
            my $found_inputs = $1;
            push @Module_Inputs, $found_inputs;
        }

        elsif ( $line =~ /^\s*OUTPUT\((\w*)\)\s?$/ ) {    ####check outputs
            my $found_outputs = $1;
            push @Module_Outputs, $found_outputs;

        }
        elsif ( $line =~ /^\s*(\w+)\s*\=\s*(\w+)\(\s*(\w+)\s*\)/ ) {
            my $out  = $1;
            my $func = $2;
            my $in   = $3;
            @Netlist_Inputs       = @Module_Inputs;
            @Netlist_Outputs      = @Module_Outputs;
            %Netlist_Outputs_Hash = map { $_ => 1 } @Netlist_Outputs;
            %Netlist_Inputs_Hash  = map { $_ => 1 } @Netlist_Inputs;

            my $modified_name = "assign_${assign_count}_${out}_${input_file}";
            my $current_object;
            push @list_of_gates, $modified_name;
            my @current_gate_inputs = ();
            push @current_gate_inputs, $in;
            my @current_gate_outputs = ();
            push @current_gate_outputs, $out;
            my $node_class = $module_id;

#To get the true labels of nodes, Anti-SAT nodes must be specified in the locked file
#This is just used to Train and then to evaluate the peformance of GNNUnlock.
#An ANTI-SAT gate will have any of the following in its name
# *ANTISAT* | *antisat* | *in\d+xor*
            if ( $out =~ /in\d+xor|DTL|INTER|inter/ ) {
                $node_class = "antisat";

            }
            elsif ( $out =~ /ANTISAT|antisat/ ) {
                $node_class = "antisat";

            }
            elsif ( $in =~ /KEYINPUT|keyinput/ ) {

                $node_class = "antisat";

            }
            if ( $split_dataset == 3 ) {
                push @tr, $ml_count;
                print FH_TR "$ml_count\n";
            }
            elsif ( $split_dataset == 1 ) {
                push @va, $ml_count;
                print FH_VA "$ml_count\n";
            }
            else {
                push @te, $ml_count;
                print FH_TE "$ml_count\n";
            }
            $current_object = theCircuit->new(
                {
                    name          => $modified_name,
                    bool_func     => $func,
                    inputs        => \@current_gate_inputs,
                    outputs       => \@current_gate_outputs,
                    fwdgates      => [undef],
                    processed     => $node_class,
                    fwdgates_inst => [undef],
                    count         => $ml_count,
                }
            );
            my $indicator = 0;
            foreach my $current_gate_output (@current_gate_outputs) {

                my @temp      = ();
                my @temp_inst = ();
                if ( exists( $Netlist_Outputs_Hash{$current_gate_output} ) ) {
                    if ( $indicator == 0 ) {

                        push @temp, "PO";

                        push @temp_inst, $current_gate_output;
                    }
                    else {
                        @temp      = $current_object->get_fwdgates();
                        @temp_inst = $current_object->get_fwdgates_inst();
                        push @temp, "PO";

                        push @temp_inst, $current_gate_output;
                    }
                    $indicator++;

                    $current_object->set_fwdgates( \@temp );
                    $current_object->set_fwdgates_inst( \@temp_inst );
                    $the_circuit{$modified_name} = $current_object;
                }
            }
            $the_circuit{$modified_name} = $current_object;
            $ml_count++;
            $assign_count++;
        }

        elsif ( $line =~ /^\s*(\w+)\s*\=\s*(\w+)\((.+)\)/ ) {
            my $out  = $1;
            my $func = $2;
            my $ins  = $3;

            my @current_gate_inputs = ();
            my @inss = split( /,/, $ins );

            my $node_class = $module_id;
            foreach my $in (@inss) {
                $in =~ s/^\s+|\s+$//g;
                chomp($in);

                push @current_gate_inputs, $in;

                if ( $in =~ /KEYINPUT|keyinput/ ) {

                    $node_class = "antisat";

                }
            }

            my $modified_name = "assign_${assign_count}_${out}_${input_file}";
            push @list_of_gates, $modified_name;
            my $current_object;
            my @current_gate_outputs = ();
            push @current_gate_outputs, $out;
            if ( $out =~ /in\d+xor|DTL|INTER|inter/ ) {
                $node_class = "antisat";

            }
            elsif ( $out =~ /ANTISAT|antisat/ ) {
                $node_class = "antisat";

            }
            if ( $split_dataset == 3 ) {
                push @tr, $ml_count;
                print FH_TR "$ml_count\n";
            }
            elsif ( $split_dataset == 1 ) {
                push @va, $ml_count;
                print FH_VA "$ml_count\n";
            }
            else {
                push @te, $ml_count;
                print FH_TE "$ml_count\n";
            }
            $current_object = theCircuit->new(
                {
                    name          => $modified_name,
                    bool_func     => $func,
                    inputs        => \@current_gate_inputs,
                    outputs       => \@current_gate_outputs,
                    fwdgates      => [undef],
                    processed     => $node_class,
                    fwdgates_inst => [undef],
                    count         => $ml_count,
                }
            );
            my $indicator = 0;

            #Identify if any of the outputs is a PO
            foreach my $current_gate_output (@current_gate_outputs) {

                my @temp      = ();
                my @temp_inst = ();
                if ( exists( $Netlist_Outputs_Hash{$current_gate_output} ) ) {
                    if ( $indicator == 0 ) {

                        push @temp, "PO";

                        push @temp_inst, $current_gate_output;
                    }
                    else {
                        @temp      = $current_object->get_fwdgates();
                        @temp_inst = $current_object->get_fwdgates_inst();
                        push @temp, "PO";

                        push @temp_inst, $current_gate_output;
                    }
                    $indicator++;

                    $current_object->set_fwdgates( \@temp );
                    $current_object->set_fwdgates_inst( \@temp_inst );
                    $the_circuit{$modified_name} = $current_object;
                }
            }
            $the_circuit{$modified_name} = $current_object;
            $ml_count++;
            $assign_count++;
        }
        else {
            #Next
        }
    }

    #######end of parsing
    close INPUT_FH;
    ############################

    foreach my $object ( values %the_circuit ) {    ##### loop through the gates
        my $name = "";
        $name = $object->get_name();
        my @current_inputss = $object->get_inputs();

        my $limit = 0;
        $limit = @current_inputss;
        my @current_inputs           = ();
        my @current_gate_inputs      = ();
        my @current_gate_inputs_inst = ();
        my $outer_gate_type          = $object->get_bool_func();

        for my $i_index ( 0 .. $#current_inputss ) {
            my $in = $current_inputss[$i_index];

            if ( exists( $Netlist_Inputs_Hash{$in} ) ) {
                if ( index( $in, $substr ) != -1 ) {
                    push @current_gate_inputs,      "KI";
                    push @current_gate_inputs_inst, $in;
                    $limit--;
                }
                elsif ( index( $in, $substr2 ) != -1 ) {
                    push @current_gate_inputs,      "KI";
                    push @current_gate_inputs_inst, $in;
                    $limit--;
                }
                else {
                    push @current_gate_inputs,      "PI";
                    push @current_gate_inputs_inst, $in;
                    $limit--;

                }

            }    #end if it is a PI
            else {
                push @current_inputs, $in;
            }    #end if it is not a PI
        }    # end of looping through the inputs

        if ( $limit != 0 ) {    #if my input array is not empty
          OUTER:
##Loop through all the gates, and check if any gate's output is one of the inputs
            foreach my $instance (@list_of_gates) {
                my $current_objectt = "";
                my @current_outputs = ();

                $current_objectt = $the_circuit{$instance};
                @current_outputs = $current_objectt->get_outputs();
                my $current_gate_type = "";
                $current_gate_type = $current_objectt->get_bool_func();

                foreach my $current_output (@current_outputs) {
                    foreach my $input (@current_inputs) {

                        if ( $input eq $current_output ) {

                            push @current_gate_inputs,      $current_gate_type;
                            push @current_gate_inputs_inst, $instance;

                            my @temp      = ();
                            my @temp_inst = ();
                            if ( $current_objectt->get_fwdgates() ) {
                                @temp = $current_objectt->get_fwdgates();
                                @temp_inst =
                                  $current_objectt->get_fwdgates_inst();
                            }
                            push @temp,      $outer_gate_type;
                            push @temp_inst, $name;
                            @temp      = grep defined, @temp;
                            @temp_inst = grep defined, @temp_inst;
                            $current_objectt->set_fwdgates( \@temp );
                            $current_objectt->set_fwdgates_inst( \@temp_inst );

                            $the_circuit{$instance} = $current_objectt;
                        }

                    }
                }
            }
        }    #end if my input array is not empty
        $object->set_fedbygates( \@current_gate_inputs );
        $object->set_fedbygates_inst( \@current_gate_inputs_inst );
        $the_circuit{$name} = $object;

    }    #end of the outer loop through the gates
    my @data = ();
    if ( $dump == 1 ) {

        #Dumps the dictionary of the circuit
        print Dumper ( \%the_circuit );
    }
    my %params_tr = map { $_ => 1 } @tr;
    foreach my $object ( values %the_circuit ) {    ##### loop through the gates

        #Extracting the feature vector
        my @OUts           = $object->get_fwdgates();
        my @features_array = (0) x 13;
        my $label          = "";
        my $module_name    = $object->get_processed();
        if ( exists( $module_map{$module_name} ) ) {
            $label = $module_map{$module_name};
        }
        else {

            $label = 2;                             #Default
        }
        my $prev = $features_array[ $features_map{ $object->get_bool_func() } ];
        $features_array[ $features_map{ $object->get_bool_func() } ] =
          ( $prev + 1 );

        my @INputs            = $object->get_fedbygates();
        my @current_fed_gates = ();
        @current_fed_gates = $object->get_fedbygates_inst();
        foreach my $elem (@current_fed_gates) {
            if ( exists( $the_circuit{$elem} ) ) {
                my $current_ob = $the_circuit{$elem};
                my $inputt     = $current_ob->get_bool_func();
                if ( exists( $features_map{$inputt} ) ) {
                    my $prev = $features_array[ $features_map{$inputt} ];
                    $features_array[ $features_map{$inputt} ] = ( $prev + 1 );
                }
                my @INNputs = $current_ob->get_fedbygates();
                foreach my $inputtt (@INNputs) {
                    if ( exists( $features_map{$inputtt} ) ) {
                        my $prev = $features_array[ $features_map{$inputt} ];
                        $features_array[ $features_map{$inputt} ] =
                          ( $prev + 1 );
                    }
                }
            }

        }

        my $nameo     = $object->get_name();
        my $in_degree = @INputs;
        if ( $in_degree == 0 ) {
        }
        my $nameo = $object->get_name();
        $features_array[ $features_map{"in_degree"} ] = $in_degree;
        my %params = map { $_ => 1 } @INputs;
        if ( exists( $params{"PI"} ) ) {
            my $prev = 0;
            $features_array[ $features_map{"PI"} ] = ( $prev + 1 );

        }
        if ( exists( $params{"KI"} ) ) {
            my $prev = 0;
            $features_array[ $features_map{"KEY"} ] = ( $prev + 1 );

        }
        my $name = "";
        $name = $object->get_name();
        my $count             = $object->get_count();
        my @current_fwd_gates = ();
        @current_fwd_gates = $object->get_fwdgates_inst();
        my $out_degree = @current_fwd_gates;
        $features_array[ $features_map{"out_degree"} ] = $out_degree;
        foreach my $elem (@current_fwd_gates) {

            if ( exists( $the_circuit{$elem} ) ) {
                my $current_ob    = $the_circuit{$elem};
                my $current_count = $current_ob->get_count();
                my $inputt        = $current_ob->get_bool_func();
                if ( exists( $features_map{$inputt} ) ) {
                    my $prev = $features_array[ $features_map{$inputt} ];
                    $features_array[ $features_map{$inputt} ] = ( $prev + 1 );
                }
                my @INNputs = $current_ob->get_fwdgates();
                foreach my $inputtt (@INNputs) {

                    if ( exists( $features_map{$inputtt} ) ) {
                        my $prev = $features_array[ $features_map{$inputtt} ];
                        $features_array[ $features_map{$inputtt} ] =
                          ( $prev + 1 );

                    }

                }
                print FH_ROW "$count\n";
                print FH_COL "$current_count\n";
                print FH_COL "$count\n";    #SO THAT THERE IS NO DIRECTION
                print FH_ROW "$current_count\n";
                if ( exists( $params_tr{$count} ) ) {
                    if ( exists( $params_tr{$current_count} ) ) {
                        print FH_ROW_TR "$count\n";
                        print FH_COL_TR "$current_count\n";
                        print FH_ROW_TR "$current_count\n";
                        print FH_COL_TR "$count\n";
                    }
                }
            }
        }
        %params = ();
        %params = map { $_ => 1 } @OUts;
        my $check_flag = 0;
        if ( exists( $params{"PO"} ) ) {
            my $prev = 0;
            $features_array[ $features_map{"PO"} ] = ( $prev + 1 );
            my $current_count = $object->get_count();
            print FH_ROW "$count\n";
            print FH_COL "$count\n";
            if ( exists( $params_tr{$count} ) ) {
                print FH_ROW_TR "$count\n";
                print FH_COL_TR "$count\n";
            }

        }
        print FH_CELL "$count $name from file $input_file\n";
        print FH_COUNT "$count\n";

        print FH_LABEL "$label\n";
        my $size = @features_array;
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
      ',';   # To print with separator, @some_list must be outside double-quotes
    warn "DEBUG: ", (caller)[2], ": @_\n" if ($debug);
    $" = $orig_list_separator;    # Dummy " for perl-mode in Emacs
}

__END__

