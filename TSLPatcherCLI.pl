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

print "\n~~~ Game Path: $gamePath\n";
print "~~~ Mod Path: $modPath\n\n";

TSLPatcher::FunctionsCLI::Set_Base($modPath);
# TSLPatcher::GUI::Set_Base($modPath);

# my $k1path = $main_ini->get('', 'KotOR1', '');
# my $k2path = $main_ini->get('', 'KotOR2', '');

# if($k1path ne '') { TSLPatcher::Functions::SetPathFromIni(1, $k1path); }
# if($k2path ne '') { TSLPatcher::Functions::SetPathFromIni(2, $k2path); }

TSLPatcher::FunctionsCLI::SetPathFromIni(1, $gamePath);
TSLPatcher::FunctionsCLI::SetPathFromIni(2, $gamePath);

$build_menu = TSLPatcher::FunctionsCLI::NeedBuildMenu;

# Uses GUI options to determine title and geometry
# my ($GUI, $options) = TSLPatcher::GUI::Create($build_menu, %{$main_ini->get_section()});

foreach (keys %{$options})
{ unless ($_ eq '') { $main_ini->set($_, $options->{$_}); } }

# TSLPatcher::Functions::Set_GUI($GUI);

# If there are install options, build menu == 1;

# With install options: Run SetInstallOption, RunInstallOption, ProcessInstallPath, Install
# Without install options: Run ProcessInstallPath, Install
# if($build_menu == 0)
# {
# 	TSLPatcher::Functions::ProcessInstallPath;
# }
# else
# {
#     $GUI->{bm}->Popup(-popover=>undef, -overanchor=>'c', -popanchor=>'c');
# 	TSLPatcher::Functions::PopulateBuildMenu;
# }

TSLPatcher::FunctionsCLI::ProcessInstallPath;
TSLPatcher::FunctionsCLI::Install;

# Activates GUI
# $GUI->{mw}->MainLoop();

my ($ggame, $gpath) = TSLPatcher::FunctionsCLI::GetPathForIni();
$main_ini->set("KotOR$ggame", $gpath);
$main_ini->write("$modPath/tslpatcher.ini");