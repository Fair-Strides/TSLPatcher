package TSLPatcher::GUI;

use experimental qw/smartmatch autoderef switch/;

use Math::Round;

use Tk;
use Tk::BrowseEntry;
use Tk::Button;
use Tk::DialogBox;
use Tk::Frame;
use Tk::HyperText;
use Tk::Label;
use Tk::ProgressBar;
use Tk::ROText;
use Tk::Scrollbar;
use Tk::Toplevel;

use TSLPatcher::Functions;

my $base   = undef;
my $height = undef;
my $width  = undef;
my $icon   = undef;

my %GUI    = ();
$GUI{BMValue} = undef;

sub Set_Base { $base = shift; }
sub Set_Icon { my $window = shift; $window->Icon(-image=>$icon); }

sub Create
{
    my ($build_menu, %options) = @_;

    if(defined($options{Title}) == 0)    { $options{Title} = 'KotOR 1 and 2 Mod Patcher/Installer'; }
    if(defined($options{Geometry}) == 0) { $options{Geometry} = '550x500'; }
	
	# Begin coding the Main Window, which will also be the window used for mod installation progress.
	$GUI{mw} = Tk::MainWindow->new(-title=>$options{Title});
	$GUI{mw}->geometry($options{Geometry});
	$GUI{mw}->resizable(0, 0);
	$icon = $GUI{mw}->Photo(-file=>"TSLPatcher_Icon.bmp", -format=>'bmp');
	
	Set_Icon($GUI{mw});
	
	$_ = $options{Geometry};
	print "\$_ is $_.\n";
	/(\d*)x(\d*)/;
	$width  = $1;
	$height = $2;
	
	print "Height: $height " . (round($height * 0.8)) . "\n";
	print "Width: $width " . (round($width / 7)) . "\n";
	#print "Height: " . round(($height * 0.8) / 14) . " \tWidth: " . round($width / 7) . "\n";
	
	$GUI{mwTextFrame}    = $GUI{mw}->Frame(-height=>round($height * 0.8))->pack(-fill=>'y', -expand=>1);
#	$GUI{mwInfoText}     = $GUI{mwTextFrame}->Scrolled("ROText", -scrollbars=>'oe', -height=>round(($height * 0.8) / 14), -width=>round($width / 7), -wrap=>'word')->pack(-pady=>10, -fill=>'both', -expand=>1);
	$GUI{mwInstallText}  = $GUI{mwTextFrame}->Scrolled("ROText", -scrollbars=>'oe', -height=>round(($height * 0.8) / 14), -width=>round($width / 7), -wrap=>'word');
	
	$GUI{mwInstallText}->tagConfigure('Green',  -foreground=>'#026111', -font=>[-size=>10, -family=>"Courier New", -weight=>'bold']);
	$GUI{mwInstallText}->tagConfigure('Blue',   -foreground=>'#042098', -font=>[-size=>10, -family=>"Courier New"]);
	$GUI{mwInstallText}->tagConfigure('Orange', -foreground=>'#A05702', -font=>[-size=>10, -family=>"Courier New"]);
	$GUI{mwInstallText}->tagConfigure('Red',    -foreground=>'#9C0202', -font=>[-size=>10, -family=>"Courier New"]);
	$GUI{mwInstallText}->tagConfigure('Black',  -foreground=>'#2E2E2E', -font=>[-size=>10, -family=>"Courier New"]);
	$GUI{mwInstallText}->tagConfigure('Mixed',  -foreground=>'#026111', -font=>[-size=>10, -family=>"Courier New"]);

	$GUI{mwProgress} = $GUI{mw}->ProgressBar(-troughcolor=>'#bfbfbf', -colors=>[0, '#7ccd7c'], -width=>5, -gap=>0, -length=>560, -resolution=>-1, -blocks=>100, -from=>0.0, -to=>100.0, -value=>-1)->pack(-padx=>20, -fill=>'y', -expand=>1);
	
	$GUI{mwLowerFrame} = $GUI{mw}->Frame(-height=>($height * 0.2), -width=>($width * 0.9))->pack(-fill=>'both', -pady=>15, -expand=>1);
	$GUI{mwExitBtn}    = $GUI{mwLowerFrame}->Button(-width=>15, -text=>"Quit", -command=>sub { &TSLPatcher::Functions::Exit; })->pack(-anchor=>'w', -side=>'left', -padx=>25, -expand=>1);
	$GUI{mwLabelInfo}  = $GUI{mwLowerFrame}->Label(-text=>"Made by stoffe - August 2007\nTSLPatcher 1.3.0b", -justify=>'center')->pack(-anchor=>'c', -side=>'left', -padx=>50, -expand=>1);
#	$GUI{mwSummaryBtn} = $GUI{mwLowerFrame}->Button(-width=>5, 
	$GUI{mwInstallBtn} = $GUI{mwLowerFrame}->Button(-width=>15, -text=>'Install', -command=>sub { &TSLPatcher::Functions::Install; })->pack(-anchor=>'e', -side=>'left', -padx=>25, -expand=>1);

	$GUI{mwInfoText}     = $GUI{mwTextFrame}->Scrolled("HyperText", -scrollbars=>'oe', -height=>round(($height * 0.8) / 25), -width=>round($width / 7), -wrap=>'word')->pack(-pady=>10, -padx=>10, -fill=>'x', -expand=>1);	
	$GUI{mw}->withdraw;
	
	# Now code the Namespaces Window.
	$GUI{ns} = $GUI{mw}->Toplevel(-title=>'Install Options');
	$GUI{ns}->protocol('WM_DELETE_WINDOW'=>sub { exit; });
	$GUI{ns}->geometry('400x220+0+0');
	$GUI{ns}->resizable(0, 0);
	Set_Icon($GUI{ns});
	
	$GUI{nsLabel}    = $GUI{ns}->Label(-text=>'Please select what to install: ', -font=>[-size=>16], -justify=>'left')->pack(-anchor=>'w', -pady=>5);
	$GUI{nsBrowserVar} = '';
	$GUI{nsBrowser}  = $GUI{ns}->BrowseEntry(-state=>'readonly', -autolimitheight=>1, -autolistwidth=>0, -listheight=>5, -listwidth=>450, -font=>[-size=>9], -width=>450, -browse2cmd=>sub { TSLPatcher::Functions::SetInstallOption($_[1]); }, -variable=>\$GUI{nsBrowserVar})->pack(-padx=>10, -pady=>15, -fill=>'x');
	$GUI{nsDescript} = $GUI{ns}->Scrolled('ROText', -scrollbars=>'oe', -bg=>"#f0f0f0", -relief=>'flat', -wrap=>'word', -height=>6, -width=>60, -font=>[-size=>10])->pack(-fill=>'x', -padx=>5);

	$GUI{nsFrame}    = $GUI{ns}->Frame(-height=>30)->pack(-fill=>'x');
	$GUI{nsQuitBtn}  = $GUI{nsFrame}->Button(-text=>'Exit',   -command=>sub { exit; }, -width=>10)->pack(-side=>'right', -padx=>10, -anchor=>'e');
	$GUI{nsSlctBtn}  = $GUI{nsFrame}->Button(-text=>'Select', -command=>sub { &TSLPatcher::Functions::RunInstallOption; }, -width=>10)->pack(-side=>'right', -padx=>10, -anchor=>'e');
	
	$GUI{ns}->withdraw;

	# Now code the Menu Window
    $GUI{bm} = $GUI{mw}->Toplevel(-title=>'Mod Installation Selection Menu');
	$GUI{bm}->protocol('WM_DELETE_WINDOW'=>sub { exit; });
	$GUI{bm}->geometry('400x500+0+0');
	$GUI{bm}->resizable(0, 0);
	Set_Icon($GUI{bm});
	
	$GUI{bmLabel}  = $GUI{bm}->Label(-text=>"No 'tslpatchdata' folder was found. However, the following folder were found to be installable mods. Please select from one of the folders below:\n\n", -wraplength=>360, -width=>60, -font=>[-size=>12])->pack(-fill=>'x', -padx=>20, -pady=>5);
		
	$GUI{bmFrame1} = $GUI{bm}->Frame(-height=>300, -width=>380)->pack(-fill=>'x', -padx=>10, -pady=>10);
	
	$GUI{bmFrame2} = $GUI{bm}->Frame(-height=>30, -width=>380)->pack(-fill=>'x', -side=>'bottom', -padx=>30, -pady=>10);
	$GUI{bmLtBtn}  = $GUI{bmFrame2}->Button(-text=>'<-', -command=>sub { &TSLPatcher::Functions::BM_ScrollLeft; }, -width=>5)->pack(-side=>'left', -anchor=>'w', -padx=>30);
	$GUI{bmLabel2} = $GUI{bmFrame2}->Label(-text=>'Page 1 of 1', -wraplength=>80, -width=>20)->pack(-side=>'left', -anchor=>'c', -padx=>10);
	$GUI{bmRtBtn}  = $GUI{bmFrame2}->Button(-text=>'->', -command=>sub { &TSLPatcher::Functions::BM_ScrollRight; }, -width=>5)->pack(-side=>'left', -anchor=>'e', -padx=>30);
		
	$GUI{bmFrame3} = $GUI{bm}->Frame(-height=>30, -width=>380)->pack(-fill=>'x', -side=>'bottom', -before=>$GUI{bmFrame2}, -padx=>30);
	$GUI{bmExBtn}  = $GUI{bmFrame3}->Button(-text=>'Exit', -command=> sub { exit; }, -width=>10)->pack(-side=>'left', -anchor=>'w', -padx=>30);
	$GUI{bmGoBtn}  = $GUI{bmFrame3}->Button(-text=>'Install', -command=>sub { &TSLPatcher::Functions::RunInstallPath; }, -width=>10)->pack(-side=>'left', -anchor=>'e', -padx=>50);
		
	$GUI{bm}->withdraw;
	
	# Popup Window 1 ("Ok")
	$GUI{Popup1}{Widget} = $GUI{mw}->DialogBox(-title=>'Warning!', -buttons=>['Ok']);
	$GUI{Popup1}{Widget}->add('Label', -textvariable=>\$GUI{Popup1}{Message})->pack(-fill=>'both', -padx=>35, -pady=>15);

	Set_Icon($GUI{Popup1}{Widget});
	
	# Popup Window 2 ("Yes", "No")
	$GUI{Popup2}{Widget} = $GUI{mw}->DialogBox(-title=>'Query', -buttons=>['Yes', 'No']);
	$GUI{Popup2}{Widget}->add('Label', -textvariable=>\$GUI{Popup2}{Message})->pack(-fill=>'both', -padx=>35, -pady=>15);
	
	Set_Icon($GUI{Popup2}{Widget});
	return (\%GUI, \%options);
}

sub SetHTMLText
{
	my $text = shift;
	
	$GUI{mwInfoText}->allowEverything();
	$GUI{mwInfoText}->loadString($$text);
}

sub BMAddOption
{
	my ($index, $text) = @_;
	
	$GUI{'bmOption' . $index . 'Frame'} = $GUI{bmFrame1}->Frame()->pack(-fill=>'x');
	$GUI{'bmOption' . $index . 'Radio'} = $GUI{'bmOption' . $index . 'Frame'}->Radiobutton(-indicatoron=>1, -value=>$index, -variable=>\$GUI{BMValue}, -command=>sub { &TSLPatcher::Functions::SetInstallPath($index); })->pack(-padx=>25, -side=>'left');
	$GUI{'bmOption' . $index . 'Label'} = $GUI{'bmOption' . $index . 'Frame'}->Label(-text=>$text, -justify=>'left', -width=>40)->pack(-side=>'left', -anchor=>'w', -fill=>'x');
}

sub BMAddSpace
{
	my $index = shift;
	
	$GUI{'bmOption' . $index . 'Frame'} = $GUI{bmFrame1}->Frame()->pack(-fill=>'x');
}

sub BMRemoveOption
{
	my $index = shift;

	$GUI{'bmOption' . $index . 'Frame'}->destroy;
}

1;