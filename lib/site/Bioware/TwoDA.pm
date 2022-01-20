#line 1 "Bioware/TwoDA.pm"
package Bioware::TwoDA;

use strict;
require Exporter;
use vars qw ($VERSION @ISA @EXPORT);
#use File::Temp qw (tempfile);
use File::Slurp;
use IO::Scalar;

use List::Util;

# set library version
$VERSION=0.21; #added binmode

@ISA    = qw(Exporter);

# export functions/variables
@EXPORT = qw(  );


# define globals (use vars)

#private vars
#private subs
sub new;
sub get_2da_rows_and_1stcol;
sub get_column_names;
sub get_cell;
sub add_column;
sub add_row;
sub change_cell;

sub read2da_for_spreadsheet;
sub read_2da;
sub read2da_fh;
sub read2da_asarray;
sub read2da_asarray_fh;
sub read2da_scalar;
sub read2da_asarray_scalar;

sub write2da;
sub write2da_for_spreadsheet;

sub get_err;
sub set_err;

sub get_cell
{
# PURPOSE: To return the entry for a cell of the loaded .2da file.
# INPUTS:  2DA Object, Row number, and the Column name
# OUTPUTS: Cell data, undef on failure (with error message in $self->{error})

#    my $self=shift;
#    my $row = shift;
#    my $column = shift;

    if(scalar @_ < 2)
    {
        $_[0]->set_err("Routine get_cell lacks a Row Number to index, as well as a Column Header to find the cell...\n");
        return undef;
    }
    elsif(scalar @_ < 3)
    {
        $_[0]->set_err("Routine get_cell lacks a Column Header to find the cell...\n");
        return undef;
    }

#    print "Cell data for " . $_[2] . " of row " . $_[1] . " is: " . $_[0]->{table}->{$_[1]}{$_[2]} . "\n";
    return $_[0]->{table}->{$_[1]}{$_[2]};
}

sub change_cell
{
# PURPOSE: To change the entry fro a cell of the loaded .2da file to the argument supplied
# INPUTS:  2DA Object, Row number, Column name, and new entry for the cell.
# OUTPUTS: None

    if(scalar @_ < 2)
    {
        $_[0]->set_err("Routine change_cell lacks a Row Number to index and a Column Header to find the cell...\n");
        return undef;
    }
    elsif(scalar @_ < 3)
    {
        $_[0]->set_err("Routine change_cell lacks a Column Header to find the cell...\n");
        return undef;
    }

    if(defined($_[3]) == 0) { $_[3] = ""; }

    $_[0]->{table}->{$_[1]}{$_[2]} = $_[3];
}

sub add_column
{
# PURPROSE: To add a new column at the end of the .2da's list.
# INPUTS:   2DA Object, Column Header, Default Value for the cells
# OUTPUTS:  None

    my ($self, $column, $value, $index) = @_;

    if(defined($column) == 0)
    {
        $self->set_err("Routine add_column lacks a Column Header to add to the .2da file...\n");
        return undef;
    }

    if(defined($value) == 0) { $value = ""; }

    if(defined($index) == 1)
    {
        my $i = -1;
        my @array = ();

        foreach my $c (@{$self->{columns}})
        {#print "C: $c\n";
            $i++;
            if($i == $index)
            {
                push (@array, $column);
                push (@array, $c);
            }
            else { push (@array, $c); }
        }
        $self->{columns} = \@array;
    }
    else
    {
        push (@{$self->{columns}}, $column);
    }

    foreach (@{$self->{rows_array}})
    {
        $self->{table}->{$_}{$column} = $value;
    }
}

sub delete_column
{
	my ($self, $column) = @_;
	
	my @new = ();
	foreach(@{$self->{columns}})
	{
		if($_ ne $column) { push(@new, $_); }
	}
	
	$self->{columns} = \@new;
}

sub get_row_number
{
    my ($self, $row_header) = @_;
    return (List::Util::first { $_ == $row_header }, @{$self->{rows_array}});
}

sub get_row_header
{
    my ($self, $row_number) = @_;
	
	if((scalar @{$self->{rows_array}}) >= $row_number)
	{ return @{$self->{rows_array}}[$row_number]; }
	else
	{ return -1; }
}

sub add_row
{
# PURPROSE: To add a new row just before the given index of the .2da.
# INPUTS:   2DA Object, row index, optional row to copy values from
# OUTPUTS:  None

    my ($self, $row_header, $copy) = @_;
    my %hash1;
    my %hash2;

    if(defined($row_header) == 0)
    {
        $self->set_err("Routine add_row lacks an index to tell where to add to the .2da file...\n");
        return -1;
    }

    my $index = List::Util::first { $_ == $row_header }, @{$self->{rows_array}};

    if(defined($index) == 0) { $index = $self->{rows}; }
    elsif(defined($copy))    { $index = $self->{rows}; }
    else                     { return $index;          } #return @{$self->{rows_array}}[$index]; }


    if(defined($index) == 1 && $index < $self->{rows})
    {
        my $i = -1;
        my @array = ();

        foreach my $c (@{$self->{rows_array}})
        {#print "C: $c\n";
            $i++;
            if($i == $index)
            {
                push (@array, $index);

                foreach (@{$self->{columns}})
                {
                    $hash1{$_} = $self->{table}->{$i}{$_};
                    $self->{table}->{$i}{$_} = "";
                }

                push (@array, $c + 1);
            }
            elsif($i > $index)
            {
                foreach (@{$self->{columns}})
                {
                    $hash2{$_} = $self->{table}->{$i}{$_};
                    $self->{table}->{$i}{$_} = $hash1{$_};
                    $hash1{$_} = $hash2{$_};
                }

                push (@array, $c + 1);
            }
            else
            {
                push (@array, $c);
            }
        }

        $self->{rows_array} = \@array;
        foreach (@{$self->{columns}})
        {
            $self->{table}->{$self->{rows_array}[-1]}{$_} = $hash1{$_};
        }
    }
    else
    {
        push (@{$self->{rows_array}}, $row_header);

        foreach (@{$self->{columns}})
        {
            if(defined($copy))
            {
                $self->{table}->{$row_header}{$_} = $self->{table}->{$copy}{$_};
            }
            else
            {
                $self->{table}->{$row_header}{$_} = "";
            }
        }
    }

    $self->{rows} += 1;

    return $index;
}

sub set_err
{
    $_[0]->{error} = $_[1];
}

sub get_err
{
    our $d = $_[0]->{error};
    $_[0]->{error} = undef;
    return $d;
}

sub get_is_error
{
    if(defined($_[0]->{error})) { return 1; }
    else                        { return 0; }
}
#line 289

sub get_2da_rows_and_1stcol{
    my $twoda_filename = shift;
    open my ($fh),"<",$twoda_filename;
    binmode $fh;
    # header
    read $fh, my ($header_packed),9;
    my $header=unpack('a*',$header_packed);
    #if ($header =~ /2DA V2\.0/) {

    unless ($header eq '2DA V2.b'.v10) { return ();}


    my $twoda=read_file($twoda_filename);

    #null separates the rows from the columns
    my $the_null_pos=0;
    while ($twoda=~/\0/g) {
        if (!$the_null_pos) { $the_null_pos=pos $twoda }
    }
    seek $fh, $the_null_pos,0;
    #row count is next DWORD
    read $fh,my ($num_of_rows_packed),4;
    my $num_of_rows=unpack('V',$num_of_rows_packed);
    #columns are separated by tabs before the null position
    my $tab_cnt=0;
    while ($twoda=~/\t/g) {
        my $this_pos = pos $twoda;
        if ($this_pos < $the_null_pos) {
            $tab_cnt++;
        }
    }
    my $num_of_cols=$tab_cnt;



    my $count=0;
    my $after_rownames_pos=0;
    while ($twoda=~/\t/g) {
        if (pos $twoda > $the_null_pos) {
            if (++$count==$num_of_rows) {
                $after_rownames_pos=pos $twoda;
            }
        }
    }


    my $num_of_pointers = $num_of_rows * $num_of_cols; #number of pointers (words)
    my $data_area = $after_rownames_pos+($num_of_pointers * 2)+2; #this many bytes of pointers

    my $row=0;
    my %row_to_label;
    for (my $i=0; $i<$num_of_pointers; $i+=$num_of_cols) {
        my $pointer_packed;
        seek $fh,$after_rownames_pos+($i*2),0;
        read $fh,$pointer_packed,2;
        my $pointer=unpack('v',$pointer_packed);
        seek $fh,$data_area,0;
        my $t=tell $fh;
        seek $fh,$pointer,1;
        my $t1=tell $fh;
        read $fh,my ($temp_pack),500;
        my $value=unpack('Z*',$temp_pack);
        if ($value eq '') { $row++; next; }
        $row_to_label{$row}=$value;
        $row++;
    }
    close $fh;
    return %row_to_label;

}

sub new {
    #this is a generic constructor method
    my $invocant=shift;
    my $class=ref($invocant)||$invocant;
    my $self={ @_ };
    bless $self,$class;
    return $self;
}

sub get_column_names
{
    my @columns;
    my $self=shift;
    my $file_to_read=shift;
    if (ref $file_to_read eq 'SCALAR') { return read2da_scalar($self,$file_to_read) }
    if (ref $file_to_read eq 'GLOB')   { return read2da_fh($self,$file_to_read) }
    my %table;
    my %table2;
    my @colwidths;
    (open my ($fh),"<",$file_to_read) or return;
    binmode $fh;
    my $header;
    read $fh, $header,9;
    unless ($header eq '2DA V2.b'.v10) { return ();}
    { local $/="\000";
      my $columnchunk=<$fh>;
      chop $columnchunk;
      @columns=split /\t/,$columnchunk;     #we now have column names
    }
    return @columns;
}

sub read2da_for_spreadsheet {
#this sub receives the twoda_obj and the filename to read as parameters
    my $self=shift;
    my $file_to_read=shift;
    if (ref $file_to_read eq 'SCALAR') { return read2da_scalar($self,$file_to_read) }
    if (ref $file_to_read eq 'GLOB')   { return read2da_fh($self,$file_to_read) }
    my %table;
    my %table2;
    my @colwidths;
    (open my ($fh),"<",$file_to_read) or return;
    binmode $fh;
    my $header;
    read $fh, $header,9;
    unless ($header eq '2DA V2.b'.v10) { return ();}
    { local $/="\000";
      my $columnchunk=<$fh>;
      chop $columnchunk;
      my @columns=split /\t/,$columnchunk;     #we now have column names

      read $fh, my ($rowcnt),4;
      $rowcnt=unpack('V',$rowcnt);             #we now know the number of rows
      $/="\t";
      my @rows;
      for (1..$rowcnt) {
         $_=<$fh>;
         chop;
         push @rows, $_;                       #we now have the row headers
      }
      my $pointer_cursor;
      my $data_start_pos=tell ($fh) + (2*$rowcnt*(scalar @columns))+2 ;
      #print "$data_start_pos\n";
      $/="\000";
      my $rix=1;
      for my $r (@rows) {
        $table2{"$rix,0"}=$r;
        $colwidths[0]=length($r) if length($r)>$colwidths[0];
        my $cix=1;
        for my $c (@columns) {
          read $fh,(my $p),2;
          $pointer_cursor=tell $fh;
          $p=unpack('v',$p);
          seek $fh,$data_start_pos+$p,0;
          $_=<$fh>;
          chop;
          $table{$r}{$c}=$_;                  #we now have the data for each cell
          $colwidths[$cix]=length($_) if length($_)>$colwidths[$cix];
          $table2{"$rix,$cix"}=$_;
          $table2{"0,$cix"}=$c;
          $colwidths[$cix]=length($c) if length($c)>$colwidths[$cix];
          $cix++;

          seek $fh,$pointer_cursor,0;
        }
        $rix++;
      }
    }
    close $fh;
    return (\%table,\%table2,\@colwidths);
}

sub read2da {
#this sub receives the twoda_obj and the filename to read as parameters
    my $self=shift;
    my $file_to_read=shift;
    if (ref $file_to_read eq 'SCALAR') { return read2da_scalar($self,$file_to_read) }
    if (ref $file_to_read eq 'GLOB')   { return read2da_fh($self,$file_to_read) }

my $filename = (split(/\\/, $file_to_read))[-1];
#print "filename: $filename\n";

$self->{filename} = $filename;

    my %table;
    (open my ($fh),"<",$file_to_read) or return;
#open F, ">", "read_data.txt";
    binmode $fh;
    my $header;
    read $fh, $header,9;
    unless ($header eq '2DA V2.b'.v10) { return (0);}
    { local $/="\000";
      my $columnchunk=<$fh>;
      chop $columnchunk;
      my @columns=split /\t/,$columnchunk;     #we now have column names
      $self->{columns} = \@columns;

      read $fh, my ($rowcnt),4;
      $rowcnt=unpack('V',$rowcnt);             #we now know the number of rows
      $/="\t";
      my @rows;

      $self->{rows}    = $rowcnt;
      for (1..$rowcnt) {
         $_=<$fh>;
         chop;
         push @rows, $_;                       #we now have the row headers
      }
      $self->{rows_array} = \@rows;


      my $pointer_cursor;
      my $data_start_pos=tell ($fh) + (2*$rowcnt*(scalar @columns))+2 ;
      my $tell = tell ($fh);
      my $show = (2*$rowcnt*(scalar @columns))+2;
      #print "$data_start_pos\n";
#print F "Data_Start_pos is: $data_start_pos, $tell and $show\n\n";
      $/="\000";
      for my $r (@rows) {                      # Is the row of the 2da
        for my $c (@columns) {                 # Is the column name of the 2da
          read $fh,(my $p),2;
          $pointer_cursor=tell $fh;
          $p=unpack('v',$p);
          seek $fh,$data_start_pos+$p,0;
#print F "Data for row $r, column $c: Packed pos is $p, total pos is " . ($data_start_pos + $p) . "\n";
          $_=<$fh>;
          chop;
          $table{$r}{$c}=$_;                  #we now have the data for each cell
          seek $fh,$pointer_cursor,0;
        }
      }
    }

    $self->{table}   = \%table;
#close F;
    close $fh;
    return \%table;
}

sub readFS
{
	our @rows;
	our @columns;
	our %table;
#this sub receives the twoda_obj and the filename to read as parameters
    my $self=shift;
    my $file_to_read=shift;
    if (ref $file_to_read eq 'SCALAR') { return read2da_scalar($self,$file_to_read) }
    if (ref $file_to_read eq 'GLOB')   { return read2da_fh($self,$file_to_read) }
#    my %table;
    (open my ($fh),"<",$file_to_read) or return;
    binmode $fh;
    my $header;
    read $fh, $header,9;
    unless ($header eq '2DA V2.b'.v10) { return ();}
    { local $/="\000";
      my $columnchunk=<$fh>;
      chop $columnchunk;
      @columns=split /\t/,$columnchunk;#	print join "\n", @columns; print "\n";     #we now have column names
      read $fh, my ($rowcnt),4;
      $rowcnt=unpack('V',$rowcnt);             #we now know the number of rows
      $/="\t";
      
      for (1..$rowcnt) {
         $_=<$fh>;
         chop;
         push @rows, $_;                       #we now have the row headers
      }

#	if($file_to_read == "appearance.2da"){	print join "\n", @rows; print "\n"; }
      my $pointer_cursor;
      my $data_start_pos=tell ($fh) + (2*$rowcnt*(scalar @columns))+2 ;
      #print "$data_start_pos\n";
      $/="\000";
      for my $r (@rows) {                      # Is the row of the 2da
        for my $c (@columns) {                 # Is the column name of the 2da
          read $fh,(my $p),2;
          $pointer_cursor=tell $fh;
          $p=unpack('v',$p);
          seek $fh,$data_start_pos+$p,0;
          $_=<$fh>;
          chop;
          $table{$r}{$c}=$_;                  #we now have the data for each cell
          seek $fh,$pointer_cursor,0;
        }
      }
    }
    close $fh;
    my %s={};

	for my $zz (@columns)
	{
		$s{columns}->{"Column_$zz"}=$zz;
	}

	for my $ii (@rows)
	{
		$s{rows}->{"Row_$ii"}=$ii;
	}

#	for my $i(@rows)
#	{
#		$s{"row $i"}= $table{$i};
#	}
#	my %t={columns=>\@columns, rows=>{\%s}};

#    $self->{columns} = @columns;
#    $self->{rows_array} = @rows;
#    $self->{rows}    = $rowcnt;
#    $self->{table}   = \%table;
	return %s;
}

sub read2da_asarray {
    my $self=shift;
    my $file_to_read=shift;
    if (ref $file_to_read eq 'SCALAR') { return read2da_asarray_scalar($self,$file_to_read) }
    if (ref $file_to_read eq 'GLOB')   { return read2da_asarray_fh($self,$file_to_read) }

    my @table;
    
    (open my ($fh),"<",$file_to_read) or return;
    binmode $fh;
    my $header;
    read $fh, $header,9;
    unless ($header eq '2DA V2.b'.v10) { return ();}
    { local $/="\000";
      my $columnchunk=<$fh>;
      chop $columnchunk;
      my @columns=split /\t/,$columnchunk;     #we now have column names
      $self->{columns} = @columns;
      read $fh, my ($rowcnt),4;
      $rowcnt=unpack('V',$rowcnt);             #we now know the number of rows
      $/="\t";
      my @rows;

      $self->{rows}    = $rowcnt;
      for (1..$rowcnt) {
         $_=<$fh>;
         chop;
         push @rows, $_;                       #we now have the row headers
      }
      $self->{rows_array} = @rows;

      my $pointer_cursor;
      my $data_start_pos=tell ($fh) + (2*$rowcnt*(scalar @columns))+2 ;
      #print "$data_start_pos\n";
      $/="\000";
      for my $r (@rows) {
        my %row;
        $row{row}=$r;
        for my $c (@columns) {
          read $fh,(my $p),2;
          $pointer_cursor=tell $fh;
          $p=unpack('v',$p);
          seek $fh,$data_start_pos+$p,0;
          $_=<$fh>;
          chop;
          $row{$c}=$_;
          #$table{$r}{$c}=$_;                  #we now have the data for each cell
          seek $fh,$pointer_cursor,0;
        }
        push @table,\%row;
      }
      
    }

    $self->{table}   = \@table;

    close $fh;
    return \@table;

}

sub read2da_fh {
# this sub receives the twoda object and the open filehandle as parameters
    my $self=shift;
    my $fh=shift;
    my $header;
    my %table;
    binmode $fh;
    read $fh, $header,9;
    unless ($header eq '2DA V2.b'.v10) { return ();}
    { local $/="\000";
      my $columnchunk=<$fh>;
      chop $columnchunk;
      my @columns=split /\t/,$columnchunk;     #we now have column names
      $self->{columns} = @columns;

      read $fh, my ($rowcnt),4;
      $rowcnt=unpack('V',$rowcnt);             #we now know the number of rows
      $/="\t";
      my @rows;

      $self->{rows}    = $rowcnt;
      for (1..$rowcnt) {
         $_=<$fh>;
         chop;
         push @rows, $_;                       #we now have the row headers
      }
      $self->{rows_array} = @rows;

      my $pointer_cursor;
      my $data_start_pos=tell ($fh) + (2*$rowcnt*(scalar @columns)) +2;
      #print "$data_start_pos\n";
      $/="\000";
      for my $r (@rows) {
        for my $c (@columns) {
          read $fh,(my $p),2;
          $pointer_cursor=tell $fh;
          $p=unpack('v',$p);
          seek $fh,$data_start_pos+$p,0;
          $_=<$fh>;
          chop;
          $table{$r}{$c}=$_;                  #we now have the data for each cell
          seek $fh,$pointer_cursor,0;
        }
      }
    }

    $self->{table}   = \%table;

    return \%table;
}
sub read2da_asarray_fh {
# this sub receives the twoda object and the open filehandle as parameters
    my $self=shift;
    my $fh=shift;
    my $header;
    my @table;
    binmode $fh;
    read $fh, $header,9;
    unless ($header eq '2DA V2.b'.v10) { return ();}
    { local $/="\000";
      my $columnchunk=<$fh>;
      chop $columnchunk;
      my @columns=split /\t/,$columnchunk;     #we now have column names
      $self->{columns} = @columns;

      read $fh, my ($rowcnt),4;
      $rowcnt=unpack('V',$rowcnt);             #we now know the number of rows
      $/="\t";
      my @rows;

      $self->{rows}    = $rowcnt;
      for (1..$rowcnt) {
         $_=<$fh>;
         chop;
         push @rows, $_;                       #we now have the row headers
      }
      $self->{rows_array} = @rows;

      my $pointer_cursor;
      my $data_start_pos=tell ($fh) + (2*$rowcnt*(scalar @columns)) +2;
      #print "$data_start_pos\n";
      $/="\000";
      for my $r (@rows) {
        my %row;
        $row{row}=$r;
        for my $c (@columns) {
          read $fh,(my $p),2;
          $pointer_cursor=tell $fh;
          $p=unpack('v',$p);
          seek $fh,$data_start_pos+$p,0;
          $_=<$fh>;
          chop;
          $row{$c}=$_;
          seek $fh,$pointer_cursor,0;
        }
        push @table,\%row;
      }
    }

    $self->{table}   = \@table;

    return \@table;
}

sub read2da_scalar {
#this sub receives the twoda_obj and a scalar reference (containing the twoda) as parameters
    my $self=shift;
    my $scalar_ref=shift;
    return unless ref $scalar_ref eq 'SCALAR';
    my $fh=new IO::Scalar $scalar_ref;
    my %table;
    my $header;
    read $fh, $header,9;
    unless ($header eq '2DA V2.b'.v10) { return ();}
    { local $/="\000";
      my $columnchunk=<$fh>;
      chop $columnchunk;
      my @columns=split /\t/,$columnchunk;     #we now have column names
      $self->{columns} = @columns;

      read $fh, my ($rowcnt),4;
      $rowcnt=unpack('V',$rowcnt);             #we now know the number of rows
      $/="\t";
      my @rows;

      $self->{rows}    = $rowcnt;
      for (1..$rowcnt) {
         $_=<$fh>;
         chop;
         push @rows, $_;                       #we now have the row headers
      }
      $self->{rows_array} = @rows;

      my $pointer_cursor;
      my $data_start_pos=tell ($fh) + (2*$rowcnt*(scalar @columns)) +2;
      #print "$data_start_pos\n";
      $/="\000";
      for my $r (@rows) {
        for my $c (@columns) {
          read $fh,(my $p),2;
          $pointer_cursor=tell $fh;
          $p=unpack('v',$p);
          seek $fh,$data_start_pos+$p,0;
          $_=<$fh>;
          chop;
          $table{$r}{$c}=$_;                  #we now have the data for each cell
          seek $fh,$pointer_cursor,0;
        }
      }
    }

    $self->{table}   = \%table;

    close $fh;
    return \%table;

}
sub read2da_asarray_scalar {
#this sub receives the twoda_obj and a scalar reference (containing the twoda) as parameters
    my $self=shift;
    my $scalar_ref=shift;
    return unless ref $scalar_ref eq 'SCALAR';
    my $fh=new IO::Scalar $scalar_ref;
    my @table;
    my $header;
    read $fh, $header,9;
    unless ($header eq '2DA V2.b'.v10) { return ();}
    { local $/="\000";
      my $columnchunk=<$fh>;
      chop $columnchunk;
      my @columns=split /\t/,$columnchunk;     #we now have column names
      $self->{columns} = @columns;

      read $fh, my ($rowcnt),4;
      $rowcnt=unpack('V',$rowcnt);             #we now know the number of rows
      $/="\t";
      my @rows;

      $self->{rows}    = $rowcnt;
      for (1..$rowcnt) {
         $_=<$fh>;
         chop;
         push @rows, $_;                       #we now have the row headers
      }
      $self->{rows_array} = @rows;

      my $pointer_cursor;
      my $data_start_pos=tell ($fh) + (2*$rowcnt*(scalar @columns)) +2;
      #print "$data_start_pos\n";
      $/="\000";
      for my $r (@rows) {
        my %row;
        $row{row}=$r;
        for my $c (@columns) {
          read $fh,(my $p),2;
          $pointer_cursor=tell $fh;
          $p=unpack('v',$p);
          seek $fh,$data_start_pos+$p,0;
          $_=<$fh>;
          chop;
          $row{$c}=$_;
          seek $fh,$pointer_cursor,0;
        }
        push @table,\%row;
      }
    }

    $self->{table}   = \@table;

    close $fh;
    return \@table;
}


sub write_2da_from_spreadsheet {
    my ($self,$spreadsheet_hashref,$new_filename)=@_;
    return unless (ref $spreadsheet_hashref eq 'HASH');
    return unless $new_filename;
    (open my $fh,">",$new_filename) or return;
    binmode $fh;
    print $fh "2DA V2.b".chr(10);
    my @col_headers;
    my @row_headers;
    for my $k (keys %$spreadsheet_hashref) {
        if ($k=~/0,(\d+)/) {
          $col_headers[$1-1]=$spreadsheet_hashref->{$k};
        }
        if ($k=~/(\d+),0/) {
          $row_headers[$1-1]=$spreadsheet_hashref->{$k};
        }
    }
}

sub write2da {
#this sub receives the twoda_obj and the filename to read as parameters
    my $self=shift;
    my $file_to_read=shift;

#    if (ref $file_to_read eq 'SCALAR') { return read2da_scalar($self,$file_to_read) }
#    if (ref $file_to_read eq 'GLOB')   { return read2da_fh($self,$file_to_read) }

    our %save_hash  = ();
    our @save_array = ();

    open FH, ">", $file_to_read or return;
#    open F, ">", "write_data.txt";

    binmode FH;
    syswrite FH, "2DA V2.b".v10;

    foreach(@{$self->{columns}}) { syswrite FH, $_ . "\t"; }

    syswrite FH, pack('x', "");
    syswrite FH, pack('V', $self->{rows});

    foreach (@{$self->{rows_array}}) { syswrite FH, $_ . "\t"; }

    my $data_start_pos = sysseek(FH, 0, 1) + ( 2 * $self->{rows} * (scalar @{$self->{columns}}) ) + 2;
    my $tell = sysseek(FH, 0, 1);
    my $show = ( 2 * $self->{rows} * (scalar @{$self->{columns}}) ) + 2;
#    print F "Data_Start_pos is: $data_start_pos, $tell and $show\n\n";

    my $data_pos       = 0;
    my ($r, $c)        = (undef, undef);

    foreach $r (@{$self->{rows_array}})
    {
        foreach $c (@{$self->{columns}})
        {
            if($c eq "****") { $c = ''; }

            if(exists $save_hash{$self->{table}->{$r}{$c}})
            {
                syswrite FH, pack('v', $save_hash{$self->{table}->{$r}{$c}});
#                print F "Data for row $r, column $c: Packed pos is $data_pos, total pos is $data_start_pos\n";
            }
            else
            {
                $save_hash{$self->{table}->{$r}{$c}} = $data_pos;
#                print F "Data for row $r, column $c: Packed pos is $data_pos, total pos is $data_start_pos\n";

                $data_pos += length($self->{table}->{$r}{$c}) + 1;
                push (@save_array, $self->{table}->{$r}{$c});

                syswrite FH, pack('v', $save_hash{$self->{table}->{$r}{$c}});
            }
#            $data_pos = length($self->{table}->{$r}{$c});
#            syswrite FH, pack('v', $data_start_pos);
#            $data_start_pos += length($self->{table}->{$r}{$c});
        }
    }
    syswrite FH, pack('xx', "");

    foreach (@save_array)
    {
        syswrite FH, $_;
        syswrite FH, pack('x', "");
    }

#    close F;
    close FH;
}

1;
#&new &read_keys &fetch_resource &insert_resource &export_resource &import_resource
