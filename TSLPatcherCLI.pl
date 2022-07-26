# TSLPatcherCLI as designed in Perl...
# Main script. Will use libraries TSLPatcher::GUI and TSLPatcher::FunctionsCLI.
###############################################################################

use experimental qw/smartmatch autoderef switch/;

use Config::IniMan;
use Cwd;

use lib 'lib/site';
use TSLPatcher::FunctionsCLI;

my $gamePath   		= $ARGV[0]; # swkotor directory
my $modPath 		= $ARGV[1]; # mod directory (folder where TSLPatcher lives)
my $installOption 	= $ARGV[2]; # Array index for mods with install options
my $main_ini   		= Config::IniMan->new("$modPath/tslpatcher.ini");
my $build_menu 		= 0;

print "\n~~~ Game Path: $gamePath\n~~~ Mod Path: $modPath\n\n";

# Sets the base paths for the FunctionsCLI library
TSLPatcher::FunctionsCLI::Set_Base($modPath);

# Sets game paths
TSLPatcher::FunctionsCLI::SetPathFromIni(1, $gamePath);
TSLPatcher::FunctionsCLI::SetPathFromIni(2, $gamePath);

# If there are install options, build menu == 1;
# $build_menu = TSLPatcher::FunctionsCLI::NeedBuildMenu;

# With install options: Run ProcessNamespaces, SetInstallOption, RunInstallOption, Install
# Without install options: Run ProcessInstallPath, Install
if ($installOption eq "") {
	TSLPatcher::FunctionsCLI::ProcessInstallPath;
	TSLPatcher::FunctionsCLI::Install;
} else {
	TSLPatcher::FunctionsCLI::ProcessNamespaces;
	TSLPatcher::FunctionsCLI::SetInstallOption($installOption);
	TSLPatcher::FunctionsCLI::RunInstallOption;
	TSLPatcher::FunctionsCLI::Install;
}
