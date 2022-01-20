# TSLPatcher as designed in Perl...
# Main script. Will use libraries TSLPatcher::GUI and TSLPatcher::Functions.
###############################################################################

use experimental qw/smartmatch autoderef switch/;

use Config::IniMan;
use Cwd;

use TSLPatcher::Functions;
use TSLPatcher::GUI;

my $base       = getcwd;
my $main_ini   = Config::IniMan->new("$base/tslpatcher.ini");
my $build_menu = 0;
my $answer     = 0;

TSLPatcher::Functions::Set_Base($base);
TSLPatcher::GUI::Set_Base($base);

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
$main_ini->write("$base/tslpatcher.ini");