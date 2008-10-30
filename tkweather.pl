#!/usr/bin/perl

#NOTE: Windows compile:  perl2exe -gui -perloptions="-p2x_xbm -s" tkweather.pl
#NOTE: POD compile:  pp -g -o tkweather.exe tkweather.pl

=head1 NAME

	TkWeather, by Jim Turner c. 2003, 2004, 2005, 2006, 2007, 2008

=head1 SYNOPSIS

	tkweather.pl [-options=values] [zip-code] [site]

=head1 DESCRIPTION

	This program displays a nice square iconic button showing the 
	current weather condition.  Clicking the button shows the current
	basic weather condition values, such as temperature, humidity, and 
	wind.  Clicking again shows additional information, namely the 
	barometric pressure, UV, visiblility, and "heat index" or 
	"wind chill" or "misery index".  
	Holding the [Shift] key while 
	clicking displays a webpage showing the detailed weather info. 
	Holding the [Ctrl] key while clicking changes to the next weather 
	site.  
	Holding the [Ctrl] key while right-clicking changes to the previous 
	weather site.
	Double-clicking or holding the [Alt] key while clicking refreshes the 
	data. 
	Holding the [Shift] and [Ctrl] keys simultainously while clicking 
	exits the program.
	
	For anyone not from Houston, Texas,
	the old "misery index" is the temperature plus dewpoint.  Anything 
	over 150 is considered "miserable"!  I use this for planning 
	workouts.  The default is to use the more modern "heat index".  
	Specify "index=misery" for the old Houston "misery index".  
	"wind chill" is used if the temperature is below 70 and wind 
	is >= 10mph regardless.

	"site", is currently 0: "weather.com" (weather.com) or 1: "wunderground"
	(www.wunderground.com), 2: NOAA, or 3: Weatherbug.  If it fails on 
	the selected one, it tries the next site.  The default is 0 
	(weather.com).  

=head1 CONFIGURATION

	How to set up:

	1)  This program fetches the current conditions every 15 
	minutes (900 seconds) from www.weather.com or 
	www.wunderground.com.  

	2)  Create a "tkweather" directory in your home directory.

	3)  You will also need to specify your zipcode either as the 
	command-line argument or add a "zipcode=yourzip" line in 
	$HOME/tkweather/tkweather.cfg
	Otherwise you get the weather at the author's zipcode!

	4)  The optional file:  $HOME/tkweather/tkweather.cfg takes the
	format (defaults shown below):  Any line starting with "#" is 
	ignored as a comment.

	geometry=+100+100
	zipcode=76087
	#BROWSER TO BE INVOKED IF USER PRESSES SHIFT-CLICK ON BUTTON. 
	browser=mozilla
	#URL USED FOR SCRAPING WEATHER DATA.
	weatherurl=http://www.w3.weather.com/weather/local/<ZIP>?lswe=<ZIP>&lwsa=WeatherLocalUndeclared
	#COMMAND URL TO BE INVOKED IF USER PRESSES SHIFT-CLICK ON BUTTON. 
	weathercmd=http://www.wunderground.com/cgi-bin/findweather/getForecast?query=<ZIP> &
	#MILLISECONDS TO WAIT BETWEEN QUERIES TO THE WEATHER URL.
	checkmsec=720000
	#BUTTON RELIEF (CHOICES:  flat, groove, raised, ridge, sunken)
	relief=ridge
	#INDEX:  "misery": USE OLD "MISERY INDEX" (HEAT+DEWPOINT),
	#OTHERWISE ("heat") USE MODERN "HEAT INDEX" AS REPORTED.
	#NOTE:  WIND CHILL IS REPORTED IF TEMP. < 70 AND WIND >= 10 MPH
	#REGARDLESS OF THIS SETTING!
	index=heat
	#OVERRIDEDIRECT ARGUMENT 0=MANAGED BY WINDOWMANAGER (DECORATE)
	#1=BYPASS WINDOWMANAGER (NO DECORATION).  USE 0 IF DOCKING IN
	#WINDOWMAKER OR AFTERSTEP.
	windowmgr=0
	#STARTUP ICON IMAGE (MUST BE IN $ENV{HOME}/tkweather/)
	startimage=tkweather.gif
	#WARN ON WHICH TYPES:
	warntypes=tornado|storm|blizard|freeze|flood
	#NORMAL TEXT FOREGROUND COLOR
	normalcolor=green
	#WARNING COLOR
	warningcolor=yellow
	#ALERT COLOR
	alertcolor=red
	#COLD WARNING COLOR  (I USE cyan)  DEFAULT IS warningcolor IF NOT DEFINED.
	cwarningcolor=<undef>
	#COLD ALERT COLOR    (I USE blue)  DEFAULT IS warningcolor IF NOT DEFINED.
	calertcolor=<undef>
	#NORMAL BACKGROUND COLOR
	bgcolor=black
	#SHOW WARNING/ALERT COLOR IN BACKGROUND OF ICON (0=OLD WAY - BGCOLOR)
	bgwarn=1
	#CONVERT TEMPS AND WINDSPEED TO METRIC IF SET.
	metric=0
	#DO NOT DISPLAY MESSAGE TO STDERR WHEN FETCHING WEATHER FROM WEB:
	silent=0
	#DO NOT DUMP DEBUG INFORMATION TO STDERR
	debug=0
	#SHOW SITE NAME IN TEMPERATURE BALLOON
	noshowsite=0

	5)  Copy the image "tkweather.gif" to $HOME/tkweather/

	6)  Copy tkweather.pl to somewhere in your PATH or wherever you 
	want to be able to run it from.  Make sure line 1 points to your
	perl interpreter.

	7)  To make this app appear in your AfterStep/Windowmaker "wharf", 
	add the following to your config file:
	*Wharf Tkwather - MaxSwallow "Tkweather" tkweather.pl &
        
	8)  Enjoy!

=cut

########### THIS SECTION NEEDED BY PAR COMPILER! ############
#NOTE:  FOR SOME REASON, v.pl NEEDS BUILDING WITH:  pp -M Tk::ROText ...!
#REASON:  par does NOT pick up USE and REQUIRE's quoted in EVAL strings!!!!!

#
#STRIP OUT INC PATHS USED IN COMPILATION - COMPILER PUTS EVERYTING IN IT'S OWN
#TEMPORARY PATH AND WE DONT WANT THE RUN-TIME PHISHING AROUND THE USER'S LOCAL
#MACHINE FOR (POSSIBLY OLDER) INSTALLED PERL LIBS (IF HE HAS PERL INSTALLED)!
BEGIN
{
	if ($0 =~ /exe$/io)
	{
		while (@INC)
		{
			$_ = shift(@INC);
			push (@myNewINC, $_)  if (/(?:cache|CODE)/o);
		}
		@INC = @myNewINC;
	}
}
################# END PAR COMPILER SECTION ##################
use Tk;
use Tk ':eventtypes';
use Tk::X11Font;
use Tk::ROText;
use Tk::JPEG;
#use Geo::Weather;
use LWP::Simple;
#eval 'use  Tk::Balloon; $useBalloon = 1;';
use  Tk::Balloon; $useBalloon = 1;

our $VERSION = '1.83';
our $geometry = '';
$cputemp='';
my $thisPgm = $0;
$thisPgm =~ s#\\#\/#gso;
(my $thisPgmName = $thisPgm) =~ s#.+\/([^\/]+)$#$1#o;
$bummer = ($^O =~ /Win/o) ? 1 : 0;
if ($bummer)
{
	$ENV{HOME} ||= $ENV{USERPROFILE}  if (defined $ENV{USERPROFILE});
	$ENV{HOME} ||= $ENV{ALLUSERSPROFILE}  if (defined $ENV{ALLUSERSPROFILE});
	$ENV{HOME} =~ s#\\#\/#gso;
}

#FETCH COMMAND-LINE OPTIONS:

my (@NEWARGV, %opts);
our $dbh;
while (@ARGV) {
	$_ = shift(@ARGV);
	if (/^\-\-(\w+)/o) {
		my $one = $1;
		$opts{$one} = (/\=\"?([^\"]+)\"?$/o) ? $1 : 1;
	} elsif (/^\-(\w+)/o) {
		$opts{'-'} = $1;
		my @v = split('', $opts{'-'});
		my $opt;
		while (@v)
		{
			$opt = shift @v;
			$opts{$opt} = 1;
		}
		$opts{help} = 1  if ($opts{h});  #ALLOW OLD-STYLE "-h" for HELP!
		$opts{debug} = 1  if ($opts{d});
	} else {
		push (@NEWARGV, $_);
	}
}
my $cfgFile = $thisPgmName;
if ($cfgFile =~ /\./o) {
	$cfgFile =~ s/\..*$/\.cfg/o;
} else {
	$cfgFile .= '.cfg';
}

$zipcode = '76087';    #DEFAULT IS AUTHOR'S ZIPCODE!
$browser = $bummer ? 'start' : 'mozilla';
if ($opts{help}) {
	warn "..usage $0 [-d|--debug][--browser=<webbrowser>][--config=<configfile>[--geometry=wxh+x+y][--windowmgr=0|1][--index=heat|misery][--metric=0|1][--site=0|1|2|noaa|weather|wunderground] [zipcode [site]]\n";
	warn "..defaults (unless specified in config file):  --debug=0 --browser=$browser --config=$ENV{HOME}/tkweather/$cfgFile --windowmgr=0 --index=heat --metric=0 --site=weather $zipcode\n";
	exit(0);
}

$cfgFile = $opts{config}  if (defined($opts{config}) && -f $opts{config} && -r $opts{config});
$cfgFile = "$ENV{HOME}/tkweather/" . $cfgFile  unless ($cfgFile =~ m#^(?:\/|\w\:)#o);
unless (-r $cfgFile)
{
	$cfgFile = $thisPgm;
	if ($cfgFile =~ /\./o) {
		$cfgFile =~ s/\..*$/\.cfg/o;
	} else {
		$cfgFile .= '.cfg';
	}
}

if (-r $cfgFile && open(IN, $cfgFile))
{
	my ($var, $val);
	while (<IN>)
	{
		chomp;
		next  if (/^\*\#/o);
		s/\s*\#.*$//o;
		($var, $val) = split(/\=/o, $_, 2);
		next  unless ($var =~ /^(?:zipcode|browser|weathercmd|site|checkmsec|relief|windowmgr|geometry|index|startimage|normalcolor|bgcolor|bgwarn|warntypes|warningcolor|alertcolor|debug|metric|silent|cputemp|cwarningcolor|calertcolor|extra\d)$/o);
		eval "\$$var = '$val';";
	}
}

#$geometry = shift(@ARGV)  if ($ARGV[0] =~ /--geometry/o);
#$geometry =~ s/\-\-geometry\=//o;

push (@ARGV, shift(@NEWARGV)) while (@NEWARGV);
$geometry = $opts{geometry}  if (defined $opts{geometry});

$zipcode = $opts{zipcode}  if (defined $opts{zipcode});
$browser = $opts{browser}  if (defined $opts{browser});
$weatherurls[0] = 'http://www.weather.com/outlook/recreation/golf/local/<ZIP>?from=hp_promolocator&lswe=<ZIP>&lwsa=Weather36HourGolfCommand';
$weatherurls[1] = 'http://www.wunderground.com/cgi-bin/findweather/getForecast?query=<ZIP><EXTRA>';
$weatherurls[2] = 'http://forecast.weather.gov/zipcity.php?Go2=Go&inputstring=<ZIP>';
$weatherurls[3] = 'http://weather.weatherbug.com/Common/SearchResults.html?loc=<ZIP>&nav_section=1&zcode=z6286&lang_i=en-us&country=';

$weatherurls2[0] = '';
$weatherurls2[1] = '';
$weatherurls2[2] = '';
$weatherurls2[3] = '=~\<a href\=\"([^\"]+)\" title\=\"Detailed Conditions';

$weathercmds[0] = 'http://www.weather.com/outlook/recreation/golf/local/<ZIP>?from=hp_promolocator&lswe=<ZIP>&lwsa=Weather36HourGolfCommand';
$weathercmds[1] = 'http://www.wunderground.com/cgi-bin/findweather/getForecast?query=<ZIP><EXTRA>';
$weathercmds[2] = 'http://forecast.weather.gov/zipcity.php?Go2=Go&inputstring=<ZIP>';
$weathercmds[3] = 'http://weather.weatherbug.com/Common/SearchResults.html?loc=<ZIP>&nav_section=1&zcode=z6286&lang_i=en-us&country=';

$altweathercmds[0] = 'http://www.wunderground.com/cgi-bin/findweather/getForecast?query=<ZIP><EXTRA>';
$altweathercmds[1] = 'http://www.wunderground.com/cgi-bin/findweather/getForecast?query=<ZIP><EXTRA>';
$altweathercmds[2] = 'http://www.wunderground.com/cgi-bin/findweather/getForecast?query=<ZIP><EXTRA>';
$altweathercmds[3] = 'http://www.wunderground.com/cgi-bin/findweather/getForecast?query=<ZIP><EXTRA>';

$siteName[0] = 'Weather.com';
$siteName[1] = 'Wunderground';
$siteName[2] = 'NOAA';
$siteName[3] = 'Weatherbug';

$site ||= $weatherurls[0];
$site = $opts{site}  if (defined $opts{site});
$zipcode = $ARGV[0] || $zipcode;    #SET YOUR ZIP-CODE HERE.
$site = $ARGV[1]  if (defined $ARGV[1]);
print "-site specified=$site=\n"  if ($debug);
if ($site =~ /^\d$/o)
{
	$weatherindex = $site;
}
else
{
	$weatherindex = 0;
	for (my $i=3;$i>0;$i--)
	{
		if ($siteName[$i] =~ /^$site/i)
		{
			$weatherindex = $i;
			last;
		}
	}
#	$weatherindex = ($site =~ /wunderground/o) ? 1 : 0;
#	$weatherindex = 2  if ($site =~ /noaa/io);
}
print "-site index selecte=$weatherindex=\n"  if ($debug);
$site = $weatherurls[$weatherindex];
#$weathercmd ||= "http://www.wunderground.com/cgi-bin/findweather/getForecast?query=$zipcode &";
#$weathercmd ||= join('|', @weathercmds);
@weathercmds = split(/\|/o, $weathercmd)  if ($weathercmd);
$checkmsec ||= '720000';
$relief ||= 'ridge';
$windowmgr = $opts{windowmgr}  if (defined $opts{windowmgr});
$windowmgr ||= 0;
$startimage ||= 'tkweather.gif';
$icontype = 'gif';
$index = $opts{'index'}  if (defined $opts{'index'});
$idx = ($index =~ /misery/o) ? 'MI' : 'HI';
$normalcolor ||= 'green';
$bgcolor ||= 'black';
$bgwarn ||= 1;
$warningcolor ||= 'yellow';
$warntypes ||= 'tornado|storm|blizard|freeze|flood';
$alertcolor ||= 'red';
$metric = $opts{metric}  if (defined $opts{metric});
$metric ||= 0;
$debug = $opts{debug}  if (defined $opts{debug});
$debug ||= 0;
$silent ||= 0;
$alertcmd ||= 0;
@extras = ('', '', '');
$extras[0] = $extra0  if (defined $extra0);
$extras[1] = $extra1  if (defined $extra1);
$extras[2] = $extra2  if (defined $extra2);
$extras[3] = $extra3  if (defined $extra3);

print "-CONFIG FILE=$cfgFile=\n"  if ($debug);
$site =~ s/\<ZIP\>/$zipcode/g;
$site =~ s/\<EXTRA\>/$extras[$weatherindex]/g;
for (my $i=0;$i<=3;$i++)
{
	$weathercmds[$i] =~ s/\<ZIP\>/$zipcode/g;
	$weathercmds[$i] =~ s/\<EXTRA\>/$extras[$weatherindex]/g;
	$weathercmds[$i] ||= $weathercmds[0];
	$altweathercmds[$i] =~ s/\<ZIP\>/$zipcode/g;
	$altweathercmds[$i] =~ s/\<EXTRA\>/$extras[$weatherindex]/g;
	$altweathercmds[$i] ||= $weathercmds[0];
}

$btnState = 0;
$btnTextWidth = $bummer ? 10 : 6;
$btnTextHeight = $bummer ? 6 : 5;
our $mw   = MainWindow->new();
$mw->title()  if ($bummer);
$mw->overrideredirect($windowmgr);
$mw->geometry($geometry)  if ($geometry);

#$mw->after($checkmsec, \&getweather);
$skyicon = $mw->Photo(-format => $icontype, -file => "$ENV{HOME}/tkweather/$startimage");
$skybutton = $mw->Button(
	-text => "temp: $current->{temp}\nbp: 30.4\nhum:  40\nNW 10G30\nweather!", 
	-fg => $normalcolor, 
	-activeforeground => $normalcolor,
	-image => $skyicon,
	-font => '-*-lucida console-medium-r-*-*-9-*-100-100-*-*-*-*',
	-bg => 'black', 
	-activebackground => 'black',
	-width => 64,
	-height => 64,
	-pady => 2,
	-relief => $relief,
	-command => sub {
		#$skybutton->packForget();
		++$btnState;
		$btnState = 0  if ($btnState > 2);
		&reconfigButton();
	}
)->pack(-side => 'left', -padx => 0, -pady => 0, -ipadx => 0, -ipady => 0);

if ($useBalloon)
{
	$balloon = $mw->Balloon();
	$balloon->attach($skybutton, -state => 'balloon', -balloonmsg => "TkWeather,v. $VERSION");
}

$activebg = $skybutton->cget('-activebackground');
$mw->bind('<Shift-Control-1>' => sub { print "Exiting!"; exit(0); });
$mw->bind('<Enter>' => sub { 
		if ($useBalloon)
		{
			my $showSite = $opts{noshowsite} ? '' : " ($siteName[$weatherindex])";
			if (open (IN, $cputemp))
			{
				$_ = <IN>;
				chomp;
				close IN;
				$cputmp = $1  if (/(\d+)/o);
				if ($metric)
				{
					$cputmp = ($cputmp - 32) / 1.8  unless (/\d+\s*C/io);
				}
				else
				{
					$cputmp = ($cputmp * 1.8) + 32  if (/\d+\s*C/io);
				}
				$cputmp =~ s/\.\d//o;
				$_ = $balloon->{'clients'}{$skybutton}->{-balloonmsg};
				s/\;.+//o;
				if ($cputmp)
				{
					$balloon->{'clients'}{$skybutton}->{-balloonmsg} = "$_; cpu=${cputmp}".chr(186)
							.$showSite;
				}
				else
				{
					$balloon->{'clients'}{$skybutton}->{-balloonmsg} = "$_;"
							.$showSite;
				}
			}
			else
			{
				$_ = $balloon->{'clients'}{$skybutton}->{-balloonmsg};
				s/\;.+//o;
				$balloon->{'clients'}{$skybutton}->{-balloonmsg} = "$_;"
						.$showSite;
			}
		}
});

$mw->bind('<Double-1>' => sub {    #REFRESH DATA
		--$btnState;  #UNDO THE BUTTON-STATE ADVANCE ON CLICK.
		$btnState = 3  if ($btnState < 0);
		--$btnState;
		$btnState = 3  if ($btnState < 0);
		&getweather();
});

$mw->bind('<Alt-1>' => sub {    #REFRESH DATA
		--$btnState;  #UNDO THE BUTTON-STATE ADVANCE ON CLICK.
		$btnState = 3  if ($btnState < 0);
		--$btnState;
		$btnState = 3  if ($btnState < 0);
		&getweather();
});

$mw->bind('<Shift-3>' => sub {    #PULL UP SITE'S ALTERNATE. WEBPAGE:
print "-ALT1- BEF: btnState=$btnState=\n"  if ($debug);
		for (my $i=0;$i<=3;$i++)
		{
			--$btnState;
			$btnState = 3  if ($btnState < 0);
		}
#		&getweather();
		$mw->update;
		$_ = $altweathercmds[$weatherindex];
print "-ALT2- AFT: btnState=$btnState= CMD=$_=\n"  if ($debug);
		system($browser, $_);
});

$mw->bind('<Shift-1>' => sub {    #PULL UP SITE'S WEBPAGE:
print "-1- BEF: btnState=$btnState=\n"  if ($debug);
		--$btnState;
		$btnState = 3  if ($btnState < 0);
#		&getweather();
		$mw->update;
		$_ = $weathercmds[$weatherindex];
print "-2- AFT: btnState=$btnState= browser=$browser= CMD=$_=\n"  if ($debug);
		system($browser, $_);
});

$mw->bind('<Control-1>' => sub {    #NEXT SITE.
print "-3- BEF: indx=$weatherindex=\n"  if ($debug);
		$weatherindex++;
		$weatherindex = 0  if ($weatherindex > 3);
		$site = $weatherurls[$weatherindex];
		$site =~ s/\<ZIP\>/$zipcode/g;
		$site =~ s/\<EXTRA\>/$extras[$weatherindex]/g;
		--$btnState;
		$btnState = 3  if ($btnState < 0);
print "-4- AFT: indx=$weatherindex= site=$site= state=$btnState\n"  if ($debug);
		&getweather();
});

$mw->bind('<Control-3>' => sub {    #PREV. SITE.
print "-3- BEF: indx=$weatherindex=\n"  if ($debug);
#		$weatherindex = ($weatherindex ? 0 : 1);
		$weatherindex--;
		$weatherindex = 3  if ($weatherindex < 0);
		$site = $weatherurls[$weatherindex];
		$site =~ s/\<ZIP\>/$zipcode/g;
		$site =~ s/\<EXTRA\>/$extras[$weatherindex]/g;
		for (my $i=0;$i<=3;$i++)
		{
			++$btnState;
			$btnState = 0  if ($btnState > 3);
		}
print "-4- AFT: indx=$weatherindex= site=$site= state=$btnState\n"  if ($debug);
		&getweather();
});

@wkdays = (qw(SU MO TU WE TH FR SA));

#1$weather = new Geo::Weather;
#1die "-Could not create Geo::Weather object $!"  unless ($weather);

$mw->update();

&getweather();
#$mw->after($checkmsec, \&getweather);  #DOESN'T SEEM TO WORK.

MainLoop;

sub getweather
{
	my %out;

	print STDERR "-TkWeather v. $VERSION fetching weather for zipcode: $zipcode, using site $weatherindex.\n"
			unless ($silent && !$debug);
	 
	$current = &get_weather($weatherindex);
	unless ($current->{temp} =~ /\d/o)          #TRY ANOTHER SITE!
	{
		$weatherindex++;
		$weatherindex = 0  if ($weatherindex > 3);
		$site = $weatherurls[$weatherindex];
		$site =~ s/\<ZIP\>/$zipcode/g;
		$site =~ s/\<EXTRA\>/$extras[$weatherindex]/g;
		$current = &get_weather($weatherindex);
	}
	unless ($current->{temp} =~ /\d/o)          #TRY THE REMAINING SITE!
	{
		$weatherindex++;
		$weatherindex = 0  if ($weatherindex > 3);
		$site = $weatherurls[$weatherindex];
		$site =~ s/\<ZIP\>/$zipcode/g;
		$site =~ s/\<EXTRA\>/$extras[$weatherindex]/g;
		$current = &get_weather($weatherindex);
	}
	return undef  unless $current;
	$_ = '';
	#1$_ = "-p $weather->{proxy}"  if ($weather->{proxy});
	$_ = "-p $ENV{HTTP_PROXY}"  if ($ENV{HTTP_PROXY});
print "---pic=".$current->{pic}."=\n"  if ($debug);
	if ($current->{pic} =~ /([\w\d]+\.)(gif|jpg|png)$/io)
	{
		$icontype = $2;
		$iconid = $1.$icontype;
		$icontype = 'jpeg'  if ($icontype =~ /jpg/io);   #FOR SOME REASON THEY DIDN'T NAME THIS RIGHT?!
	}
print "----iconid=$iconid= type=$icontype\n"  if ($debug);
	if ($iconid)
	{
		unless (-r "$ENV{HOME}/tkweather/$iconid")
		{
			print "****** LWP REQUEST=lwp-request $_ -H \"Pragma: no-cache\" $current->{pic} >$ENV{HOME}/tkweather/$iconid=\n"  if ($debug);
			`lwp-request $_ -H "Pragma: no-cache" $current->{pic} >"$ENV{HOME}/tkweather/$iconid"`;
		}
	}
	#print "The current temperature is $current->{temp} degrees\n";
		
	if ($debug)
	{
		foreach my $i (keys %$current)
		{
			print STDERR "-$i: $current->{$i}\n";
		}
		print STDERR "-current=$current=\n";
	}

	my $barodir = $1  if ($current->{baro} =~ s/([A-Z])$//o);
	$uvrating = $1  if ($current->{uv} =~ /(\w+)$/o);
	$current->{baro} = $1  if ($current->{baro} =~ /^\s*([\d\.]+)/o);
	$current->{visb} = $1  if ($current->{visb} =~ /^\s*([\d\.]+)/o);
	$current->{visb} ||= '99.9';
	$current->{uv} = $1  if ($current->{uv} =~ /^\s*([\d\.]+)/o);
	$_ = $current->{cond};
	$current->{cond} = substr($_,0,9)  if (length($_) > 9);
	$current->{baro} .= $barodir;
print "+++++ Now wind=$current->{wind}=\n"  if ($debug);
	($winddir, $windspeed) = ($1, $2)  if ($current->{wind} =~ /From\s+(\w+)\s+at\s+([\d\.]+)/o);
	$winddir =~ s/\s//go;
	$winddir =~ s/North/N/igo;
	$winddir =~ s/South/S/igo;
	$winddir =~ s/East/E/igo;
	$winddir =~ s/West/W/igo;
print "+++++ Now windir=$winddir= sp=$windspeed=\n"  if ($debug);
	$winddir = 'CLM'  unless ($windspeed =~ /[1-9]/o);
	$winddir ||= 'CLM';
	if ($current->{temp} < 65 || ($current->{temp} < 70 && $windspeed >= 10))
	{
		$misery = $current->{heat};
		$idxdesc = 'WC';
	}
	elsif ($idx eq 'MI')
	{
		$_ = $current->{dewp} || $current->{humi};
		s/\D//go;
		#TWEAK MISERY INDEX TO FACTOR IN BREEZE! (WINDSPEED * (1 - HUMIDITY))
		$misery = ($current->{temp} + $_) - int($windspeed * (1 - ($current->{humi} / 100)));
		$idxdesc = 'MI';
	}
	else
	{
		$misery = $current->{heat};
		$idxdesc = 'HI';
	}

	foreach my $i (qw(cond temp humi baro dewp uv visb))
	{
		$out{$i} = $current->{$i};
	}
	$out{misery} = $misery;
	$out{windspeed} = sprintf('%.0f',$windspeed);
	$out{winddir} = $winddir;
	$_ = $balloon->{'clients'}{$skybutton}->{-balloonmsg};
	if ($idx eq 'MI')
	{
		$_ .= ' (MISERABLE!)'  if ($misery >= 150);
	}
	elsif ($idx eq 'HI')
	{
		$_ .= ' (HEAT ALERT!)'  if ($misery >= 100);
	}
	$balloon->{'clients'}{$skybutton}->{-balloonmsg} = $_;
	if ($metric)
	{
		foreach my $i (qw(temp dewp heat))  #CONVERT FAIRENHEIGHT TO CELCIUS
		{
			$out{$i} = ($out{$i} - 32) / 1.8;
		}
		$out{misery} = ($out{misery} - 32) / 1.8  unless ($idxdesc eq 'MI');
		$out{windspeed} *= 1.609;         #CONVERT MILES TO KILOMETERS.
		$out{visb} *= 1.609;
	}

	$skyicon = ($iconid && -r "$ENV{HOME}/tkweather/$iconid") ? $mw->Photo(-format => $icontype, -file => "$ENV{HOME}/tkweather/$iconid")
			: $mw->Photo(-format => $icontype, -file => "$ENV{HOME}/tkweather/$startimage");
	(undef,$min,$hour,undef,undef,undef,$wday) = localtime();
	$text[0] = 'icon';
	if ($metric)
	{
		$text[1] = sprintf("%-2s %2.2d:%2.2d\n%-8s\ntmp:%3.0fc\nhum:%4s\nW:%3s%3.0f",
					$wkdays[$wday], $hour, $min, $out{cond}, $out{temp}, 
					$out{humi}, $out{winddir}, $out{windspeed});
	}
	else
	{
		$text[1] = sprintf("%-2s %2.2d:%2.2d\n%-8s\ntemp:%3.0f\nhum:%4s\nW:%3s%3.0f",
					$wkdays[$wday], $hour, $min, $out{cond}, $out{temp}, 
					$out{humi}, $out{winddir}, $out{windspeed});
	}
	$text[2] = sprintf("b:%5.2f%1s\nDew: %3d\n${idxdesc}:  %3d\nUV:   %2d\nVis:%4.1f", 
				$out{baro}, $barodir, $out{dewp}, $out{misery}, 
				$out{uv}, $out{visb});
	&reconfigButton();
	$mw->after($checkmsec, \&getweather);  #THIS SEEMS TO HAVE TO BE HERE TO REPEAT?!
	$mw->update;
print "-???- alert=$current->{alert}=\n"  if ($debug);
	if ($current->{alert})
	{
		$mw->bell;    #RING THE BELL!
print "-!!!- SHOULD FLIP IT!\n"  if ($debug);
		++$btnState;
		$btnState = 0  if ($btnState > 2);
		&reconfigButton();
		sleep(1);
	$mw->update;
		++$btnState;
		$btnState = 0  if ($btnState > 2);
		&reconfigButton();
		sleep(1);
	$mw->update;
		++$btnState;
		$btnState = 0  if ($btnState > 2);
		&reconfigButton();
		sleep(1);
	$mw->update;
	}
}

sub reconfigButton
{
	$fg = $normalcolor;
	my $bg = undef;
	if ($windspeed >= 20 || $current->{temp} >= 90)
	{
		$fg = $warningcolor  if ($btnState == 1);
		$bg = $warningcolor;
	}
	if ($current->{temp} < 50)
	{
		$fg = $cwarningcolor || $warningcolor  if ($btnState == 1);
		$bg = $cwarningcolor || $warningcolor;
	}
	if (($idx eq 'MI' && $misery >= 150) || $uvrating =~ /High/io
			|| $current->{uv} > 7
			|| $current->{visb} < 3)
	{
		$fg = $warningcolor  if ($btnState == 2);
		$bg = $warningcolor;
	}
	elsif (($idx eq 'HI' && $misery >= 95) || $current->{visb} < 3)
	{
		$fg = $warningcolor  if ($btnState == 2);
		$bg = $warningcolor;
	}
	elsif ($current->{alert} =~ /watch/io)
	{
		$fg = $warningcolor  if ($btnState == 0);
		$bg = $warningcolor;
	}
	if ($windspeed >= 35)
	{
		$fg = $alertcolor  if ($btnState == 1);
		$bg = $alertcolor;
	}
	if ($current->{temp} <= 32)
	{
		$fg = $calertcolor || $alertcolor  if ($btnState == 1);
		$bg = $calertcolor || $alertcolor;
	}
	elsif ($current->{temp} >= 100)
	{
		$fg = $alertcolor  if ($btnState == 1);
		$bg = $alertcolor;
	}
	if (($idx eq 'MI' && $misery >= 160) || $current->{visb} < 1.5)
	{
		$fg = $alertcolor  if ($btnState == 2);
		$bg = $alertcolor;
	}
	elsif (($idx eq 'HI' && $misery >= 105) || $current->{visb} < 1.5)
	{
		$fg = $alertcolor  if ($btnState == 2);
		$bg = $alertcolor;
	}
	if ($current->{alert} =~ /warning/io)
	{
		$fg = $alertcolor  if ($btnState == 0);
		$bg = $alertcolor;
	}
	if ($btnState || !$bgwarn)
	{
		$skybutton->configure(
				-image => ($btnState ? undef : $skyicon), 
				-height => ($btnState ? $btnTextHeight : 54),
				-width => ($btnState ? $btnTextWidth : 54),
				-text => $text[$btnState],
				-fg => $fg,
				-activeforeground => $fg,
				-bg => $bgcolor,
				-activebackground => $bgcolor,
		);
	}
	else
	{
		$skybutton->configure(
				-image => $skyicon, 
				-height => 54,
				-width => 54,
				-text => $text[$btnState],
				-fg => $fg,
				-activeforeground => $fg,
				-bg => $bg || $bgcolor,
				-activebackground => $bg || $bgcolor,
		);
	}
	`$alertcmd $current->{alert}`  if ($current->{alert} =~ /warning/io && $alertcmd);
}

sub get_weather
{
	my $siteid = shift;	
	print STDERR "-site=$siteid= url=$site=\n"  if ($debug);
	my $html = LWP::Simple::get($site);
	my $c;
	my $tempConv;
	my $t;
	my $html2 = '';
	if ($html)
	{
		if ($weatherurls2[$siteid])
		{
			if ($weatherurls2[$siteid] =~ s#^\=\~##o)
			{
				eval "\$weatherurls2[$siteid] = \$1  if (\$html =~ s#$weatherurls2[$siteid]##);";
print "-???- eval=$@= str=\$weatherurls2[$siteid] = \$1  if (\$html =~ s#$weatherurls2[$siteid]##);=\n-???- url2=$weatherurls2[$siteid]=\n"  if ($debug);
			}
			$html2 = LWP::Simple::get($weatherurls2[$siteid])  if ($weatherurls2[$siteid]);
		}
		if ($siteid == 0)   #weather.com
		{
			$c->{temp} = $1  if ($html =~ s/\&temp\=(\-?\d+)//so);
			$c->{dewp} = $1  if ($html =~ s/\&dewp?\=(\-?\d+)//so);
			$c->{uv} = $1  if ($html =~ s/\&uv\=(\d+)//so);
			$c->{humi} = $1  if ($html =~ s/\&humid\=(\d+)//so);
			#$c->{long_cond} = $1  if ($html =~ s/\&cond\=([^\&]+)//s);
			$c->{long_cond} = $1  if ($html =~ s/\>\<BR\>\<B CLASS\=obsTextA\>([\w ]+)\<\/B\>\<\/TD\>//so);
			$c->{wind} = $1  if ($html =~ /WIND\:.*?obsTextA\"\>(.*?)\</sio);
			$c->{baro} = $1  if ($html =~ /Pressure\:.*?obsTextA\"\>(.*?)\&/so);
			$c->{baro} .= 'R'  if ($html =~ s/up_pressure\.gif//so);
			$c->{baro} .= 'F'  if ($html =~ s/down_pressure\.gif//so);
			$c->{baro} .= 'S'  unless ($c->{baro} =~ /[RF]$/o);
			$c->{heat} = $1  if ($html =~ /Feels Like\<BR\>\s*(\-?\d+)\&/so);
			$c->{heat} ||= $c->{temp};
			$c->{visb} = $1  if ($html =~ s!Visibility:\<\/td\>\s+\<TD\>\<IMG SRC="[^\>]+\>\<\/td\>\s+\<TD VALIGN\=\"top\"\s+CLASS\=\"obsTextA\"\>([\d\.]+)!!so);
			$c->{cond} = $c->{long_cond};
			$c->{pic} = $1  if ($html =~ s#\<IMG\s+SRC\=\"(http\:\/\/image\.weather\.com\/web\/common\/wxicons\/\d+/\d+\.gif)(?:\?\d*)?\"\s+WIDTH\=52\s+HEIGHT\=52\s+BORDER\=0\s+ALT##so);
			$c->{alert} = ($html =~ /new\s+alertObj\(\'[^\']*\'\,\'((?:$warntypes)\s+(?:watch|warning))\'/io) ? $1 : '';
		}
		elsif ($siteid == 2)  #NOAA
		{
#			$c->{pic} = $1  if ($html =~ s#\<img src\=\"(\/forecast\/images\/[^\"]+)\"##);
#			$c->{pic} = $1  if ($html =~ s#\<img src\=\"(\/images\/wtf\/[^\"]+)\"\s+width\=\"55\"\s+height\=\"58\"##);
			$c->{pic} = $1  if ($html =~ s#\<img src\=\"([^\"]+)\"\s+width\=\"55\"\s+height\=\"58\"##o);
			if ($c->{pic})
			{
				$c->{pic} = 'http://forecast.weather.gov' . $c->{pic}  if ($c->{pic} =~ m#^\/#o);
			}
			else
			{
				$c->{pic} = $1  if ($html =~ s#\<IMG\s+SRC\=\"(\/HW3php\/images\/fcicons\/\w+.(?:jpg|gif|png))\"\s+WIDTH\=\"5\d\"\s+HEIGHT\=\"5\d\"##iso);
print "-???- alternate pic:".$c->{pic}."=\n"  if ($debug);
			}
			if ($html =~ m!\<td class\=\"big\" width\=.+?center\"\>(.+?)\<br\>\<br\>(\-?\d+)\&deg\;F\<!o)
			{
				$c->{long_cond} = $1;
				$c->{temp} = $2;
			}
			$c->{dewp} = $1  if ($html =~ m!Dewpoint\<\/b\>\:.+?right\"\>(\-?\d+)\&deg\;F!so);
#############			$c->{uv} = $1  if ($html =~ m!UV\:\<\/td\>.+?\>(\d+) \<span!s);
			$c->{humi} = $1  if ($html =~ m!Humidity\<\/b\>\:.+?right\"\>(\d+) \%\<!so);
			$c->{wind} = "From $1 at $2"  if ($html =~ s!\<b\>Wind Speed\<\/b\>\:\<\/td\>\s*\<td align\=\"right\"\>(\w+)\s+(\d+)!!sio);
print "------wind=$c->{wind}=\n"  if ($debug);
			$c->{baro} = $1  if ($html =~ m!Barometer\<\/b\>\:.+? nowrap>([\d\.]+)\&quot\;!so);
print "------baro=".$c->{baro}."=\n"  if ($debug);
			$c->{baro} .= ' ';
			$c->{heat} = $1  if ($html =~ m!Wind\s+Chill\<\/b\>\:.+?right\"\>(\-?\d+)\&deg\;F!so);
			#$c->{heat} = $1  if ($html =~ /Feels Like\<BR\>\s*(\-?\d+)\&/s);
			$c->{visb} = $1  if ($html =~ m!Visibility\<\/b\>\:.+?right\"\>([\d\.]+) mi\.!so);
			$c->{cond} ||= $c->{long_cond};  #<img src="http://icons.wunderground.com/graphics/conds/nt_clear.GIF" alt
			$_ = $c->{cond};
			#$c->{pic} = $1  if ($html =~ s#\s+\<img\s+src\=\"(http\:\/\/icons\.wunderground\.com\/graphics\/conds\/\w+\.GIF)\"##is);
			$c->{alert} = ($html =~ /Hazardous weather condition\(s\)\:.*\<span class\=\"warn\"\>((?:$warntypes)\s+(?:watch|warning))\<\/span\>.+\<\/div\>/iso) ? $1 : '';
		}
		elsif ($siteid == 3)  #WEATHERBUG
		{
#print "*********** html1=>>>$html<<<=\n";
#print "*********** html2=>>>$html2<<<=\n";
			$c->{temp} = $1  if ($html =~ s#divTemp\"\s+class\=\"wXconditions-temp\"\>(\-?[\d\.]+)\&deg;F##o);
			$c->{dewp} = $1  if ($html2 =~ s#divDewPoint\"\>(\d+)\&deg\;F\<##so);
#			$c->{uv} = $1  if ($html =~ s/\&uv\=(\d+)//so);
			$c->{humi} = $1  if ($html =~ s#divHumidity\"\>(\d+)\%\<##so);
#			$c->{long_cond} = $1  if ($html =~ s/\>\<BR\>\<B CLASS\=obsTextA\>([\w ]+)\<\/B\>\<\/TD\>//so);
			$c->{wind} = "From $2 at $1"  if ($html2 =~ s#divAvgWind">(\d+)\s*(\w+)<##sio);
			$c->{baro} = $1  if ($html2 =~ s#divPressure\"\>([\d\.]+)&quot;<##so);
			$c->{heat} = $1  if ($html =~ s#divFeelsLike\"\>(\d+)\&deg\;F\<##so);
			$c->{heat} ||= $c->{temp};
			$c->{visb} = $1  if ($html =~ s!Visibility:\<\/td\>\s+\<TD\>\<IMG SRC="[^\>]+\>\<\/td\>\s+\<TD VALIGN\=\"top\"\s+CLASS\=\"obsTextA\"\>([\d\.]+)!!so);
#			$c->{alert} = $1  if ($html =~ /new\s+alertObj\(\'[^\']*\'\,\'((?:$warntypes)\s+(?:watch|warning))\'/io) ? $1 : '';
			($c->{pic}, $c->{cond}, $c->{long_cond}) = ($1, $2, $2)
					if ($html =~ s#rel\=\"nofollow\"\>\<img src\=\"(http\:\/\/deskwx\.weatherbug\.com\/images\/Forecast\/icons\/[^\.]+\.gif)" alt="([^\"]*)" border=##so);
print "-???- PIC=".$c->{pic}."= cond=".$c->{cond}."=\n"  if ($debug);
		}
		else  #wunderground (site=1)
		{
			#$c->{pic} = $1  if ($html =~ m#1px solid \#996\;\"\>\<img\s+src\=\"(http\:\/\/icons-aa\.wunderground\.com\/graphics\/conds\/\w+\.gif)\"#is);
#			$c->{pic} = $1  if ($html =~ m#\#996\;\"\>\<img\s+src\=\"(http\:\/\/icons-aa\.\S+\/graphics\/conds\/\w+\.gif)\"#iso);
			$c->{pic} = $1  if ($html =~ s#td class=\"vaM taC\"\>\<img src=\"(http:\/\/icons-pe.wxug.com\/[^\"]+)\" width=\"42\"##iso);
#class="taC" style="padding: 3px; border-bottom: 1px solid #996;"><img src="http://icons-pe.wxug.com/graphics/conds/nt_rain.GIF" title=
			#http://icons-aa.wxug.com/graphics/conds/rain.GIF
#			$c->{temp} = $1  if ($html =~ s!<div class="smB">\n\s*<div>\n\s*<b>([\d\.]+)</b>&nbsp;&#176;F!!so);
#			$c->{temp} = $1  if ($html =~ s!<nobr><b>([\d\.]+)</b>&nbsp;&#176;F</nobr>!!so);
			$c->{temp} = $1  if ($html =~ s! pwsvariable=\"tempf\" english=\"\&deg;F\" metric=\"&deg;C\" value=\"([\d\.]+)\">!!so);
print "------TEMP=$c->{temp}=\n"  if ($debug);
			$c->{dewp} = $1  if ($html =~ m!Dew Point\:\<\/td\>.+?deg;C" value=\"(\-?\d+)\"\>!so);
			$c->{uv} = $1  if ($html =~ m!UV:\</td\>\s+\<td class=\"b\">(\d+)\s*\<span!so);
			$c->{humi} = $1  if ($html =~ m!humidity\" english=\"\" metric=\"\" value=\"(\d+)\"\>!so);
			$c->{long_cond} = $1  if ($html =~ s!div class=\"b\" style=\"font-size: 14px;\"\>([^\<]+)\<\/div!!so);
			$c->{long_cond} = $1  if (($c->{long_cond} eq 'Unknown') && ($html =~ s!  \<font size\=-1\>\<b\>([\w\s]+)\<\/b\>\<\/font\>!!so));
#			$c->{wind} = $1  if ($html =~ s!windspeedmph\" english=\"mph\" metric=\"km/h\"\>\s*\<b\>(\d+)\<\/b\>\&nbsp;mph!!so);
#			$c->{wind} = $1  if ($html =~ s!windspeedmph\D+([\d\.]+)!!so);
			$c->{wind} = $1  if ($html =~ s!windspeedmph\" english=\"mph\" metric=\"km/h\"\>\s*(.+?)\<\/span>!!so);
#print "-???- wind1=".$c->{wind}."=\n";
			$c->{wind} = 0   if ($c->{wind} =~ /calm/io);
#print "-???- wind2=".$c->{wind}."=\n";
			$c->{wind} = $1  if ($c->{wind} =~ /^\D*([\d\.]+)/);
#print "-???- wind3=".$c->{wind}."=\n";
			my $windir = $1  if ($html =~ m! pwsvariable\=\"winddir\" english\=\"\" metric\=\"\" value\=\"(\w+)\"\>!so);
print "------wind=$c->{wind}= dir=$windir=\n"  if ($debug);
			$c->{wind} = "From $windir at ".$c->{wind};
			$c->{baro} = $1  if ($html =~ m!Pressure\:\<\/td\>.+?\<b\>([^\<]+)\<!so);
print "------baro=".$c->{baro}."=\n"  if ($debug);
			$c->{baro} .= 'R'  if ($html =~ s/\(Rising\)//so);
			$c->{baro} .= 'F'  if ($html =~ s/\(Falling\)//so);
			$c->{baro} .= 'S'  unless ($c->{baro} =~ /[RF]$/o);
			$c->{heat} = $1  if ($html =~ m!Windchill\:\<\/td\>.+?b\>(\d+)\<!so);
			#$c->{heat} = $1  if ($html =~ /Feels Like\<BR\>\s*(\-?\d+)\&/so);
			$c->{heat} = $1  if ($html =~ s!Heat\s+Index:</td>\n\s*<td class="b">\n\s*\D+([\d\.]+)</span>\&nbsp;&#176;F!!so);
			$c->{cond} = $c->{long_cond};  #<img src="http://icons.wunderground.com/graphics/conds/nt_clear.GIF" alt
			$c->{gust} = $1  if ($html =~ s!\<nobr\>\<b\>([\d\.]+)\<\/b\>\&nbsp\;mph\<\/nobr\>!!so);
			$c->{visb} = $1  if ($html =~ s!Visibility:</td>\n\s*<td class="b">\n\s*\D+([\d\.]+)</span>\&nbsp;miles!!so);
print "------gust=".$c->{gust}."=\n"  if ($debug);
print "------visb=".$c->{visb}."=\n"  if ($debug);
			$_ = $c->{cond};
			#$c->{pic} = $1  if ($html =~ s#\s+\<img\s+src\=\"(http\:\/\/icons\.wunderground\.com\/graphics\/conds\/\w+\.GIF)\"##is);
			#$c->{alert} = ($html =~ /No Active Advisories/o) ? 0 : 1;
			$t = ($html =~ /Advisory:(.+)\<\/td\>/so) ? $1 : '';
			$c->{alert} = ($t =~ /((?:$warntypes)\s+(?:watch|warning))/is) ? $1 : 0;
		}
		$tempConv = $c->{temp};
		$tempConv = ($tempConv - 32) / 1.8  if ($metric);
		if ($useBalloon)
		{
		  	my $alert = $c->{alert} ? "\U$c->{alert}\E! " : '';
			$balloon->{'clients'}{$skybutton}->{-balloonmsg} = (sprintf('%.0f',$tempConv).chr(186).", ${alert}$c->{long_cond}");
		}
		$balloon->idletasks  if ($useBalloon);
		$c->{heat} = $c->{temp}  unless ($c->{heat} =~ /\d/o);
	}
	return $c;
}

__ENd__
