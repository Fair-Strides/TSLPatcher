#line 1 "Bioware/SSF.pm"
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
package Bioware::SSF; #~~~~~~~~~~~~~~~
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#use strict;
use File::Temp qw( tempfile );
require Exporter;
use vars qw ($VERSION @ISA @EXPORT);
$VERSION=1.0;

@ISA    = qw(Exporter);

# export functions/variables
@EXPORT = qw(  );


# define globals (use vars)
my @strings = ('Battlecry 1', 'Battlecry 2', 'Battlecry 3', 'Battlecry 4', 'Battlecry 5', 'Battlecry 6', 'Selected 1', 	'Selected 2', 'Selected 3', 'Attack 1', 'Attack 2', 'Attack 3', 'Pain 1', 'Pain 2', 'Low health', 'Death', 'Critical hit', 'Target immune', 'Place mine', 'Disarm mine', 'Stealth on', 'Search', 'Pick lock start', 'Pick lock fail', 'Pick lock done', 'Leave party', 'Rejoin party', 'Poisoned', 'Unknown (29)', 'Unknown (30)', 'Unknown (31)', 'Unknown (32)', 'Unknown (33)', 'Unknown (34)', 'Unknown (35)', 'Unknown (36)', 'Unknown (37)', 'Unknown (38)', 'Unknown (39)', 'Unknown (40)');

sub new {
    #this is a generic constructor method
    

    my $invocant=shift;
    my $class=ref($invocant)||$invocant;
    my $self={ @_ };
    bless $self,$class;
    return $self;
}

sub load_ssf
{
	my ($self, $file) = @_;

	$self->{'Battlecry 1'}     = 0;
	$self->{'Battlecry 2'}     = 0;
	$self->{'Battlecry 3'}     = 0;
	$self->{'Battlecry 4'}     = 0;
	$self->{'Battlecry 5'}     = 0;
	$self->{'Battlecry 6'}     = 0;
	$self->{'Selected 1'}      = 0;
	$self->{'Selected 2'}      = 0;
	$self->{'Selected 3'}      = 0;
	$self->{'Attack 1'}        = 0;
	$self->{'Attack 2'}        = 0;
	$self->{'Attack 3'}        = 0;
	$self->{'Pain 1'}          = 0;
	$self->{'Pain 2'}          = 0;
	$self->{'Low health'}      = 0;
	$self->{'Death'}           = 0;
	$self->{'Critical hit'}    = 0;
	$self->{'Target immune'}   = 0;
	$self->{'Place mine'}      = 0;
	$self->{'Disarm mine'}     = 0;
	$self->{'Stealth on'}      = 0;
	$self->{'Search'}          = 0;
	$self->{'Pick lock start'} = 0;
	$self->{'Pick lock fail'}  = 0;
	$self->{'Pick lock done'}  = 0;
	$self->{'Leave party'}     = 0;
	$self->{'Rejoin party'}    = 0;
	$self->{'Poisoned'}        = 0;
	$self->{'Unknown (29)'}    = 0;
	$self->{'Unknown (30)'}    = 0;
	$self->{'Unknown (31)'}    = 0;
	$self->{'Unknown (32)'}    = 0;
	$self->{'Unknown (33)'}    = 0;
	$self->{'Unknown (34)'}    = 0;
	$self->{'Unknown (35)'}    = 0;
	$self->{'Unknown (36)'}    = 0;
	$self->{'Unknown (37)'}    = 0;
	$self->{'Unknown (38)'}    = 0;
	$self->{'Unknown (39)'}    = 0;
	$self->{'Unknown (40)'}    = 0;
	
	open FH, "<", $file;
	binmode FH;
	
	$self->{filename} = $file;
	
	my ($filetype, $fileversion, $offset) = (undef, undef, undef);
	sysread FH, $filetype, 4;
	sysread FH, $fileversion, 4;
	sysread FH, $offset, 4;
	
	if(($filetype ne 'SSF ') or ($fileversion ne 'V1.1')) { return 0; }
	
	$offset = unpack('V', $offset);
	$self->{offset} = $offset;
	
	sysseek FH, $offset, 0;
	
	my $buffer = undef;
	foreach(@strings)
	{
		sysread FH, $buffer, 4;
		$self->{$_} = unpack('V', $buffer);
	}
	
	close FH;
	return 1;
}

sub save_ssf
{
	my ($self, $file) = @_;
	
	open FH, ">", $file;
	binmode FH;
	
	syswrite FH, "SSF V1.1";
	syswrite FH, pack('V', $self->{offset});
	
	foreach(@strings)
	{
		syswrite FH, pack('V', $self->{$_});
	}
	
	close FH;
}

sub set_entry
{
	my ($self, $entry, $value) = @_;

	$self->{$entry} = $value;
}

1;