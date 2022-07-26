# TSLPatcherCLI as designed in Perl...
# Main script. Will use libraries TSLPatcher::GUI and TSLPatcher::FunctionsCLI.
###############################################################################

use experimental qw/smartmatch autoderef switch/;

use Config::IniMan;
use Cwd;

use lib 'lib/site';
use TSLPatcher::FunctionsCLI;
use TSLPatcher::GUI;

my $gamePath   = $ARGV[0];
my $modPath 	= $ARGV[1];
my $main_ini   = Config::IniMan->new("$modPath/tslpatcher.ini");
my $build_menu = 0;
my $answer     = 0;

my $username = $ENV{USERNAME};

print "\nGame Path: $gamePath\n";
print "\nMod Path: $modPath\n";

TSLPatcher::Functions::Set_Base($modPath);
TSLPatcher::GUI::Set_Base($modPath);

my $k1path = $main_ini->get('', 'KotOR1', '');
my $k2path = $main_ini->get('', 'KotOR2', '');

if($k1path ne '') { TSLPatcher::Functions::SetPathFromIni(1, $k1path); }
if($k2path ne '') { TSLPatcher::Functions::SetPathFromIni(2, $k2path); }

$build_menu = TSLPatcher::Functions::NeedBuildMenu;

my ($GUI, $options) = TSLPatcher::GUI::Create($build_menu, %{$main_ini->get_section()});

foreach (keys %{$options})
{ unless ($_ eq '') { $main_ini->set($_, $options->{$_}); } }

TSLPatcher::Functions::Set_GUI($GUI);

if($build_menu == 0)
{
	TSLPatcher::Functions::ProcessInstallPath;
}
else
{
    $GUI->{bm}->Popup(-popover=>undef, -overanchor=>'c', -popanchor=>'c');
	TSLPatcher::Functions::PopulateBuildMenu;
}

$GUI->{mw}->MainLoop();

my ($ggame, $gpath) = TSLPatcher::Functions::GetPathForIni();
$main_ini->set("KotOR$ggame", $gpath);
$main_ini->write("$modPath/tslpatcher.ini");