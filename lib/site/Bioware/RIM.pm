#line 1 "Bioware/RIM.pm"
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
package Bioware::RIM; #~~~~~~~~~~~~~~~
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
use strict;
use Bioware::GFF;
require Exporter;
use vars qw ($VERSION @ISA @EXPORT);
$VERSION=0.01;

@ISA    = qw(Exporter);

# export functions/variables
@EXPORT = qw(  );


# define globals (use vars)

#private vars
our %res_types =(
0x0000 => 'res', 	#Misc. GFF resources
0x0001 => 'bmp', 	#Microsoft Windows Bitmap
0x0002 => 'mve',
0x0003 => 'tga', 	#Targa Graphics Format
0x0004 => 'wav', 	#Wave
0x0006 => 'plt', 	#Bioware Packed Layer Texture
0x0007 => 'ini', 	#Windows INI
0x0008 => 'mp3', 	#MP3
0x0009 => 'mpg', 	#MPEG
0x000A => 'txt', 	#Text file
0x000B => 'wma', 	#Windows Media audio?
0x000C => 'wmv', 	#Windows Media video?
0x000D => 'xmv',
0x07D0 => 'plh',
0x07D1 => 'tex',
0x07D2 => 'mdl', 	#Model
0x07D3 => 'thg',
0x07D5 => 'fnt', 	#Font
0x07D7 => 'lua',
0x07D8 => 'slt',
0x07D9 => 'nss', 	#NWScript source code
0x07DA => 'ncs', 	#NWScript bytecode
0x07DB => 'mod', 	#Module
0x07DC => 'are', 	#Area (GFF)
0x07DD => 'set', 	#Tileset (unused in KOTOR?)
0x07DE => 'ifo', 	#Module information
0x07DF => 'bic', 	#Character sheet (unused)
0x07E0 => 'wok', 	# walk-mesh
0x07E1 => '2da', 	#2-dimensional array
0x07E2 => 'tlk', 	#conversation file
0x07E6 => 'txi', 	#Texture information
0x07E7 => 'git', 	#Dynamic area information, game instance file, all area and objects that are scriptable
0x07E8 => 'bti',
0x07E9 => 'uti', 	#item blueprint
0x07EA => 'btc',
0x07EB => 'utc', 	#Creature blueprint
0x07ED => 'dlg', 	#Dialogue
0x07EE => 'itp', 	#tile blueprint pallet file
0x07EF => 'btt',
0x07F0 => 'utt', 	#trigger blueprint
0x07F1 => 'dds', 	#compressed texture file
0x07F2 => 'bts',
0x07F3 => 'uts', 	#sound blueprint
0x07F4 => 'ltr', 	#letter combo probability info
0x07F5 => 'gff', 	#Generic File Format
0x07F6 => 'fac', 	#faction file
0x07F7 => 'bte',
0x07F8 => 'ute', 	#encounter blueprint
0x07F9 => 'btd',
0x07FA => 'utd', 	#door blueprint
0x07FB => 'btp',
0x07FC => 'utp', 	#placeable object blueprint
0x07FD => 'dft', 	#default values file (text-ini)
0x07FE => 'gic', 	#game instance comments
0x07FF => 'gui', 	#GUI definition (GFF)
0x0800 => 'css',
0x0801 => 'ccs',
0x0802 => 'btm',
0x0803 => 'utm', 	#store merchant blueprint
0x0804 => 'dwk', 	#door walkmesh
0x0805 => 'pwk', 	#placeable object walkmesh
0x0806 => 'btg',
0x0807 => 'utg',
0x0808 => 'jrl', 	#Journal
0x0809 => 'sav', 	#Saved game (ERF)
0x080A => 'utw', 	#waypoint blueprint
0x080B => '4pc',
0x080C => 'ssf', 	#sound set file
0x080D => 'hak', 	#Hak pak (unused)
0x080E => 'nwm',
0x080F => 'bik', 	#movie file (bik format)
0x0810 => 'ndb',        #script debugger file
0x0811 => 'ptm',        #plot manager/plot instance
0x0812 => 'ptt',        #plot wizard blueprint
0x0BB8 => 'lyt',
0x0BB9 => 'vis',
0x0BBA => 'rim', 	#See RIM File Format
0x0BBB => 'pth', 	#Path information? (GFF)
0x0BBC => 'lip',
0x0BBD => 'bwm',
0x0BBE => 'txb',
0x0BBF => 'tpc', 	#Texture
0x0BC0 => 'mdx',
0x0BC1 => 'rsv',
0x0BC2 => 'sig',
0x0BC3 => 'xbx',
0x270D => 'erf', 	#Encapsulated Resource Format
0x270E => 'bif',
0x270F => 'key');

sub make_new_from_folder
{
	my ($folder, $saveas) = @_;
	
	my %file_data = ();

	my $res_id       = 0;
	my $entry_count  = 0;
	my $resource_off = 0;

	
	$_ = $folder;
	s/\\/\//g;
	$folder = $_;
	opendir DIR, $folder;
	my @files = grep { -f } map {"$folder/$_"} readdir DIR;
	closedir DIR;

	my $s = 0;
	%res_types = reverse %res_types;
	my $file = undef;
	foreach $file (@files)
	{
		my ($name, $ext) = (undef, undef);

		$_ = $file;
		s/\\/\//g;
		$file = $_;

		my $filename = (split(/\//, $file))[-1];
		$_ = $filename;
		/(.*)\.(.*)/;
		$name = $1;
		$ext  = $2;
		
		$file_data{$res_id}{ResRef}  = $name;
		$file_data{$res_id}{ResType} = $res_types{$ext};

#		print "File: $file - Size: " . (-s $file) . "\n\n";		
		$s += (-s $file);
		
		open FH, "<", $file;
		binmode FH;
#		print "File: $file - Size: " . (-s FH) . "\n\n";
		sysread FH, $file_data{$res_id}{Data}, (-s FH);
		$file_data{$res_id}{Size} = (-s FH);

		close FH;
		#unlink($file);
		$res_id++;
	}
	$s += ((32 * $res_id) + 120);
	print "here: $s\n";

	$entry_count = $res_id;
	$res_id--;
	$resource_off = 120; #(32 * $entry_count) + 120;
	my $resource_fileoff = (32 * $entry_count) + 120;

	open RIM, ">", $saveas;
	binmode RIM;
	
	syswrite RIM, "RIM V1.0";
	syswrite RIM, pack('V', 0);
	syswrite RIM, pack('V', $entry_count);
	syswrite RIM, pack('V', $resource_off);
	syswrite RIM, pack("x100", 0);
	
	foreach(sort { $a<=>$b } keys %file_data)#0 .. $res_id)
	{
#print "Res $res_id " . $file_data{$_}{ResRef} . " Type " . $file_data{$_}{ResType} . " Offset before is $resource_fileoff\n";
		syswrite RIM, pack('a16', pack('Z16', $file_data{$_}{ResRef}));
		syswrite RIM, pack('V', $file_data{$_}{ResType});
		syswrite RIM, pack('V', $_);
		syswrite RIM, pack('V', $resource_fileoff);
		syswrite RIM, pack('V', $file_data{$_}{Size});
		
		$resource_fileoff += $file_data{$_}{Size};
#print "Res $res_id Offset now $resource_fileoff\n";
	}
	
	foreach(sort { $a<=>$b } keys %file_data)
	{
		syswrite RIM, $file_data{$_}{Data};
	}
	
	close RIM;
	
	%res_types = reverse %res_types;
}

sub new {
    #this is a generic constructor method
    my $invocant=shift;
    my $class=ref($invocant)||$invocant;
    my $self={ @_ };
    bless $self,$class;
    return $self;
}
sub read_rim {
    #--------------------------
    #this method returns everything except acutal resource data from ERF
    #INPUTS: ERF filename
    #OUTPUTS: 1 on success, 0 on failure
    #--------------------------
    my $self=shift;
    my $rim_filename=shift; my $y = shift;
    (open my ($fh), "<", $rim_filename) or (return 0);
    binmode $fh;
    #aux info
    $self->{'rim_filename'}=$rim_filename;
    #header
    sysread $fh,$self->{'sig'},4;                #offset 0
    sysread $fh,$self->{'version'},4;            #offset 4
    sysseek $fh,4,1;
    sysread $fh, my ($rim_info_packed),8;        #offset 12
    ($self->{'res_count'},$self->{'keyoffset'})=unpack('V2',$rim_info_packed);
    my @resources; my @files;
    for (my $res_id=0; $res_id<$self->{'res_count'}; $res_id++){
        sysseek $fh, $self->{'keyoffset'} +  (32 * $res_id), 0;
        sysread $fh, my ($key_packed), 32;
        my ($res_name,$res_type,$res_id2,$res_offset,$res_size)=unpack('a16V4',$key_packed);
        $res_name=~s/\W+//g;
        my $hashref={'res_ref'=>$res_name,
                     'res_id'=>$res_id,
                     'res_type'=>$res_type,
                     'res_ext'=>$res_types{$res_type},
                     'res_offset'=>$res_offset,
                     'res_size'=>$res_size};
        push @resources,$hashref; push @files, "$res_name\." . $res_types{$res_type}; if($y == 1) { print "$res_name." . $res_types{$res_type} . "\n"; }
    }
    $self->{Files}=\@files;# print "::\n" . join "\n", @files;
    $self->{'resources'}=[@resources];
    close $fh;
    return 1;
}

sub getfiles
{
    my $self = shift;
    my $a = $self->{Files};
#    print "Rim:\n" . join "\n", @$a;
    return @$a;
}
sub load_rim_resource_by_index () {
    my $self=shift;
    my $res_ix=shift;
    return -1 unless defined ($res_ix);

    (open my ($in_fh),"<", $self->{'rim_filename'})  or (return -3);
    binmode $in_fh;
    sysseek $in_fh, $self->{'resources'}[$res_ix]{'res_offset'},0;
    my $total_read=sysread $in_fh,
                    $self->{'resources'}[$res_ix]{'res_data'},
                    $self->{'resources'}[$res_ix]{'res_size'};
    close $in_fh;
    return $total_read;

}

sub export_resource_by_index  {
    my ($self, $res_ix, $output_filepath)=@_;
    return 0 unless defined $res_ix;
    my $resource=$self->{'resources'}[$res_ix];
    #my $resource_name = lc "$resource->{'res_ref'}.$resource->{'res_ext'}";
    (open my ($out_fh),">",$output_filepath) or (return 0);
    binmode $out_fh;
    my $written;
    if ($resource->{'res_data'}) {
        $written=syswrite $out_fh, $resource->{'res_data'};
    }
    else {
        (open my ($in_fh),"<", $self->{'rim_filename'})  or (return -3);
        binmode $in_fh;
        sysseek $in_fh, $self->{'resources'}[$res_ix]{'res_offset'},0;

        my $chunk;
        my $bytes_to_read=$self->{'resources'}[$res_ix]{'res_size'};

        sysread $in_fh, $chunk, $bytes_to_read;
        $written += syswrite $out_fh,$chunk;

        close $in_fh;
    }
    close $out_fh;

#   Added by Fair Strides later for future projects. Commented out to avoid interfering with KSE.
#    my $old = $_;
#    $_ = $output_filepath;
#    /(...)$/;
#    my $t = $1;
#    $_ = $old;

#    if($t ~~ ["dlg", "utc", "utd", "ute", "uti", "utm", "utp", "uts", "utt", "utw", "fac", "are", "git", "ifo", "vis", "pth"])
#    {
#        my $gff = Bioware::GFF->new();
#        $gff->read_gff_file($output_filepath);
#        $written = $gff->write_gff_file($output_filepath);
#    }

    return $written;

}

sub get_resource_id_by_name{
    #-----------------------------------------------------
    # this private sub will return the resource id
    # (which is also the index in 'resources' array)
    # given then name of the resource
    # INPUTS: resource name (incl. extension)
    # OUTPUTS: index number on success, undef on failure
    #-----------------------------------------------------
    my $self=shift;
    my $resource_name=shift;
    $resource_name= lc $resource_name;
    for my $resource (@{$self->{'resources'}}) {
        my $res_check = lc "$resource->{'res_ref'}.$resource->{'res_ext'}";
        if ($resource_name eq $res_check) {
            return $resource->{'res_id'};
        }
    }
    return undef;
}

sub get_resource_id_by_type{
    #-----------------------------------------------------
    # this private sub wil return the first resource that
    # matches the type given.
    # INPUTS: resource type(extension)'
    # OUTPUTS: index number on success, undef on failure
    #-----------------------------------------------------
    my $self = shift;
    my $type = shift;

    for my $resource (@{$self->{'resources'}}) {
        if($resource->{'res_ext'} eq $type)
        {
            my @data = ($resource->{'res_ref'} . "\.$type", $resource->{'res_id'});
            return @data;
        }
    }
    return undef;
}

sub get_resources_by_type
{
    my $self = shift;
    my $type = shift;

    my @resources;
    for my $resource (@{$self->{'resources'}})
    {
        if($resource->{'res_ext'} eq $type)
        { push(@resources, $resource->{'res_id'}); }
    }

    return @resources;
}
#-----------------------------------
#  subroutines below this line have not been RIMified!
#-----------------------------------

sub import_resource {

    #-------------------------
    # this method will read a resource from a file
    # and put it into the ERF. if an identical resource
    # (res_ref + res_type) exists in the erf, it will
    # be replaced.
    # INPUTS: filename, store_as
    # OUTPUTS: 1 on success, 0 on failure
    #-------------------------
    my $self=shift;
    my $new_resource_file=shift;
    my $store_as=shift;
    return 0 unless ($new_resource_file);
    unless ($store_as) { $store_as = (split /\\/,$new_resource_file)[-1] }
    my $res_ix=$self->get_resource_id_by_name($store_as);
    (open my ($in_fh),"<",$new_resource_file) or (return 0);
    binmode $in_fh;
    if (defined $res_ix) {
        sysread $in_fh,
                $self->{'resources'}[$res_ix]{'res_data'},
                (-s $in_fh);

    }
    else {
        $store_as=~/(.*)\.(.*)/;
        my $new_res_ref=$1;
        my $new_ext=$2;
        my %reversed = reverse %res_types;
        unless (exists $reversed{$new_ext}) {
            close $in_fh;
            return 0;
        }
        my $new_res_type=$reversed{$new_ext};
        $res_ix=scalar @{$self->{'resources'}};
        my $new_offset=$self->{resources}[$res_ix-1]{'res_offset'}+$self->{resources}[$res_ix-1]{'res_size'};
        my $hashref={'res_ref'=>$new_res_ref,
                     'res_id'=>$res_ix,
                     'res_type'=>$new_res_type,
                     'res_ext'=>$new_ext,
                     'res_offset'=>$new_offset,
                     'res_size'=>0};
        push @{$self->{'resources'}}, $hashref;
        sysread $in_fh,
                $self->{'resources'}[$res_ix]{'res_data'},
                (-s $in_fh);
    }
    close $in_fh;
    $self->{'resources'}[$res_ix]{'is_new'}=1;
    $self->recalculate_packing();
    return 1;
}
sub recalculate_packing {
    #---------------------------------------
    # this method determines the size of each res_data,
    # adjusts the res_size accordingly, and readjusts
    # res_offsets
    # INPUTS: none
    # OUTPUTS: none
    #---------------------------------------
    my $self=shift;


    # tune entry count
    $self->{'res_count'}=scalar @{$self->{'resources'}};
    $self->{'offset_to_resource_list'}=$self->{'offset_to_key_list'}+(24* $self->{'entry_count'});
    my $offset_to_resource_data=$self->{'offset_to_resource_list'} + (8* $self->{'entry_count'});

    # tune resource list

    my $prev_resource_offset=$offset_to_resource_data;
    my $prev_resource_length=0;
    my $prev_resource_offset_memory=$offset_to_resource_data;
    my $prev_resource_length_memory=0;
    for my $resource (@{$self->{'resources'}}) {
        $resource->{'res_offset'}=$prev_resource_offset+$prev_resource_length;
        $resource->{'new_offset'}=$prev_resource_offset_memory+$prev_resource_length_memory;
        if (length($resource->{'res_data'})) {
            $resource->{'res_size'}=length $resource->{'res_data'};
            $resource->{'new_size'}=length($resource->{'res_data'});
        }
        if (length($resource->{'new_data'})) {
            $resource->{'new_size'}=length($resource->{'new_data'});
        }
        $prev_resource_offset=$resource->{'res_offset'};
        $prev_resource_offset_memory=$resource->{'new_offset'};
        $prev_resource_length=$resource->{'res_size'};
        $prev_resource_length_memory=$resource->{'new_size'};
    }
    return;
}

1;