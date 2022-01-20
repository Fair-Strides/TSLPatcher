#line 1 "Bioware/TLK.pm"
#
#  NOTES ~~ Fair Strides, not Tk102
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#	1. Seek starts from the beginning of the file every time...
#	2. There is no ending to the file, except the last StrRef.
#	3. You have the header, then two tables: String data, and String.
#	4. To access the string data, you need to count 20 + (StrRef*40) from the beginning of the file.
#	5. The string data for any given StrRef is 40 bytes.

# Define package name
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
package Bioware::TLK; #~~~~~~~~~~~~~~~
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

use strict;
use bytes;
require Exporter;
use vars qw ($VERSION @ISA @EXPORT);

# set version
$VERSION=0.04; #SUPPORT FOR TLK V4.0 files (Jade Empire)
#$VERSION=0.03; #changed > to >= in if ($resrefnum>=$string_count)


@ISA    = qw(Exporter);

# export functions/variables
@EXPORT = qw( &new &load_tlk &edit_entry &add_entry &delete_entry &save_tlk &string_from_resref &number_of_strings &number_of_stringsFH &tlk_info &add_new_entry &save_TLK &GetStringInfo);

sub string_from_resref($$;$) {
    my $tlk_path=shift;
    my $resrefnum=shift;
    my $breadcrumb=shift;
    #print "TLK: $resrefnum\n";
    return '' if $resrefnum<0;
    
    (open TLK, "<", "$tlk_path\\dialog.tlk") || (return);

    seek TLK,0,0;
    read TLK,(my $tlkversion),8;
    if ($tlkversion eq 'TLK V4.0')
	{
        seek TLK,12,0;
        read TLK,(my $string_count_packed),4;
        my $string_count=unpack('V',$string_count_packed);
        if ($resrefnum>=$string_count) {
##            $msgbox->Call(0,"Attempted to read past end of end of dialog.tlk \n"
##            ."(tried to read string $resrefnum but dialog.tlk only goes up to entry number " . ($string_count-1) .")"."\n\n$breadcrumb",
##            "Dialog.tlk error",0);
        return "Bad StrRef";
#            die "Dialog.tlk error: Attempted to read past end of end of dialog.tlk \n"
#            ."(tried to read string $resrefnum but dialog.tlk only goes up to entry number " . ($string_count-1) .")"."\n$breadcrumb"
        }
        seek TLK,32+(10*$resrefnum)+4,0;
        read TLK,(my $info_packed),6;
        my ($offset,$size)=unpack('V',$info_packed);
        seek TLK,$offset,0;
        read TLK,(my $string),$size;
        return $string;
    }
    seek TLK,12,0;
    read TLK,(my $string_count_packed),4;
    my $string_count=unpack('V',$string_count_packed);
    if ($resrefnum>=$string_count) {
##      $msgbox->Call(0,"Attempted to read past end of end of dialog.tlk \n"
##      ."(tried to read string $resrefnum but dialog.tlk only goes up to entry number " . ($string_count-1) .")"."\n\n$breadcrumb",
##     "Dialog.tlk error",0);
    return "Bad StrRef";
#      die "Dialog.tlk error: Attempted to read past end of end of dialog.tlk \n"
#        ."(tried to read string $resrefnum but dialog.tlk only goes up to entry number " . ($string_count-1) .")"."\n$breadcrumb"
    }
    read TLK,(my $offset_packed),4;
    my $offset=unpack('V',$offset_packed);
#    print "\$resref is $resrefnum\n\$offset is $offset\n";
    seek TLK, 20+(40*$resrefnum)+28,0;
    read TLK,(my $info_packed),8;
    my ($offset2,$size)=unpack('V2',$info_packed);
    seek TLK,$offset+$offset2,0;
    read TLK,(my $string),$size;


    my $math_info = 20 + (40*$resrefnum) + 28;
    my $file_size = $offset + $offset2;

#    print "Beginning TLK output:\n";
#    print "TLK Size: " . -s "$tlk_path\\dialog.tlk";
#    print "\nVersion: $tlkversion\n";
#    print "Resref: $resrefnum\n";
#    print "String Count: $string_count\n";
#    print "Offset of file: $offset\n";
#    print "Offset of in String table: $offset2\n\n";

#    print "Area of String: $file_size\n";
#    print "Size of string: $size\n";
#    print "String: $string\n\n";

#    print "Info area: $math_info\n";
#    print "Ending TLK output.\n\n";

    seek TLK,12,0;
    read TLK,(my $string_count_packed),4;
    my $string_count=unpack('V',$string_count_packed);
    if ($resrefnum>=$string_count) {
#      $msgbox->Call(0,"Attempted to read past end of end of dialog.tlk \n"
#      ."(tried to read string $resrefnum but dialog.tlk only goes up to entry number " . ($string_count-1) .")"."\n\n$breadcrumb",
#      "Dialog.tlk error",0);

#      die "Dialog.tlk error: Attempted to read past end of end of dialog.tlk \n"
#        ."(tried to read string $resrefnum but dialog.tlk only goes up to entry number " . ($string_count-1) .")"."\n$breadcrumb"
    }
    read TLK,(my $offset_packed),4;
    my $offset=unpack('V',$offset_packed);
#    print "\$offset is $offset\n";
    seek TLK, 20+(40*$resrefnum),0;
    read TLK, (my $bits_packed), 4;

#    print "\$bits_packed is $bits_packed\n";
    my $bits = unpack('V', $bits_packed);
#    print "\$bits is $bits\n";
    close TLK;
    return $string;
}

sub GetStringInfo($$;$) {
    my $tlk_path=shift;
    my $resrefnum=shift;
    my $breadcrumb=shift;

    my %tlk = ();
    
    return '' if $resrefnum<0;
    
    (open TLK, "<", "$tlk_path") || (return);

    seek TLK,0,0;

    seek TLK,12,0;
    read TLK,(my $string_count_packed),4;
    my $string_count=unpack('V',$string_count_packed);
    if ($resrefnum>=$string_count) {
#      $msgbox->Call(0,"Attempted to read past end of end of dialog.tlk \n"
#      ."(tried to read string $resrefnum but dialog.tlk only goes up to entry number " . ($string_count-1) .")"."\n\n$breadcrumb",
#      "Dialog.tlk error",0);

#      die "Dialog.tlk error: Attempted to read past end of end of dialog.tlk \n"
#        ."(tried to read string $resrefnum but dialog.tlk only goes up to entry number " . ($string_count-1) .")"."\n$breadcrumb"
    }
    read TLK,(my $offset_packed),4;
    my $offset=unpack('V',$offset_packed);
#    print "\$resref is $resrefnum\n\$offset is $offset\n";
    seek TLK, 20+(40*$resrefnum),0;
    read TLK,(my $flags_packed), 4;
    read TLK,(my $sound_file), 16;
	read TLK, my $junk, 8;
    read TLK,(my $info_packed),8;
    my ($offset2,$size)=unpack('V2',$info_packed);
    seek TLK,$offset+$offset2,0;
    read TLK,(my $string),$size;    

    $tlk{Flags}  = unpack('v', $flags_packed);
    $tlk{Sound}  = $sound_file;
    $tlk{String} = $string;
    $tlk{Size}   = $size;

    close TLK;
    return \%tlk;
}

sub tlk_info
{
    my $tlk_path = shift;
    my %info;

    open (TLK, "<", "$tlk_path\\dialog.tlk");

    seek TLK, 0, 0;
    read TLK, $info{'version'}, 8;
    read TLK, (my $lang), 4;
    read TLK, (my $scount), 4;
    read TLK, (my $soffset), 4;

    $info{'language'} = unpack("V", $lang);
    $info{'scount'} = unpack("V", $scount);
    $info{'soffset'} = unpack("V", $soffset);

    return %info;
}

sub number_of_strings
{
    my $tlk_path=shift;

    (open TLK, "<", "$tlk_path\\dialog.tlk") || (return);

    seek TLK,0,0;
    read TLK,(my $tlkversion),8;
    if ($tlkversion eq 'TLK V4.0') {
        seek TLK,12,0;
        read TLK,(my $string_count_packed),4;
        my $string_count=unpack('V',$string_count_packed);

        close TLK;
        return $string_count;
    }
    seek TLK,12,0;
    read TLK,(my $string_count_packed),4;
    my $string=unpack('V',$string_count_packed);

    my $string_count = $string - 1;
    close TLK;
    return $string_count;
}

sub number_of_stringsFH
{
    my $tlk=shift;

    seek $tlk,0,0;
    read $tlk,(my $tlkversion),8;
    if ($tlkversion eq 'TLK V4.0') {
        seek $tlk,12,0;
        read $tlk,(my $string_count_packed),4;
        my $string_count=unpack('V',$string_count_packed);

        close $tlk;
        return $string_count;
    }
    seek $tlk,12,0;
    read $tlk,(my $string_count_packed),4;
    my $string=unpack('V',$string_count_packed);

    my $string_count = $string - 1;
    print "FH worked\n";
    return $string_count;
}

sub new_tlk
{
    my $file = shift;
    my %info = shift;
    open FILE, ">", "$file" or die("$!\n");
    binmode FILE;

    seek FILE, 0, 0;
    syswrite TLK, $info{'version'};
    syswrite TLK, $info{'lang'};
    syswrite TLK, $info{'scount'};
    syswrite TLK, $info{'soffset'};

#    close FILE;
    return \*FILE;
}

sub add_new_entry
{
#    my $tlk = shift;
    my $tlk_path = shift;
#    my $num_entries = shift;
    my $entry = shift;
#    open TLK, "<", "$tlk_path\\dialog.tlk" or die("$!");
#    my $num_entry = number_of_strings($tlk_path);

#    seek TLK, 16, 0;
#    read TLK,(my $offset_packed),4;
#    my $offset=unpack('V',$offset_packed);
#    read TLK, (my $of), 4;
#    my $off=unpack('V',$of);
#    print "\$off is $off\n";

#    seek TLK,20+($num_entries*40), 0;
#    read TLK, (my $one), 4;
#    read TLK, (my $two), 16;
#    read TLK, (my $three), 4;
#    read TLK, (my $four), 4;
#    read TLK, (my $five), 4;
#    read TLK, (my $six), 4;
#    read TLK, (my $seven), 4;

#    print "Flags: $one\n";
#    print "Flags: $two\n";
#    print "Flags: $three\n";
#    print "Flags: $four\n";
#    print "Flags: $five\n";
#    print "Flags: $six\n";
#    print "Flags: $seven\n";

#    print "Flags: " . unpack('V', $one) . "\n";
#    print "Hex: " . hex($one) . "\n";
#    print "Flags: " . unpack('A*', $two) . "\n";
#    print "Flags: " . unpack('V', $three) . "\n";
#    print "Flags: " . unpack('V', $four) . "\n";
#    print "Flags: " . unpack('V', $five) . "\n";
#    print "Flags: " . unpack('V', $six) . "\n";
#    print "Flags: " . unpack('V', $seven) . "\n";

#    seek TLK, 20+(40*$num_entries)+28,0;
#    read TLK,(my $info_packed),8;
#    my ($offset2,$size)=unpack('V2',$info_packed);
#    seek TLK,$offset+$offset2+$size,0;

#    seek TLK,20+($num_entries*40)+40, 0;
#    close TLK;

#    my %info;
#    $info{'version'} = "TLK V3.0";
#    $info{'lang'} = pack('V', 0);
#    $info{'scount'} = pack('V', 0);
#    $info{'soffset'} = pack('V', 0);

#    my $TLK = new_tlk("$tlk_path\\funny.tlk", %info);
    open(TLK, ">", "$tlk_path\\funny.tlk");

    my %entry1 = %{$entry};
    $entry1{StringSize} = length($entry1{String});

    syswrite TLK, "TLK V3.0";
    syswrite TLK, pack('V', 0);
    syswrite TLK, pack('V', 1);
    syswrite TLK, pack('V', 60);

    foreach my $key (sort keys %entry1)
    {
        print "\$key is $key\n";
        print "The entry is: $entry1{$key}\n";
    }

    syswrite TLK, pack('V', $entry1{Flags});
    print "Flags are: " . $entry1{Flags} . ".\n";
    syswrite TLK, $entry1{SoundRR};
    syswrite TLK, pack('V', "0");
    syswrite TLK, pack('V', "0");
    syswrite TLK, pack('V', 0);#$entry1{OffsetToString});
    syswrite TLK, pack('V', $entry1{StringSize});
    syswrite TLK, pack('V', "0");

    seek TLK, 60, 0;
#    syswrite TLK, pack('V', "Carth's a moron!");
    syswrite TLK, $entry1{String};

    close TLK;

    print "FS_Okay\n";

}

sub new
{
    my $invocant=shift;
    my $class=ref($invocant)||$invocant;
    my $self={ @_ };
    bless $self,$class;
    return $self;
}

sub load_tlk
{
	my ($self, $file) = @_;
	
#	$_ = $file;
	$file =~ s/\\/\//g;
#	$file = $_;
	
	$self->{'file_path'} = $file;
	$self->{'file_name'} = (split(/\//, $file))[-1];
	
	open TLK, "<", $file;
	binmode TLK;
	
	sysseek TLK, 0, 0;
	sysread TLK, $self->{'version'}, 8;
	sysread TLK, (my $lang), 4;
	sysread TLK, (my $scount), 4;
	sysread TLK, (my $soffset), 4;
	
	$self->{'language'}      = unpack('V', $lang);
	$self->{'string_count'}  = unpack('V', $scount);
	$self->{'string_offset'} = unpack('V', $soffset);
	
	my $entry = undef;
	foreach $entry (0 .. ($self->{'string_count'} - 1))
	{
		sysseek TLK, 20 + (40 * $entry), 0;
		
		sysread TLK, (my $flags_packed), 4;
		sysread TLK, (my $sound_file), 16;
		sysread TLK, my $junk, 8;
		sysread TLK, (my $info_packed),8;
		sysread TLK, (my $length), 4;
		
		my ($offset2,$size)=unpack('V2',$info_packed);
		sysseek TLK, ($self->{'string_offset'} + $offset2),0;
		sysread TLK, $self->{$entry}{Text},$size;    

		$self->{$entry}{Flags}  = unpack('V', $flags_packed);
		$self->{$entry}{Sound}  = unpack('a16', $sound_file);
		$self->{$entry}{Size}   = $size;
#		$self->{$entry}{Volume} = 0; # unpack(, $volume);
#		$self->{$entry}{Pitch}  = 0; # unpack(, $pitch);
		$self->{$entry}{Length} = unpack('f', $length);
	}
	
	close TLK;
	return 1;
}

sub save_tlk
{
	my ($self, $saveas) = @_;
	
	if(defined($saveas) == 0) { $saveas = $self->{'file_path'}; }
	
	open TLK, ">", $saveas;
	binmode TLK;
	
	syswrite TLK, $self->{'version'};
	syswrite TLK, pack('V', $self->{'language'});
	syswrite TLK, pack('V', $self->{'string_count'});
	syswrite TLK, pack('V', 20 + (40 * $self->{'string_count'}));
	
	my $string_offset = 0; #20 + (40 * $self->{'string_count'});
	
	foreach(0 .. ($self->{'string_count'} - 1))
	{
		syswrite TLK, pack('V', $self->{$_}{Flags});
		syswrite TLK, pack('a16', $self->{$_}{Sound});
		syswrite TLK, pack('V', 0);
		syswrite TLK, pack('V', 0);
		syswrite TLK, pack('V', $string_offset);
		syswrite TLK, pack('V', length($self->{$_}{Text}));
		syswrite TLK, pack('f', $self->{$_}{Length});
		
		$string_offset += length($self->{$_}{Text});
	}
	
	foreach(0 .. ($self->{'string_count'} - 1))
	{
		syswrite TLK, $self->{$_}{Text};
	}
	
	close TLK;
}

sub edit_entry
{
	my ($self, $entry, $piece, $value) = @_;
	
	$self->{$entry}{$piece} = $value;
}

sub add_entry
{
	my ($self, $text, $sound, $flags, $length) = @_;
	
	my $exists = 0;
	my @array2 = ($text, $sound, $flags, $length);
	
	foreach my $entry (0 .. ($self->{'string_count'} - 1))
	{
		$exists = CompareEntries($entry, $self->{$entry}{Text}, $self->{$entry}{Sound}, $self->{$entry}{Flags}, $self->{$entry}{Length}, @array2);
		
		return (-1, $entry) if $exists == $entry;
	}
	
	my $max = $self->{'string_count'};
	$self->{'string_count'}++;
	
	$self->{$max}{Flags}  = $flags;
	$self->{$max}{Sound}  = $sound;
	$self->{$max}{Text}   = $text;
	$self->{$max}{Size}   = length($text);
	$self->{$max}{Length} = $length;
	
	return (1, $max);
}

sub delete_entry
{
	my ($self, $entry) = @_;
	
	if($entry != $self->{'string_count'})
	{
		foreach (($entry + 1) .. $self->{'string_count'})
		{
			$self->{($_ - 1)} = $self->{$_};
		}
		
		delete $self->{$self->{'string_count'}};
	}
	else
	{
		delete $self->{$self->{'string_count'}};
	}
	
	$self->{'string_count'}--;
}

sub delete_all_entries
{
	my $self = shift;
	
	foreach(0 .. ($self->{'string_count'} - 1))
	{
		delete $self->{$_};
	}
	
	$self->{'string_count'} = 0;
}

sub CompareEntries
{
	my $entry  = shift;
	my @entry1 = (shift, shift, shift, shift);
	my @entry2 = @_;

#	print "Entry $entry:\n";
#	print "Text: " .   $entry1[0] . " " . $entry2[0] . "\n";
#	print "Sound: " .  $entry1[1] . " " . $entry2[1] . "\n";
#	print "Flags: " .  $entry1[2] . " " . $entry2[2] . "\n";
#	print "Length: " . $entry1[3] . " " . $entry2[3] . "\n\n";
	
	# Array is: text, sound, flags, length
	if(($entry1[0] eq $entry2[0]) and
	   ($entry1[1] eq $entry2[1]) and 
	   ($entry1[2] eq $entry2[2]) and
	   ($entry1[3] eq $entry2[3]))
	{ return $entry; }
	else
	{ return -1; }
}

1;
