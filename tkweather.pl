#!/usr/bin/perl

=head1 NAME

	TkWeather, by Jim Turner c. 2003, 2004, 2005

=head1 SYNOPSIS

	tkweather.pl [zip-code] [site]

=head1 DESCRIPTION

	This program displays a nice square iconic button showing the 
	current weather condition.  Clicking the button shows the current
	basic weather condition values, such as temperature, humidity, and 
	wind.  Clicking again shows additional information, namely the 
	barometric pressure, UV, visiblility, and "heat index" or 
	"wind chill" or "misery index".  For anyone not from Houston, Texas,
	the old "misery index" is the temperature plus dewpoint.  Anything 
	over 150 is considered "miserable"!  I use this for planning 
	workouts.  The default is to use the more modern "heat index".  
	Specify "index=misery" for the old Houston "misery index".  
	"wind chill" is used if the temperature is below 70 and wind 
	is >= 10mph regardless.

	"site", is currently "weather" (weather.com) or "wunderground"
	(www.wunderground.com).  If it fails on the selected one, it tries 
	the other.  The default is "weather".  

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
	checkmsec=900000
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
	#NORMAL TEXT FOREGROUND COLOR
	normalcolor=green
	#WARNING COLOR
	warningcolor=yellow
	#ALERT COLOR
	alertcolor=red
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

	5)  Copy the image "tkweather.gif" to $HOME/tkweather/

	6)  Copy tkweather.pl to somewhere in your PATH or wherever you 
	want to be able to run it from.  Make sure line 1 points to your
	perl interpreter.

	7)  To make this app appear in your AfterStep/Windowmaker "wharf", 
	add the following to your config file:
	*Wharf Tkwather - MaxSwallow "Tkweather" tkweather.pl &
        
	8)  Enjoy!

=cut

use Tk;
use Tk ':eventtypes';
use Tk::X11Font;
use Tk::ROText;
#use Geo::Weather;
use LWP::Simple;
#eval 'use  Tk::Balloon; $useBalloon = 1;';
use  Tk::Balloon; $useBalloon = 1;

our $VERSION = '1.37';
our $geometry = '';
$cputemp='';
if (-r "$ENV{HOME}/tkweather/tkweather.cfg" 
		&& open(IN, "$ENV{HOME}/tkweather/tkweather.cfg"))
{
	my ($var, $val);
	while (<IN>)
	{
		chomp;
		next  if (/^\#/);
		($var, $val) = split(/\=/, $_, 2);
		next  unless ($var =~ /^(?:zipcode|browser|weathercmd|site|checkmsec|relief|windowmgr|geometry|index|startimage|normalcolor|bgcolor|bgwarn|warningcolor|alertcolor|debug|metric|silent|cputemp)$/);
		eval "\$$var = '$val';";
	}
}

$geometry = shift(@ARGV)  if ($ARGV[0] =~ /--geometry/);
$geometry =~ s/\-\-geometry\=//;
$zipcode ||= '76087';
$browser ||= ($^O =~ /Win/) ? 'start' : 'mozilla';
#$site ||= 'http://www.w3.weather.com/weather/local/<ZIP>?lswe=<ZIP>&lwsa=WeatherLocalUndeclared';
$weatherurls[0] = 'http://www.w3.weather.com/weather/local/<ZIP>?lswe=<ZIP>&lwsa=WeatherLocalUndeclared';
$weatherurls[1] = 'http://www.wunderground.com/cgi-bin/findweather/getForecast?query=<ZIP>';
$weatherurls[2] = 'http://www.srh.noaa.gov/zipcity.php?Go2=Go&inputstring=<ZIP>';
$weathercmds[0] = 'http://www.w3.weather.com/weather/local/<ZIP>?lswe=<ZIP>&lwsa=WeatherLocalUndeclared';
$weathercmds[1] = 'http://www.wunderground.com/cgi-bin/findweather/getForecast?query=<ZIP>';
$weathercmds[2] = 'http://www.srh.noaa.gov/zipcity.php?Go2=Go\&inputstring=<ZIP>';
$site ||= $weatherurls[0];
$zipcode = $ARGV[0] || $zipcode;    #SET YOUR ZIP-CODE HERE.
$site = $ARGV[1]  if (defined $ARGV[1]);
if ($site =~ /^\d$/)
{
	$weatherindex = $site;
}
else
{
	$weatherindex = ($site =~ /wunderground/) ? 1 : 0;
	$weatherindex = 2  if ($site =~ /noaa/i);
}
$site = $weatherurls[$weatherindex];
#$weathercmd ||= "http://www.wunderground.com/cgi-bin/findweather/getForecast?query=$zipcode &";
#$weathercmd ||= join('|', @weathercmds);
@weathercmds = split(/\|/, $weathercmd)  if ($weathercmd);
$checkmsec ||= '900000';
$relief ||= 'ridge';
$windowmgr ||= 0;
$startimage ||= 'tkweather.gif';
$icontype = 'gif';
$idx = ($index =~ /misery/) ? 'MI' : 'HI';
$normalcolor ||= 'green';
$bgcolor ||= 'black';
$bgwarn ||= 1;
$warningcolor ||= 'yellow';
$alertcolor ||= 'red';
$metric ||= 0;
$debug ||= 0;
$silent ||= 0;

$site =~ s/\<ZIP\>/$zipcode/g;
for (my $i=0;$i<=2;$i++)
{
	$weathercmds[$i] =~ s/\<ZIP\>/$zipcode/g;
	$weathercmds[$i] ||= $weathercmds[0];
}

$btnState = 0;
our $mw   = MainWindow->new();
$mw->overrideredirect($windowmgr);
$mw->geometry($geometry)  if ($geometry);

#$mw->after($checkmsec, \&getweather);
$skyicon = $mw->Photo(-format => $icontype, -file => "$ENV{HOME}/tkweather/$startimage");
$skybutton = $mw->Button(
	-text => "temp: $current->{temp}\nbp: 30.4\nhum:  40\nNW 10G30\nweather!", -fg => $normalcolor, 
	-image => $skyicon,
	-font => '-*-lucida console-medium-r-*-*-9-*-100-100-*-*-*-*',
	-bg => 'black', 
	-width => 64,
	-height => 64,
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
$mw->bind('<Shift-Control-ButtonRelease>' => sub { print "Exiting!"; exit(0); });
$mw->bind('<Enter>' => sub { 
		if ($useBalloon && open (IN, $cputemp))
		{
			$_ = <IN>;
			chomp;
			close IN;
			$cputmp = $1  if (/(\d+)/);
			if ($metric)
			{
				$cputmp = ($cputmp - 32) / 1.8  unless (/\d+\s*C/i);
			}
			else
			{
				$cputmp = ($cputmp * 1.8) + 32  if (/\d+\s*C/i);
			}
			$cputmp =~ s/\.\d//;
			$_ = $balloon->{'clients'}{$skybutton}->{-balloonmsg};
			s/\; cpu.+//;
			$balloon->{'clients'}{$skybutton}->{-balloonmsg} = "$_; cpu=${cputmp}".chr(186)
					unless (!$cputmp);
		}
});

$mw->bind('<Double-ButtonRelease>' => sub {
		--$btnState;  #UNDO THE BUTTON-STATE ADVANCE ON CLICK.
		$btnState = 2  if ($btnState < 0);
		--$btnState;
		$btnState = 2  if ($btnState < 0);
		&getweather();
});
$mw->bind('<Alt-ButtonRelease>' => sub {
		--$btnState;  #UNDO THE BUTTON-STATE ADVANCE ON CLICK.
		$btnState = 2  if ($btnState < 0);
		&getweather();
});
$mw->bind('<Shift-ButtonRelease>' => sub {
print "-1- BEF: btnState=$btnState=\n"  if ($debug);
		--$btnState;
		$btnState = 2  if ($btnState < 0);
		&getweather();
		$mw->update;
print "-2- AFT: btnState=$btnState= CMD=$weathercmds[$weatherindex]=\n"  if ($debug);
		system("$browser $weathercmds[$weatherindex]");
});
$mw->bind('<Control-ButtonRelease>' => sub {
print "-3- BEF: indx=$weatherindex=\n"  if ($debug);
#		$weatherindex = ($weatherindex ? 0 : 1);
		$weatherindex++;
		$weatherindex = 0  if ($weatherindex > 2);
		$site = $weatherurls[$weatherindex];
		$site =~ s/\<ZIP\>/$zipcode/g;
		--$btnState;
		$btnState = 2  if ($btnState < 0);
print "-4- AFT: indx=$weatherindex= site=$site=\n"  if ($debug);
		&getweather();
});

@wkdays = (qw(SU MO TU WE TH FR SA));

#1$weather = new Geo::Weather;
#1die "-Could not create Geo::Weather object $!"  unless ($weather);

&getweather();
#$mw->after($checkmsec, \&getweather);  #DOESN'T SEEM TO WORK.

MainLoop;

sub getweather
{
	my %out;

	print STDERR "-TkWeather v. $VERSION fetching weather for zipcode: $zipcode, using site $weatherindex.\n"
			unless ($silent && !$debug);
	 
	#1$current = $weather->get_weather($zipcode);
	$current = &get_weather($weatherindex);
	unless ($current->{temp} =~ /\d/)          #TRY THE OTHER SITE!
	{
		$weatherindex = ($weatherindex ? 0 : 1);
		$site = $weatherurls[$weatherindex];
		$site =~ s/\<ZIP\>/$zipcode/g;
		&get_weather($weatherindex);
	}
	return undef  unless $current;
	$_ = '';
	#1$_ = "-p $weather->{proxy}"  if ($weather->{proxy});
	$_ = "-p $ENV{HTTP_PROXY}"  if ($ENV{HTTP_PROXY});
print "---pic=".$current->{pic}."=\n"  if ($debug);
	if ($current->{pic} =~ /([\w\d]+\.)(gif|jpg)$/i)
	{
		$icontype = $2;
		$iconid = $1.$icontype;
	}
print "----iconid=$iconid= type=$icontype\n"  if ($debug);
	if ($iconid)
	{
		if ($icontype =~ /jpg/i)
		{
print "-!!!- icon is a JPEG!\n"  if ($debug);
			my $iconname = $iconid;
			$iconname =~ s/\.jpg$//i;
			unless (-r "$ENV{HOME}/tkweather/${iconname}\.gif")
			{
print "+++++ Fetching new icon via wget!\n"  if ($debug);
				my $iconurl = $current->{pic};
				unless ($iconurl =~ m#//#)  #A VALID URL
				{
					my $sitebase = $site;
					$sitebase =~ s#^(\w+\:\/\/[^\/]+\/).+#$1#;
					$sitebase .= '/'  unless ($sitebase =~ m#/$#);
print "-???- sitebase =$sitebase=\n"  if ($debug);
					$iconurl =~ s#^/##;
					$iconurl = $sitebase . $iconurl;
				}
print "----- icon ID=$iconid= URL=$iconurl=\n"  if ($debug);
				`/usr/bin/lwp-request $_ -H 'Pragma: no-cache' $iconurl >$ENV{HOME}/tkweather/$iconid`;
				`convert $ENV{HOME}/tkweather/${iconname}.jpg $ENV{HOME}/tkweather/${iconname}.gif`;
print "=!!!= converted, id=$iconid= tp=$icontype=\n"  if ($debug);
			}
			$icontype = 'gif';
			$iconid = $iconname . '.' . $icontype;
print "===== using converted gif icon we already have: id=$iconid= tp=$icontype=\n"  if ($debug);
		}
		else
		{
			`/usr/bin/lwp-request $_ -H 'Pragma: no-cache' $current->{pic} >$ENV{HOME}/tkweather/$iconid`
					unless (-r "$ENV{HOME}/tkweather/$iconid");
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

	my $barodir = $1  if ($current->{baro} =~ s/([A-Z])$//);
	$uvrating = $1  if ($current->{uv} =~ /(\w+)$/);
	$current->{baro} = $1  if ($current->{baro} =~ /^\s*([\d\.]+)/);
	$current->{visb} = $1  if ($current->{visb} =~ /^\s*([\d\.]+)/);
	$current->{visb} ||= '99.9';
	$current->{uv} = $1  if ($current->{uv} =~ /^\s*([\d\.]+)/);
	$_ = $current->{cond};
	$current->{cond} = substr($_,0,9)  if (length($_) > 9);
	$current->{baro} .= $barodir;
print "+++++ Now wind=$current->{wind}=\n"  if ($debug);
	($winddir, $windspeed) = ($1, $2)  if ($current->{wind} =~ /From\s+(\w+)\s+at\s+(\d+)/);
	$winddir =~ s/\s//g;
	$winddir =~ s/North/N/ig;
	$winddir =~ s/South/S/ig;
	$winddir =~ s/East/E/ig;
	$winddir =~ s/West/W/ig;
print "+++++ Now windir=$windir= sp=$windspeed=\n"  if ($debug);
	$winddir ||= 'CLM';
	if ($current->{temp} < 65 || ($current->{temp} < 70 && $windspeed >= 10))
	{
		$misery = $current->{heat};
		$idxdesc = 'WC';
	}
	elsif ($idx eq 'MI')
	{
		$_ = $current->{dewp} || $current->{humi};
		s/\D//g;
		$misery = $current->{temp} + $_;
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
	$out{windspeed} = $windspeed;
	$out{winddir} = $winddir;
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
}

sub reconfigButton
{
	$fg = $normalcolor;
	my $bg = undef;
	if ($windspeed >= 20 || $current->{temp} < 50 || $current->{temp} >= 90)
	{
		$fg = $warningcolor  if ($btnState == 1);
		$bg = $warningcolor;
	}
	if (($idx eq 'MI' && $misery >= 150) || $uvrating =~ /High/i
			|| $current->{visb} < 4)
	{
		$fg = $warningcolor  if ($btnState == 2);
		$bg = $warningcolor;
	}
	if ($windspeed >= 35 || $current->{temp} <= 32
			|| $current->{temp} >= 100)
	{
		$fg = $alertcolor  if ($btnState == 1);
		$bg = $alertcolor;
	}
	if (($idx eq 'MI' && $misery >= 165) || $current->{visb} < 2)
	{
		$fg = $alertcolor  if ($btnState == 2);
		$bg = $alertcolor;
	}
	if ($btnState || !$bgwarn)
	{
		$skybutton->configure(
				-image => ($btnState ? undef : $skyicon), 
				-height => ($btnState ? 5 : 53),
				-width => ($btnState ? 6 : 54),
				-text => $text[$btnState],
				-fg => $fg,
				#-activebackground => $bg || $activebg,
				#-activeforeground => $bgcolor,
				-bg => $bgcolor,
		);
	}
	else
	{
		$skybutton->configure(
				-image => ($btnState ? undef : $skyicon), 
				-height => ($btnState ? 5 : 53),
				-width => ($btnState ? 6 : 54),
				-text => $text[$btnState],
				-fg => $fg,
				#-activebackground => $bg || $activebg,
				#-activeforeground => $bgcolor,
				-bg => $bg || $bgcolor,
		);
	}
}

sub get_weather
{
	my $siteid = shift;
	my $html = LWP::Simple::get($site);
	my $c;
	my $tempConv;
	if ($html)
	{
#		($c->{temp}, $c->{uv}, $c->{humi}, $c->{dewp}, $c->{windspeed}, $c->{long_cond}) = ($1, $2, $3, $4, $5, $6)
#				if ($html =~ s/temp\=(\-?\d+)\&uv\=(\d+)&humid\=(\d+)&dew=(\-?\d+)&wind=(\d+)&cond=(\w+)\&//s);
		print STDERR "-site=$siteid= url=$site=\n"  if ($debug);
		if ($siteid == 0)
		{
			$c->{temp} = $1  if ($html =~ s/\&temp\=(\-?\d+)//s);
			$c->{dewp} = $1  if ($html =~ s/\&dewp?\=(\-?\d+)//s);
			$c->{uv} = $1  if ($html =~ s/\&uv\=(\d+)//s);
			$c->{humi} = $1  if ($html =~ s/\&humid\=(\d+)//s);
			#$c->{long_cond} = $1  if ($html =~ s/\&cond\=([^\&]+)//s);
			$c->{long_cond} = $1  if ($html =~ s/\>\<BR\>\<B CLASS\=obsTextA\>([\w ]+)\<\/B\>\<\/TD\>//s);
			$c->{wind} = $1  if ($html =~ /WIND\:.*?obsTextA\"\>(.*?)\</si);
			$c->{baro} = $1  if ($html =~ /Pressure\:.*?obsTextA\"\>(.*?)\&/s);
			$c->{baro} .= 'R'  if ($html =~ s/up_pressure\.gif//s);
			$c->{baro} .= 'F'  if ($html =~ s/down_pressure\.gif//s);
			$c->{baro} .= 'S'  unless ($c->{baro} =~ /[RF]$/);
			$c->{heat} = $1  if ($html =~ /Feels Like\<BR\>\s*(\-?\d+)\&/s);
		$c->{heat} ||= $c->{temp};
			$c->{visb} = $1  if ($html =~ s!Visibility:\<\/td\>\s+\<TD\>\<IMG SRC="[^\>]+\>\<\/td\>\s+\<TD VALIGN\=\"top\"\s+CLASS\=\"obsTextA\"\>([\d\.]+)!!s);
			#$c->{long_cond} =~ s/\_/ /g;          #MAKE THIS MORE READABLE!
			#$c->{long_cond} =~ s/cloud$/cloudy/;
			#$c->{long_cond} =~ s/cloud /cloudy /;
			#$c->{long_cond} =~ s/^(\w+)\s+(\w+)$/\u\L$2\E \u\L$1\E/;
			#$c->{long_cond} =~ s/^(\w+)$/\u\L$1\E/;
			$c->{cond} = $c->{long_cond};
			$c->{pic} = $1  if ($html =~ s#\<IMG\s+SRC\=\"(http\:\/\/image\.weather\.com\/web\/common\/wxicons\/\d+/\d+\.gif)(?:\?\d*)?\"\s+WIDTH\=52\s+HEIGHT\=52\s+BORDER\=0\s+ALT##s);
		}
		elsif ($siteid == 2)  #NOAA
		{
			#if ($html =~ m!\<img\s+src\=\"(\/ifps\/text\/images\/\w+\.jpg)\".+? title\=\"(.+?)\".+?FF0000\"\>(\-?\d+)\&deg\;F!is)
			#{
				#$c->{pic} = 'http://www.srh.noaa.gov'.$1;
			#}
			$c->{pic} = $1  if ($html =~ s#\<img src\=\"(\/forecast\/images\/[^\"]+)\"##);
			unless ($c->{pic})
			{
#				$c->{pic} = $1  if ($html =~ s#\<IMG\s+SRC\=\"(\/HW3php\/images\/fcicons\/\w+.(?:jpg|gif|png))\"\s+WIDTH\=\"5\d\"\s+HEIGHT\=\"5\d\"##is);
#				$c->{pic} = $1  if ($html =~ s#\<IMG\s+SRC\=\"(\/HW3php\/images\/fcicons\/\w+.(?:jpg|gif|png))\"##is);
				$c->{pic} = $1  if ($html =~ s#\<IMG\s+SRC\=\"(\/HW3php\/images\/fcicons\/\w+.(?:jpg|gif|png))\"\s+WIDTH\=\"5\d\"\s+HEIGHT\=\"5\d\"##is);
print "-???- alternate pic:".$c->{pic}."=\n"  if ($debug);
			}
			if ($html =~ m!\<td class\=\"big\" width\=.+?center\"\>(.+?)\<br\>\<br\>(\-?\d+)\&deg\;F\<!)
			{
				$c->{long_cond} = $1;
				$c->{temp} = $2;
			}
			$c->{dewp} = $1  if ($html =~ m!Dewpoint\<\/b\>\:.+?right\"\>(\-?\d+)\&deg\;F!s);
#############			$c->{uv} = $1  if ($html =~ m!UV\:\<\/td\>.+?\>(\d+) \<span!s);
			$c->{humi} = $1  if ($html =~ m!Humidity\<\/b\>\:.+?right\"\>(\d+) \%\<!s);
			$c->{wind} = "From $1 at $2"  if ($html =~ m!Wind\s+Speed\<\/b\>\:.+?right\"\>(\w+)\s+(\d+)\s+MPH\<!s);
print "------wind=$c->{wind}=\n"  if ($debug);
			$c->{baro} = $1  if ($html =~ m!Barometer\<\/b\>\:.+? nowrap>([\d\.]+)\&quot\;!s);
print "------baro=".$c->{baro}."=\n"  if ($debug);
			$c->{baro} .= ' ';
			$c->{heat} = $1  if ($html =~ m!Wind\s+Chill\<\/b\>\:.+?right\"\>(\-?\d+)\&deg\;F!s);
			#$c->{heat} = $1  if ($html =~ /Feels Like\<BR\>\s*(\-?\d+)\&/s);
			$c->{visb} = $1  if ($html =~ m!Visibility\<\/b\>\:.+?right\"\>([\d\.]+) mi\.!s);
			$c->{cond} ||= $c->{long_cond};  #<img src="http://icons.wunderground.com/graphics/conds/nt_clear.GIF" alt
			$_ = $c->{cond};
			#$c->{pic} = $1  if ($html =~ s#\s+\<img\s+src\=\"(http\:\/\/icons\.wunderground\.com\/graphics\/conds\/\w+\.GIF)\"##is);
		}
		else  #wunderground
		{
			$c->{pic} = $1  if ($html =~ m#1px solid \#996\;\"\>\<img\s+src\=\"(http\:\/\/icons-aa\.wunderground\.com\/graphics\/conds\/\w+\.gif)\"#is);
			$c->{temp} = $1  if ($html =~ s!\<nobr\>\<b\>(\-?[\d\.]+)\<\/b\>\&nbsp\;\&\#176\;F\<\/nobr\>!!s);
			$c->{dewp} = $1  if ($html =~ m!Dew Point\:\<\/td\>.+?\>(\-?\d+)\<\/b\>!s);
			$c->{uv} = $1  if ($html =~ m!UV\:\<\/td\>.+?\>(\d+) \<span!s);
			$c->{humi} = $1  if ($html =~ m!Humidity\:\<\/td\>.+?\>(\d+)\%\<!s);
			$c->{long_cond} = $1  if ($html =~ s!\" title\=\"([^\"]+)\" width\=!!s);
			$c->{long_cond} = $1  if (($c->{long_cond} eq 'Unknown') && ($html =~ s!  \<font size\=-1\>\<b\>([\w\s]+)\<\/b\>\<\/font\>!!s));
#			$c->{wind} = $1  if ($html =~ m!Wind\:\<\/td\>.+?\>(\d+)\<\/b\>\&nbsp\;mph!s);
			$c->{wind} = $1  if ($html =~ s!\<nobr\>\<b\>([\d\.]+)\<\/b\>\&nbsp\;mph\<\/nobr\>!!s);
#			my $windir = $1  if ($html =~ m! from the \<\/span\>\W+?(\w+)!s);
			my $windir = $1  if ($html =~ m! pwsvariable\=\"winddir\" english\=\"\" metric\=\"\" value\=\"(\w+)\"\>!s);
print "------wind=$c->{wind}= dir=$windir=\n"  if ($debug);
			$c->{wind} = "From $windir at ".$c->{wind};
			$c->{baro} = $1  if ($html =~ m!Pressure\:\<\/td\>.+?\<b\>([^\<]+)\<!s);
print "------baro=".$c->{baro}."=\n"  if ($debug);
			$c->{baro} .= 'R'  if ($html =~ s/\(Rising\)//s);
			$c->{baro} .= 'F'  if ($html =~ s/\(Falling\)//s);
			$c->{baro} .= 'S'  unless ($c->{baro} =~ /[RF]$/);
			$c->{heat} = $1  if ($html =~ m!Windchill\:\<\/td\>.+?b\>(\d+)\<!s);
			$c->{heat} = $1  if ($html =~ /Feels Like\<BR\>\s*(\-?\d+)\&/s);
			$c->{cond} = $c->{long_cond};  #<img src="http://icons.wunderground.com/graphics/conds/nt_clear.GIF" alt
			$c->{gust} = $1  if ($html =~ s!\<nobr\>\<b\>([\d\.]+)\<\/b\>\&nbsp\;mph\<\/nobr\>!!s);
			$c->{visb} = $1  if ($html =~ s!\<nobr\>\<b\>([\d\.]+)\<\/b\>\&nbsp\;miles\<\/nobr\>!!s);
print "------gust=".$c->{gust}."=\n"  if ($debug);
print "------visb=".$c->{visb}."=\n"  if ($debug);
			$_ = $c->{cond};
			#$c->{pic} = $1  if ($html =~ s#\s+\<img\s+src\=\"(http\:\/\/icons\.wunderground\.com\/graphics\/conds\/\w+\.GIF)\"##is);
		}
		$tempConv = $c->{temp};
		$tempConv = ($tempConv - 32) / 1.8  if ($metric);
		$balloon->{'clients'}{$skybutton}->{-balloonmsg} = (sprintf('%.0f',$tempConv).chr(186).", $c->{long_cond}")  if ($useBalloon);
		$balloon->idletasks  if ($useBalloon);
		$c->{heat} = $c->{temp}  unless ($c->{heat} =~ /\d/);
	}
	return $c;
}

__ENd__
