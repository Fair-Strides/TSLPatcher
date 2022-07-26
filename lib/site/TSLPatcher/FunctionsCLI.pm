package TSLPatcher::FunctionsCLI;

use Bioware::BIF;
use Bioware::ERF;
use Bioware::GFF;
use Bioware::RIM;
use Bioware::SSF;
use Bioware::TLK;
use Bioware::TwoDA;

use Config::IniMan;

use constant {
	LOG_LEVEL_VERBOSE     => 1,
	LOG_LEVEL_ERROR       => 2,
	LOG_LEVEL_ALERT       => 3,
	LOG_LEVEL_INFORMATION => 4,
	LOG_LEVEL_NOTICE      => 5,
	ACTION_ADD_ROW    => 1,
	ACTION_MODIFY_ROW => 2,
	ACTION_COPY_ROW   => 3,
	ACTION_ADD_COLUMN => 4,
	ACTION_ADD_FIELD  => 5,
	TLK_TYPE_NORMAL => 1,
	TLK_TYPE_FEMALE => 2
	};

use experimental qw/smartmatch autoderef switch/;

use File::Copy;
use File::Find;
use File::Path qw/make_path remove_tree/;

use Math::Round;

#use RTF::HTMLConverter;

use Scalar::Util qw/looks_like_number/;

use TSLPatcher::GUI;

#use XML::GDOME;

use utf8;

my $user = getlogin || getpwuid($<);
my $base    = undef;
my $game1   = 0;
my $game2   = 0;
my $pathgame1 = '';
my $pathgame2 = '';
my $GUI     = undef;

my $install_path = $base . '/tslpatchdata';
my $install_info = 'info.rtf';
my $install_ini  = 'changes.ini';
my $install_dest_path = undef;
my $ini_object    = Config::IniMan->new();
my $uninstall_ini = Config::IniMan->new();
my $bInstalled   = 0;

my %Tokens       = ();
my @twoda_tokens = ();
my @ERFs         = ();

my %InstallInfo = (
FileExists => 0,
bInstall  => 0,
sMessage  => $Messages{LS_GUI_DEFAULTCONFIRMTEXT},
iLoglevel => 3,
bLogOld   => 0
);

my %ScriptInfo = (
OrgFile => undef,
ModFile => undef,
IsInclude => undef);

my $log_alerts = 0;
my $log_errors = 0;
my $log_count  = 0;
my $log_index  = 0;
my $log_text   = 0;
my $log_text_done = 0;
my $log_first  = 1;

my ($twoda_addnum,
	$twoda_chanum,
	$twoda_colnum,
	$twoda_delcolnum,
	$twoda_delnum) = (0, 0, 0, 0, 0);
	
my ($gff_delfnum,
	$gff_delnum,
	$gff_repnum) = (0, 0, 0);

# Patcher Messages
my %Messages = (
	# Miscellaneous
    LS_GUI_CONFIGMISSING      => 'WARNING! Cannot locate the INI file "%s1" with work instructions!',
    LS_GUI_DEFAULTCAPTION     => 'Game Data Patcher for KotOR/TSL',
    LS_GUI_SBARINSTALLDEST    => 'Game folder: %s1',
    LS_GUI_SBARINSTALLUSERSEL => 'User selected.',
    LS_GUI_INFOLOADERROR      => 'Unable to load the instructions text! Make sure the "tslpatchdata" folder containing the "%s1" file is located in the same folder as this application.',
    LS_GUI_BUTTONCAPINSTALL   => 'Install Mod',
    LS_GUI_BUTTONCAPPATCH     => 'Start patching',
    LS_GUI_CONFIGLOADERROR    => 'Unable to load the %s1 file! Make sure the "tslpatchdata" folder is located in the same folder as this application.',
    LS_GUI_DEFAULTCONFIRMTEXT => 'This will start patching the necessary game files. Do you want to do this?',
    LS_GUI_SUMMARY            => 'The Installer is finished. Please check the progress log for details about what has been done.',
    LS_GUI_SUMMARYWARN        => 'The Installer is finished, but %s1 warnings were encountered! The Mod may or may not be properly installed. Please check the progress log for further details.',
    LS_GUI_SUMMARYERROR       => 'The Installer is finished, but %s1 errors were encountered! The Mod has likely not been properly installed. Please check the progress log for further details.',
    LS_GUI_SUMMARYERRORWARN   => 'The Installer is finished, but %s1 errors and %s2 warnings were encountered! The Mod most likely has not been properly installed. Please check the progress log for further details.',
    LS_GUI_PSUMMARY           => 'The Patcher is finished. Please check the progress log for details about what has been done.',
    LS_GUI_PSUMMARYWARN       => 'The Patcher is finished, but %s1 warnings were encountered! The Mod may or may not be properly installed. Please check the progress log for further details.',
    LS_GUI_PSUMMARYERROR      => 'The Patcher is finished, but %s1 errors were encountered! The Mod has likely not been properly installed. Please check the progress log for further details.',
    LS_GUI_PSUMMARYERRORWARN  => 'The Patcher is finished, but %s1 errors and %s2 warnings were encountered! The Mod most likely has not been properly installed. Please check the progress log for further details.',
    LS_GUI_EXCEPTIONPREFIX    => 'An error occured! %s1',
    LS_GUI_UEXCEPTIONPREFIX   => 'An unhandled error occured! ',
    LS_GUI_CONFIRMQUIT        => 'Are you sure you wish to quit?',

    # Configuration summary
    LS_GUI_REPTITLE           => 'CONFIGURATION SUMMARY',
    LS_GUI_REPSETTINGS        => 'Settings',
    LS_GUI_REPCONFIGFILE      => 'Config file',
    LS_GUI_REPINFOFILE        => 'Information file',
    LS_GUI_REPINSTALLOC       => 'Install location',
    LS_GUI_REPUSERSELECTED    => 'User selected.',
    LS_GUI_REPBACKUPS         => 'Make backups',
    LS_GUI_REPDOBACKUPS       => 'Before modifying/overwriting existing files.',
    LS_GUI_REPNOBACKUPS       => 'Disabled, no backups are made.',
    LS_GUI_REPLOGLEVEL0       => 'Log level: 0 - No progress log',
    LS_GUI_REPLOGLEVEL1       => 'Log level: 1 - Errors only',
    LS_GUI_REPLOGLEVEL2       => 'Log level: 2 - Errors and warnings only',
    LS_GUI_REPLOGLEVEL3       => 'Log level: 3 - Standard: Progress, errors and warnings.',
    LS_GUI_REPLOGLEVEL4       => 'Log level: 4 - Debug: Detailed progress, errors and warnings.',
    LS_GUI_REPTLKAPPEND       => 'dialog tlk appending',
    LS_GUI_REPNEWTLKCOUNT     => 'New entries',
    LS_GUI_REP2DATITLE        => '2DA file changes',
    LS_GUI_REP2DAFILE         => '%s1 - new rows: %s2, modified rows: %s3, new columns: %s4',
    LS_GUI_REPGFFTITLE        => 'GFF file changes',
    LS_GUI_REPNONE            => 'none',
    LS_GUI_REPOVERWRITE       => 'overwrite existing',
    LS_GUI_REPMODIFY          => 'modify existing',
    LS_GUI_REPSKIP            => 'skip existing',
    LS_GUI_REPLOCATION        => 'location',
    LS_GUI_REPHACKTITLE       => 'NCS file integer hacks',
    LS_GUI_REPCOMPILETITLE    => 'Modified & recompiled scripts',
    LS_GUI_REPSSFTITLE        => 'New/modified Soundset files',
    LS_GUI_REPINSTALLSTART    => 'Unpatched files to install',
    LS_GUI_REPINSTALLLOC      => 'Location',
    LS_GUI_REPGAMEFOLDER      => 'Game folder',
	
    # Run Patch Operation
    LS_LOG_RPOINSTALLSTART       => 'Installation started %s1...',
    LS_LOG_RPOPATCHSTART         => 'Patch operation started %s1...',
    LS_LOG_RPOSUMMARYWARN        => 'Done. Changes have been applied, but %s1 warnings were encountered.',
    LS_LOG_RPOSUMMARYERROR       => 'Done. Some changes may have been applied, but %s1 errors were encountered!',
    LS_LOG_RPOSUMMARYWARNERROR   => 'Done. Some changes may have been applied, but %s1 errors and %s2 warnings were encountered!',
    LS_LOG_RPOSUMMARY            => 'Done. All changes have been applied.',
    LS_LOG_RPOGENERALEXCEPTION   => 'Unhandled exception: %s1',

    # TLK file handler
    LS_LOG_LOADINGSTRREFTOKENS   => 'Loading StrRef token table...',
    LS_LOG_LOADEDSTRREFTOKENS    => '%s1 StrRef tokens found and indexed.',
    LS_EXC_TLKFILETYPEMISMATCH   => 'Internal error, invalid TLK file type specified. This should never happen.',
    LS_LOG_APPENDFEEDBACK        => 'Appending strings to TLK file "%s1"',
    LS_LOG_TLKENTRYMATCHEXIST    => 'Identical string for append StrRef %s1 found in %s2 StrRef %s3, reusing it instead.',
    LS_LOG_APPENDTLKENTRY        => 'Appending new entry to %s1, new StrRef is %s2',
    LS_LOG_MAKETLKBACKUP         => 'Saving unaltered backup copy of %s1 file in %s2',
    LS_LOG_TLKSUMMARY1           => '%s1 file updated with %s2 new entries, %s3 entries already existed.',
    LS_LOG_TLKSUMMARY2           => '%s1 file updated with %s2 new entries.',
    LS_LOG_TLKSUMMARY3           => '%s1 file not updated, all %s2 entries were already present.',
    LS_LOG_TLKSUMMARYWARNING     => 'Warning: No new entries appended to %s1. Possible missing entries in append.tlk referenced in the TLKList.',
    LS_LOG_TLKFILEMISSING        => 'Unable to load specified %s1 file! Aborting...',
    LS_EXC_TLKFILEMISSING        => 'No TLK file loaded. Unable to proceed.',
    LS_LOG_TLKNOTSELECTED        => 'No %s1 file specified. Unable to proceed!',
    LS_LOG_UNKNOWNSTRREFTOKEN    => 'Encountered StrRef token "%s1" in modifier list that was not present in the TLKList! Value set to StrRef #0.',

	# Install List Handler
	LS_LOG_INSSTART              => 'Installing unmodified files...',
	LS_LOG_INSDESTINVALID        => 'Destination file "%s1" does not appear to be a valid ERF or RIM archive! Skipping section...',
	LS_LOG_INSDESTNOTEXIST       => 'Destination file "%s1" does not exist at the specified location! Skipping section...',
	LS_LOG_INSCREATEFOLDER       => 'Folder %s1 did not exist, creating it...',
	LS_LOG_INSFOLDERCREATEFAIL   => 'Unable to create folder %s1! Skipping folder...',
	LS_LOG_INSBACKUPFILE         => 'Saving unaltered backup copy of destination file %s1 in %s2.',
	LS_LOG_INSNOEXEPLEASE        => 'Skipping file %s1, this Installer will not overwrite EXE files!',
	LS_LOG_INSENOUGHTLK          => 'Skipping file %s1, this Installer will not overwrite dialog.tlk directly.',
	LS_LOG_INSSKELETONKEY        => 'Skipping file %s1, this Installer will not overwrite the chitin.key file.',
	LS_LOG_INSBIFTHEUNDERSTUDY   => 'Skipping file %s1, this Installer will not overwrite BIF data files.',
	LS_LOG_INSREPLACERENAME      => 'Renaming and replacing file "%s1" to "%s2" in the %s folder...',
	LS_LOG_INSREPLACE            => 'Replacing file %s1 in the %s2 folder...',
	LS_LOG_INSLASKIP             => 'A file named %s1 already exists in the %s2 folder. Skipping file...',
	LS_LOG_INSRENAMECOPY         => 'Renaming and copying file "%s1" to "%s2" to the %s3 folder...',
	LS_LOG_INSCOPYFILE           => 'Copying file %s1 to the %s2 folder...',
	LS_LOG_INSREPLACERENAMEFILE  => 'Renaming and replacing file "%s1" to "%s2" in the %s3 archive...',
	LS_LOG_INSREPLACEFILE        => 'Replacing file %s1 in the %s2 archive...',
	LS_LOG_INSEXCEPTIONSKIP      => '%s Skipping...',
	LS_LOG_INSLASKIPFILE         => 'A file named %s1 already exists in the %s2 archive. Skipping file...',
	LS_LOG_INSRENAMEADDFILE      => 'Renaming and adding file "%s1" to "%s2" in the %s3 archive...',
	LS_LOG_INSADDFILE            => 'Adding file %s1 to the %s2 archive...',
	LS_LOG_INSCOPYFAILED         => 'Unable to copy file "%s1", file does not exist!',
	LS_LOG_INSNOMODIFIERS        => 'No install instructions (%s1) found for folder %s2.',
	LS_LOG_INSINVALIDDESTINATION => 'Invalid install location "%s1" encountered! Skipping...',

    # 2DA Handler
    LS_LOG_2DAFILENOTFOUND       => 'Unable to find 2DA file "%s1" to modify! Skipping file...',
    LS_LOG_2DAINVALIDMODIFIER    => 'Invalid modifier type "%s1" found for modifier label "%s2". Skipping...',
    LS_LOG_2DABACKUPFILE         => 'Saving unaltered backup copy of %s1 in %s2',
    LS_LOG_2DAFILEUPDATED        => 'Updated 2DA file %s1.',
    LS_LOG_2DALOADERROR          => 'Unable to load the 2DA file %s1! Skipping it...',
    LS_LOG_2DANOFILESELECTED     => 'No %s1 file was specified! Skipping it...',
    LS_LOG_EXCLUSIVECOLINVALID   => 'Invalid Exclusive column label "%s1" specified, ignoring...',
    LS_LOG_EXCLUSIVEMATCHFOUND   => 'Matching value in column %s1 found for existing row %s2...',
    LS_LOG_NOEXCLUSIVEVALUESET   => 'No value has been assigned to column %s1 for new 2DA line in modifier "%s2" with Exclusive checking enabled! Skipping line...',
    LS_LOG_2DAEXROWNOTFOUND      => 'Error locating row when trying to modify existing Exclusive row in modifier "%s1".',
    LS_LOG_2DAEXROWINDEXTOOHIGH  => 'Too high row-number encountered when trying to modify existing Exclusive row in modifier "%s1".',
    LS_LOG_2DAEXROWMATCH         => 'New Exclusive row matched line %s1 in 2DA file %s2, modifying existing line instead.',
    LS_LOG_2DAINVALIDCOLLABEL    => 'Invalid column label "%s1" encountered! Skipping entry...',
    LS_LOG_2DAHIGHTOKENRLFOUND   => 'Setting row label to next HIGHEST value %s1.',
    LS_LOG_2DAADDINGROW          => 'Adding new row (index %s1) to 2DA file %s2...',
    LS_LOG_2DASETROWLABELERROR   => 'Unable to set new row label "%s1" in modifier + "%s2"!',
    LS_LOG_2DAHIGHTOKENVALUE     => 'Setting added row column %s1 to next HIGHEST value %s2.',
    LS_LOG_2DAADDROWERROR        => 'An error occured while trying to add new line to 2DA in modifier "%s1"!',
    LS_LOG_2DANOLABELCOL         => '%s1 used as index when changing line in modifier "%s2" but 2DA file has no label column! Skipping...',
    LS_LOG_2DANONEXCLUSIVECOL    => 'Warning, multiple rows matching Label Index found! Last found row will be used...',
    LS_LOG_2DAMULTIMATCHINDEX    => 'Multiple matches for specified Label Index, previously found row %s1, now found row %s2.',
    LS_LOG_2DAMODIFYLINE         => 'Modifying line (index %s1) in 2DA file %s2...',
    LS_LOG_2DANOINDEXFOUND       => 'No RowIndex/RowLabel identifier for row to modify found at top of modifier list! Unable to apply modifier "%s1".',
    LS_LOG_2DAADDCOLUMN          => 'Adding new column to 2DA file %s1...',
    LS_LOG_2DACOLEXISTS          => 'A column with the label "%s1" already exists in %s1, unable to add new column!',
    LS_LOG_2DAINVALIDROWLABEL    => 'Invalid row label %s1 encountered! Skipping entry...',
    LS_LOG_2DANEWROWLABELHIGH    => 'Setting new row label to next HIGHEST value %s1.',
    LS_LOG_2DACOPYFAILED         => 'Error! Failed to copy line in 2DA! Skipping...',
    LS_LOG_2DACOPYINGLINE        => 'Copying line %s1 to new line %s2 in %s3.',
    LS_LOG_2DAINCTOPENCOPY       => 'Incrementing value of copied row for column %s1 by %s2, new value is %s3.',
    LS_LOG_2DAINCFAILED          => 'Row value increment failed! Specified modifier "%s1" is not a number. Old row value not changed.',
    LS_LOG_2DAINCFAILEDNONUM     => 'Row value increment failed! Specified row column does not contain a number. Old row value not changed.',
    LS_LOG_2DACOPYHIGH           => 'Setting copied row column %s1 to next HIGHEST value %s2.',

	# 2DAMEMORY token handler
    LS_LOG_TOKENERROR1           => 'Invalid 2DAMEMORY token found! Token indexes start at 1 and go up...',
    LS_LOG_TOKENERROR2           => 'Invalid memory token %s1 encountered, using first memory slot instead.',
    LS_LOG_TOKENFOUND            => 'Found a %s1 token! Storing value "%s2" from 2da to memory...',
    LS_LOG_TOKENLABELERROR       => 'Error looking up row label for row index %s1',
    LS_LOG_TOKENCOLUMNERROR      => 'Invalid column label "%s1" passed to %s2 key!',
    LS_LOG_TOKENCOLLABELERROR    => 'Error looking up column label for column index %s1',
    LS_LOG_INVALIDCOLLABEL       => 'Invalid column label passed to %s1 key!',
    LS_LOG_TOKENROWLERROR        => 'Invalid row label "%s1" passed to %s2 key!',
    LS_LOG_LINDEXTOKENFOUND      => 'Found a %s1 token! Storing ListIndex "%s2" from GFF to memory...',
    LS_LOG_FPATHTOKENFOUND       => 'Found a %s1 token! Storing Field Path "%s2" from GFF to memory...',
    LS_LOG_TOKENINDEXERROR1      => 'Invalid memory token %s1 encountered, assuming first memory slot.',
    LS_LOG_TOKENINDEXERROR2      => 'Invalid memory token %s1 encountered, unable to insert a proper value into cell or field!',
    LS_LOG_GETTOKENVALUE         => 'Found a %s1 value, substituting with value "%s2" in memory...',

    # Override fileexists check and response
    LS_LOG_OVRCHECKNOFILE        => 'Override check: No file with name "%s1" found in override folder.',
    LS_LOG_OVRCHECKEXISTWARN     => 'A file named %s1 already exists in the override folder! This may cause incompatibility with the one used by this mod!',
    LS_LOG_OVRCHECKRENAMED       => 'A file named %s1 already existed in the override folder! This existing file has been renamed to %s2 to allow the one in this Mod to be used!',
    LS_LOG_OVRRENAMEFAILED       => 'A file named %s1 already exists in the override folder! Renaming existing file to %s2 failed! The file might be write-protected or a file with the new name already exist.',
    LS_LOG_OVRCHECKSILENTWARN    => 'Warning: A file named %s1 already exists in the override folder. It will override the one in the ERF/RIM archive in-game.',

    # GFF file handler
    LS_LOG_GFFSECTIONMISSING     => 'Unable to locate section "%s1" when attempting to add GFF Field, skipping...',
    LS_LOG_GFFPARENTALERROR      => 'Parent field at "%s1" does not exist or is not a LIST or STRUCT! Unable to add new Field "%s2"...',
    LS_LOG_GFFMISSINGLABEL       => 'No field label has been specified for new field in section "%s1"! Unable to create field...',
    LS_LOG_GFFLABELEXISTS        => 'A Field with the label "%s1" already exists at "%s2", skipping it...',
    LS_LOG_GFFLABELEXISTSMOD     => 'A Field with the label "%s1" already exists at "%s2", modifying instead...',
    LS_LOG_GFFINVALIDSTRREF      => 'Invalid StrRef value "%s1" when attempting to add ExoLocString. Defaulting to -1...',
    LS_LOG_GFFINVALIDTYPEDATA    => 'Invalid field type "%s1" or data specified in section "%s2" when trying to add fields to %s3, skipping...',
    LS_LOG_GFFADDEDSTRUCT        => 'Added %s1, index %s2, at position "%s3"',
    LS_LOG_GFFADDEDFIELD         => 'Added %s1 field "%s2" at position "%s3"',
    LS_LOG_GFFPROCSUBFIELDS      => 'Processing new sub-fields at %s1.',
    LS_LOG_GFFMODIFYING          => 'Modifying GFF format files...',
    LS_LOG_GFFNOINSTRUCTION      => 'No instruction section found for file %s1, skipping...',
    LS_LOG_GFFMODIFYINGFILE      => 'Modifying GFF file %s1...',
    LS_LOG_GFFBLANKFIELDLABEL    => 'Blank Gff Field Label encountered in instructions, skipping...',
    LS_LOG_GFFNEWFIELDADDED      => 'Added new field to GFF file %s1...',
    LS_LOG_GFFBLANKVALUE         => 'Blank value encountered for GFF field label %s1, skipping...',
    LS_LOG_GFFMODIFIEDVALUE      => 'Modified value "%s1" to field "%s2" in %s3.',
    LS_LOG_GFFINCORRECTLABEL     => 'Unable to find a field label matching "%s1" in %s2, skipping...',
    LS_LOG_GFFBACKUPFILE         => 'Saving unaltered backup copy of %s1 file in %s2',
    LS_LOG_GFFBACKUPDEST         => 'Saving unaltered backup copy of destination file %s1 file in %s2',
    LS_LOG_GFFMODFIELDSUMMARY    => 'Modified %s1 fields in "%s2"...',
    LS_LOG_GFFINSERTDONE         => 'Finished updating GFF file "%s1" in "%s2"...',
    LS_LOG_GFFSAVEINERFORRIM     => 'Saving modified file "%s1" in archive "%s2".',
    LS_LOG_GFFUPDATEFINISHED     => 'Finished updating GFF file "%s1"...',
    LS_LOG_GFFNOCHANGES          => 'No changes could be applied to GFF file %s1.',
    LS_LOG_GFFNOMODIFIERS        => 'No GFF modifier instructions found for file %s1, skipping...',
    LS_LOG_GFFCANTLOADFILE       => 'Unable to load file %s1! Skipping...',
    LS_LOG_GFFNOFILEOPENED       => 'No valid %s1 file was opened, skipping...',
    LS_LOG_GFFMISSINGLISTSTRUCT  => 'Could not find struct to modify in parent list at %s1, unable to add new field!',

    # HACK List handler
    LS_LOG_HAKSTART              => 'Modifying binary files...',
    LS_LOG_HAKMODIFYFILE         => 'Modifying binary file "%s1"...',
    LS_LOG_HAKNOOFFSETS          => 'No offsets found for file %s1, skipping...',
    LS_LOG_HAKNOVALIDFILE        => 'No valid %s1 file found! Skipping file.',
    LS_LOG_HAKBACKUPFILE         => 'Saving unaltered backup copy of %s1 in %s2.',
    LS_LOG_HAKMODIFYINGDATA      => 'Modifying file %s1, setting value at offset "%s2" to "%s3".',
    LS_LOG_HAKINVALIDOFFSET      => 'Invalid offset(%s1) or value(%s2) modifier for file %s3. Skipping...',

    # Recompile file handler
    LS_LOG_NCSBEGINNING          => 'Modifying and compiling scripts...',
    LS_LOG_NCSCOMPILERMISSING    => 'Could not locate nwnsscomp.exe in the tslpatchdata folder! Unable to compile scripts!',
    LS_LOG_NCSPROCESSINGTOKENS   => 'Replacing tokens in script %s1...',
    LS_LOG_NCSCOMPILINGSCRIPT    => 'Compiling modified script %s1...',
    LS_LOG_NCSCOMPILEROUTPUT     => 'NWNNSSComp says: %s1',
    LS_LOG_NCSDESTBACKUP         => 'Saving unaltered backup copy of destination file %s1 in %s2',
    LS_LOG_NCSFILEEXISTSKIP      => 'File "%s1" already exists in archive "%s2", file skipped...',
    LS_LOG_NCSSAVEINERFORRIM     => 'Adding script "%s1" to archive "%s2"...',
    LS_LOG_NCSCOMPILEDNOTFOUND   => 'Unable to find compiled version of file "%s1"! The compilation probably failed! Skipping...',
    LS_LOG_NCSINCLUDEDETECTED    => 'Script "%s1" has no start function, assuming include file. Compile skipped...',
    LS_LOG_NCSPROCNSSMISSING     => 'Unable to find processed version of file %s1; cannot compile it!',
    LS_LOG_NCSSAVEERFRIM         => 'Saving changes to ERF/RIM file %s1...',

    # SSF file handler
    LS_LOG_SSFNOMODIFIERS        => 'File "%s1" has no modifier section specified! Skipping it...',
    LS_LOG_SSFFILENOTFOUND       => 'File %s1 could not be found! Skipping it...',
    LS_LOG_SSFMODSTRREFS         => 'Modifying StrRefs in Soundset file "%s1"...',
    LS_LOG_SSFSETTINGENTRY       => 'Setting Soundset entry "%s1" to %s2...',
    LS_LOG_SSFINVALIDSTRREF      => 'Unable to set StrRef for entry "%s1", %s2 is not a valid StrRef value!',
    LS_LOG_SSFUPDATESUMMARY      => 'Finished updating %s1 entries in file "%s2".',
    LS_LOG_SSFEXCEPTIONERRORS    => '%s1 [%s2] - file skipped!',
    LS_LOG_SSFNOFILE             => 'No %s1 file was specified! Skipping it...',

	# File handler
	LS_EXC_FHRENAMEFAILED        => 'Unable to locate source file "%s1" to rename to "%s2" and install, skipping...',
	LS_EXC_FHNODESTPATHSET       => 'Error! No install path has been set!',
	LS_EXC_FHNOSOURCEFILESET     => 'Error! No file to install is specified!',
	LS_EXC_FHSOURCEDONTEXIST     => 'Error! File "%s1" set to be patched does not exist!',
	LS_DLG_SELECTINSTALLFOLDER   => 'Please select the folder where your game is installed. (The folder containing the game executable.)',
	LS_EXC_FHINVALIDGAMEFOLDER   => 'Invalid game directory specified!',
	LS_EXC_FHTALKYMANNOTFOUND    => 'Invalid game folder specified, dialog.tlk file not found! Make sure you have selected the correct folder.',
	LS_LOG_FHINSTALLPATHSET      => 'Install path set to %s1.',
	LS_DLG_FILETYPETLK           => 'TLK file %s1',
	LS_DLG_FILETYPE2DA           => '2DA file %s1',
	LS_DLG_FILETYPENSS           => 'NSS Script Source %s1',
	LS_DLG_FILETYPESSF           => 'SSF Soundset file %s1',
    LS_DLG_FILETYPEITM           => 'Item template %s1',
    LS_DLG_FILETYPEUTC           => 'Creature template %s1',
    LS_DLG_FILETYPEUTM           => 'Store template %s1',
    LS_DLG_FILETYPEUTP           => 'Placeable template %s1',
    LS_DLG_FILETYPEDLG           => 'Dialog file %s1',
    LS_DLG_FILETYPEGFF           => 'GFF format file %s1',
    LS_DLG_FILETYPEALL           => 'All files %s1',
	LS_DLG_FILESELECTDESC        => 'Please select your %s1 file.',
	LS_DLG_FILESELECTDESCMOD     => 'Please select the %s1 file that came with this Mod.',
	LS_DLG_FILEWORD              => '%s1 File',
	LS_EXC_FHNODESTSELECTED      => 'Error! No valid game folder selected! Installation aborted.',
	LS_EXC_FHREQFILEMISSING      => 'Cannot locate required file %s1, unable to continue with install!',
	LS_EXC_FHTLKFILEMISSING      => 'Error! Unable to locate TLK file to patch, "%s1" file not found!',
	LS_LOG_FHDESTFILENOTFOUND    => 'Unable to locate archive "%s1" to modify or insert file "%s2" into, skipping...',
	LS_LOG_FHDESTNOTFOUNDEXC     => 'Unable to load archive "%s1" to modify or insert file "%s2" into, skipping... (%s3)',
	LS_LOG_FHCANNOTLOADDEST      => 'Unable to load archive "%s1" to insert file "%s2" into, skipping...',
	LS_LOG_FHDESTRESEXISTMOD     => 'File "%s1" already exists in archive "%s2", modifying existing file...',
	LS_LOG_FHSOURCENOTFOUND      => 'Unable to locate file "%s1" to rename to "%s2" and install, skipping...',
	LS_LOG_FHADDTODEST           => 'Adding file "%s1" to archive "%s2"...',
	LS_LOG_FHTEMPFILEFAILED      => 'Unable to make work copy of file "%s1". File not saved to ERF/RIM archive!',
	LS_LOG_FHMAKEOVERRIDE        => 'No Override folder found, creating it at %s1.',
	LS_LOG_FHMISSINGARCHIVE      => 'Unable to locate archive "%s1" to insert script "%s2" into, skipping...',
	LS_LOG_FHLOADARCHIVEEXC      => 'Unable to load archive "%s1" to insert script "%s2" into, skipping... (%s3)',
	LS_LOG_FHLOADARCHIVEERR      => 'Unable to load archive "%s1" to insert script "%s2" into, skipping...',
	LS_LOG_FHBACKUPSCRIPT        => 'Making backup copy of script file "%s1" found in override...',
	LS_LOG_FHSCRIPTEXISTS        => 'Script file "%s1" already exists in override! Skipping...',
	LS_LOG_FHUPDATEREPLACE       => 'Updating and replacing file %s1 in Override folder...',
	LS_LOG_FHUPDATECOPY          => 'Updating and copying file %s1 to Override folder...',
	LS_LOG_FHINSFILENOTFOUND     => 'Unable to locate file "%s1" to install, skipping...',
	LS_LOG_FHCOPY2OVERRIDE       => 'Copying file %s1 to Override folder...',
	LS_LOG_FHSAVEASSRCNOTFOUND   => 'Unable to locate file "%s1" to install as "%s2", skipping...',
	LS_LOG_FHFILEEXISTSKIP       => 'A file named "%s1" already exists in the Override folder. Skipping...',
	LS_LOG_FHNOTSLPATCHDATAFILE  => 'No file blueprint found in tslpatchdata folder, fallback to manual source...',
	LS_DLG_MANUALLOCATEFILE      => 'File not found! Please locate the "%s1" ("%s2") file.',
	LS_LOG_FHCOPYFILEAS          => 'Copying file "%s1" as "%s2" to Override folder...',
	LS_EXC_FHCRITFILEMISSING     => 'Critical error: Unable to locate file to patch, "%s1" file not found!',
	LS_LOG_FHMODIFYINGFILE       => 'Modifying file "%s1" found in Override folder...',
	
	LS_TLK_CHANGING=>"Changing TLK entries...",
	LS_TLK_NOIDEA=>"Can't find Entry \"%s1\" to change...",
	LS_TLK_CHANGNUM=>"Changing Entry \"%s1\"...",
	LS_TLK_CHANGETOTAL=>"Changed \"%s1\" entries.",
	LS_TLK_DELETING=>"Deleting TLK entries...",
	LS_TLK_DELETENUM=>"Deleting Entry \"%s1\"...",
	LS_TLK_DELETETOTAL=>"Deleted \"%s1\" entries.",

	LS_LOG_2DADELETINGROW=>"Deleting row \"%s1\" in \"%s2\"...",
	LS_LOG_2DADELETEROWERR=>"Cannot find row \"%s1\" to delete!",
	LS_LOG_2DADELETINGCOL=>"Deleting column (\"%s1\") in \"%s2\"...",
	LS_LOG_2DADELETECOLERR=>"Cannot find column (\"%s1\" to delete!",
	
	LS_GUI_UNINSTALLOPT=>"Uninstall.ini file detected.\n\nDo you want to uninstall the mod?"
);

sub Format
{
	my ($message, @fixes) = @_;

	my $index = undef;
	my $scur  = 1;
	my $smax  = scalar @fixes;

	while($scur < ($smax + 1))
	{
		$index = index($message, "%s$scur");

		substr($message, $index, 3, $fixes[$scur - 1]);
		
		$scur++;
	}
	
	return $message;
}

sub WriteInstallLog
{
	open FH, ">", "$base/installlog.rtf";
	print FH "{\\rtf1\\ansi\\ansicpg1252\\deff0\\deflang1033{\\fonttbl{\\f0\\fnil\fcharset0 Courier New;}}\n";
	print FH "{\\colortbl ;\\red2\\green97\\blue17;\\red4\\green32\\blue152;\\red160\\green87\\blue2;\\red156\\green2\\blue2;\\red2\\green97\\blue17;}\n";
	print FH "\\viewkind4\\uc1\\pard\\cf1\\b\\f0\\fs2";
	print FH $log_text;
	print FH "\\b0 \\par }";
	close FH;
}

sub ProcessMessage
{
	my ($message, $loglevel) = @_;
	my $color  = 'Black';
	my $prefix = '';
	my $colorlog = undef;
	
	if($InstallInfo{iLogLevel} == 0)                      { return;                           } # Off
	elsif($loglevel == LOG_LEVEL_VERBOSE && $InstallInfo{iLogLevel} == 4)
	{ $colorlog = 2; $color = 'Blue';                                                 } # Verbose
	elsif($loglevel == LOG_LEVEL_ERROR && $InstallInfo{iLogLevel} >= 1)
	{ $colorlog = 4; $color = 'Red';    $log_errors++; $prefix = 'Error: ';           } # Error
	elsif($loglevel == LOG_LEVEL_ALERT && $InstallInfo{iLogLevel} >= 2)
	{ $colorlog = 3; $color = 'Orange'; $log_alerts++; $prefix = 'Warning: ';         } # Alert
	elsif($loglevel == LOG_LEVEL_INFORMATION)
	{ $colorlog = 0; $color = 'Black';                                                } # Information
	elsif($loglevel == LOG_LEVEL_NOTICE)
	{ $colorlog = 1; $color = 'Green';                                                } # Notice

	return if $loglevel == LOG_LEVEL_VERBOSE and $color ne 'Blue';
	return if $loglevel == LOG_LEVEL_ALERT and $color ne 'Orange';
	return if $loglevel == LOG_LEVEL_ERROR and $color ne 'Red';
	
	if($color eq 'Green')
	{
		$log_text_done = 2;
		if($log_alerts > 0 and $log_errors == 0)    { $colorlog = 3; $color = 'Orange'; }
		elsif($log_alerts == 0 and $log_errors > 0) { $colorlog = 4; $color = 'Red';    }
		elsif($log_alerts > 0 and $log_errors > 0)  { $cologlog = 5; $color = 'Mixed';  }
	}

	my $pre = "\\par ";
	if($log_first == 1) { $pre = ""; $log_first = 0; }
	
	if($log_text_done == 0)
	{ $log_text .= "$pre\\b0 \\cf$colorlog  \\bullet  $prefix$message\n"; $log_text_done = 1; }
	elsif($log_text_done == 2)
	{ $log_text .= "$pre\\b\\cf$colorlog  \\bullet  $prefix$message\n"; $log_text_done = 0; }
	else
	{ $log_text .= "$pre\\cf$colorlog  \\bullet  $prefix$message\n"; }
	
	if($InstallInfo{bLogOld} == 0)
	{
		# $GUI->{mwInstallText}->insert('end', " • " . $prefix . $message . "\n", [$color]);
	}
	else
	{
		# $GUI->{mwInstallText}->insert('end', $prefix . $message . "\n");
	}
	
	# my @yview_data = $GUI->{mwInstallText}->yview();
	# #print "Yview: " . $yview_data[1] . "\n";
	# if($yview_data[1] > 0.0)
	# {
	# 	$GUI->{mwInstallText}->yviewScroll(1, 'units');
	# }

	# $GUI->{mw}->update();
}

# Basic functions
sub Exit;
sub Set_Base { $base = shift; $install_path = $base . '/tslpatchdata'; }
sub Set_GUI  { $GUI = shift; }

sub SetPathFromIni
{
	my ($game, $path) = @_;
	
	if($game == 1)
	{
		$game1 = 1;
		$pathgame1 = $path;
	}
	else
	{
		$game2 = 1;
		$pathgame2 = $path;
	}
}

sub GetPathForIni
{
	if($InstallInfo{LookNum} == 1)
	{
		return (1, $pathgame1);
	}
	else
	{
		return (2, $pathgame2);
	}
}

# Namespaces functions
sub ProcessNamespaces;
sub SetInstallOption;
sub RunInstallOption;

my %nsOptions = (Count => -1, Index => 0);

sub ProcessNamespaces
{
	my $ns_ini = Config::IniMan->new($install_path . '\namespaces.ini');
	
	# $GUI->{nsBrowser}->delete(0, 'end');
	
	foreach($ns_ini->section_values('Namespaces'))
	{
		next if $_ eq '' or $_ =~ /^\;/;
		$nsOptions{Count}++;
		
		$nsOptions{$nsOptions{Count}}{Ini}  = $ns_ini->get($_, 'IniName');
		$nsOptions{$nsOptions{Count}}{Info} = $ns_ini->get($_, 'InfoName');
		$nsOptions{$nsOptions{Count}}{Path} = $ns_ini->get($_, 'DataPath');
		$nsOptions{$nsOptions{Count}}{Name} = $ns_ini->get($_, 'Name');
		$nsOptions{$nsOptions{Count}}{Desc} = $ns_ini->get($_, 'Description');
		
		# $GUI->{nsBrowser}->insert('end', $nsOptions{$nsOptions{Count}}{Name});
	}
	
	SetInstallOption(0);
}

sub SetInstallOption
{
	$nsOptions{Index} = shift;
	# $GUI->{nsBrowserVar} = $nsOptions{$nsOptions{Index}}{Name};
	# $GUI->{nsDescript}->Contents($nsOptions{$nsOptions{Index}}{Desc});
}

sub RunInstallOption
{
	$install_path .= "\\" . $nsOptions{$nsOptions{Index}}{Path};
	$install_info  = $nsOptions{$nsOptions{Index}}{Info};
	$install_ini   = $nsOptions{$nsOptions{Index}}{Ini};
	$install_name  = $nsOptions{$nsOptions{Index}}{Name};

	print "\nSelected $install_name\n";
	
	&ProcessInstallPath;
}

# Build Menu functions
sub NeedBuildMenu;
sub PopulateBuildMenu;
sub BuildMenu_ScrollLeft;
sub BuildMenu_ScrollRight;
sub RunInstallPath;

use File::Find;
my @subdirs - ();
my $subindex = 0;
my $submax   = 13;
my $subpage  = 1;
my $pages    = 1;

sub has_subdir 
{
    #The path of the file/dir being visited.
    my $subdir = $File::Find::name;

    #Ignore if this is a file.
    return unless -d $subdir;

    #Ignore if $subdir is $Dirname itself.
    return if ( $subdir eq $base);
	
	return if ( $subdir eq 'backup');
	
	return if ( $subdir eq 'tslpatchdata');
	
	return if ( $subdir eq 'source');

    # if we have reached here, this is a subdirector.
    print "Sub directory found - $subdir\n";
	if(-e $subdir . '/tslpatchdata')
	{
		$subdir = substr($subdir, (length($base) + 1), (length($subdir) - length($base) - 1));
		push(@subdirs, $subdir);
	}
}

sub NeedBuildMenu
{
	my $value = 0;
	
	if(-e $install_path == 0)
	{
		find(\&has_subdir, $base);

		if(scalar @subdirs > 0) { $value = 1; }
	}
	
	return $value;
}

sub PopulateBuildMenu
{
	$pages = int((scalar @subdirs) / ($submax + 1));
	if((int(scalar @subdirs) % ($submax + 1)) > 0) { $pages += 1; }
	
	$GUI->{bmLabel2}->configure(-text=>"$subpage of $pages");
	
	foreach my $v ($subindex .. ($subindex + $submax))
	{
		if(defined($subdirs[$v]))
		{
			TSLPatcher::GUI::BMAddOption($v, $subdirs[$v]);
		}
		else
		{
			TSLPatcher::GUI::BMAddSpace($v);
		}
	}
	
	$GUI->{BMValue} = 0;
	SetInstallPath(0);
}

sub BM_ScrollLeft
{
	if($subpage == 1) { return; }

	foreach my $v ($subindex .. ($subindex + $submax))
	{
		TSLPatcher::GUI::BMRemoveOption($v);
	}

	$subindex -= ($submax + 1);
	$subpage  -= 1;
	
	$GUI->{bmLabel2}->configure(-text=>"$subpage of $pages");
	
	foreach my $v ($subindex .. ($subindex + $submax))
	{
		if(defined($subdirs[$v]))
		{
			TSLPatcher::GUI::BMAddOption($v, $subdirs[$v]);
		}
		else
		{
			TSLPatcher::GUI::BMAddSpace($v);
		}
	}
}

sub BM_ScrollRight
{
	if($subpage == $pages) { return; }

	foreach my $v ($subindex .. ($subindex + $submax))
	{
		TSLPatcher::GUI::BMRemoveOption($v);
	}
	
	$subindex += ($submax + 1);
	$subpage  += 1;
	
	$GUI->{bmLabel2}->configure(-text=>"$subpage of $pages");
	
	foreach my $v ($subindex .. ($subindex + $submax))
	{
		if(defined($subdirs[$v]))
		{
			TSLPatcher::GUI::BMAddOption($v, $subdirs[$v]);
		}
		else
		{
			TSLPatcher::GUI::BMAddSpace($v);
		}
	}
}

sub SetInstallPath
{
	my $index = shift;
	#print "Base1 $base\n";
	#$base = "$base\\" . @subdirs[$index];
	#print "Base2 $base\n";
	$install_path = $base . "/" . @subdirs[$index] . '/tslpatchdata';
}

sub RunInstallPath
{
    $GUI->{bm}->withdraw;
	$GUI->{mw}->Popup(-popover=>undef, -overanchor=>'c', -popanchor=>'c');
	
	&ProcessInstallPath;
}

# Installer functions
sub ProcessInstallPath;
sub Install;
sub DoTLKList;
sub DoInstallFiles;
sub Do2DAList;
sub DoGFFList;
sub DoHackList;
sub DoCompileFiles;
sub DoSSFList;

# Normal operations required to process mods
sub ProcessInstallPath
{
	print "\nProcessInstallPath\n";
#	$GUI->{mw}->withdraw;
	# $GUI->{ns}->withdraw;
	# $GUI->{bm}->withdraw;

    if(-e "$install_path/namespaces.ini")
	{
#		print "h0a\n";
		&ProcessNamespaces;
		
		# $GUI->{ns}->Popup(-popover=>$GUI->{mw}, -overanchor=>'c', -popanchor=>'c');
		# $GUI->{mw}->withdraw;
	}
	else
	{
#		print "h0b\n";
#		if(-e "$install_path/uninstall.ini")
#		{
#		    $GUI->{Popup2}{Message} = $Messages{LS_GUI_UNINSTALLOPT};
#			$answer = $GUI->{Popup2}{Widget}->Show();
#			
#			if($answer eq 'Yes') { Uninstall(); }
#		}

		unless(-e "$install_path/$install_ini")
		{
			print "h1\n";
			# $GUI->{Popup1}{Message} = Format($Messages{LS_GUI_CONFIGMISSING}, $install_ini);
			# $answer = $GUI->{Popup1}{Widget}->Show();
			exit;
		}
		
		if(-e "$install_path/$install_info")
		{
#			print "h3\n";
			# ParseInfo("$install_path\\$install_info");
#			print "h4\n";
			$ini_object->read($install_path . "\\$install_ini");
			$uninstall_ini->add_section("Settings");
			
			foreach($ini_object->section_params('Settings'))
			{ $uninstall_ini->set('Settings', $_, $ini_object->get('Settings', $_, '')); }
			
			$uninstall_ini->add_section("TLKList");
			$uninstall_ini->add_section("InstallList");
			$uninstall_ini->add_section("2DAList");
			$uninstall_ini->add_section("GFFList");
			$uninstall_ini->add_section("CompileList");
			$uninstall_ini->add_section("SSFList");
			$uninstall_ini->add_section("HACKList");
#			print "h5\n";
			$InstallInfo{caption}    = $ini_object->get('Settings', 'WindowCaption', $Messages{LS_GUI_DEFAULTCAPTION});
			$InstallInfo{FileExists} = $ini_object->get('Settings', 'FileExists', 0);
			$InstallInfo{bInstall}   = $ini_object->get('Settings', 'InstallerMode', 0);
			$InstallInfo{sMessage}   = $ini_object->get('Settings', 'ConfirmMessage', $Message{LS_GUI_DEFAULTCONFIRMTEXT});
			$InstallInfo{iLogLevel}  = $ini_object->get('Settings', 'LogLevel', 3);
			$InstallInfo{bLogOld}    = $ini_object->get('Settings', 'PlaintextLog', 0);
#			print "h6\n";
			if($InstallInfo{FileExists} == 0)
			{
				print "h7\n";
				# $GUI->{Popup1}{Message} = Format($Messages{LS_GUI_CONFIGLOADERROR}, $install_ini);
				# $GUI->{Popup1}{Widget}->Show();
				exit;
			}
			
			# $GUI->{mw}->configure(-title=>$InstallInfo{caption});
#			print "h8\n";
			
			if($InstallInfo{bInstall} == 1)
			{
#				print "h9a\n";
				# $GUI->{mwInstallBtn}->configure(-text=>$Messages{LS_GUI_BUTTONCAPINSTALL});
			}
			else
			{
#				print "h9b\n";
				# $GUI->{mwInstallBtn}->configure(-text=>$Messages{LS_GUI_BUTTONCAPPATCH});
			}
			
			# $GUI->{mw}->Popup(-popover=>undef, -overanchor=>'c', -popanchor=>'c');
		}
		else
		{
			# print "h2\n";
			# $GUI->{Popup1}{Message} = Format($Messages{LS_GUI_INFOLOADERROR}, $install_info);
			# $answer = $GUI->{Popup1}{Widget}->Show();
			exit;
		}
	}
}

sub Exit
{
	if($bInstalled == 0)
	{
		$GUI->{Popup2}{Message} = $Messages{LS_GUI_CONFIRMQUIT};
		my $answer = $GUI->{Popup2}{Widget}->Show();
		
		if($answer eq 'No') { return; }
	}
	
	exit;
}

sub Install
{
# 	if($InstallInfo{sMessage} ne "N/A")
# 	{
# #		print "h10 - " . $InstallInfo{sMessage} . "\n";
		
# 		$GUI->{Popup2}{Message} = $InstallInfo{sMessage};
# 		my $answer = $GUI->{Popup2}{Widget}->Show();
		
# 		if($answer eq 'No') { return; }
# 	}

	print "\n\nINSTALLING\n\n";
	
	# Finish grabbing the mod settings
	$InstallInfo{Backups}      = $ini_object->get('Settings', 'BackupFiles', 1);
	$InstallInfo{LookGame}     = $ini_object->get('Settings', 'LookupGameFolder', 1);
	$InstallInfo{LookNum}      = $ini_object->get('Settings', 'LookupGameNumber', 1);
	$InstallInfo{SaveNss}      = $ini_object->get('Settings', 'SaveProcessedScripts', 0);
	$InstallInfo{RequiredFile} = $ini_object->get('Settings', 'Required', '');
	$InstallInfo{RequiredMsg}  = $ini_object->get('Settings', 'RequiredMsg', '');
	
	$InstallInfo{LookGame} = 0;
	if($InstallInfo{LookNum} == 1 and $game1 == 1)
	{
		$install_dest_path = $pathgame1;
	}
	elsif($InstallInfo{LookNum} == 2 and $game2 == 1)
	{
		$install_dest_path = $pathgame2;
	}
#	elsif($InstallInfo{LookGame} == 1)
#	{
#		# Need to do the registry...
#	}
	else
	{
		$install_dest_path = $GUI->{mw}->chooseDirectory(-title=>'Select the KotOR ' . $InstallInfo{LookNum} . ' Main Directory...', -mustexist=>1, -parent=>$GUI->{mw});

		if((-e $install_dest_path) == 0)
		{
			ProcessMessage(Format($Messages{LS_LOG_INSINVALIDDESTINATION}, $install_dest_path));
			# $GUI->{Popup1}{Message} = Format($Messages{LS_LOG_INSINVALIDDESTINATION}, $install_dest_path);
			# $GUI->{Popup1}{Widget}->Show();
			exit;
		}
		
		if($install_dest_path =~ /(data|docs|launcher|lips|logs|miles|modules|movies|override|rims|saves|streammusic|streamsounds|streamwaves|texturepacks|utils|streamvoices)$/i)
		{
			$_ = $install_dest_path;
			s/\/$1//;
			$install_dest_path = $_;
		}
		
		if($InstallInfo{LookNum} == 1)
		{
			$game1 = 1;
			$pathgame1 = $install_dest_path;
		}
		else
		{
			$game2 = 1;
			$pathgame2 = $install_dest_path;
		}
	}
	
	ProcessMessage("Install path set to $install_dest_path.", LOG_LEVEL_VERBOSE);
	
	# $GUI->{mwInstallBtn}->configure(-state=>'disabled');
	# $GUI->{mwExitBtn}->configure(-state=>'disabled');

	# If the log is set to be active, make it show up.
	# Also, hide the mod's info while we're at it. :)
	# if($InstallInfo{iLogLevel} > 0)
	# {
	# 	$GUI->{mwInfoText}->packForget;
	# 	$GUI->{mwInstallText}->pack(-pady=>10, -fill=>'both', -expand=>1);
	# }

	# Propertly format our time for the log...
	my @time = localtime;
	@time = @time[0 .. 5];
	if($time[0] < 10) { $time[0] = '0' . $time[0]; }
	if($time[1] < 10) { $time[1] = '0' . $time[1]; }
	if($time[2] < 10) { $time[2] = '0' . $time[2]; }
	$time[4] += 1;
	$time[5] += 1900;
	
	my $timestring = undef;
	if($time[2] > 12) { $timestring = ($time[2] - 12) . ":$time[1]:$time[0] PM on $time[4]/$time[3]/" . $time[5]; }
	else              { $timestring = "$time[2]:$time[1]:$time[0] AM on $time[4]/$time[3]/" . ($time[5] + 1900); }
	
	$timestring = Format($Messages{LS_LOG_RPOINSTALLSTART}, $timestring);

	if($InstallInfo{bInstall} == 1)
	{
		ProcessMessage($timestring, LOG_LEVEL_NOTICE);
	}
	else
	{
		ProcessMessage($timestring, LOG_LEVEL_NOTICE);
	}
	
	# Initialize (or reset) the log counts
	$log_errors  = 0;
	$log_alerts = 0;
	$log_index  = 0;
	
	# Gets the total number of files to operate on;
	# this allows proper updates of the Progress Bar.
	GetFileCount();
#	print "FileCount: $log_count\n";
	
	# $GUI->{mw}->update();
	DoTLKList();
	
	# $GUI->{mw}->update();
	DoInstallFiles();
	
	# $GUI->{mw}->update();
	Do2DAList();
	
	# $GUI->{mw}->update();
	DoGFFList();
	
	# $GUI->{mw}->update();
	DoHACKList();
	
	# $GUI->{mw}->update();
	DoCompileFiles();
	
	# $GUI->{mw}->update();
	DoSSFList();
	
	# $GUI->{mw}->update();
	# Now to do cleanup operations
	DoCleanup();
	
	# $GUI->{mw}->update();
	# End of the job, post a summary
	if($log_alerts > 0 and $log_errors == 0)
	{
		ProcessMessage(Format($Messages{LS_LOG_RPOSUMMARYWARN}, $log_alerts), LOG_LEVEL_NOTICE);
		# $GUI->{Popup1}{Message} = Format($Messages{LS_LOG_RPOSUMMARYWARN}, $log_alerts);
	}
	elsif($log_alerts == 0 and $log_errors > 0)
	{
		ProcessMessage(Format($Messages{LS_LOG_RPOSUMMARYERROR}, $log_errors), LOG_LEVEL_NOTICE);
		# $GUI->{Popup1}{Message} = Format($Messages{LS_LOG_RPOSUMMARYERROR}, $log_errors);
	}
	elsif($log_alerts > 0 and $log_errors > 0)
	{
		ProcessMessage(Format($Messages{LS_LOG_RPOSUMMARYWARNERROR}, $log_alerts, $log_errors), LOG_LEVEL_NOTICE);
		# $GUI->{Popup1}{Message} = Format($Messages{LS_LOG_RPOSUMMARYWARNERROR}, $log_alerts, $log_errors);
	}
	else
	{
		ProcessMessage($Messages{LS_LOG_RPOSUMMARY}, LOG_LEVEL_NOTICE);
		# $GUI->{Popup1}{Message} = $Messages{LS_LOG_RPOSUMMARY};
	}

	$bInstalled = 1;
	
#	$uninstall_ini->write("$install_path/uninstall.ini");
	# $GUI->{mwExitBtn}->configure(-state=>'normal');
	# $GUI->{Popup1}{Widget}->Show();
	
	WriteInstallLog();
}

sub Uninstall
{
	$ini_object->read("$install_path/uninstall.ini");
	
	$InstallInfo{Backups}      = $ini_object->get('Settings', 'BackupFiles', 1);
	$InstallInfo{LookGame}     = $ini_object->get('Settings', 'LookupGameFolder', 1);
	$InstallInfo{LookNum}      = $ini_object->get('Settings', 'LookupGameNumber', 2);
	$InstallInfo{SaveNss}      = $ini_object->get('Settings', 'SaveProcessedScripts', 0);
	$InstallInfo{RequiredFile} = $ini_object->get('Settings', 'Required', '');
	$InstallInfo{RequiredMsg}  = $ini_object->get('Settings', 'RequiredMsg', '');
	
	$InstallInfo{LookGame} = 0;
	if($InstallInfo{LookNum} == 1 and $game1 == 1)
	{
		$install_dest_path = $pathgame1;
	}
	elsif($InstallInfo{LookNum} == 2 and $game2 == 1)
	{
		$install_dest_path = $pathgame2;
	}
	elsif($InstallInfo{LookGame} == 1)
	{
		# Need to do the registry...
	}
	else
	{
		$install_dest_path = $GUI->{mw}->chooseDirectory(-title=>'Select the KotOR ' . $InstallInfo{LookNum} . ' Main Directory...', -mustexist=>1, -parent=>$GUI->{mw});

		if((-e $install_dest_path) == 0)
		{
			ProcessMessage(Format($Messages{LS_LOG_INSINVALIDDESTINATION}, $install_dest_path));
			# $GUI->{Popup1}{Message} = Format($Messages{LS_LOG_INSINVALIDDESTINATION}, $install_dest_path);
			# $GUI->{Popup1}{Widget}->Show();
			exit;
		}
		
		if($install_dest_path =~ /(data|docs|launcher|lips|logs|miles|modules|movies|override|rims|saves|streammusic|streamsounds|streamwaves|texturepacks|utils|streamvoices)$/i)
		{
			$_ = $install_dest_path;
			s/\/$1//;
			$install_dest_path = $_;
		}
		
		if($InstallInfo{LookNum} == 1)
		{
			$game1 = 1;
			$pathgame1 = $install_dest_path;
		}
		else
		{
			$game2 = 1;
			$pathgame2 = $install_dest_path;
		}
	}
	
	ProcessMessage("Install path set to $install_dest_path.", LOG_LEVEL_VERBOSE);
	
	# $GUI->{mwInstallBtn}->configure(-state=>'disabled');
	# $GUI->{mwExitBtn}->configure(-state=>'disabled');

	# If the log is set to be active, make it show up.
	# Also, hide the mod's info while we're at it. :)
	# if($InstallInfo{iLogLevel} > 0)
	# {
	# 	$GUI->{mwInfoText}->packForget;
	# 	$GUI->{mwInstallText}->pack(-pady=>10, -fill=>'both', -expand=>1);
	# }

	# Propertly format our time for the log...
	my @time = localtime;
	@time = @time[0 .. 5];
	if($time[0] < 10) { $time[0] = '0' . $time[0]; }
	if($time[1] < 10) { $time[1] = '0' . $time[1]; }
	if($time[2] < 10) { $time[2] = '0' . $time[2]; }
	$time[4] += 1;
	$time[5] += 1900;
	
	my $timestring = undef;
	if($time[2] > 12) { $timestring = ($time[2] - 12) . ":$time[1]:$time[0] PM on $time[4]/$time[3]/" . $time[5]; }
	else              { $timestring = "$time[2]:$time[1]:$time[0] AM on $time[4]/$time[3]/" . ($time[5] + 1900); }
	
	$timestring = Format($Messages{LS_LOG_RPOINSTALLSTART}, $timestring);

	if($InstallInfo{bInstall} == 1)
	{
		ProcessMessage($timestring, LOG_LEVEL_NOTICE);
	}
	else
	{
		ProcessMessage($timestring, LOG_LEVEL_NOTICE);
	}
	
	# Initialize (or reset) the log counts
	$log_errors  = 0;
	$log_alerts = 0;
	$log_index  = 0;
	
	# Gets the total number of files to operate on;
	# this allows proper updates of the Progress Bar.
	GetFileCount();
#	print "FileCount: $log_count\n";
	
	# $GUI->{mw}->update();
	DoTLKList();
	
	# $GUI->{mw}->update();
	DoInstallFiles();
	
	# $GUI->{mw}->update();
	Do2DAList();
	
	# $GUI->{mw}->update();
	DoGFFList();
	
	# $GUI->{mw}->update();
	DoHACKList();
	
	# $GUI->{mw}->update();
	DoCompileFiles();
	
	# $GUI->{mw}->update();
	DoSSFList();
	
	# $GUI->{mw}->update();
	# Now to do cleanup operations
	DoCleanup();
	
	# $GUI->{mw}->update();
	# End of the job, post a summary
	if($log_alerts > 0 and $log_errors == 0)
	{
		ProcessMessage(Format($Messages{LS_LOG_RPOSUMMARYWARN}, $log_alerts), LOG_LEVEL_NOTICE);
		# $GUI->{Popup1}{Message} = Format($Messages{LS_LOG_RPOSUMMARYWARN}, $log_alerts);
	}
	elsif($log_alerts == 0 and $log_errors > 0)
	{
		ProcessMessage(Format($Messages{LS_LOG_RPOSUMMARYERROR}, $log_errors), LOG_LEVEL_NOTICE);
		# $GUI->{Popup1}{Message} = Format($Messages{LS_LOG_RPOSUMMARYERROR}, $log_errors);
	}
	elsif($log_alerts > 0 and $log_errors > 0)
	{
		ProcessMessage(Format($Messages{LS_LOG_RPOSUMMARYWARNERROR}, $log_alerts, $log_errors), LOG_LEVEL_NOTICE);
		# $GUI->{Popup1}{Message} = Format($Messages{LS_LOG_RPOSUMMARYWARNERROR}, $log_alerts, $log_errors);
	}
	else
	{
		ProcessMessage($Messages{LS_LOG_RPOSUMMARY}, LOG_LEVEL_NOTICE);
		# $GUI->{Popup1}{Message} = $Messages{LS_LOG_RPOSUMMARY};
	}

	$bInstalled = 1;
	
	# $GUI->{mwExitBtn}->configure(-state=>'normal');
	# $GUI->{Popup1}{Widget}->Show();
	
	WriteInstallLog();
}

sub UpdateProgress
{
	$log_index++;
	#print "$log_index / $log_count: " . (($log_index / $log_count) * 100) . "\n";
	# $GUI->{mwProgress}->configure(-value=>($log_index/$log_count) * 100);
}

sub GetFileCount
{
	my @lines = $ini_object->section_params('TLKList');
	
	foreach(@lines)
	{
		if($_ ne '' and ($_ =~ /__SKIP__/) == 0 and ($_ =~ /^\;/) == 0)
		{
			$log_count = 1;
		}
	}

	foreach('2DAList', 'GFFList', 'HACKList', 'CompileList', 'SSFList')
	{
		@lines = $ini_object->section_params($_);

		foreach(@lines)
		{
			if($_ ne '' and ($_ =~ /__SKIP__/) == 0 and ($_ =~ /^\;/) == 0)
			{
				$log_count++;
			}
		}
	}
	
	@lines = $ini_object->section_params('InstallList');
	
	foreach(@lines)
	{
		if($_ ne '' and ($_ =~ /^\;/) == 0)
		{
			foreach($ini_object->section_params($_))
			{
				if($_ ne '' and ($_ =~ /__SKIP__/) == 0 and ($_ =~ /^\;/) == 0)
				{
					$log_count++;
				}
			}
		}
	}
}

# Helper function to locate files
sub ExecuteFile
{
	my ($filename, $patchtype, $overwrite, $destination) = @_;

	if(defined($overwrite) == 0) { $overwrite = 0; }
	if((defined($destination) == 0) or ($destination eq '')) { $destination = 'override'; }
	
	my %FileBox = (
	-defaultextension=>undef,
	-filetypes=>[],
	-initialdir=>"$install_dest_path\\$destination",
	-initialfile=>$filename,
	-title=>Format($Messages{LS_DLG_FILESELECTDESC}, $filename)
	);
	
	if($patchtype eq 'fileTLK')
	{
		$FileBox{-defaultextension} = 'tlk';
		$FileBox{-filetypes}        = [['TLK file', '.tlk']];
	}
	elsif($patchtype eq 'file2DA')
	{
		$FileBox{-defaultextension} = '2da';
		$FileBox{-filetypes}        = [['2D Array', '.2da']];
	}
	elsif($patchtype eq 'fileGFF')
	{
		my $ext = lc(substr($filename, (length($filename) - 3), 3));
		
		if(length($ext) < 1)
		{ $ext = "*"; }
		
		   if($ext eq 'are') { $FileBox{-filetypes} = [['Area template', '.are']]; }
		elsif($ext eq 'dlg') { $FileBox{-filetypes} = [['Conversation file', '.dlg']]; }
		elsif($ext eq 'fac') { $FileBox{-filetypes} = [['Faction template', '.fac']]; }
		elsif($ext eq 'gff') { $FileBox{-filetypes} = [['GFF template', '.gff']]; }
		elsif($ext eq 'git') { $FileBox{-filetypes} = [['Area Properties', '.git']]; }
		elsif($ext eq 'ifo') { $FileBox{-filetypes} = [['Level Properties', '.ifo']]; }
		elsif($ext eq 'utc') { $FileBox{-filetypes} = [['Creature template', '.utc']]; }
		elsif($ext eq 'utd') { $FileBox{-filetypes} = [['Door template', '.utd']]; }
		elsif($ext eq 'ute') { $FileBox{-filetypes} = [['Encounter template', '.ute']]; }
		elsif($ext eq 'uti') { $FileBox{-filetypes} = [['Item template', '.uti']]; }
		elsif($ext eq 'utm') { $FileBox{-filetypes} = [['Store template', '.utm']]; }
		elsif($ext eq 'utp') { $FileBox{-filetypes} = [['Placeable template', '.utp']]; }
		elsif($ext eq 'uts') { $FileBox{-filetypes} = [['Sound List template', '.utS']]; }
		elsif($ext eq 'utt') { $FileBox{-filetypes} = [['Trigger template', '.utt']]; }
		elsif($ext eq 'utw') { $FileBox{-filetypes} = [['Waypoint template', '.utw']]; }
		
		$FileBox{-defaultextension} = $ext;
	}
	elsif($patchtype eq 'fileHACK')
	{
		my $ext = lc(substr($filename, (length($filename) - 3), 3));
		
		$FileBox{-filetypes} = [[uc($ext) . ' file', ".$ext"]];
		$FileBox{-defaultextension} = $ext;
	}
	elsif($patchtype eq 'fileCompile')
	{
		$FileBox{-defaultextension} = 'nss';
		$FileBox{-filetypes} = [['NSS Source Script', ".nss"]];
	}
	elsif($patchtype eq 'fileSSF')
	{
		$FileBox{-defaultextension} = 'ssf';
		$FileBox{-filetypes} = [['SSF Soundset file', '.ssf']];
	}
	
	if($InstallInfo{bInstall} == 1)
	{
		$required = $ini_object->get('Settings', 'Required', '');
		$required_msg = $ini_object->get('Settings', 'RequiredMsg', Format($Messages{LS_EXC_FHREQFILEMISSING}, $required));
		
		if(($required ne '') &&
    	   (defined($required) == 1) &&
		   (-e "$install_dest_path\\override\\$required") == 0)
		{
			print "error 1: $required_msg\n";
			$GUI->{Popup1}{Message} = $required_msg;
			$GUI->{Popup1}{Widget}->Show();
			
			return (-1, '');
		}
		
		if($patchtype eq 'fileTLK')
		{
			if(-e "$install_dest_path/$filename")
			{
				return (1, "$install_dest_path/$filename");
			}
			else
			{
				$GUI->{Popup1}{Message} = Format($Messages{LS_EXC_FHTLKFILEMISSING}, $filename);
				$GUI->{Popup1}{Widget}->Show();
				
				return (-1, '');
			}
		}
		
		if((-e "$install_dest_path/override") == 0)
		{
			make_path("$install_dest_path\\override", {chmod=>0777, user=>$user});
			ProcessMessage(Format($Messages{LS_LOG_FHMAKEOVERRIDE}, "$install_dest_path/override"), LOG_LEVEL_INFORMATION);
		}
		
		if($patchtype eq 'fileGFFERF')
		{
			my $dest = "$install_dest_path/$destination";
			
			if((-e $dest) == 0)
			{
				ProcessMessage(Format($Messages{LS_LOG_FHDESTNOTFOUND}, $destination, $filename), LOG_LEVEL_ERROR);
				return (-1, '');
			}
			
			my ($ERF, $IsERF, $ERF_name, $ERF_type) = (undef, undef, undef, undef);
			
			if($destination ~~ @ERFs)
			{
				$ERF_name = (split(/(\\|\/)/, $destination))[-1];
				$ERF_name = substr($ERF_name, 0, (length($ERF_name) - 4));
			}
			else
			{
#				print "GFF adding $destination to the array.\n";
				push(@ERFs, $destination);			
				
				# Set whether to treat this as an ERF or a RIM
				if($dest =~ /\.rim$/) { $IsERF = 0; }
				else                  { $IsERF = 1; }
				
				if($IsERF == 1)
				{
					$ERF = Bioware::ERF->new();
					$ERF->read_erf("$dest");
					
					$ERF_name = $ERF->{'erf_filename'};
					$ERF_name = (split(/(\\|\/)/, $ERF_name))[-1];
				}
				else
				{
					$ERF = Bioware::RIM->new();
					$ERF->read_rim($dest);
					
					$ERF_name = $ERF->{'rim_filename'};
					$ERF_name = (split(/(\\|\/)/, $ERF_name))[-1];
				}
				
				# Make a backup in the Backup folder
				if((MakeBackup("$dest", 'modules')) == 1)
				{
					ProcessMessage(Format($Messages{LS_LOG_INSBACKUPFILE}, $ERF_name, $install_path . "\\backup\\"), LOG_LEVEL_INFORMATION);
				}
				
				# Now pull everything into a sub-folder named after the level
				# itself. This way we aren't having to deal with the data in
				# memory...
				$ERF_type = substr($ERF_name, (length($ERF_name) - 3), 3);
				$ERF_name = substr($ERF_name, 0, (length($ERF_name) - 4));
				
				make_path("$install_path/" . $ERF_name, {chmod=>0777, user=>$user});
				
				foreach(@{$ERF->{Files}})
				{
					$ERF->export_resource_by_index($ERF->get_resource_id_by_name($_), "$install_path/$ERF_name/$_");
				}
			}
			
			my $saveas = $ini_object->get($filename, '!SaveAs', $filename);

#			if(-e "$install_path\\$ERF_name\\$saveas")
#			{
#				unlink("$install_path\\$ERF_name\\$saveas");
#			}
			
			if(($overwrite == 0) and (-e "$install_path/$ERF_name/$saveas"))
			{
				ProcessMessage(Format($Messages{LS_LOG_FHDESTRESEXISTMOD}, $saveas, $destination), LOG_LEVEL_INFORMATION);
				return(1, "$install_path/$ERF_name/$saveas");
			}
			else
			{
				my $sourcefile = $ini_object->get($filename, '!SourceFile', $filename);
				
				ProcessMessage(Format($Messages{LS_LOG_FHADDTODEST}, $saveas, (split(/(\\|\/)/, $destination))[-1]), LOG_LEVEL_INFORMATION);
				if((File::Copy::copy("$install_path\\$sourcefile", "$install_path\\$ERF_name\\$saveas")) == 0)
				{
					print "Failed!:\n Install Path: $install_path\n Source File: $sourcefile\nERF Name: $ERF_name\nSave As: $saveas\n\n";
#					ProcessMessage(Format($Messages{LS_LOG_FHTEMPFILEFAILED}, $saveas), LOG_LEVEL_ERROR);
					
					# $GUI->{Popup2}{Message} = "The file \"$sourcefile\" was not found in the patch data folder.\n\nWould you like to use the original file from the archive the ERF, MOD, or RIM file?";
					# if($GUI->{Popup2}{Widget}->Show() ne 'Yes')
					# {
					# 	ProcessMessage(Format($Messages{LS_LOG_FHTEMPFILEFAILED}, $saveas), LOG_LEVEL_ERROR);
					# 	return (-1, '');
					# }
					# else
					# {
						return (1, "$install_path/$ERF_name/$saveas");
					# }
				}
				else
				{
					return(1, "$install_path/$ERF_name/$saveas");
				}
			}
		}
		
		if($patchtype eq 'fileCompile')
		{
			my $destination = "$install_dest_path\\$destination";
			
			if(lc($destination) ne 'override')
			{
				my $d = (split(/(\\|\/)/, $dest))[-1];
				
				$d =~ /(.*?)\....$/;
				#print "Dest1: $destination\n";
				$destination = "$install_path\\$1";
				#print "Dest2: $destination\n";
			}
			
			my $saveas = $ini_object->get($filename, '!SourceFile', $filename);
			
			if((-e "$install_path/$saveas") == 0)
			{
				ProcessMessage(Format($Messages{LS_LOG_FHSOURCENOTFOUND}, $saveas), LOG_LEVEL_ERROR);
				
				return(-1, '');
			}
			
			#print "SaveAs: $saveas\n";
			($temp = $saveas) =~ s/\.nss/\.ncs/;
			#print "SaveAs1: $saveas\n";
			#print "Temp: $temp\n";
			
			if($overwrite == 1)
			{
				if((lc($destination) eq 'override') and (-e "$install_dest_path\\override\\$temp"))
				{
					if($InstallInfo{Backups} == 1)
					{
						if((-e "$install_path/backup/override/$temp") == 0)
						{
							MakeBackup("$install_path/override/$temp", 'override');
							ProcessMessage(Format($Messages{LS_LOG_FHBACKUPSCRIPT}, $filename), LOG_LEVEL_INFORMATION);
						}
					}
				}
			}
		}
		
		if($overwrite)
		{
			my $sourcefile = $ini_object->get($filename, '|SourceFile', $filename);
			my $saveasfile = $ini_object->get($filename, '|SaveAs', $filename);
			
			if(-e "$install_path/$sourcefile")
			{
				if(-e "$install_dest_path/$destination/$saveasfile")
				{
					if($InstallInfo{Backups} == 1)
					{ MakeBackup("$install_dest_path/$destination/$saveasfile", $destination); }
					
					unlink("$install_dest_path/$destination/$saveasfile");
					ProcessMessage(Format($Messages{LS_LOG_FHUPDATEREPLACE}, $saveasfile), LOG_LEVEL_INFORMATION);
				}
				else
				{
					ProcessMessage(Format($Messages{LS_LOG_FHUPDATECOPY}, $saveasfile), LOG_LEVEL_INFORMATION);
				}
				
				File::Copy::copy("$install_path\\$sourcefile", "$install_dest_path\\$destination\\$saveasfile");
				return (1, "$install_dest_path/$destination/$saveasfile");
			}
			else
			{
				ProcessMessage(Format($Messages{LS_LOG_FHINSFILENOTFOUND}, $filename), LOG_LEVEL_ERROR);
				return (-1, '');
			}
		}
		
		if($patchtype eq 'fileHACK')
		{
			my $sourcefile = $ini_object->get($filename, '|SourceFile', $filename);
			my $saveasfile = $ini_object->get($filename, '|SaveAs', $filename);
			
			if((-e "$install_dest_path/$destination/$saveasfile") == 0)
			{
				if(-e "$install_path/$sourcefile")
				{
					File::Copy::copy("$install_path/$sourcefile", "$install_dest_path/$destination/$saveasfile");
					
					ProcessMessage(Format($Messages{LS_LOG_FHCOPY2OVERRIDE}, $saveasfile), LOG_LEVEL_INFORMATION);
					return (1, "$install_dest_path/$destination/$saveasfile");
				}
				else
				{
					ProcessMessage(Format($Messages{LS_LOG_FHSAVASSRCNOTFOUND}, $filename, $sourcefile), LOG_LEVEL_ERROR);
					return (-1, '');
				}
			}
			else
			{
				ProcessMessage(Format($Messages{LS_LOG_FHFILEEXISTSKIP}, $saveasfile), LOG_LEVEL_ALERT);
				return (-1, '');
			}
		}
		
		my $sourcefile = $ini_object->get($filename, '|SourceFile', $filename);
		my $saveasfile = $ini_object->get($filename, '|SaveAs', $filename);
			
		if((-e "$install_dest_path\\$destination\\$saveasfile") == 0)
		{
			if((-e "$install_path\\$sourcefile") == 0)
			{
				ProcessMessage($Messages{LS_LOG_FHNOTSLPATCHDATAFILE}, LOG_LEVEL_VERBOSE);
				$FileBox{-title} = Format($Messages{LS_DLG_MANUALLOCATEFILE}, $saveasfile, $sourcefile);
				my $located = $GUI->{mw}->getOpenFile(%FileBox);
				
				if($located ne '')
				{
					File::Copy::copy($located, "$install_dest_path\\$destination\\$saveasfile");
					ProcessMessage(Format($Messages{LS_LOG_FHCOPYFILEAS}, $sourcefile, $saveasfile), LOG_LEVEL_INFORMATION);
					
					return (1, "$install_dest_path/$destination/$saveasfile");
				}
				else
				{
					$GUI->{Popup1}{Message} = Format($Messages{LS_EXC_FHCRITFILEMISSING}, $saveasfile);
					$GUI->{Popup1}{Widget}->Show();
					ProcessMessage($GUI->{Popup1}{Message}, LOG_LEVEL_ERROR);
					return (0, '');
				}
			}
			else
			{
				File::Copy::copy("$install_path\\$sourcefile", "$install_dest_path\\$destination\\$saveasfile");
				
				if($sourcefile ne $saveasfile)
				{
					ProcessMessage(Format($Messages{LS_LOG_FHCOPYFILEAS}, $sourcefile, $saveasfile), LOG_LEVEL_INFORMATION);
				}
				else
				{
					ProcessMessage(Format($Messages{LS_LOG_FHCOPY2OVERRIDE}, $saveasfile), LOG_LEVEL_INFORMATION);
				}
				
				return (1, "$install_dest_path/$destination/$saveasfile");
			}
		}
		else
		{
			ProcessMessage(Format($Messages{LS_LOG_FHMODIFYINGFILE}, $saveasfile), LOG_LEVEL_INFORMATION);
#			print "Install Path: $install_dest_path\n";
#			print "Destination: $destination\n";
#			print "SaveAs: $saveasfile\n";
			return (1, "$install_dest_path/$destination/$saveasfile");
		}
	}
	else
	{
		my $file = $GUI->{mw}->getOpenFile(%FileBox);
		if($file ne '')
		{
			$file =~ s/\\/\//g;
			return (1, $file);
		}
		else
		{
			return (-1, '');
		}
	}
}

# Checks to validate the location as a valid RIM or ERF file.
sub IsValidArchive
{
	open FH, "<", shift;
	binmode FH;
	sysread FH, my $header, 8;
	close FH;
	
	   if($header eq 'ERF V1.0') { return 1; }
	elsif($header eq 'MOD V1.0') { return 1; }
	elsif($header eq 'HAK V1.0') { return 1; }
	elsif($header eq 'SAV V1.0') { return 1; }
	elsif($header eq 'RIM V1.0') { return 1; }
	else                         { return 0; }
}

# Make backups in the backup folder.
sub MakeBackup
{
	my ($file, $folder) = @_;

#	print "File: $file\n";
	$file =~ /(.*)(\\|\/)(.*?)$/;
	my $filename = $3;
	my $backup_path = $install_path;
	$backup_path =~ s#\\#\/#g;
	my @a = split(/\//, $backup_path);
#	print "Backup1: $backup_path\n";
	my $a_count = scalar @a;
#	print "Backup_count: $a_count\n";
	$a_count -= 2;
	$backup_path = join("/", @a[0 .. $a_count]);
#	print "Backup2: $backup_path\n";

	if((-e "$backup_path\\backup") == 0) { make_path("$backup_path\\backup", {chmod=>0777, user=>$user}); }
	if((-e "$backup_path\\backup\\$folder") == 0) { make_path("$backup_path\\backup\\$folder", {chmod=>0777, user=>$user}); }
	
	$folder = "\\$folder\\";
#	print "Making a backup at: \n" . "$base\\backup" . $folder . $filename . "\n\n";
	return File::Copy::copy($file, "$backup_path\\backup" . $folder . $filename);
}

# Check for files in the Override when adding to ERF or RIM packages.
sub HandleERFOverrideType
{
	my ($filename, $section, $bNoDest, $AltDest) = @_;
	my $destination = undef;
	
	if(defined($AltDest) == 0) { $AltDest = 'override'; }
	
	if($bNoDest == 0)
	{
		$destination = lc($ini_object->get($section, '!Destination', $AltDest));
		
		if($destination eq 'override')
		{ return; }
	}
	
	my $type = lc($ini_object->get($section, '!OverrideType', 'ignore'));
	my $file = "$install_dest_path\\override\\$filename";
	
	if((-e $file) == 0)
	{
		ProcessMessage(Format($Messages{LS_LOG_OVRCHECKNOFILE}, $filename), LOG_LEVEL_VERBOSE);
		return;
	}
	
	if($type eq 'warn')
	{
		ProcessMessage(Format($Messages{LS_LOG_OVRCHECKEXISTWARN}, $filename), LOG_LEVEL_ALERT);
	}
	elsif($type eq 'rename')
	{
		my $new = "$install_dest_path\\override\\old_$filename";
		if(File::Copy::copy($file, $new))
		{
			unlink($file);
			ProcessMessage(Format($Messages{LS_LOG_OVRCHECKRENAMED}, $filename, "old_$filename"), LOG_LEVEL_INFORMATION);
		}
		else
		{
			ProcessMessage(Format($Messages{LS_LOG_OVRRENAMEFAILED}, $filename, "old_$filename"), LOG_LEVEL_ALERT);
		}
	}
	else
	{
		ProcessMessage(Format($Message{LS_LOG_OVRCHECKSILENTWARN}, $filename), LOG_LEVEL_VERBOSE);
	}
}

# Functions to process the TLK file and sub-functions to help with that.
sub DoTLKList
{
	print "\nDoTLKList\n";
	my $tlk_append = Bioware::TLK->new();
	my $tlk_dialog = Bioware::TLK->new();
	
	ProcessMessage($Messages{LS_LOG_LOADINGSTRREFTOKENS}, LOG_LEVEL_VERBOSE);
	
	my @lines = undef;
	foreach($ini_object->section_params('TLKList'))
	{
		if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_ =~ /^\;/) == 0))
		{
			push(@lines, $_);
		}
	}
	
	my $key          = undef;
	my $value        = undef;
	
	my $entry_count  = 0;
	my $delete_count = 0;
	my $change_count = 0;
	
	my $count        = 0;
	my $added        = 0;
	my $reused       = 0;
	
	my %tlk_data     = undef;
	
	foreach $key (@lines)
	{
		$value = $ini_object->get('TLKList', $key);
		
		if(lc(substr($key, 0, 6)) eq 'strref')
		{
			$tlk_data{$value} = substr($key, 6, (length($key) - 6));
			$entry_count++;
		}
		elsif(lc(substr($key, 0, 6)) eq 'delete')
		{
			$tlk_data{"Delete" . substr($key, 6, (length($key) - 6))} = $value;
			$delete_count++;
		}
		elsif(lc(substr($key, 0, 6)) eq 'change')
		{
			$tlk_data{"Change" . substr($key, 6, (length($key) - 6))} = $value;
			$change_count++;
		}
	}
	
	if($entry_count > 0)
	{
		ProcessMessage(Format($Messages{LS_LOG_LOADEDSTRREFTOKENS}, $entry_count), LOG_LEVEL_VERBOSE);
	}
		
	foreach my $action (TLK_TYPE_NORMAL, TLK_TYPE_FEMALE)
	{
		my $default = '';
		my $dialog  = '';
		
		if($action == TLK_TYPE_NORMAL)
		{
			$count   = 0;
			$added   = 0;
			$reused  = 0;
			
			$default = 'append.tlk';
			$dialog  = 'dialog.tlk';
		}
		else
		{
			$count   = 0;
			$added   = 0;
			$reused  = 0;
			
			$default = 'appendf.tlk';
			$dialog  = 'dialogf.tlk';
			
			$tlk_append->delete_all_entries();
			$tlk_dialog->delete_all_entries();
		}
		
		next if (-e "$install_path\\$default") == 0;
		
		my @answer = ExecuteFile($dialog, 'fileTLK');
		if($answer[0] == 1)
		{
			if(((-e "$install_path/$default") == 1) and ((-e $answer[1]) == 1))
			{
				$dialog = (split(/\//, $answer[1]))[-1];
				ProcessMessage(Format($Messages{LS_LOG_APPENDFEEDBACK}, $answer[1]), LOG_LEVEL_INFORMATION);
				
				$tlk_dialog->load_tlk($answer[1]);
				$tlk_append->load_tlk("$install_path\\" . $ini_object->get('TLKList', '!SourceFile', $default));
				
				# Change entries in the dialog.tlk file
				if($change_count > 0)
				{
					ProcessMessage($Messages{LS_TLK_CHANGING}, LOG_LEVEL_INFORMATION);
					
					my $section = undef;
					foreach(0 .. ($change_count - 1))
					{
						$section = $tlk_data{"Change$_"};
						$uninstall_ini->set("TLKList", "Change$_", $section);
						
						if($uninstall_ini->section_exists($section) == 0)
						{ $uninstall_ini->add_section($section); }
						
						if(($ini_object->get($section, '!Entry', '-1')) < 0)
						{
							ProcessMessage(Format($Messages{LS_TLK_CHANGENOIDEA}, $_), LOG_LEVEL_ERROR);
							next;
						}
					
						ProcessMessage(Format($Messages{LS_TLK_CHANGENUM}, $_), LOG_LEVEL_VERBOSE);
					
						my $entry = $ini_object->get($section, '!Entry');
						$uninstall_ini->set($section, '!Entry', $entry);
						
						foreach($ini_object->section_params($section))
						{
							$uninstall_ini->set($section, $_, $ini_object->get($section, $_, ''));
							
							if($dialog eq 'dialogf.tlk')
							{
								if(lc($_) eq 'textf') { $tlk_dialog->edit_entry($entry, 'Text', $ini_object->get($section, $_, $ini_object->get($section, 'Text'))); }
							}
							else
							{
								if(lc($_) eq 'text')   { $tlk_dialog->edit_entry($entry, 'Text',  $ini_object->get($section, $_, '')); }
							}
							
							if(lc($_) eq 'flags')  { $tlk_dialog->edit_entry($entry, 'Flags', $ini_object->get($section, $_)); }
							if(lc($_) eq 'sound')  { $tlk_dialog->edit_entry($entry, 'Sound', $ini_object->get($section, $_)); }
						}
					}
					
					ProcessMessage(Format($Messages{LS_TLK_CHANGETOTAL}, $change_count), LOG_LEVEL_VERBOSE);
				}
				
				# Now delete any entries that we need to delete.
				if($delete_count > 0)
				{
					ProcessMessage($Messages{LS_TLK_DELETING}, LOG_LEVEL_INFORMATION);
					
					foreach(0 .. ($delete_count - 1))
					{
						ProcessMessage(Format($Messages{LS_TLK_DELETNUM}, $_), LOG_LEVEL_VERBOSE);
						$tlk_dialog->delete_entry($tlk_data{"Delete$_"});
					}
					
					ProcessMessage(Format($Messages{LS_TLK_DELETETOTAL}, $delete_count), LOG_LEVEL_VERBOSE);
				}
				
				# NOW we can add new entries...
				if($entry_count > 0)
				{
					my $entry = undef;
					foreach $entry (0 .. ($tlk_append->{'string_count'} - 1))
					{
						my ($text, $sound, $flags, $length) = (undef, undef, undef, undef);
						
						$text   = $tlk_append->{$entry}{'Text'};
						$sound  = $tlk_append->{$entry}{'Sound'};
						$flags  = $tlk_append->{$entry}{'Flags'};
						$length = $tlk_append->{$entry}{'Length'};
						
						my ($return, $new) = $tlk_dialog->add_entry($text, $sound, $flags, $length);
#						print "$entry return $return new $new\n";
						
						if($return == -1)
						{
							$count++;
							$reused++;
							ProcessMessage(Format($Messages{LS_LOG_TLKENTRYMATCHEXIST}, $entry, $dialog, $new), LOG_LEVEL_VERBOSE);
						}
						else
						{
							$count++;
							$added++;
							ProcessMessage(Format($Messages{LS_LOG_APPENDTLKENTRY}, $dialog, $new), LOG_LEVEL_VERBOSE);
							$uninstall_ini->set('TLKList', "Delete$_", $new);
						}
						
						if(defined($tlk_data{$entry}) == 1)
						{
							$Tokens{'StrRef' . $tlk_data{$entry}} = $new;
						}
					}
				}
				
				if($count > 0)
				{
					if(MakeBackup($answer[1], '') == 1)
					{
						ProcessMessage(Format($Messages{LS_LOG_MAKETLKBACKUP}, $dialog, "$install_path\\backup"), LOG_LEVEL_INFORMATION);
					}
					
					$tlk_dialog->save_tlk($answer[1]);
					
					if(($added > 0) and ($reused > 0))
					{
						ProcessMessage(Format($Messages{LS_LOG_TLKSUMMARY1}, $dialog, $added, $reused), LOG_LEVEL_INFORMATION);
					}
					elsif($added > 0)
					{
						ProcessMessage(Format($Messages{LS_LOG_TLKSUMMARY2}, $dialog, $added), LOG_LEVEL_INFORMATION);
					}
					elsif($reused > 0)
					{
						ProcessMessage(Format($Messages{LS_LOG_TLKSUMMARY3}, $dialog, $reused), LOG_LEVEL_INFORMATION);
					}
					else
					{
						ProcessMessage(Format($Messages{LS_LOG_TLKSUMMARYWARNING}, $dialog), LOG_LEVEL_ALERT);
					}
				}
			}
			else
			{
				ProcessMessage(Format($Messages{LS_LOG_TLKFILEMISSING}, $dialog), LOG_LEVEL_ERROR);
			}
		}
		else
		{
			ProcessMessage(Format($Messages{LS_LOG_TLKNOTSELECTED}, $dialog), LOG_LEVEL_ERROR);
		}
	}
	
	if($count > 0)
	{	UpdateProgress(); }
#	$tlk_append->load_tlk($install_path . '/append.tlk');
	
#	my $entry = $tlk_append->add_entry("Hi!", '', 7, 0.1);
#	$tlk_append->edit_entry($entry, 'Text', "Goodbye!");
	
#	$tlk_append->delete_entry(0);
#	$tlk_append->save_tlk($install_path . '/new.tlk');
}

sub GetIsStringToken
{
	my $token = shift;
	
	if(length $token > 5)
	{
		my $part1 = substr($token, 0, 6);
		my $part2 = substr($token, 6, (length($token) - 6));
		
		if((lc($part1) eq 'strref') and (looks_like_number($part2)))
		{ return 1; }
		else
		{ return 0; }
	}
	else
	{ return 0; }
}

sub ProcessStrRefToken
{
	my $token = shift;
	
	if($token ne '')
	{
		if(lc(substr($token, 0, 6)) eq 'strref')
		{
			my $index = substr($token, 6, (length($token) - 6));
			
			if($index >= 0 and (defined($Tokens{'StrRef' . $index}) == 1))
			{
				return $Tokens{'StrRef' . $index};
			}
		}
	}
	
	ProcessMessage(Format($Messages{LS_LOG_UNKNOWNSTRREFTOKEN}, $token), LOG_LEVEL_ERROR);
	return 0;
}

# Process the Install Files list.
sub DoInstallFiles
{
	print "\nDoInstallFiles\n";
	my @lines1     = ();
	my @lines2     = ();
	my $folder     = undef;
	my $foldername = undef;
	my $IsArchive  = 0;
	my $IsERF      = 0;
	
	my $ERF = undef;
	my $ERF_name = undef;
	my $ERF_type = undef;

	foreach ($ini_object->section_params('InstallList'))
	{
		if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_ =~ /^\;/) == 0))
		{
			push(@lines1, $_);
		}
	}
	
	return if scalar @lines1 <= 0;
	
	return if $InstallInfo{bInstall} == 0;
	
	ProcessMessage($Messages{LS_LOG_INSSTART}, LOG_LEVEL_INFORMATION);

	foreach my $section (@lines1)
	{
		@lines2 = ();
		$folder = $ini_object->get('InstallList', $section);
		$uninstall_ini->set('InstallList', $section, $folder);
		
		$IsArchive = 0;
		# If this is a file, it must be an ERF or RIM, and it must exist.
		# Otherwise, there's no point being here.
		if(-f "$install_dest_path\\$folder")
		{
			if(-e "$install_dest_path\\$folder")
			{
				if(IsValidArchive("$install_dest_path\\$folder") == 1) { $IsArchive = 1; }
				else { ProcessMessage(Format($Messages{LS_LOG_INSDESTINVALID}, $folder), LOG_LEVEL_ERROR); next; }
			}
			else
			{
				ProcessMessage(Format($Messages{LS_LOG_INSDESTNOTEXIST}, $folder), LOG_LEVEL_ERROR);
				next;
			}
		}
		
		if($folder eq "\.\\") { $foldername = 'Game';  }
		else                  { $foldername = $folder; }
		
		if($folder ne '' and ($folder =~ /\.\.\\/) == 0)
		{
			if($uninstall_ini->section_exists($section) == 0)
			{ $uninstall_ini->add_section($section); }
			
			if($IsArchive == 0 and (-e "$install_dest_path\\$folder") == 0)
			{
				ProcessMessage(Format($Messages{LS_LOG_INSCREATEFOLDER}, "$install_dest_path\\$folder"), LOG_LEVEL_INFORMATION);
				
				my $err = undef;
				make_path("$install_dest_path\\$folder", {error=>\$err});
				
				if(@$err)
				{
					ProcessMessage(Format($Messages{LS_LOG_INSFOLDERCREATEFAIL}, "$install_dest_path\\$folder"), LOG_LEVEL_ERROR);
				}
			}
			
			foreach($ini_object->section_params($section))
			{
				if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_ =~ /^\;/) == 0))
				{ push(@lines2, $_); }
			}
			
			if((scalar @lines2) > 0)
			{
				if($IsArchive == 1)
				{
					# Set whether to treat this as an ERF or a RIM
					if($foldername =~ /\.rim$/) { $IsERF = 0; }
					else                        { $IsERF = 1; }

					if($IsERF == 1)
					{
						$ERF = Bioware::ERF->new();
						$ERF->read_erf("$install_dest_path\\$folder");

						$ERF_name = $ERF->{'erf_filename'};
						$ERF_name = (split(/\//, $ERF_name))[-1];
						
						if(($folder ~~ @ERFs) == 0) { push(@ERFs, $folder); }
					}
					else
					{
						$ERF = Bioware::RIM->new();
						$ERF->read_rim("$install_dest_path\\$folder");

						$ERF_name = $ERF->{'rim_filename'};
						$ERF_name = (split(/\//, $ERF_name))[-1];
						
						if(($folder ~~ @ERFs) == 0) { push(@ERFs, $folder); }
					}

					# Make a backup in the Backup folder
					if((MakeBackup("$install_dest_path\\$folder", 'modules')) == 1)
					{
						ProcessMessage(Format($Messages{LS_LOG_INSBACKUPFILE}, $ERF_name, $install_path . "\\backup\\"), LOG_LEVEL_INFORMATION);
					}
					
					# Now pull everything into a sub-folder named after the level
					# itself. This way we aren't having to deal with the data in
					# memory...
					$ERF_type = substr($ERF_name, (length($ERF_name) - 3), 3);
					$ERF_name = substr($ERF_name, 0, (length($ERF_name) - 4));
					
					make_path("$install_path\\" . $ERF_name, {chmod=>0777, user=>$user});

					foreach(@{$ERF->{Files}})
					{
						$ERF->export_resource_by_index($ERF->get_resource_id_by_name($_), "$install_path\\$ERF_name\\$_");
					}
				}
				
				my $repnum = 0;
				my $delnum = 0;
				
				foreach(@lines2)
				{
					my $key = $_;
					my $file = $ini_object->get($section, $key);
					my $filename = $file;
					
					if(lc($key) eq '!overridetype') { next; }
					
					my $sourcefile = $ini_object->get($file, '!SourceFile', $file);
					my $file = $ini_object->get($file, '!SaveAs', $file);
					
					if($file ne '' and (-e "$install_path\\$sourcefile") == 1)
					{
						if($IsArchive == 0) # Copying (or replacing) to a folder
						{
							if(-e "$install_dest_path\\$folder\\$file") # The file exists already...
							{
								if(lc(substr($key, 0, 7)) eq 'replace') # The file exists, but will be replaced
								{
									if(index($key, '.exe') > 0) # Make sure it's not an .exe.
									{
										ProcessMessage(Format($Messages{LS_LOG_INSNOEXEPLEASE}, $file), LOG_LEVEL_ALERT);
										next;
									}
									if(index($key, '.tlk') > 0) # Make sure it's not a .tlk.
									{
										ProcessMessage(Format($Messages{LS_LOG_INSENOUGHTLK}, $file), LOG_LEVEL_ALERT);
										next;
									}
									if(index($key, '.key') > 0) # Make sure it's not a .key.
									{
										ProcessMessage(Format($Messages{LS_LOG_INSSKELETONKEY}, $file), LOG_LEVEL_ALERT);
										next;
									}
									if(index($key, '.bif') > 0) # Make sure it's not a .bif.
									{
										ProcessMessage(Format($Messages{LS_LOG_INSBIFTHEUNDERSTUDY}, $file), LOG_LEVEL_ALERT);
										next;
									}
									
									if($InstallInfo{Backups} == 1) # Make a backup
									{
										MakeBackup("$install_dest_path\\$folder\\$file", "$folder");
									}
									
									$uninstall_ini->set($section, "Replace$repnum", $filename);
									
									if($uninstall_ini->section_exists($filename) == 0)
									{ $uninstall_ini->add_section($filename); }
									
									$uninstall_ini->set($filename, '!SourceFile', $filename);
									$uninstall_ini->set($filename, '!SaveAs', $filename);
									$repnum++;
									
									unlink("$install_dest_path\\$folder\\$file");
									File::Copy::copy("$install_path\\$sourcefile", "$install_dest_path\\$folder\\$file");
									UpdateProgress();
									
									if($file ne $sourcefile)
									{
										ProcessMessage(Format($Messages{LS_LOG_INSREPLACERENAME}, $sourcefile, $file, $foldername), LOG_LEVEL_INFORMATION);
									}
									else
									{
										ProcessMessage(Format($Messages{LS_LOG_INSREPLACE}, $file, $foldername), LOG_LEVEL_INFORMATION);
									}
								}
								else # The file won't be replaced.
								{
									if($ini_object->get($file, '!Silent', 0) == 0)
									{
										ProcessMessage(Format($Messages{LS_LOG_INSLASKIP}, $file, $foldername), LOG_LEVEL_ALERT);
									}
								}
							}
							else # The file doesn't exist, just copy it over.
							{
								$uninstall_ini->set($section, "Delete$delnum", $filename);
								
								if($uninstall_ini->section_exists($filename) == 0)
								{ $uninstall_ini->add_section($filename); }
								
								$uninstall_ini->set($filename, '!SourceFile', $filename);
								$uninstall_ini->set($filename, '!SaveAs', $filename);
								$delnum++;
								
								File::Copy::copy("$install_path\\$sourcefile", "$install_dest_path\\$folder\\$file");
								UpdateProgress();
								
								if($file ne $sourcefile)
								{
									ProcessMessage(Format($Messages{LS_LOG_INSRENAMECOPY}, $sourcefile, $file, $foldername), LOG_LEVEL_INFORMATION);
								}
								else
								{
									ProcessMessage(Format($Messages{LS_LOG_INSCOPYFILE}, $file, $foldername), LOG_LEVEL_INFORMATION);
								}
							}
						}
						else # Inserting the file into an ERF or RIM
						{
							if((-e "$install_path\\$ERF_name\\$file") == 1) # It already exists in the ERF or RIM.
							{
								if(lc(substr($key, 0, 7)) eq 'replace') # It will be replaced, though.
								{
									$uninstall_ini->set($section, "Replace$repnum", $filename);
									
									if($uninstall_ini->section_exists($filename) == 0)
									{ $uninstall_ini->add_section($filename); }
									
									$uninstall_ini->set($filename, '!SourceFile', $filename);
									$uninstall_ini->set($filename, '!SaveAs', $filename);
									$repnum++;
									
									unlink("$install_path\\$ERF_name\\$file");
									File::Copy::copy("$install_path\\$sourcefile", "$install_path\\$ERF_name\\$file");
									UpdateProgress();
									
									if($file ne $sourcefile)
									{
										ProcessMessage(Format($Messages{LS_LOG_INSREPLACERENAMEFILE}, $sourcefile, $file, $foldername), LOG_LEVEL_INFORMATION);
									}
									else
									{
										ProcessMessage(Format($Messages{LS_LOG_INSREPLACEFILE}, $file, $foldername), LOG_LEVEL_INFORMATION);
									}
								}
								else # It will not be replaced...
								{
									ProcessMessage(Format($Messages{LS_LOG_INSLASKIPFILE}, $file, $foldername), LOG_LEVEL_ALERT);
								}
							}
							else
							{
								$uninstall_ini->set($section, "Delete$delnum", $filename);
								
								if($uninstall_ini->section_exists($filename) == 0)
								{ $uninstall_ini->add_section($filename); }
								
								$uninstall_ini->set($filename, '!SourceFile', $filename);
								$uninstall_ini->set($filename, '!SaveAs', $filename);
								$delnum++;
								
								File::Copy::copy("$install_path\\$sourcefile", "$install_path\\$ERF_name\\$file");
								UpdateProgress();
									
								if($file ne $sourcefile)
								{
									ProcessMessage(Format($Messages{LS_LOG_INSRENAMEADDFILE}, $sourcefile, $file, $foldername), LOG_LEVEL_INFORMATION);
								}
								else
								{
									ProcessMessage(Format($Messages{LS_LOG_INSADDFILE}, $file, $foldername), LOG_LEVEL_INFORMATION);
								}
							}
							
							HandleERFOverrideType($file, $folder, 1);
						}
					}
					else
					{
						ProcessMessage(Format($Messages{LS_LOG_INSCOPYFAILED}, $file), LOG_LEVEL_ERROR);
					}
				}
				
				# $GUI->{mw}->update();
			}
			else
			{
				ProcessMessage(Format($Messages{LS_LOG_INSNOMODIFIERS}, $section, $foldername), LOG_LEVEL_ERROR);
			}
		}
		else
		{
			ProcessMessage(Format($Messages{LS_LOG_INSINVALIDDESTINATION}, $foldername), LOG_LEVEL_ERROR);
		}
	}
}

# Functions to process the 2DA files and sub-functions to help with that.
sub Do2DAList
{
	print "\nDo2DAList\n";
	my @lines1   = ();
	my @lines2   = ();
	my $two_da   = Bioware::TwoDA->new();
	my $filename = undef;
	my $row_job  = undef;
	
	foreach($ini_object->section_values('2DAList'))
	{
		if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_ =~ /^\;/) == 0))
		{
			push(@lines1, $_);
		} 
	}

	foreach $filename (@lines1)
	{
		($twoda_addnum, $twoda_chanum, $twoda_colnum, $twoda_delcolnum, $twoda_delnum) = (0, 0, 0, 0, 0);
		
		@lines2 = ();
		
		if($uninstall_ini->section_exists($filename) == 0)
		{ $uninstall_ini->add_section($filename); }
		
		my @answer = ExecuteFile($filename, 'file2DA');
		
		if($filename ne '' and $answer[0] == 1)
		{
			my $file = $answer[1];
			
			if((-e $file) == 0)
			{
				ProcessMessage(Format($Messages{LS_LOG_2DAFILENOTFOUND}, (split(/\//, $file))[-1]), LOG_LEVEL_ERROR);
				next;
			}
			
			$two_da = Bioware::TwoDA->new();
			
			if($two_da->read2da($file) > 0)
			{
				foreach($ini_object->section_params($filename))
				{
					if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_ =~ /^\;/) == 0))
					{
						push (@lines2, $_);
					}
				}
				
				foreach $row_job (@lines2)
				{
					my $modifier = $ini_object->get($filename, $row_job, '');
					
					   if($row_job =~ /AddRow/)       { Add2daRow($two_da, $modifier);       }
					elsif($rwo_job =! /DeleteRow/)    { Delete2daRow($two_da, $modifier);    }
					elsif($row_job =~ /ChangeRow/)    { Change2daRow($two_da, $modifier);    }
					elsif($row_job =~ /AddColumn/)    { Add2daColumn($two_da, $modifier);    }
					elsif($row_job =~ /DeleteColumn/) { Delete2daColumn($two_da, $modifier); }
					elsif($row_job =~ /CopyRow/)      { Copy2daRow($two_da, $modifier);      }
					else
					{
						ProcessMessage(Format($Messages{LS_LOG_2DAINVALIDMODIFIER}, $row_job, $modifier), LOG_LEVEL_ALERT);
					}
				}
				
				$two_da->write2da($file);
			}
			else
			{
				ProcessMessage(Format($Messages{LS_LOG_2DALOADERROR}, (split(/\//, $file))[-1]), LOG_LEVEL_ALERT);
			}
		}
		else
		{
			ProcessMessage(Format($Messages{LS_LOG_2DANOFILESELECTED}, $filename), LOG_LEVEL_ALERT);
		}
		
		UpdateProgress();
	}
}

sub GetMemoryToken
{
    my $value = shift;

	if(substr($value, 0, 9) eq '2DAMEMORY')
	{
		my $tmp = substr($value, 9, (length($value) - 9));
		
		if($tmp >= 0)
		{
			if((($tmp ~~ @twoda_tokens) == 0) and ((scalar @twoda_tokens) > 0)) #(((scalar @twoda_tokens) - 1) < $tmp) and (((scalar @twoda_tokens) - 1) > 0))
			{
				$tmp = 1;
				ProcessMessage(Format($Messages{LS_LOG_TOKENINDEXERROR1}, $value), LOG_LEVEL_ALERT);
			}
			elsif((($tmp ~~ @twoda_tokens) == 0) and ((scalar @twoda_tokens) < 1)) #if((((scalar @twoda_tokens) - 1) < $tmp) and (((scalar @twoda_tokens) - 1) <= 0))
			{
				ProcessMessage(Format($Messages{LS_LOG_TOKENINDEXERROR2}, $value), LOG_LEVEL_ERROR);
				return $value;
			}
			
			#$tmp -= 1;
			if($tmp < 0) { $tmp = 0; }
		}
		else
		{
			if((scalar @twoda_tokens) > 0)
			{
				$tmp = 0;
				ProcessMessage(Format($Messages{LS_LOG_TOKENINDEXERROR1}, $value), LOG_LEVEL_ALERT);
			}
			else
			{
				ProcessMessage(Format($Messages{LS_LOG_TOKENINDEXERROR2}, $value), LOG_LEVEL_ERROR);
				return $value;
			}
		}
		
		ProcessMessage(Format($Messages{LS_LOG_GETTOKENVALUE}, $value, $Tokens{'2DAMEMORY' . $tmp}), LOG_LEVEL_VERBOSE);
		return $Tokens{'2DAMEMORY' . $tmp};
	}
	else { return $value; }
}

sub SetMemoryToken
{
	my ($key, $value, $action, $twoda, $rowindex, $constant) = @_;
	
	if(substr($key, 0, 9) eq '2DAMEMORY')
	{
		my $tmp = substr($key, 9, (length($key) - 9));
		
		if($tmp < 0)
		{
			ProcessMessage($Messages{LS_LOG_TOKENERROR1}, LOG_LEVEL_ERROR);
			return 0;
		}
		
		#$tmp -= 1;
		if($tmp < 0) { $tmp = 0; }
		
		if($action == ACTION_ADD_ROW or
		   $action == ACTION_COPY_ROW or
		   $action == ACTION_MODIFY_ROW)
		{
			if($value eq 'RowIndex')
			{
				push (@twoda_tokens, $tmp);
				$Tokens{'2DAMEMORY' . $tmp} = $rowindex;
				ProcessMessage(Format($Messages{LS_LOG_TOKENFOUND}, $key, $rowindex), LOG_LEVEL_VERBOSE);
			}
			elsif($value eq 'RowLabel')
			{
				if(($rowindex > -1) and ($rowindex < $twoda->{rows}))
				{
					push (@twoda_tokens, $tmp);
					$Tokens{'2DAMEMORY' . $tmp} = $twoda->get_row_header($rowindex);
					ProcessMessage(Format($Messages{LS_LOG_TOKENFOUND}, $key, $twoda->get_row_header($rowindex)), LOG_LEVEL_VERBOSE);
				}
				else
				{
					ProcessMessage(Format($Messages{LS_LOG_TOKENCOLLABELERROR}, $rowindex), LOG_LEVEL_ALERT);
				}
			}
			else
			{
				push (@twoda_tokens, $tmp);
				$Tokens{'2DAMEMORY' . $tmp} = $twoda->get_cell($twoda->get_row_header($rowindex), $value);
				ProcessMessage(Format($Messages{LS_LOG_TOKENFOUND}, $key, $Tokens{'2DAMEMORY' . $tmp}), LOG_LEVEL_VERBOSE);
			}
		}
		elsif($action == ACTION_ADD_COLUMN)
		{
			if($value eq 'ColumnLabel')
			{
				if($rowindex > -1 and $rowindex < (scalar @{$twoda->{columns}}))
				{
					push (@twoda_tokens, $tmp);
					$Tokens{'2DAMEMORY' . $tmp} = @{$twoda->{columns}}[$rowindex];
					ProcessMessage(Format($Messages{LS_LOG_TOKENFOUND}, $key, $Tokens{'2DAMEMORY' . $tmp}), LOG_LEVEL_INFORMATION);
				}
				else
				{
					ProcessMessage(Format($Messages{LS_LOG_TOKENCOLLABELERROR}, $rowindex), LOG_LEVEL_ALERT);
				}
			}
			else
			{
				$tmp = substr($value, 1, length($value) - 1);
				if((lc(substr($value, 0, 1)) eq 'i') and ($tmp >= 0))
				{ $row = $tmp; }
				elsif((lc(substr($value, 0, 1)) eq 'l') and ($tmp ne ''))
				{ $row = $twoda->get_row_header($tmp); }
				else
				{ $row = -1; }
			}
		}
		elsif($action == ACTION_ADD_FIELD)
		{
			if(lc($value) eq 'listindex')
			{
				push (@twoda_tokens, $tmp);
				$Tokens{'2DAMEMORY' . $tmp} = $rowindex;
				ProcessMessage(Format($Messages{LS_LOG_LINDEXTOKENFOUND}, $key, $rowindex), LOG_LEVEL_VERBOSE);
			}
			elsif(lc($value) eq '!fieldpath')
			{
				push (@twoda_tokens, $tmp);
				$Tokens{'2DAMEMORY' . $tmp} = $constant;
				ProcessMessage(Format($Messages{LS_LOG_FPATHTOKENFOUND}, $key, $constant), LOG_LEVEL_VERBOSE);
			}
		}
		
		return 1;
	}
	else
	{ return 0; }
}

sub CheckForNonExclusiveLabel
{
	my ($twoda, $section, $exclusive, $oldrow) = @_;
	
	my $haslabel = 0;
	if($exclusive ~~ @{$twoda->{columns}})
	{
		$haslabel = 1;
	}
	
	if($haslabel == 0)
	{
		ProcessMessage(Format($Messages{LS_LOG_EXCLUSIVECOLINVALID}, $exclusive), LOG_LEVEL_ALERT);
		return (1, 0);
	}
	
	my $value = $ini_object->get($section, $exclusive, '');
	
	if($value ne '')
	{
		foreach(0 .. ($twoda->{rows} - 1))
		{
			if($twoda->get_cell($twoda->get_row_header($_), $exclusive) eq $value)
			{
				ProcessMessage(Format($Messages{LS_LOG_EXCLUSIVEMATCHFOUND}, $exclusive, $_), LOG_LEVEL_VERBOSE);
				return (0, $_);
			}
		}
	}
	else
	{
		ProcessMessage(Format($Messages{LS_LOG_NOEXCLUSIVEVALUESET}, $exclusive, $section), LOG_LEVEL_ERROR);
		return (1, -1);
	}
	
	return (1, 0);
}

sub CheckLabelIdentifier
{
	my ($index, $twoda, $section, $key, $value) = @_;
	
	if(($key eq 'LabelIndex') and ($value ne '') and ($index == -1))
	{
		$HasLabel = 0;
		if('label' ~~ @{$twoda->{columns}}) { $HasLabel = 1; }
		
		if($HasLabel == 0)
		{
			ProcessMessage(Format($Messages{LS_LOG_2DANOLABELCOL}, $key, $section), LOG_LEVEL_ERROR);
			return $index;
		}
		
		foreach(0 .. ($twoda->{rows} - 1))
		{
			if($twoda->get_cell($twoda->get_row_header($_), 'label') eq $value)
			{
				if($index > -1)
				{
					ProcessMessage($Messages{LS_LOG_2DANONEXCLUSIVECOL}, LOG_LEVEL_ALERT);
					ProcessMessage(Format($Messages{LS_LOG_2DAMULTIMATCHINDEX}, $index, $_), LOG_LEVEL_VERBOSE);
				}
				
				$index = $_;
			}
		}
		
		return $index;
	}
	
	return $index;
}

sub Add2daRow
{
	my ($twoda, $section) = @_;
	
	my $modify_row = undef;
	my $exclusive  = $ini_object->get($section, 'ExclusiveColumn', '');
	my $added      = 0;
	
	if($exclusive ne '')
	{
		my @answer = CheckForNonExclusiveLabel($twoda, $section, $exclusive);
		
		if($answer[0] == 0)
		{
			$modify_row = $answer[1];
			$added = 1;
		}
	}
	
	my @data = ();
	foreach($ini_object->section_params($section))
	{
		if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_ =~ /^\;/) == 0))
		{
			push (@data, $_);
		}
	}
	
	my $piece = undef;
	foreach $piece (@data)
	{
		my $piece_value = $ini_object->get($section, $piece, '');
		#print "Piece: $piece Value: $piece_value\n";
		
		if($piece eq 'ExclusiveColumn') { next; }
		elsif(lc($piece) eq 'rowlabel')
		{
			if(lc($piece_value) eq 'high()')
			{
				my $val = 0;
				
				foreach(0 .. ($twoda->{rows} - 1))
				{
					if(@{$twoda->{rows_array}}[$_] > $val)
					{ $val = @{$twoda->{rows_array}}[$_]; }
				}
				
				$piece_value = $val + 1;
				ProcessMessage(Format($Messages{LS_LOG_2DAHIGHTOKENRLFOUND}, $piece_value), LOG_LEVEL_VERBOSE);
			}
			
			$piece_value = GetMemoryToken($piece_value);
			
			if($piece_value ne '')
			{
				if($added == 0)
				{
					$modify_row = $twoda->add_row($piece_value);
					ProcessMessage(Format($Messages{LS_LOG_2DAADDINGROW}, $modify_row, $twoda->{filename}), LOG_LEVEL_VERBOSE);
					$added = 1;
				}
			}
			
		}
		elsif($added == 1 and SetMemoryToken($piece, $piece_value, ACTION_ADD_ROW, $twoda, $modify_row))
		{ } # do nothing
		else
		{
			if($added == 0)
			{
				$modify_row = $twoda->add_row($piece_value);
				ProcessMessage(Format($Messages{LS_LOG_2DAADDINGROW}, $modify_row, $twoda->{filename}), LOG_LEVEL_VERBOSE);
				$added = 1;
			}
			
			if($piece_value eq '') { $piece_value = "****"; }
			
			if(GetIsStringToken($piece_value))
			{
				$piece_value = ProcessStrRefToken($piece_value);
			}
			
			if(lc($piece_value) eq 'high()')
			{
				my $val = 0;
				
				foreach(0 .. ($twoda->{rows} - 1))
				{
					if(@{$twoda->{rows_array}}[$_] > $val)
					{ $val = @{$twoda->{rows_array}}[$_]; }
				}
				
				$piece_value = $val + 1;
				ProcessMessage(Format($Messages{LS_LOG_2DAHIGHTOKENVALUE}, $piece, $piece_value), LOG_LEVEL_VERBOSE);
			}
			
			$piece_value = GetMemoryToken($piece_value);
			
			#print "Row header for row $modify_row is " . $twoda->get_row_header($modify_row) . "\n";
			$twoda->change_cell($twoda->get_row_header($modify_row), $piece, $piece_value);
		}
	}
	
	$uninstall_ini->set($twoda->{filename}, "DeleteRow$twoda_delnum", $modify_row);
	$twoda_delnum++;
}

sub Delete2daRow
{
	my ($twoda, $section) = @_;
	
	my $row = $twoda->get_row_header($section);
	if($row == -1)
	{
		ProcessMessage(Format($Messages{LS_LOG_2DADELETEROWERR}, $section), LOG_LEVEL_ALERT);
		return -1;
	}
	
	$uninstall_ini->set($twoda->{filename}, "AddRow$twoda_addnum", (split(/\./, $twoda->{filename}))[0] . "_row_delete_$section_0");
	$twoda_addnum++;
	
	my $un_section = (split(/\./, $twoda->{filename}))[0] . "_row_delete_$section_0";
	
	if($uninstall_ini->section_exists($un_section) == 0)
	{ $uninstall_ini->add_section($un_section); }
	
	ProcessMessage(Format($Messages{LS_LOG_2DADELETINGROW}, $modify_row, $twoda->{filename}), LOG_LEVEL_VERBOSE);
	foreach(@{$twoda->{columns}})
	{
		$uninstall_ini->set($un_section, $_, $twoda->get_cell($row, $_));
		$twoda->change_cell($row, $_, "****");
	}
	
	return 1;
}

sub Change2daRow
{
	my ($twoda, $section) = @_;

	my @data = ();
	foreach($ini_object->section_params($section))
	{
		if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_ =~ /^\;/) == 0))
		{
			push (@data, $_);
		}
	}
	
	my $piece = undef;
	my $index = -1;
	foreach $piece (@data)
	{
		my $piece_value = $ini_object->get($section, $piece, '');
		
		if((lc($piece) eq 'rowindex') and ($index == -1) and ($piece_value ne ''))
		{
			$piece_value = GetMemoryToken($piece_value);
			
			if(($piece_value < 0) or ($piece_value >= $twoda->{rows}))
			{
				$piece_value = -1;
			}
			else
			{
				$index = $piece_value;
				
				$uninstall_ini->set($twoda->{filename}, "ChangeRow$twoda_chanum", $section);
				$uninstall_ini->add_section($section);
				$uninstall_ini->set($section, 'RowIndex', $index);
				$twoda_chanum++;
				
				ProcessMessage(Format($Messages{LS_LOG_2DAMODIFYLINE}, $index, $twoda->{'filename'}), LOG_LEVEL_VERBOSE);
			}
		}
		elsif((lc($piece) eq 'rowlabel') and ($index == -1) and ($piece_value ne ''))
		{
			$piece_value = GetMemoryToken($piece_value);
			
			if(($piece_value < 0) or ($piece_value >= $twoda->{rows}))
			{
				$piece_value = -1;
			}
			else
			{
				$index = $twoda->get_row_number($piece_value);
				
				$uninstall_ini->set($twoda->{filename}, "ChangeRow$twoda_chanum", $section);
				$uninstall_ini->add_section($section);
				$uninstall_ini->set($section, 'RowLabel', $index);
				$twoda_chanum++;
				
				ProcessMessage(Format($Messages{LS_LOG_2DAMODIFYLINE}, $index, $twoda->{'filename'}), LOG_LEVEL_VERBOSE);
			}
		}
		elsif($index == -1)
		{
			$index = CheckLabelIdentifier($index, $twoda, $section, $piece, $piece_value);
			
			if(($index < 0) or ($index >= $twoda->{rows}))
			{ $index = -1}
			else
			{
				$uninstall_ini->set($twoda->{filename}, "ChangeRow$twoda_chanum", $section);
				$uninstall_ini->add_section($section);
				$uninstall_ini->set($section, 'RowIndex', $index);
				$twoda_chanum++;
				
				ProcessMessage(Format($Messages{LS_LOG_2DAMODIFYLINE}, $index, $twoda->{'filename'}), LOG_LEVEL_VERBOSE);
			}
		}
		elsif(($index == -1) and (lc($piece) ne 'rowlabel') and (lc($piece) ne 'rowindex'))
		{
			ProcessMessage(Format($Messages{LS_LOG_2DANOINDEXFOUND}, $section), LOG_LEVEL_ERROR);
			return;
		}
		elsif(($index > -1) and SetMemoryToken($piece, $piece_value, ACTION_MODIFY_ROW, $twoda, $index))
		{ } # Do nothing here
		elsif(($index > -1) and ($piece ne ''))
		{
			if($piece_value eq '') { $piece_value = "****"; }
			
			if(GetIsStringToken($piece_value))
			{ $piece_value = ProcessStrRefToken($piece_value); }
			
			if($piece ~~ @{$twoda->{columns}})
			{
				if(lc($piece_value) eq 'high()')
				{
					my $val = 0;
					
					foreach(0 .. ($twoda->{rows} - 1))
					{
						if(@{$twoda->{rows_array}}[$_] > $val)
						{ $val = @{$twoda->{rows_array}}[$_]; }
					}
					
					$piece_value = $val + 1;
					ProcessMessage(Format($Messages{LS_LOG_2DAHIGHTOKENVALUE}, $piece, $piece_value), LOG_LEVEL_VERBOSE);
				}
				
				$piece_value = GetMemoryToken($piece_value);
				
				$uninstall_ini->set($piece, $twoda->get_cell($twoda->get_row_header($index), $piece));
				$twoda->change_cell($twoda->get_row_header($index), $piece, $piece_value);
			}
		}
	}
}

sub Add2daColumn
{
	my ($twoda, $section) = @_;
	
	ProcessMessage(Format($Messages{LS_LOG_2DAADDCOLUMN}, $twoda->{filename}), LOG_LEVEL_VERBOSE);
	
	my $added = 0;
	my $default = "****";
	my @lines = ();
	my $piece = undef;
	my $piece_value = undef;
	my $column = undef;
	
	foreach($ini_object->section_params($section))
	{
		if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_ =~ /^\;/) == 0))
		{
			push(@lines, $_);
		}
	}
	
	foreach $piece (@lines)
	{
		$piece_value = $ini_object->get($section, $piece, '');
		
		if((lc($piece) eq 'columnlabel') and ($added == 0))
		{
			if($piece_value ~~ @{$twoda->{columns}})
			{
				ProcessMessage(Format($Messages{LS_LOG_2DACOLEXISTS}, $piece_value, $twoda->{filename}), LOG_LEVEL_ERROR);
				return;
			}
			
			$column = $piece_value;
			$twoda->add_column($column, $default);

			$uninstall_ini->set($twoda->{filename}, "DeleteColumn$twoda_colnum", $column);
			$twoda_colnum++;
			
			$added = 1;
		}
		elsif(($added == 1) and (SetMemoryToken($piece, $piece_value, ACTION_ADD_COLUMN, $twoda, $column)))
		{ } # Do nothing
		elsif((lc($piece) eq 'defaultvalue') and ($added == 1))
		{
			if($piece_value ne '')
			{
				if(GetIsStringToken($piece_value))
				{
					$piece_value = ProcessStrRefToken($piece_value);
				}
				
				$piece_value = GetMemoryToken($piece_value);
				my $old_default = $default;
				$default = $piece_value;
				
				my $row = undef;
				foreach $row (0 .. ($twoda->{rows} - 1))
				{
					if($twoda->get_cell($twoda->get_row_header($row), $column) eq $old_default)
					{ $twoda->change_cell($twoda->get_row_header($row), $column, $default); }
				}
			}
		}
		elsif($added == 1)
		{
			if($piece_value eq '') { $piece_value = $default; }
			
			if(GetIsStringToken($piece_value))
			{ $piece_value = ProcessStrRefToken($piece_value); }
			
			my $index = substr($piece, 1, length($piece));
			if((lc(substr($piece, 0, 1)) eq 'i') and ($index >= 0) and ($index < $twoda->{rows}))
			{
				$twoda->change_cell($twoda->get_row_header($index), $column, $piece_value);
			}
			elsif((lc(substr($piece, 0, 1)) eq 'l') and ($index ne ''))
			{
				$index = $twoda->get_row_number($index);
				$piece_value = GetMemoryToken($piece_value);
				
				if(($index >= 0) and ($index < $twoda->{rows}))
				{
					$twoda->change_cell($twoda->get_row_header($index), $column, $piece_value);
				}
			}
		}
	}
}

sub Delete2daColumn
{
    my ($twoda, $section) = @_;
	
	if($section ~~ @{$twoda->{columns}})
	{
		my $un_section = (split(/\./, $twoda->{filename}))[0] . "_col_delete_$section_0";
		$uninstall_ini->set($twoda->{filename}, "AddColumn$twoda_delcolnum", $un_section);
		$twoda_delcolnum++;
		
		if($uninstall_ini->section_exiss($un_section) == 0)
		{ $uninstall_ini->add_section($un_section); }
		
		$uninstall_ini->set($un_section, "ColumnLabel", $section);
		
		foreach($twoda->{rows_array})
		{
			$uninstall_ini->set($un_section, $_, $twoda->get($_, $section));
		}
		
		$twoda->delete_column($section);
		ProcessMessage(Format($Messages{LS_LOG_2DDELETINGCOLUMN}, $section, $twoda->{filename}), LOG_LEVEL_VERBOSE);
		
		return 1;
	}
	else
	{
		ProcessMessage(Format($Messages{LS_LOG_2DADELETECOLERR}, $section), LOG_LEVEL_ALERT);
		return 0;
	}
}

sub Copy2daRow
{
	my ($twoda, $section) = @_;
	
	my $exclusive  = $ini_object->get($section, 'ExclusiveColumn', '');
	my $added      = 0;
	my $rowlabel   = '';
	my $piece = undef;
	my $index = undef;
	
	if($value ne '')
	{
		my @answer = CheckForNonExclusiveLabel($twoda, $section, $exclusive);
		
		if($answer[0] == 0)
		{
			$$index = $answer[1];
			$added = 1;
		}
	}
	
	my @data = ();
	foreach($ini_object->section_params($section))
	{
		if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_ =~ /^\;/) == 0))
		{
			push (@data, $_);
		}
	}
	
	foreach $piece (@data)
	{
		my $piece_value = $ini_object->get($section, $piece, '');
		#print "Piece: $piece Value: $piece_value\n";
		
		if((lc($piece) eq 'rowindex') and ($index == -1) and ($piece_value ne ''))
		{
			$piece_value = GetMemoryToken($piece_value);
			
			if(($piece_value < 0) or ($piece_value >= $twoda->{rows}))
			{
				$piece_value = -1;
			}
			else
			{
				$index = $piece_value;
				ProcessMessage(Format($Messages{LS_LOG_2DAMODIFYLINE}, $index, $twoda->{'filename'}), LOG_LEVEL_VERBOSE);
			}
		}
		elsif((lc($piece) eq 'rowlabel') and ($index == -1) and ($piece_value ne ''))
		{
			$piece_value = GetMemoryToken($piece_value);
			
			if(($piece_value < 0) or ($piece_value >= $twoda->{rows}))
			{
				$piece_value = -1;
			}
			else
			{
				$index = $twoda->get_row_number($piece_value);
				ProcessMessage(Format($Messages{LS_LOG_2DAMODIFYLINE}, $index, $twoda->{'filename'}), LOG_LEVEL_VERBOSE);
			}
		}
		elsif($piece eq 'ExclusiveColumn') { next; }
		elsif(($index > -1) and (SetMemoryToken($piece, $piece_value, ACTION_COPY_ROW, $twoda, $index)))
		{ } # Do nothing.
		elsif((lc($piece) eq 'newrowlable') and ($piece_value ne ''))
		{
			if(lc($piece_value) eq 'high()')
			{
				my $val = 0;
				
				foreach(0 .. ($twoda->{rows} - 1))
				{
					if(@{$twoda->{rows_array}}[$_] > $val)
					{ $val = @{$twoda->{rows_array}}[$_]; }
				}
				
				$piece_value = $val + 1;
				ProcessMessage(Format($Messages{LS_LOG_2DANEWROWLABELHIGH}, $piece_value), LOG_LEVEL_VERBOSE);
			}
			
			$piece_value = GetMemoryToken($piece_value);
			$rowlabel = $piece_value;
		}
		elsif(($index > -1) and ($piece ne ''))
		{
			if($piece_value eq '') { $piece_value = "****"; }
			
			if(GetIsStringToken($piece_value))
			{ $piece_value = ProcessStrRefToken($piece_value); }
			
			if($added == 0)
			{
				my $old_index = $index;
				if($rowlabel eq '') { $rowlabel = $twoda->{rows}; }
				
				$index = $twoda->add_row($rowlabel, $twoda->get_row_header($index));
				
				if($index == -1)
				{
					ProcessMessage($Messages{LS_LOG_2DACOPYFAILED}, LOG_LEVEL_ERROR);
					return;
				}
				ProcessMessage(Format($Messages{LS_LOG_2DACOPYINGLINE}, $old_index, $index, $twoda->{filename}), LOG_LEVEL_VERBOSE);
			}
			
			if((lc(substr($piece_value, 0, 4)) eq 'inc(') and (substr($piece_value, (length($piece_value) - 1), 1) eq ')'))
			{
				my $temp = substr($piece_value, 4, (length($piece_value) - 1));
				my $value = $twoda->get_cell($twoda->get_row_header($index), $piece);
				
				if(($value >= 0) and ($temp >= 0))
				{
					$piece_value = $value + $temp;
					
					ProcessMessage(Format($Messages{LS_LOG_2DAINCTOPENCOPY}, $piece, $temp, $piece_value), LOG_LEVEL_VERBOSE);
				}
				elsif(($value < 0) and ($temp >= 0))
				{
					ProcessMessage(Format($Messages{LS_LOG_2DAINCFAILED}, $temp), LOG_LEVEL_ALERT);
				}
				elsif(($value >= 0) and ($temp < 0))
				{
					ProcessMessage($Messages{LS_LOG_2DAINCFAILEDNONUM}, LOG_LEVEL_ALERT);
				}
			}
			elsif(lc(substr($piece_value, 0, 6)) eq 'high()')
			{
				my $val = 0;
				
				foreach(0 .. ($twoda->{rows} - 1))
				{
					if(@{$twoda->{rows_array}}[$_] > $val)
					{ $val = @{$twoda->{rows_array}}[$_]; }
				}
				
				$piece_value = $val + 1;
				ProcessMessage(Format($Messages{LS_LOG_2DACOPYHIGH}, $piece, $piece_value), LOG_LEVEL_VERBOSE);
			}
			
			$piece_value = GetMemoryToken($piece_value);
			
			$twoda->change_cell($twoda->get_row_header($index), $piece, $piece_value);
		}
	}
	
	$uninstall_ini->set($twoda->{filename}, "DeleteRow$twoda_delnum", $modify_row);
	$twoda_delnum++;
}

# Functions to process the GFF List and sub-functions to help with that.
sub DoGFFList
{
	print "\nDoGFFList\n";
	my @lines1 = ();
	my @lines2 = ();
	
	foreach($ini_object->section_params('GFFList'))
	{
		if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_ =~ /^\;/) == 0))
		{
			push(@lines1, $_);
		}
	}
	
	if((scalar @lines1) > 0)
	{
		ProcessMessage($Messages{LS_LOG_GFFMODIFYING}, LOG_LEVEL_INFORMATION);
	}
	
	my $piece       = undef;
	my $piece_value = undef;
	my $filename    = undef;
	my $changes     = 0;
	my $Destination = undef;
	my $PatchType   = undef;
	my $Overwrite   = 0;
	my @answer      = ();
	my $gff         = undef;
	my $result      = 1;
	my $key         = undef;
	my $value       = undef;
	foreach $piece (@lines1)
	{
		($gff_delfnum, $gff_delnum, $gff_repnum) = (0, 0, 0);
		
		@lines2 = ();
		$piece_value = $ini_object->get('GFFList', $piece, '');
		$filename = $piece_value;
		$changes = 0;
		
		foreach($ini_object->section_params($piece_value))
		{
			if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_ =~ /^\;/) == 0))
			{
				push(@lines2, $_);
			}
		}
		
		if((scalar @lines2) == 0)
		{
			ProcessMessage(Format($Messages{LS_LOG_GFFNOINSTRUCTION}, $piece_value), LOG_LEVEL_ALERT);
			next;
		}
		else
		{
			$filename = $ini_object->get($piece_value, '!Filename', $piece_value);
		}
		
		$Destination = $ini_object->get($piece_value, '!Destination', 'override');
		
		if(lc($Destination) eq 'override') { $PatchType = 'fileGFF';    }
		else                               { $PatchType = 'fileGFFERF'; }
		
		$Overwrite = 0;
		if($filename ne '') { $Overwrite = $ini_object->get($piece_value, '!ReplaceFile', 0); }
		
		@answer = ExecuteFile($filename, $PatchType, $Overwrite, $Destination);
		
		if(($filename ne '') and ($answer[0] == 1))
		{
			if((-e $answer[1]) == 0) { next; }
			
			$gff = Bioware::GFF->new();
			$result = $gff->read_gff_file($answer[1]);
			
			if($result == 1)
			{
				ProcessMessage(Format($Messages{LS_LOG_GFFMODIFYINGFILE}, (split(/\//, $answer[1]))[-1]), LOG_LEVEL_INFORMATION);
				if($Overwrite == 0)
				{ $uninstall_ini->set('GFFList', "Replace$gff_repnum", (split(/\//, $answer[1]))[-1]); $gff_repnum++; }
				else
				{ $uninstall_ini->set('GFFList', "Delete$gff_delnum", (split(/\//, $answer[1]))[-1]); $gff_delnum++; }
				
				if((scalar @lines2) > 0)
				{
					my $un_section = (split(/\//, $answer[1]))[-1];
					if($uninstall_ini->section_exists($un_section) == 0)
					{ $uninstall_ini->add_section($un_section); }
					
					foreach $key (@lines2)
					{
						$value = $ini_object->get($piece_value, $key, '');
						
						$key = GetMemoryToken($key);
						
						$skip = 0;
						if($key eq '')
						{
							$skip = 1;
							ProcessMessage($Messages{LS_LOG_GFFBLANKFIELDLABEL}, LOG_LEVEL_ALERT);
						}
						
						if(GetIsStringToken($value))
						{ $value = ProcessStrRefToken($value); }
						else
						{ $value = GetMemoryToken($value); }
						
						if((lc(substr($key, 0, 12)) eq '!replacefile') or
						   (lc(substr($key, 0, 12)) eq '!destination') or
						   (lc(substr($key, 0, 9)) eq '!sourcefile') or
						   (lc(substr($key, 0, 7)) eq '!saveas') or
						   (lc(substr($key, 0, 13)) eq '!overridetype'))
						{ $skip = 1; }
						
						if(substr($key, 0, 11) eq 'DeleteField')
						{
							if(DeleteGFFField($gff, $value, '') == 1)
							{
								ProcessMessage(Format($Messages{LS_LOG_GFFFIELDDELETED}, (split(/\//, $answer[1]))[-1]), LOG_LEVEL_INFORMATION);
								$changes++;
							}
							
							$skip = 1;
						}
						if(substr($key, 0, 8) eq 'AddField')
						{
							my @v = AddGFFField($gff, $value, '');
							if($v[0] == 1)
							{
								$uninstall_ini->set($un_section, "DeleteField$gff_delfnum", "delete_gff$gff_delfnum" . "_section");

								$uninstall_ini->add_section("delete_gff$gff_delfnum" . "_section");
								$uninstall_ini->set("delete_gff$gff_delfnum" . "_section", 'Path', $ini_object->get($value, 'Path', ''));
								$uninstall_ini->set("delete_gff$gff_delfnum" . "_section", 'FieldType', $ini_object->get($value, 'FieldType', ''));
								$uninstall_ini->set("delete_gff$gff_delfnum" . "_section", 'Label', $ini_object->get($value, 'Label', ''));
								$uninstall_ini->set("delete_gff$gff_delfnum" . "_section", 'Value', $ini_object->get($value, 'Value', ''));
								$uninstall_ini->set("delete_gff$gff_delfnum" . "_section", 'StructIndex', $v[1]);
								
								$gff_delfnum++;
								
								ProcessMessage(Format($Messages{LS_LOG_GFFNEWFIELDADDED}, (split(/\//, $answer[1]))[-1]), LOG_LEVEL_INFORMATION);
								$changes++;
							}
							
							$skip = 1;
						}
						
						if($skip == 0)
						{
							my @v = ChangeGFFFieldValue($gff, $key, $value);
							if($v[0] == 1)
							{
								$uninstall_ini->set($un_section, $key, $v[1]);
								
								ProcessMessage(Format($Messages{LS_LOG_GFFMODIFIEDVALUE}, $value, $key, (split(/\//, $answer[1]))[-1]), LOG_LEVEL_VERBOSE);
								$changes++;
							}
							else
							{
								ProcessMessage(Format($Messages{LS_LOG_GFFINCORRECTLABEL}, $key, (split(/\//, $answer[1]))[-1]), LOG_LEVEL_ALERT);
							}
						}
					}
					
					if($changes > 0)
					{
						if($PatchType eq 'fileGFF')
						{
							if(MakeBackup($answer[1], ''))
							{
								ProcessMessage(Format($Messages{LS_LOG_GFFBACKUPFILE}, (split(/\//, $answer[1]))[-1], "$base/backup"), LOG_LEVEL_INFORMATION);
							}
						}
						else
						{
							if(MakeBackup("$install_dest_path/$Destination", 'modules'))
							{
								ProcessMessage(Format($Messages{LS_LOG_GFFBACKUPDEST}, (split(/(\\|\/)/, $Destination))[-1], "$base/backup"), LOG_LEVEL_INFORMATION);
							}
						}
						
						ProcessMessage(Format($Messages{LS_LOG_GFFMODFIELDSUMMARY}, $changes, (split(/(\\|\/)/, $answer[1]))[-1]), LOG_LEVEL_VERBOSE);

						$gff->write_gff_file($answer[1]);
						UpdateProgress();
						
						if($PatchType eq 'fileGFFERF')
						{
							HandleERFOverrideType((split(/\//, $answer[1]))[-1], $piece_value);
							
							ProcessMessage(Format($Messages{LS_LOG_GFFINSERTDONE}, (split(/(\\|\/)/, $answer[1]))[-1], $Destination), LOG_LEVEL_INFORMATION);
							
							$Destination =~ s/\\/\//g;
							my $ERF_name = (split(/\//, $Destination))[-1];
							my $ERF_type = substr($ERF_name, (length($ERF_name) - 3), 3);
							
							if(("modules/$ERF_name" ~~ @ERFs) == 0)
							{
								my $IsERF = 0;
								my $ERF   = undef;

								# Set whether to treat this as an ERF or a RIM
								if($dest =~ /\.rim$/) { $IsERF = 0; }
								else                  { $IsERF = 1; }
								
								if($IsERF == 1)
								{
									$ERF = Bioware::ERF->new();
									$ERF->read_erf("$install_dest_path\\$folder");
									
									$ERF_name = $ERF->{'erf_filename'};
									$ERF_name = (split(/\//, $ERF_name))[-1];
									
									if(("modules/$ERF_name" ~~ @ERFs) == 0) { push(@ERFs, "modules/$ERF_name"); }
								}
								else
								{
									$ERF = Bioware::RIM->new();
									$ERF->read_rim("$install_dest_path\\$folder");
									
									$ERF_name = $ERF->{'rim_filename'};
									$ERF_name = (split(/\//, $ERF_name))[-1];
									
									if(("modules/$ERF_name" ~~ @ERFs) == 0) { push(@ERFs, "modules/$ERF_name"); }
								}
								
								# Make a backup in the Backup folder
								if((MakeBackup("$install_dest_path\\$folder", 'modules')) == 1)
								{
									ProcessMessage(Format($Messages{LS_LOG_NCSDESTBACKUP}, $ERF_name, $install_path . "\\backup\\"), LOG_LEVEL_INFORMATION);
								}
								
								# Now pull everything into a sub-folder named after the level
								# itself. This way we aren't having to deal with the data in
								# memory...
								$ERF_type = substr($ERF_name, (length($ERF_name) - 3), 3);
								$ERF_name = substr($ERF_name, 0, (length($ERF_name) - 4));
					
								make_path("$install_path\\" . $ERF_name, {chmod=>0777, user=>$user});
								
								foreach(@{$ERF->{Files}})
								{
									$ERF->export_resource_by_index($ERF->get_resource_id_by_name($_), "$install_path\\$ERF_name\\$_");
								}
							}
							
							$ERF_name = (split(/\//, $Destination))[-1];
							$ERF_name = substr($ERF_name, 0, (length($ERF_name) - 4));
							
							if($answer[1] ne "$install_path/$ERF_name/" . (split(/(\\|\/)/, $answer[1]))[-1])
							{
								File::Copy::copy($answer[1], "$install_path/$ERF_name/" . (split(/(\\|\/)/, $answer[1]))[-1]);
							}
							
							
							if(($answer[1] ne "$install_path/$ERF_name/" . (split(/(\\|\/)/, $answer[1]))[-1]) && ($InstallInfo{bInstall} == 1))
							{ unlink($answer[1]); }
							
							ProcessMessage(Format($Messages{LS_LOG_GFFSAVEINERFORRIM}, (split(/(\\|\/)/, $answer[1]))[-1], (split(/(\\|\/)/, $Destination))[-1]), LOG_LEVEL_INFORMATION);
						}
						else
						{
							ProcessMessage(Format($Messages{LS_LOG_GFFUPDATEFINISHED}, (split(/\//, $answer[1]))[-1]), LOG_LEVEL_INFORMATION);
						}
					}
					else
					{
						ProcessMessage(Format($Messages{LS_LOG_GFFNOCHANGES}, (split(/\//, $answer[1]))[-1]), LOG_LEVEL_ALERT);
					}
				}
				else
				{
					ProcessMessage(Format($Messages{LS_LOG_GFFNOMODIFIERS}, $filename), LOG_LEVEL_ALERT);
				}
			}
			else
			{
				ProcessMessage(Format($Messages{LS_LOG_GFFCANTLOADFILE}, (split(/\//, $answer[1]))[-1]), LOG_LEVEL_ERROR);
			}
		}
		else
		{
			ProcessMessage(Format($Messages{LS_LOG_GFFNOFILEOPENED}, $filename), LOG_LEVEL_ALERT);
		}
	}
}

sub DeleteGFFField
{
	my ($gff, $section, $override_path) = @_;
	
	my @lines1 = ();
	foreach($ini_object->section_params($section))
	{
		if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_ =~ /^\;/) == 0))
		{
			push(@lines1, $_);
		}
	}
	
	if((scalar @lines1) == 0)
	{
		ProcessMessage(Format($Messages{LS_LOG_GFFSECTIONMISSING}, $section), LOG_LEVEL_ALERT);
		return 0;
	}
	
	my $type   = $ini_object->get($section, 'FieldType', '');
	my $path   = $ini_object->get($section, 'Path', $override_path);
	my $key    = $ini_object->get($section, 'Label', '');
	my $index    = $ini_object->get($section, 'StructIndex', 0);
	
	my $struct = $gff->{Main};
	my $stype   = FIELD_STRUCT;
	
	if($path ne '')
	{
		foreach(split(/(\\|\/)/, $path))
		{
			if(($stype eq FIELD_LIST) and (looks_like_number($_)))
			{
				$struct = $struct->{Value}[$_];
				$stype  = $struct->{Type};
			}
			else
			{
				if((scalar $struct{Fields}) > 1)
				{
					$struct = $struct->{Fields}[$struct->get_field_ix_by_label($_)];
				}
				else
				{
					$struct = $struct->{Fields};
				}
				
				$stype  = $struct->{Type};
			}
#			$struct = $struct->{Fields}[$struct->get_field_ix_by_label($_)];
#			$stype = $struct->{Type};
		}
	}
	
	if(($stype ne FIELD_STRUCT) and ($stype ne FIELD_LIST))
	{
		ProcessMessage(Format($Messages{LS_LOG_GFFPARENTALERROR}, $path, $key), LOG_LEVEL_ALERT);
		return 0;
	}
	
	   if($type eq 'Byte')         { $type = FIELD_BYTE; }
	elsif($type eq 'Char')         { $type = FIELD_CHAR; }
	elsif($type eq 'Short')        { $type = FIELD_SHORT; }
	elsif($type eq 'Float')        { $type = FIELD_FLOAT; }
	elsif($type eq 'Double')       { $type = FIELD_DOUBLE; }
	elsif($type eq 'Int')          { $type = FIELD_INT; }
	elsif($type eq 'Int64')        { $type = FIELD_INT64; }
	elsif($type eq 'ExoString')    { $type = FIELD_CEXOSTRING; }
	elsif($type eq 'ExoLocString') { $type = FIELD_CEXOLOCSTRING; }
	elsif($type eq 'Position')     { $type = FIELD_POSITION; }
	elsif($type eq 'Orientation')  { $type = FIELD_ORIENTATION; }
	elsif($type eq 'ResRef')       { $type = FIELD_RESREF; }
	elsif($type eq 'Word')         { $type = FIELD_WORD; }
	elsif($type eq 'Dword')        { $type = FIELD_DWORD; }
	elsif($type eq 'Struct')       { $type = FIELD_STRUCT; }
	elsif($type eq 'List')         { $type = FIELD_LIST; }
	
	my $ModPath = $path;
	if(length($ModPath) > 0) { $ModPath = $path . "\\"; }
	
	my $deleted = 0;
	if($type eq FIELD_LIST)
	{
		my $new;
		foreach(@{$struct->{Value}})
		{
			if($_->{StructIndex} == $index)
			{ $deleted = 1; }
			else
			{ push(@$new, $_); }
		}
		$struct->{Value} = @$new;
	}
	else
	{
		foreach(@{$struct->{Fields}})
		{
			if(($_>{Label} eq $label) and ($_->{Type} eq $type))
			{ $struct->deleteField($_->{FieldIndex}); $deleted = 1; last; }
		}
	}
	
	if($deleted == 0)
	{
		ProcessMessage(Format($Messages{LS_LOG_GFFCANTDELETEFIELD}, $key, $path, (split(/(\\|\/)/, $gff->{filename}))[-1]), LOG_LEVEL_ALERT);
		return 0;
	}
	
	return 1;
}

sub AddGFFField
{
	my ($gff, $section, $override_path) = @_;
	
	my @lines1 = ();
	foreach($ini_object->section_params($section))
	{
		if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_ =~ /^\;/) == 0))
		{
			push(@lines1, $_);
		}
	}
	
	my $my_index = 0;
	if((scalar @lines1) == 0)
	{
		ProcessMessage(Format($Messages{LS_LOG_GFFSECTIONMISSING}, $section), LOG_LEVEL_ALERT);
		return 0;
	}
	
	my $type   = $ini_object->get($section, 'FieldType', '');
	my $path   = $ini_object->get($section, 'Path', $override_path);
	my $key    = $ini_object->get($section, 'Label', '');
	my $value  = $ini_object->get($section, 'Value', '');
	
	my $struct = $gff->{Main};
	my $stype   = FIELD_STRUCT;

	$path =~ s#\\#\/#g;
	if($path ne '')
	{
		# print "Full path: $path\n\nNow doing: ";
		# "kor36_sithstudm.utc"
		
		my $pcounter = 0;
		foreach(split(/\//, $path))
		{
#			print "$_ -> ";
			if($pcounter == 0)
			{
#				print "_ $_ _\n";
				if(ref($struct->{Fields}) ne 'Bioware::GFF::Field')
				#if((scalar $struct->{Fields}) > 1)
				{
					if(ref($struct->{Fields}) eq 'ARRAY')
					{
#						print "1 ";
						$struct = $struct->{Fields}[$struct->get_field_ix_by_label($_)];
						$stype = $struct->{Type};
						if ($struct->{Type} == undef or $struct->{Type} eq '') { $stype = FIELD_STRUCT; }
					}
					else
					{
#						print "2 ";
						$struct = $struct->{Fields}{Value}[$_];
						$stype = $struct->{Type};
						if ($struct->{Type} == undef or $struct->{Type} eq '') { $stype = FIELD_STRUCT; }
					}
				}
				else
				{
#					print "3 ";
					$struct = $struct->{Fields};
					$stype = $struct->{Type};
					if ($struct->{Type} == undef or $struct->{Type} eq '') { $stype = FIELD_STRUCT; }
				}
			}
			elsif(($stype eq FIELD_LIST) and (looks_like_number($_)))
			{
				#print "4 ";
				#print "Number of list elements: " . scalar @{$struct->{Value}};
				#print "\n";
#				print $struct->{Value}[$_] . "\n";
#				print @{$struct->{Value}}[$_] . "\n";
				$struct = @{$struct->{Value}}[$_];# or $struct->{Value}{$_};
				$stype  = $struct->{Type};
				if ($struct->{Type} == undef or $struct->{Type} eq '') { $stype = FIELD_STRUCT; }
				#print "label:_" . $struct->{Label} . "_" . DecodeFieldType($stype) . "_\n";
			}
			else
			{
				if(ref($struct->{Fields}) ne 'Bioware::GFF::Field')
				#if((scalar $struct->{Fields}) > 1)
				{
#					print "5 ";
					$struct = $struct->{Fields}[$struct->get_field_ix_by_label($_)];
					$stype = $struct->{Type};
					if ($struct->{Type} == undef or $struct->{Type} eq '') { $stype = FIELD_STRUCT; }
				}
				else
				{
					if($stype ne FIELD_STRUCT)
					{
#						print "6 ";
						$struct = $struct->{Fields};
						$stype  = $struct->{Type};
						if ($struct->{Type} == undef or $struct->{Type} eq '') { $stype = FIELD_STRUCT; }
					}
					else
					{
#						print "7 ";
						$struct = @{$struct{Fields}{Value}}[$_];
						$stype  = $struct->{Type};
						if ($struct->{Type} == undef or $struct->{Type} eq '') { $stype = FIELD_STRUCT; }
					}
				}
			}
			
#			print DecodeFieldType($stype) . "\n";
			if($pcounter > 0)
			{
				#$struct = $struct->{Fields}[$struct->get_field_ix_by_label($_)];
				#$stype = $struct->{Type};
			}
			
			$pcounter++;
		}
	}
#	print "\n\n";
	if(($stype ne FIELD_STRUCT) and ($stype ne FIELD_LIST))
	{
		ProcessMessage(Format($Messages{LS_LOG_GFFPARENTALERROR}, $path, $key), LOG_LEVEL_ALERT);
		return 0;
	}
	
	my $ModPath = $path;
	if(length($ModPath) > 0) { $ModPath = $path . "\\"; }
	
	if(GetIsStringToken($value))
	{ $value = ProcessStrRefToken($value); }
	
	$value = GetMemoryToken($value);
	
	my $modified = 0;

	if($stype != FIELD_LIST)
	{
		if($key eq '')
		{
			ProcessMessage(Format($Messages{LS_LOG_GFFMISSINGLABEL}, $section), LOG_LEVEL_ALERT);
			return 0;
		}
		
		my $field = $struct->get_field_by_label($key);
		
		if($field ne undef)
		{
			if(($type eq 'Byte') and ($field->{Type} eq FIELD_BYTE))
			{ $field->{Value} = $value; }
			elsif(($type eq 'Char') and ($field->{Type} eq FIELD_CHAR))
			{ $field->{Value} = $value; }
			elsif(($type eq 'Word') and ($field->{Type} eq FIELD_WORD))
			{ $field->{Value} = $value; }
			elsif(($type eq 'Short') and ($field->{Type} eq FIELD_SHORT))
			{ $field->{Value} = $value; }
			elsif(($type eq 'DWORD') and ($field->{Type} eq FIELD_DWORD))
			{ $field->{Value} = $value; }
			elsif(($type eq 'Int') and ($field->{Type} eq FIELD_INT))
			{ $field->{Value} = $value; }
			elsif(($type eq 'Int64') and ($field->{Type} eq FIELD_INT64))
			{ $field->{Value} = $value; }
			elsif(($type eq 'Float') and ($field->{Type} eq FIELD_FLOAT))
			{ $field->{Value} = $value; }
			elsif(($type eq 'Double') and ($field->{Type} eq FIELD_DOUBLE))
			{ $field->{Value} = $value; }
			elsif(($type eq 'ExoString') and ($field->{Type} eq FIELD_CEXOSTRING))
			{ $field->{Value} = $value; }
			elsif(($type eq 'ResRef') and ($field->{Type} eq FIELD_RESREF))
			{ $field->{Value} = $value; }
			elsif(($type eq 'ExoLocString') and ($field->{Type} eq FIELD_CEXOLOCSTRING))
			{
				$value = $ini_object->get($section, 'StrRef', '-1');
				
				if(GetIsStringToken($value))
				{ $value = ProcessStrRefToken($value); }
				
				$value = GetMemoryToken($value);
				
				if((looks_like_number($value) == 0) and ($value ne '-1'))
				{
					ProcessMessage(Format($Messages{LS_LOG_GFFINVALIDSTRREF}, $value), LOG_LEVEL_ALERT);
					$value = -1;
				}
				
				$field->{Value}{StringRef} = $value;
				
				my $temp1 = undef;
				foreach $temp1 (@lines2)
				{
					if((length($temp1) > 4) and (substr($temp1, 0, 4) eq 'lang'))
					{
						$id = substr($temp1, 4, (length($temp1) - 4));
						if(looks_like_number($id))
						{
							$value = $ini_object->get($section, $temp1, '');
							
							if(GetIsStringToken($value))
							{ $value = ProcessStrRefToken($value); }
							
							$value = GetMemoryToken($value);
							
							$id_found = 0;
							foreach($field->{Value}{Substrings})
							{
								if($_->{'StringID'} == $id) { $_->{'Value'} = $value; $id_found = 1; last; }
							}
							
							if($id_found == 0)
							{
								my $new = Bioware::GFF::CExoLocSubString->new();
								
								$new->{'StringID'} = $id;
								$new->{'Value'}    = $value;
								
								push(@{$field->{Value}{Substrings}}, $new);
							}
						}
					}
				}
			}
			elsif(($type eq 'Orientation') and ($field->{Type} eq FIELD_ORIENTATION))
			{ $field->{Value} = split(/\|/, $value); }
			elsif(($type eq 'Position') and ($field->{Type} eq FIELD_POSITION))
			{ $field->{Value} = split(/\|/, $value); }
			elsif(($type eq 'Struct') and ($field->{Type} eq FIELD_STRUCT))
			{
				$value = $ini_object->get($section, 'TypeId', '');
				
				if(($stype == FIELD_LIST) and (lc($value) eq 'listindex'))
				{ $value = scalar @{$struct->{Value}}; }
				
				if(looks_like_number($value))
				{ $field->{'ID'} = $value; }
			}
			elsif(($type eq 'List') and ($field->{Type} eq FIELD_LIST))
			{ } # Do nothing.
			else
			{
				if(length($ModPath) == 0) { $ModPath = 'root'; }
				
				ProcessMessage(Format($Messages{LS_LOG_GFFLABELEXISTS}, $key, $ModPath), LOG_LEVEL_ALERT);
				return 0;
			}
			
			if(length($ModPath) == 0) { $ModPath = 'root'; }
			
			ProcessMessage(Format($Messages{LS_LOG_GFFLABELEXISTSMOD}, $key, $ModPath), LOG_LEVEL_INFORMATION);
			$modified = 1;
		}
	}

	if($modified == 0)
	{
		if($type eq 'Byte')
		{ $struct->createField('Type'=>FIELD_BYTE, 'Label'=>$key, 'Value'=>$value); }
		elsif($type eq 'Char')
		{ $struct->createField('Type'=>FIELD_CHAR, 'Label'=>$key, 'Value'=>$value); }
		elsif($type eq 'Word')
		{ $struct->createField('Type'=>FIELD_WORD, 'Label'=>$key, 'Value'=>$value); }
		elsif($type eq 'Short')
		{ $struct->createField('Type'=>FIELD_SHORT, 'Label'=>$key, 'Value'=>$value); }
		elsif($type eq 'DWORD')
		{ $struct->createField('Type'=>FIELD_DWORD, 'Label'=>$key, 'Value'=>$value); }
		elsif($type eq 'Int')
		{ $struct->createField('Type'=>FIELD_INT, 'Label'=>$key, 'Value'=>$value); }
		elsif($type eq 'Int64')
		{ $struct->createField('Type'=>FIELD_INT64, 'Label'=>$key, 'Value'=>$value); }
		elsif($type eq 'Float')
		{ $struct->createField('Type'=>FIELD_FLOAT, 'Label'=>$key, 'Value'=>$value); }
		elsif($type eq 'Double')
		{ $struct->createField('Type'=>FIELD_DOUBLE, 'Label'=>$key, 'Value'=>$value); }
		elsif($type eq 'ExoString')
		{ $struct->createField('Type'=>FIELD_CEXOSTRING, 'Label'=>$key, 'Value'=>$value); }
		elsif($type eq 'ResRef')
		{ $struct->createField('Type'=>FIELD_RESREF, 'Label'=>$key, 'Value'=>$value); }
		elsif($type eq 'ExoLocString')
		{
			$value = $ini_object->get($section, 'StrRef', '-1');
			
			if(GetIsStringToken($value))
			{ $value = ProcessStrRefToken($value); }
			
			$value = GetMemoryToken($value);
			
			if((looks_like_number($value) == 0) and ($value ne '-1'))
			{
				ProcessMessage(Format($Messages{LS_LOG_GFFINVALIDSTRREF}, $value), LOG_LEVEL_ALERT);
				$value = -1;
			}
			
			
			my $temp1 = undef;
			my $values;
			foreach $temp1 (@lines2)
			{
				if((length($temp1) > 4) and (substr($temp1, 0, 4) eq 'lang'))
				{
					$id = substr($temp1, 4, (length($temp1) - 4));
					if(looks_like_number($id))
					{
						$value = $ini_object->get($section, $temp1, '');
						
						if(GetIsStringToken($value))
						{ $value = ProcessStrRefToken($value); }
						
						$value = GetMemoryToken($value);
						
						my $new = Bioware::GFF::CExoLocSubString->new();
							
						$new->{'StringID'} = $id;
						$new->{'Value'}    = $value;
							
						push(@$values, $new);
					}
				}
			}
			
			$struct->createField('Type'=>FIELD_CEXOLOCSTRING, 'Label'=>$key, 'StringRef'=>$value, 'Substrings'=>@$values);
		}
		elsif($type eq 'Orientation')
		{ $struct->createField('Type'=>FIELD_ORIENTATION, 'Label'=>$key, 'Value'=>split(/\|/, $value)); }
		elsif($type eq 'Position')
		{ $struct->createField('Type'=>FIELD_POSITION, 'Label'=>$key, 'Value'=>split(/\|/, $value)); }
		elsif($type eq 'Struct')
		{
			$value = $ini_object->get($section, 'TypeId', '');
			
			if(($stype == FIELD_LIST) and (lc($value) eq 'listindex'))
			{ $value = scalar @{$struct->{Value}}; }
			
			my $new_struct = Bioware::GFF::Struct->new();
			$new_struct->{StructIndex} = $gff->{highest_struct};
			$gff->{highest_struct} += 1;
			$my_index = ($gff->{highest_struct} - 1);
			
			if(looks_like_number($value))
			{ $new_struct->{'ID'} = $value; }
			
			push(@{$struct->{Value}}, $new_struct);
		}
		elsif($type eq 'List')
		{ } # Do nothing.
		else
		{
			ProcessMessage(Format($Messages{LS_LOG_GFFINVALIDTYPEDATA}, $type, $section, (split(/(\\|\/)/, $gff->{filename}))[-1]), LOG_LEVEL_ALERT);
			return 0;
		}
	}
	else { return 0; }
	
	return (1, $my_index);
}

sub DecodeFieldType
{
	my $type = shift;
	
	   if($type eq FIELD_BYTE)			{ return 'BYTE';			}
	elsif($type eq FIELD_CHAR)			{ return 'CHAR';			}
	elsif($type eq FIELD_WORD)			{ return 'WORD';			}
	elsif($type eq FIELD_SHORT)			{ return 'SHORT';			}
	elsif($type eq FIELD_DWORD)			{ return 'DWORD';			}
	elsif($type eq FIELD_INT)			{ return 'INT';				}
	elsif($type eq FIELD_DWORD64)		{ return 'DWORD64';			}
	elsif($type eq FIELD_INT64)			{ return 'INT64';			}
	elsif($type eq FIELD_FLOAT)			{ return 'FLOAT';			}
	elsif($type eq FIELD_DOUBLE)		{ return 'DOUBLE';			}
	elsif($type eq FIELD_CEXOSTRING)	{ return 'CEXOSTRING';		}
	elsif($type eq FIELD_RESREF)		{ return 'RESREF';			}
	elsif($type eq FIELD_CEXOLOCSTRING) { return 'CEXOLOCSTRING';	}
	elsif($type eq FIELD_BINARY) 		{ return 'BINARY';			}
	elsif($type eq FIELD_STRUCT)		{ return 'STRUCT';			}
	elsif($type eq FIELD_LIST) 			{ return 'LIST';			}
	elsif($type eq FIELD_ORIENTATION)	{ return 'ORIENTATION';		}
	elsif($type eq FIELD_POSITION)		{ return 'POSITION';		}
	elsif($type eq FIELD_STRREF)		{ return 'STRREF';			}
}

sub ChangeGFFFieldValue
{
	my ($gff, $path, $value) = @_;
	
	my $struct = $gff->{Main};
	my $stype  = FIELD_STRUCT;
	
#	print "path1: $path\n";
	$path =~ s#\\#\/#g;
	my @paths = split(/\//, $path);
	$path = pop @paths;
	my $old_value = undef;
	
	if($path ne '')
	{
#		print "path2: $path\n";
		my $pcounter = 0;
		foreach(@paths)
		{
#			print "Now doing $_: ";
			if($pcounter == 0)
			{
				if(ref($struct->{Fields}) ne 'Bioware::GFF::Field')
				#if((scalar keys %{$struct->{Fields}}) > 1)
				{
#					print ref($struct->{Fields}) . "\n";
					if(ref($struct->{Fields}) eq 'ARRAY')
					{
#						print "1 ";
						$struct = $struct->{Fields}[$struct->get_field_ix_by_label($_)];
						$stype = $struct->{Type};
						if ($struct->{Type} == undef or $struct->{Type} eq '') { $stype = FIELD_STRUCT; }
					}
					else
					{
#						print "2 ";
						$struct = $struct->{Fields}{Value}[$_];
						$stype = $struct->{Type};
						if ($struct->{Type} == undef or $struct->{Type} eq '') { $stype = FIELD_STRUCT; }
					}
				}
				else
				{
#					print "3 ";
					$struct = $struct->{Fields};
					$stype = $struct->{Type};
					if ($struct->{Type} == undef or $struct->{Type} eq '') { $stype = FIELD_STRUCT; }
				}
			}
			elsif(($stype eq FIELD_LIST) and (looks_like_number($_)))
			{
#				print "4 ";
				$struct = @{$struct->{Value}}[$_];# or $struct->{Value}{$_};
				$stype  = $struct->{Type};
				if ($struct->{Type} == undef or $struct->{Type} eq '') { $stype = FIELD_STRUCT; }
			}
			else
			{
				if(ref($struct->{Fields}) ne 'Bioware::GFF::Field')
				#if((scalar $struct->{Fields}) > 1)
				{
#					print "5 ";
					$struct = $struct->{Fields}[$struct->get_field_ix_by_label($_)];
					$stype = $struct->{Type};
					if ($struct->{Type} == undef or $struct->{Type} eq '') { $stype = FIELD_STRUCT; }
				}
				else
				{
					if($stype ne FIELD_STRUCT)
					{
#						print "6 ";
						$struct = $struct->{Fields}{Value}[$struct->{Fields}{Value}->get_field_by_label($_)];
						$stype  = $struct->{Type};
						if ($struct->{Type} == undef or $struct->{Type} eq '') { $stype = FIELD_STRUCT; }
					}
					else
					{
#						print "7 ";
						$struct = $struct->{Fields}{Value}->[$_];
						$stype  = $struct->{Type};
						if ($struct->{Type} == undef or $struct->{Type} eq '') { $stype = FIELD_STRUCT; }
					}
				}
			}
			
			if($pcounter > 0)
			{
				#$struct = $struct->{Fields}[$struct->get_field_ix_by_label($_)];
				#$stype = $struct->{Type};
			}
			
#			print "Type: " . DecodeFieldType($stype) . "\n";
			$pcounter++;
		}
#			#print "Now doing $_\n";
#			if(($stype eq FIELD_LIST) and (looks_like_number($_)))
#			{
#				$struct = $struct->{Value}[$_];
#				$stype  = $struct->{Type};
#			}
#			else
#			{
#				$struct = $struct->{Fields}[$struct->get_field_ix_by_label($_)];
#				$stype  = $struct->{Type};
#			}
#		}
	}
	
#	print "path: $path\n";
	if(GetIsStringToken($value))
	{ $value = ProcessStrRefToken($value); }
	
	if($path =~ /lang(\d*)/)
	{
		$path =~ s/lang(\d*)//;
		my $ix = $struct->get_field_ix_by_label($path);
		$id = $1;#substr($temp1, 4, (length($temp1) - 4));
		
		$id_found = 0;
		foreach($struct->{Fields}[$ix]{Value}{Substrings})
		{
			if($_->{'StringID'} == $id) { $old_value = $_->{'Value'}; $_->{'Value'} = $value; $id_found = 1; last; }
		}
		
		if($id_found == 0)
		{
			my $new = Bioware::GFF::CExoLocSubString->new();
			
			$new->{'StringID'} = $id;
			$new->{'Value'}    = $value;
			
			push(@{$struct->{Fields}[$ix]{Value}{Substrings}}, $new);
		}	
	}
	if($path =~ /\(strref\)/)
	{
		$path =~ s/\(strref\)//;
		my $ix = $struct->get_field_ix_by_label($path);
		
		if(defined($ix) == 0) { return (0, ''); }
		$old_value = $struct->{Fields}[$ix]{Value}{StringRef};
		$struct->{Fields}[$ix]{Value}{StringRef} = $value;
	}
	else
	{
		my $ix = undef;
		if(ref($struct->{Fields}) ne 'Bioware::GFF::Field')
		{
			$ix = $struct->get_field_ix_by_label($path);
#			print "ix: $ix\n";
			
			if(defined($ix) == 0) { return (0, ''); }
			
			$old_value = $struct->{Fields}[$ix]{Value};
			$struct->{Fields}[$ix]{Value} = $value;
		}
		else
		{
			if($struct->{Fields}{Label} eq $path)
			{
				$old_value = $struct->{Fields}{Value};
				$struct->{Fields}{Value} = $value;
			}
			else
			{
				return (0, '');
			}
		}
	}
	
	return (1, $old_value);
}

# Functions to perform binary substitutions/re-writes on files.
sub DoHACKList
{
	print "\nDoHACKList\n";
	my @lines1   = ();
	my $filename = undef;
	my $index    = undef;
	
	foreach($ini_object->section_params('HACKList'))
	{
		if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_ =~ /^\;/) == 0))
		{
			push(@lines1, $_);
		} 
	}

	if((scalar @lines1) > 0)
	{
		ProcessMessage($Messages{LS_LOG_HAKSTART}, LOG_LEVEL_INFORMATION);
	}
	
	foreach $index (@lines1)
	{
		$filename = $ini_object->get('HACKList', $index, '');
		
		if(($filename ne '') and (length($filename) > 4))
		{
			ProcessMessage(Format($Messages{LS_LOG_HAKMODIFYFILE}, $filename), LOG_LEVEL_VERBOSE);
			ProcessHACKFile($index, $filename);
		}
	}
}

sub ProcessHACKFile
{
	my $index    = shift;
	my $filename = shift;
	
	my $replace = 0;
	my @data    = ();
	
	$uninstall_ini->set('HACKList', $index, $filename);
	if($uninstall_ini->section_exists($filename) == 0)
	{ $uninstall_ini->add_section($filename); }
	
	foreach($ini_object->section_params($filename))
	{
		if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_ =~ /^\;/) == 0))
		{
			push(@data, $_);
		}
	}
	
	if((scalar @data) <= 0)
	{
		ProcessMessage(Format($Messages{LS_LOG_HAKNOOFFSETS}, $filename), LOG_LEVEL_ALERT);
		return;
	}
	
	if(lc($data[0]) eq 'replacefile')
	{ $replace = $ini_object->get($filename, $data[0], 0); }
	
	my @answer = ExecuteFile($filename, 'fileHACK', $replace);
	if($answer[0] == 1)
	{
		$file = $answer[1];
		
		if((-e $file) == 0)
		{
			ProcessMessage(Format($Messages{LS_LOG_HAKNOVALIDFILE}, $filename), LOG_LEVEL_ERROR);
			return;
		}
		
		if(MakeBackup($file, '') == 1)
		{
			ProcessMessage(Format($Messages{LS_LOG_HAKBACKUPFILE}, (split(/\//, $file))[1], $install_path . '/backup'), LOG_LEVEL_INFORMATION);
		}
		
		open FH, "+<", $file;
		binmode FH;
		
		my ($piece, $piece_value) = (undef, undef);
		foreach $piece (@data)
		{
			$piece_value = $ini_object->get($filename, $piece, '');
			if($piece_value =~ /\"(.*)\"/) { $piece_value = $1; }
			
			if(lc($piece) eq 'replacefile')
			{ $uninstall_ini->set($filename, $piece, $piece_value); } # Do nothing.
			if(lc(substr($piece, 0, 11)) eq '!sourcefile')
			{ $uninstall_ini->set($filename, $piece, $piece_value);  } # Do nothing.
			if(lc(substr($piece, 0, 7)) eq '!saveas')
			{ $uninstall_ini->set($filename, $piece, $piece_value);  } # Do nothing.
			
			if(GetIsStringToken($piece_value))
			{ $piece_value = ProcessStrRefToken($piece_value); }
			
			$piece_value = GetMemoryToken($piece_value);
			
			if(($piece ne '') and ($piece_value ne '') and
			   (looks_like_number($piece)) and (looks_like_number($piece_value)))
			{
				if((-s FH) > $piece)
				{
					use bytes;
					
					sysseek FH, $piece, 0;
					sysread FH, my $chunk, length($piece_value);
					$uninstall_ini->set($filename, $piece, $chunk);
#					substr($chunk, 0, length($chunk), $piece_value);
#					sysseek FH, $piece, 0;
					syswrite FH, $piece_value;
					
					ProcessMessage(Format($Messages{LS_LOG_HAKMODIFYINGDATA}, (split(/\//, $file))[-1], $piece, $piece_value), LOG_LEVEL_VERBOSE);
				}
			}
			else
			{
				ProcessMessage(Format($Messages{LS_LOG_HAKINVALIDOFFSET}, $piece, $piece_value, (split(/\//, $file))[-1]), LOG_LEVEL_ALERT);
			}
		}
		
		close FH;
	}
	
	UpdateProgress();
}

# Functions to process scripts to compile.
sub DoCompileFiles
{
	print "\nDoCompileFiles\n";
	my @lines1 = ();
	
	foreach($ini_object->section_params('CompileList'))
	{
		if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_=~ /^\;/) == 0))
		{
			push(@lines1, $_);
		}
	}
	
	if((scalar @lines1) > 0)
	{
		ProcessMessage($Messages{LS_LOG_NCSBEGINNING}, LOG_LEVEL_INFORMATION);
	}
	else { return; }
	
	my $compiler_path = $base . "/tslpatchdata/nwnnsscomp.exe";
	
	if((-e $compiler_path) == 0)
	{
		ProcessMessage($Messages{LS_LOG_NCSCOMPILERMISSING}, LOG_LEVEL_ERROR);
		return;
	}
	
	my $work_folder = "$base/tslpatchdata/nsstemp/";
	if((-e "$base/tslpatchdata/nsstemp/") == 0)
	{
		make_path("$base/tslpatchdata/nsstemp", {chmod=>0777, user=>$user});
	}
	
	my $NCSDestinsation = $ini_object->get('CompileList', '!DefaultDestination', 'override');
	
	my $piece     = undef;
	my $overwrite = 0;
	my $file      = undef;
	foreach $piece (@lines1)
	{
		my $piece_value = $ini_object->get('CompileList', $piece, '');
		
		if(lc($piece) eq '!defaultdestination')
		{ next; } # Do nothing.
		
		if(lc(substr($piece, 0, 7)) eq 'replace')
		{ $overwrite = 1; }
		else { $overwrite = 0; }
		
		my @answer = ExecuteFile($piece_value, 'fileCompile', $overwrite);
		
		if($answer[0] == 1)
		{
			$file = $answer[1];
			
			ReplaceTokensInFile($file);
			push(@Orgs, $ScriptInfo{OrgFile});
			
			ProcessMessage(Format($Messages{LS_LOG_NCSPROCESSINGTOKENS}, (split(/\//, $ScriptInfo{ModFile}))[-1]), LOG_LEVEL_VERBOSE);
			
			my $FileBase = $install_path . "/";
			$FileBase .= $ini_object->get($piece_value, '!SaveAs', $piece_value);
			$FileBase =~ s/\.nss/\.ncs/;
			
			if(((-e $ScriptInfo{ModFile}) == 1) and ($ScriptInfo{IsInclude} == 0))
			{
				my $flags = $ini_object->get('Settings', 'ScriptCompilerFlags', '');
				if(length($flags) > 0)
				{
					if(($flags =~ /^ /) == 0) { $flags = ' ' . $flags; }
					if(($flags =~ / $/) == 0) { $flags = $flags . ' '; }
				}
				
				my $run = "\"$compiler_path\"" . "$flags -c \"" . $ScriptInfo{ModFile} . "\" -o \"" . $FileBase . "\"";
				
				ProcessMessage(Format($Messages{LS_LOG_NCSCOMPILINGSCRIPT}, (split(/\//, $ScriptInfo{ModFile}))[-1]), LOG_LEVEL_INFORMATION);
				
				my $p1 = getcwd;
				chdir("$base/tslpatchdata");
				my $string = qx/$run/;
				chdir($p1);
				
				ProcessMessage(Format($Messages{LS_LOG_NCSCOMPILEROUTPUT}, $string), LOG_LEVEL_VERBOSE);
				
				my $NCSFile = (split(/\//, $FileBase))[-1];
				
				if(-e $FileBase) #"$base/tslpatchdata/$NCSFile")
				{
					my $dest = $ini_object->get($piece_value, '!Destination', $NCSDestinsation);
					
					if(lc($dest) ne 'override')
					{
						$dest =~ s/\\/\//g;
						
						my $ERF_name = (split(/\//, $dest))[-1];
						my $ERF_type = substr($ERF_name, (length($ERF_name) - 3), 3);
						
						if(("modules/$ERF_name" ~~ @ERFs) == 0) { push(@ERFs, "modules/$ERF_name"); }

						$ERF_name = substr($ERF_name, 0, (length($ERF_name) - 4));
						
						if(-e "$install_path/$ERF_name")
						{
							if(((-e "$install_path/$ERF_name/$NCSFile") == 1) and ($InstallInfo{Backups} = 1))
							{
								MakeBackup("$install_path/$ERF_name/$NCSFile", $ERF_name);
							}
							
							if(((-e "$install_path/$ERF_name/$NCSFile") == 1) and ($overwrite == 0))
							{
								ProcessMessage(Format($Messages{LS_LOG_NCSFILEEXISTSKIP}, (split(/\//, $NCSFile))[-1], (split(/\//, $dest))[-1]), LOG_LEVEL_ALERT);
							}
							else
							{
#								print "FileBase: $FileBase\nCopied to: $install_path/$ERF_name/$NCSFile\n\n";
								ProcessMessage(Format($Messages{LS_LOG_NCSSAVEERFRIM}, (split(/\//, $dest))[-1]), LOG_LEVEL_INFORMATION);
								File::Copy::copy($FileBase, "$install_path/$ERF_name/$NCSFile");
								unlink($FileBase);
								
								HandleERFOverrideType($NCSFile, $piece_value, 0, $NCSDestinsation);
							}
						}
						else
						{
							my $IsERF = 0;
							my $ERF   = undef;
							# Set whether to treat this as an ERF or a RIM
							if($dest =~ /\.rim$/) { $IsERF = 0; }
							else                  { $IsERF = 1; }
							
							if($IsERF == 1)
							{
								$ERF = Bioware::ERF->new();
								$ERF->read_erf("$install_dest_path/$dest");
								
								$ERF_name = $ERF->{'erf_filename'};
								$ERF_name =~ s/\\/\//g;
								$ERF_name = (split(/\//, $ERF_name))[-1];
								
								if(("modules/$ERF_name" ~~ @ERFs) == 0) { push(@ERFs, "modules/$ERF_name"); }
							}
							else
							{
								$ERF = Bioware::RIM->new();
								$ERF->read_rim("$install_dest_path\\$dest");
								
								$ERF_name = $ERF->{'rim_filename'};
								$ERF_name =~ s/\\/\//g;
								$ERF_name = (split(/\//, $ERF_name))[-1];
								
								if(("modules/$ERF_name" ~~ @ERFs) == 0) { push(@ERFs, "modules/$ERF_name"); }
							}
							
							# Make a backup in the Backup folder
							if((MakeBackup("$install_dest_path\\$folder", 'modules')) == 1)
							{
								ProcessMessage(Format($Messages{LS_LOG_NCSDESTBACKUP}, $ERF_name, $install_path . "\\backup\\"), LOG_LEVEL_INFORMATION);
							}
							
							# Now pull everything into a sub-folder named after the level
							# itself. This way we aren't having to deal with the data in
							# memory...
							$ERF_type = substr($ERF_name, (length($ERF_name) - 3), 3);
							$ERF_name = substr($ERF_name, 0, (length($ERF_name) - 4));
					
							make_path("$install_path\\" . $ERF_name, {chmod=>0777, user=>$user});

							foreach(@{$ERF->{Files}})
							{
								$ERF->export_resource_by_index($ERF->get_resource_id_by_name($_), "$install_path\\$ERF_name\\$_");
							}
							
							if(((-e "$install_path/$ERF_name/$NCSFile") == 1) and ($InstallInfo{Backups} = 1))
							{
								MakeBackup("$install_path/$ERF_name/$NCSFile", $ERF_name);
							}
							
							if(((-e "$install_path/$ERF_name/$NCSFile") == 1) and ($overwrite == 0))
							{
								ProcessMessage(Format($Messages{LS_LOG_NCSFILEEXISTSKIP}, (split(/\//, $NCSFile))[-1], (split(/\//, $dest))[-1]), LOG_LEVEL_ALERT);
							}
							else
							{
								ProcessMessage(Format($Messages{LS_LOG_NCSSAVEERFRIM}, (split(/\//, $NCSFile))[-1], (split(/\//, $dest))[-1]), LOG_LEVEL_INFORMATION);
								File::Copy::copy($FileBase, "$install_path/$ERF_name/$NCSFile");
								unlink($FileBase);
								
								HandleERFOverrideType($NCSFile, $piece_value, 0, $NCSDestinsation);
							}
						}
					}
					else
					{
						if($overwrite == 1)
						{
							unlink("$install_dest_path/override/$NCSFile");
						}
						
						File::Copy::copy($FileBase, "$install_dest_path/override/$NCSFile");
						unlink($FileBase);
					}
				}
				else
				{
					ProcessMessage(Format($Messages{LS_LOG_NCSCOMPILEDNOTFOUND}, $file), LOG_LEVEL_ERROR);
				}
			}
			else
			{
				if($ScriptInfo{IsInclude} == 1)
				{
					ProcessMessage(Format($Messages{LS_LOG_NCSINCLUDEDETECTED}, (split(/\//, $file))[-1]), LOG_LEVEL_VERBOSE);
				}
				else
				{
					ProcessMessage(Format($Messages{LS_LOG_NCSPROCNSSMISSING}, (split(/\//, $file))[-1]), LOG_LEVEL_ERROR);
				}
			}
		}
		
		UpdateProgress();
	}
	
	my $Debug = $ini_object->get('Settings', 'SaveProcessedScripts', 0);
	
	my $file = undef;
	foreach $file (@Orgs)
	{
		if($Debug == 1)
		{
			if(-e "$install_path/debug" == 0) { make_path("$install_path/debug", {chmod=>0777, user=>$user}); }
			File::Copy::copy("$install_path/nsstemp/" . (split(/\//, $file))[-1], "$install_path/debug/" . (split(/\//, $file))[-1]);
		}
		
		if(-e $file)
		{
			File::Copy::copy($file, "$install_path/" . (split(/\//, $file))[-1]);
			unlink($file);
		}
	}
	
	@orgs = ();
#	File::Path::rmtree($work_folder);
}

sub ReplaceTokensInFile
{
	my $file = shift;
	my $tmp_file = $base . "/tslpatchdata/nsstemp/" . (split(/(\\|\/)/, $file))[-1];
	
#	print "Replacing tokens in $file\nas $tmp_file\n\n";
	$ScriptInfo{ModFile} = $tmp_file;
	$ScriptInfo{OrgFile} = $file;
	$ScriptInfo{IsInclude} = 1;
	
	File::Copy::copy($file, $tmp_file);
	
	open InFile, "<", $tmp_file;
	
	my $out_text = "";
#	print "Infile: $tmp_file\n\n";
#	print "Outfile: $file\n\n";
	while(<InFile>)
	{
		my $temp = $_;
		
		if($temp =~ /(void main\(\)|void main \(\)|int startingconditional \(\)|int startingconditional \(\))/)
		{ $ScriptInfo{IsInclude} = 0; }
		
		my $key   = undef;
		my $value = undef;
		my $index = undef;
		foreach $key (keys %Tokens)
		{
			$index = index($temp, "#$key#");
			next if $index == -1;

			$value = $Tokens{$key};			
#			print "Key: $key Value: $value Index: $index\n";
#			print "\$temp before: $temp\n";
			substr($temp, $index, (length($key) + 2), $value);
#			print "\$temp after: $temp\n";
		}
		
		$out_text .= $temp;
#		print OutFile $temp;
	}
	
	close InFile;
	
	open OutFile, ">", $tmp_file;
	print OutFile $out_text;
	close OutFile;
}

# Function to process the Soundset Files.
sub DoSSFList
{
	print "\nDoSSFList\n";
	my @lines1 = ();
	my @lines2 = ();
	my @entries = ();
	
	foreach($ini_object->section_params('SSFList'))
	{
		if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_=~ /^\;/) == 0))
		{
			push(@lines1, $_);
		}
	}
	
	my $piece       = undef;
	my $piece_value = undef;
	my $overwrite   = 0;
	foreach $piece (@lines1)
	{
		$piece_value = $ini_object->get('SSFList', $piece, '');
		@lines2 = ();
		
		foreach($ini_object->section_params($piece_value))
		{
			if($_ ne '' and (($_ =~ /__SKIP__/) == 0) and (($_ =~ /^\;/) == 0))
			{
				push(@lines2, $_);
			}
		}
		
		if((scalar @lines2) == 0)
		{
			ProcessMessage(Format($Messages{LS_LOG_SSFNOMODIFIERS}, $piece_value), LOG_LEVEL_ALERT);
			next;
		}
		
		if(lc(substr($piece, 0, 7)) eq 'replace') { $overwrite = 1; }
		else { $overwrite = 0; }
		
		 my @answer = ExecuteFile($piece_value, 'fileSSF', $overwrite);
		 
		 if(($piece_value ne '') and ($answer[0] == 1))
		 {
			my $file = $answer[1];
			
			if((-e $file) == 0)
			{
				ProcessMessage(Format($Messages{LS_LOG_SSFFILENOTFOUND}, $piece_value), LOG_LEVEL_ALERT);
				next;
			}
			
			ProcessMessage(Format($Messages{LS_LOG_SSFMODSTRREFS}, $piece_value), LOG_LEVEL_INFORMATION);
			
			my $ssf = Bioware::SSF->new();
			$ssf->load_ssf($file);
			my $count = 0;
			
			my $key = undef;
			my $value = undef;
			foreach $key (@lines2)
			{
				$value = $ini_object->get($piece_value, $key, '');
				
				if(lc(substr($key, 0, 11)) eq '!sourcefile')
				{ next; } # Do Nothing
				if(lc(substr($key, 0, 7)) eq '!saveas')
				{ next; } # Do Nothing
				
				
				if(GetIsStringToken($value))
				{ $value = ProcessStrRefToken($value); }
				else
				{ $value = GetMemoryToken($value); }
				
				if(looks_like_number($value))
				{
					$ssf->set_entry($key, $value);
					ProcessMessage(Format($Messages{LS_LOG_SSFSETTINGENTRY}, $key, $value), LOG_LEVEL_VERBOSE);
					$count++;
				}
				else
				{
					ProcessMessage(Format($Messages{LS_LOG_SSFINVALIDSTRREF}, $key, $value), LOG_LEVEL_ALERT);
				}
			}
			
			$ssf->save_ssf($file);
			UpdateProgress();
			ProcessMessage(Format($Messages{LS_LOG_SSFUPDATESUMMARY}, $count, $piece_value), LOG_LEVEL_VERBOSE);
		 }
		 else
		 {
			ProcessMessage(Format($Messages{LS_LOG_SSFNOFILE}, $piece_value), LOG_LEVEL_ALERT);
		}
	}
}

# Everything's done. Move to clean-up.
sub DoCleanup
{
	print "\nDoCleanup\n";
	my $IsERF      = 0;
	my $ERF_name   = undef;
	my $ERF_name2  = undef;
	my $ERF_type   = undef;
	my $count      = 0;
	my @ERF_delete = ();
	my @files      = ();
	
	if((scalar @ERFs) > 0)
	{
		foreach (sort @ERFs)
		{
#			print "processing ERF: $_ ";
			/(.*)\.(.*)/;
			
			$ERF_name = (split(/\\/, $1))[0];
			$ERF_name2 = (split(/\\/, $1))[1];
#			print "ERF1 $ERF_name ERF2 $ERF_name2\n";
			$ERF_type = $2;
			$IsERF = 0;
			@files = ();
			
			if($ERF_type ne 'rim') { $IsERF = 1; }
			push(@ERF_delete, $ERF_name2);
			if($IsERF == 1)
			{
				Bioware::ERF::make_new_from_folder("$install_path/$ERF_name2", $ERF_type, "$install_dest_path/$ERF_name/$ERF_name2\." . lc $ERF_type);
			}
			else
			{
				Bioware::RIM::make_new_from_folder("$install_path/$ERF_name2", "$install_dest_path/$ERF_name/$ERF_name2" . "_new\.rim");
			}
			#save_erfrim_package($_);
		}
		
		$ERF_name = undef;
		foreach $ERF_name (@ERF_delete)
		{
#			print "deleting ERF_name: $ERF_name\n";
			opendir DIR, "$install_path/$ERF_name";
			@files = grep { -f } map {"$install_path/$ERF_name/$_"} readdir DIR;
			closedir DIR;
				
			foreach (@files) { unlink($_); }
			#chdir($install_path);
			rmdir("$install_path/$ERF_name");
			#File::Path::remove_tree($ERF_name, {safe => 1});
			#chdir($base);
			#File::Path::rmtree("$install_path/$ERF_name");
			#@files = ();
		}
	}
	
	# NEVER un-comment this unless you want to erase the tslpatchdata folder.
	# This is just an easy copy-paste in case I need to do more clean-up.
	#File::Path::rmtree("$install_path/");
	if(-e "$install_path\\erftemp")
	{ rmdir("$install_path/erftemp"); }

	# File::Path::rmtree("$install_path/erftemp"); }
	
	if(-e "$install_path\\nsstemp")
	{ rmdir("$install_path/nsstemp"); }
	# File::Path::rmtree("$install_path/nsstemp"); }
}

# RTF-processing code starts here, proceeds to end of file.
my @fonts     = ();
my @colorsfg  = ();
my @colorsbg  = ();
my $tag  = 0;
my $aftertext = undef;

my %ParaInfo = (
'spacing1'  => 0,      # sb
'spacing3'  => 0,      # sa
'colorbg'   => 0,      # cb#
'colorfg'   => 0,      # cf#
'inBold'    => 0,      # Until \b0
'inItalics' => 0,      # Until \i0
'inUnder'   => 0,      # Until \ulnone
'inOver'    => 0,       # Until \strike0
'align'     => 'left', # q(l r j c)
);

my %FontInfo = (
weight     => 'normal',
slant      => 'roman',
size       => '6',
family     => 'Calibri',
underline  => 0,
overstrike => 0);

sub ResetParaInfo;
sub ResetFontInfo;
sub ParseRTF;
sub ProcessRTFLine;

sub ResetParaInfo
{
	%ParaInfo = (
	'spacing1'  => 0,      # sb
	'spacing3'  => 0,      # sa
	'colorbg'   => 0,      # cb#
	'colorfg'   => 0,      # cf#
	'inBold'    => $ParaInfo{'inBold'},      # Until \b0
	'inItalics' => $ParaInfo{'inItalics'},      # Until \i0
	'inUnder'   => $ParaInfo{'inUnder'},      # Until \ulnone
	'inOver'    => $ParaInfo{'inOver'},       # Until \strike0
	'align'     => 'left'); # q(l r j c)
}

sub ResetFontInfo
{
    %FontInfo = (
    'weight'     => 'normal',
    'slant'      => 'roman',
    'size'       => '8',
    'family'     => 'Calibri',
    'underline'  => 0,
    'overstrike' => 0);
}

sub ParseInfo
{
	my $file = shift;
	
	$file =~ s#\\#\/#g;
	
	my @a = split(/\//, $file);
	my $a_count = scalar @a;
	$a_count -= 2;
	
	my $path = join('/', @a[0 .. $a_count]);
	$file = pop @a;
	
	my $html_text = '';
	if($file =~ /(\.html|\.htm)/)
	{
		open HTML, "<", $file;
		while(<HTML>)
		{
			if($_ =~ /ï»¿/) { $_ =~ s#ï»¿##g; }
			
			$html_text .= $_;
		}
		close HTML;
	}
	else # It's a .rtf file, so convert to HTML
	{
#		print "converting rtf to html\n";
		print "$path/$file\n$install_path/$file.html\n";
		system("$base/rtf2html.exe", "$path/$file", $install_path);

		sleep(2);
		$_ = $file;
		s#\.rtf#\.html#;
#		print "\$_ is $_\n";
		$file = $_;

		open HTML, "<", "$install_path/$file";
		while(<HTML>)
		{
			if($_ =~ /ï»¿/) { $_ =~ s#ï»¿##g; }
			
			$html_text .= $_;
		}

		close HTML;
		
		unlink("$install_path/$file");
	}
	
	# TSLPatcher::GUI::SetHTMLText(\$html_text);
}

sub ParseRTF
{
	my $file = shift;

#	my $html_code = undef;
#	my $rtf_parser = RTF::HTMLConverter->new(in=>$file, out=>\$html_code);
#	
#	TSLPatcher::GUI::SetHTMLText(\$html_code);

	my @colors = ();

	open FH, "<", $file;

	while(<FH>)
	{
		if($_ =~ /^\{\\rtf/)
		{
			s/(.*)\\fonttbl/\\fonttbl/;
			my @font = split(/\{/, $_);
			shift @font;
			
			foreach (0 .. (scalar @font - 1))
			{
				my $f = $font[$_];
#				print "$_ $f\n";
				unshift @font;

				$_ = $f;
				/(.*)\\(.*)\\fcharset(\d*) (.*);/;
#				print "Pieces: $4\n";
				
				push(@fonts, $4);
			}
		}
		elsif ($_ =~ /\\colortbl/)
		{
			@colors = split(/;/, $_);

			foreach (0 .. (scalar @colors - 2))
			{
				my $c = $colors[$_];
#				print "$_ is $c\n";
				
				if($_ > 0)
				{
					$_ = $c;
#					print "\$_ now: $_\n";

					/\\red(\d*)\\/;
					my $r = $1;
					/\\green(\d*)\\/;
					my $g = $1;
					/\\blue(\d*);/;
					my $b = $1;

					print "$r $g $b\n";

					$r = sprintf("%X", $r);
					$g = sprintf("%X", $g);
					$b = sprintf("%X", $b);
					
					if(length $r < 2) { $r = "0" . $r; }
					if(length $g < 2) { $g = "0" . $g; }
					if(length $b < 2) { $b = "0" . $b; }
					
					$c = "#$r$g$b";
#					print "\$c is now $c\n";
					push(@colorsfg, $c);
					push(@colorsbg, $c);
				}
				else
				{
					push(@colorsfg, "#000000");
					push(@colorsbg, "#FFFFFF");
				}
			}
		}
		elsif ($_ =~ /^\{\\\*\\gen/)
		{
			if (scalar @colors == 0)
			{
				push (@colors, "#000000");
			}
			
			my $line = $_;
#			/(.*?)\\pard/;
#			print "\$1 is $1\n";
			s/(.*?)\\pard/\\pard/;
			s/\\pard//;
#			/(.*)\\par/;
			$line = $_;
			
			ProcessRTFLine($line);			
		}
		else { ProcessRTFLine($_); }
	}
	close FH;
	
	
}

sub ProcessRTFLine
{
	my $line      = shift;
	my $skip      = shift;
	my $index     = 0;
	my $length    = 0;

	chomp $line;

	if(defined($skip) == 0) { $skip = 0; }

	# Remove unused stuff
	$_ = $line;
	s/\\sl(\d*)//;
	s/\\slmult(\d*)//;
	s/\\lang(\d*)//;
	$line = $_;
	
	# Begin processing individual character substitutions
	# Unusual character »
	if($line =~ /\\'bb/) { $line =~ s/\\'bb/»/g; }
	
	# Tab
	if($line =~ /\\tab/) { $line =~ s/\\tab/	/g; }
	
	# The rquote
	if($line =~ /\\rquote /) { $line =~ s/\\rquote /'/g; }
	
	# The lquote
	if($line =~ /\\lquote /) { $line =~ s/\\lquote /'/g; }
	
	# The ldblquote
	if($line =~ /\\ldblquote /) { $line =~ s/\\ldblquote /"/g; }
	
	# The endash
	if($line =~ /\\endash /) { $line =~ s/\\endash /-/g; }
	
	
	# End processing individual character substitutions
	
	# Foreground Color
	if($line =~ /(.*?)\\cf(\d*)(.*)/)
	{
		ProcessRTFLine($1);
		$ParaInfo{'colorfg'} = $2;
		
		$line = "\\cf$2$3\n";
		
		$length = length("\\cf$2");
		$index = index($line, "\\cf$2");
		
		$line = substr($line, 0, $index) . substr($line, ($index + $length), (length($line) - $index));

		if($line =~ /(.*?)\\cf(\d*)(.*)/)
		{
			ProcessRTFLine($1);
			$ParaInfo{'colofg'} = $2;
			$line = ProcessRTFLine($3);
		}
	}
	
	# Background Color
	if($line =~ /(.*?)\\cb(\d*)(.*)/)
	{
		ProcessRTFLine($1);
		$ParaInfo{'colorbg'} = $2;
		
		$line = "\\cb$2$3";
		
		$length = length("\\cb$2");
		$index = index($line, "\\cb$2");
		
		$line = $line = substr($line, 0, $index) . substr($line, ($index + $length), (length($line) - $index));
		
		if($line =~ /(.*?)\\cb(\d*)(.*)/)
		{
			ProcessRTFLine($1);
			$ParaInfo{'colorbg'} = $2;
			$line = ProcessRTFLine($3);
		}
	}

	# Spacing1
	if($line =~ /\\sb(\d*)/)
	{
		$ParaInfo{'spacing1'} = $1 / 20;
		
		$line = join('', split(/\\sb$1/, $line));
	}

	# Spacing 3
	if($line =~ /\\sa(\d*)/)
	{
		$ParaInfo{'spacing3'} = $1 / 20;
		
		$line = join('', split(/\\sa$1/, $line));
	}

	# Font size
	if($line =~ /(.*?)\\fs(\d*)(.*)/)
	{
		if($1 ne '') { ProcessRTFLine($1); }
		$FontInfo{'size'} = ($2 / 2);
		
		$line = "\\fs$2$3";
		
		$length = length("\\fs$2");
		$index = index($line, "\\fs$2");
		
		$line = $line = substr($line, 0, $index) . substr($line, ($index + $length), (length($line) - $index));
		
		if($line =~ /(.*?)\\fs(\d*)(.*)/)
		{
			ProcessRTFLine($1);
			$FontInfo{'size'} = ($2 / 2);
			$line = ProcessRTFLine($3);
		}
	}

	# Font
	if($line =~ /(.*?)\\f(\d*)(.*)/)
	{
		if($1 ne '') { ProcessRTFLine($1); }
		$FontInfo{'family'} = @fonts[$2];
		
		$line = "\\f$2$3";
		
		$line = join('', split(/\\f$2/, $line));
		
		if($line =~ /(.*?)\\f(\d*)(.*)/)
		{
			ProcessRTFLine($1);
			$FontInfo{'family'} = @fonts[$2];
			$line = ProcessRTFLine($3);
		}
	}

	# Alignment
	if($line =~ /\\q(.)/)
	{
		if($1 eq 'l')    { $ParaInfo{'align'} = 'left'; }
		elsif($1 eq 'r') { $ParaInfo{'align'} = 'right'; }
#		elsif($1 eq 'j') { $ParaInfo{'align'} = 'justified'; }
		else             { $ParaInfo{'align'} = 'center'; }
		
		$line = join('', split(/\\q$1/, $line));
	}
	
	# Bold
	if($line =~ /\\b/)
	{
		if($line =~ /(.*)\\b(\D*)\\b0(.*)/)
		{
			ProcessRTFLine($1);
			$ParaInfo{'inBold'} = 1;
			$FontInfo{'weight'} = 'bold';
			
			$line = ProcessRTFLine($2);
			
			$ParaInfo{'inBold'} = 0;
			$FontInfo{'weight'} = 'normal';
			
			ProcessRTFLine($3);
		}
		elsif($ParaInfo{'inBold'} == 0)
		{
			$line =~ /(.*)\\b(\D*)/;
			my $nline = $1;
			$line = $2;
			
			ProcessRTFLine($nline);
			
			$ParaInfo{'inBold'} = 1;
			$FontInfo{'weight'} = 'bold';
			
			$line = substr($line, 0, index($line, '\b')) . substr($line, (index($line, '\b') + 3), (length($line) - index($line, '\b')));
		}
		elsif($ParaInfo{'inBold'} == 1 && $line =~ /\\b0/)
		{
			$line =~ /(.*)\\b0(.*)/;
			my $nline = $1;
			$line = $2;
			
#			if($nline ne '' && ($nline =~ /\\b|\\i|\\b0|\\i0|\\strike|\\strike0|\\sa(\d*)|\\sb(\d*)|\\f(\d*)|\\fs(\d*)|\\cf(\d*)|\\cb(\d*)/) == 0)
#			{
#				WriteRTFLine($nline);
#			}
#			else
#			{
				ProcessRTFLine($nline);
#			}
			
			$ParaInfo{'inBold'} = 0;
			$FontInfo{'weight'} = 'normal';

			
#			$line = join('', split(/\\b0/, $line));
		}
	}
	
	# Underline
	if($line =~ /\\ul/)
	{
		if($line =~ /(.*)\\ul(.*)\\ulnone(.*)/)
		{
			ProcessRTFLine($1);

			$ParaInfo{'inUnder'} = 1;
			$FontInfo{'underline'} = 1;

			$line = ProcessRTFLine($2);
			$ParaInfo{'inUnder'} = 0;
			$FontInfo{'underlined'} = 0;
			
			ProcessRTFLine($3);
		}
		elsif($ParaInfo{'inUnder'} == 0)
		{
			$line =~ /(.*)\\ul(.*)/;
			my $nline = $1;
			$line = $2;
			
			ProcessRTFLine($nline);
			
			$ParaInfo{'inUnder'} = 1;
			$FontInfo{'underline'} = 1;
			
#			$line = substr($line, 0, index($line, '\ul')) . substr($line, (index($line, '\ul') + 3), (length($line) - index($line, '\ul')));
#			print "line: $line\n";
		}
		elsif($ParaInfo{'inUnder'} == 1 && $line =~ /\\ulnone/)
		{
			$line =~ /(.*)\\ulnone(.*)/;
			my $nline = $1;
			$line = $2;
			
#			print "Part to be underlined: $nline\nPart to be processed: $line\n";
#			if($nline ne '' && ($nline =~ /\\b|\\i|\\b0|\\i0|\\strike|\\strike0|\\sa(\d*)|\\sb(\d*)|\\f(\d*)|\\fs(\d*)|\\cf(\d*)|\\cb(\d*)/) == 0)
#			{
#				WriteRTFLine($nline);
#			}
#			else
#			{
				ProcessRTFLine($nline);
#			}

			$ParaInfo{'inUnder'} = 0;
			$FontInfo{'underline'} = 0;

			$line = ProcessRTFLine($line);		
#			$line = join('', split(/\\ulnone/, $line));
		}
	}
	
	# Overstrike
	if($line =~ /\\strike/)
	{
		if($line =~ /(.*)\\strike(.*)\\strike0(.*)/)
		{
			ProcessRTFLine($1);
			
			$ParaInfo{'inOver'} = 1;
			$FontInfo{'overstrike'} = 1;
			
			$line = ProcessRTFLine($2);

			$ParaInfo{'inOver'} = 0;
			$FontInfo{'overstrike'} = 0;
			
			ProcessRTFLine($3);
		}
		elsif($ParaInfo{'inOver'} == 0)
		{
			$line =~ /(.*)\\strike(\D*)/;
			my $nline = $1;
			$line = $2;
			
			ProcessRTFLine($nline);
			
			$ParaInfo{'inOver'} = 1;
			$FontInfo{'overstrike'} = 1;
			
			$line = substr($line, 0, index($line, '\strike')) . substr($line, (index($line, '\strike') + 7), (length($line) - index($line, '\strike')));
		}
		elsif($ParaInfo{'inOver'} == 1 && $line =~ /\\strike0/)
		{
			$line =~ /(.*)\\strike0(.*)/;
			my $nline = $1;
			$line = $2;
			
#			if($nline ne '' && ($nline =~ /\\b|\\i|\\b0|\\i0|\\strike|\\strike0|\\sa(\d*)|\\sb(\d*)|\\f(\d*)|\\fs(\d*)|\\cf(\d*)|\\cb(\d*)/) == 0)
#			{
#				WriteRTFLine($nline);
#			}
#			else
#			{
				ProcessRTFLine($nline);
#			}
			
			$ParaInfo{'inOver'} = 0;
			$FontInfo{'overstrike'} = 0;
			
#			$line = join('', split(/\\strike0/, $line));
		}
	}
	
	# Italics
	if($line =~ /\\i/)
	{
		if($line =~ /(.*)\\i(.*)\\i0(.*)/)
		{
			ProcessRTFLine($1);

			$ParaInfo{'inItalics'} = 1;
			$FontInfo{'slant'} = 'italic';
			
			$line = ProcessRTFLine($2);
			
			$ParaInfo{'inItalics'} = 0;
			$FontInfo{'slant'} = 'roman';
			
			ProcessRTFLine($3);
		}
		elsif($ParaInfo{'inItalics'} == 0)
		{
			$line =~ /(.*)\\i(\D*)/;
			my $nline = $1;
			$line = $2;
			
			ProcessRTFLine($nline);
			
			$ParaInfo{'inItalics'} = 1;
			$FontInfo{'slant'} = 'italic';
			
			$line = substr($line, 0, index($line, '\i')) . substr($line, (index($line, '\i') + 3), (length($line) - index($line, '\i')));
		}
		elsif($ParaInfo{'inItalics'} == 1 && $line =~ /\\i0/)
		{
			$line =~ /(.*)\\i0(.*)/;
			my $nline = $1;
			$line = $2;
			
#			if($nline ne '' && ($nline =~ /\\b|\\i|\\b0|\\i0|\\strike|\\strike0|\\sa(\d*)|\\sb(\d*)|\\f(\d*)|\\fs(\d*)|\\cf(\d*)|\\cb(\d*)/) == 0)
#			{
#				WriteRTFLine($nline);
#			}
#			else
#			{
				ProcessRTFLine($nline);
#			}
			
			$ParaInfo{'inItalics'} = 0;
			$FontInfo{'slant'} = 'roman';
			
#			$line = join('', split(/\\i0/, $line));
		}
	}

	if($line =~ /^\}/) { $line = ''; }
	
	if($line ne '' and $skip == 0)
	{
		chomp $line;

		if($line =~ /^ /)
		{
			$_ = $line;
			s/^ //;
			$line = $_;
		}
		
		if(($line =~ /\\par\\pard/) or ($line =~ /\\pard\\par/))
		{
			$_ = $line;
			s/\\pard//;
#			s/\\par/\n/;
			
			ResetParaInfo;
		}
		elsif($line =~ /\\pard|\\line/)
		{
			$_ = $line;
			s/\\pard|\\line//;
			$line = $_;
			
			ResetParaInfo;
		}
		elsif($line =~ /\\par/)
		{
			$_ = $line;
			s/\\par/\n/;
			$line = $_;
		}
		
		WriteRTFLine($line);
	
		$line = "";
	}
	
	return $line;
}

sub WriteRTFLine
{
	my $line = shift;
	my @tags = ();
	
#	print "Writing line #" . ($tag + 1) . " $line\nBolds: " . $FontInfo{'weight'} . " Italics: " . $FontInfo{'slant'} . " Underlines: " . $FontInfo{'underline'} . " Overstriked: " . $FontInfo{'overstrike'} . " Family: " . $FontInfo{'family'} . " Size: " . $FontInfo{'size'} . " CF: " . $ParaInfo{'colorfg'} . " CB: " . $ParaInfo{'colorbg'} . "\n\n";
	$GUI->{'mwInfoText'}->tagConfigure('Tag' . $tag, -background=>$colorsbg[$ParaInfo{'colorbg'}], -foreground=>$colorsfg[$ParaInfo{'colorfg'}], -font=>[-weight=>$FontInfo{'weight'}, -slant=>$FontInfo{'slant'}, -underline=>$FontInfo{'underline'}, -overstrike=>$FontInfo{'overstrike'}, -family=>$FontInfo{'family'}, -size=>$FontInfo{'size'}],
							-spacing1=>$ParaInfo{'spacing1'}, -spacing3=>$ParaInfo{'spacing3'},-underline=>$FontInfo{'-underline'}, -justify=>$ParaInfo{'align'});
	push (@tags, 'Tag' . $tag);
	
	$tag++;

	$GUI->{'mwInfoText'}->insert('end', $line, @tags);
	@tags = ();
	
	if($aftertext ne '')
	{
		ProcessRTFLine($aftertext, 0);
		$aftertext = '';
	}
}

1;