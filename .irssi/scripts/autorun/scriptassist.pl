# by Stefan "tommie" Tomanek
#
# scriptassist.pl


use strict;

our $VERSION = '2023111700';
our %IRSSI = (
    authors     => 'Stefan \'tommie\' Tomanek',
    contact     => 'stefan@pico.ruhr.de',
    name        => 'scriptassist',
    description => 'keeps your scripts on the cutting edge',
    license     => 'GPLv2',
    url         => 'https://scripts.irssi.org/',
    modules     => 'CPAN::Meta::YAML LWP::Protocol::https (GnuPG)',
    commands	=> "scriptassist"
);

our ($forked, %remote_db, $have_gpg, @complist);

use Irssi 20020324;
use CPAN::Meta::YAML;
use LWP::UserAgent;
use Hash::Util qw(lock_ref_keys);
use JSON::PP;
use POSIX;
use version;

# GnuPG is not always needed
$have_gpg = 0;
eval "use GnuPG qw(:algo :trust);";
$have_gpg = 1 if not ($@);

my $irssi_version = qv('v'.Irssi::parse_special('$J') =~ s/[^.\d].*//r);

sub show_help {
    my $help = "scriptassist $VERSION
/scriptassist check
    Check all loaded scripts for new available versions
/scriptassist update <script|all>
    Update the selected or all script to the newest version
/scriptassist search <query>
    Search the script database
/scriptassist info <scripts>
    Display information about <scripts>
/scriptassist ratings <scripts|all>
    Retrieve the average ratings of the scripts
/scriptassist top <num>
    Retrieve the first <num> top rated scripts
/scriptassist new <num>
    Display the newest <num> scripts
/scriptassist rate <script>
    Rate the script if you like it
/scriptassist contact <script>
    Write an email to the author of the script
    (Requires OpenURL)
/scriptassist cpan <module>
    Visit CPAN to look for missing Perl modules
    (Requires OpenURL)
/scriptassist install <script>
    Retrieve and load the script
/scriptassist autorun <script>
    Toggles automatic loading of <script>
";  
    my $text='';
    foreach (split(/\n/, $help)) {
        $_ =~ s/^\/(.*)$/%9\/$1%9/;
        $text .= $_."\n";
    }
    print CLIENTCRAP &draw_box("ScriptAssist", $text, "scriptassist help", 1);
    #theme_box("ScriptAssist", $text, "scriptassist help", 1);
}

sub theme_box {
    my ($title, $text, $footer, $colour) = @_;
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'box_header', $title);
    foreach (split(/\n/, $text)) {
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'box_inside', $_);
    }
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, 'box_footer', $footer);
}

sub draw_box {
    my ($title, $text, $footer, $colour) = @_;
    my $box = '';
    $box .= '%R,--[%n%9%U'.$title.'%U%9%R]%n'."\n";
    foreach (split(/\n/, $text)) {
        $box .= '%R|%n '.$_."\n";
    }
    $box .= '%R`--<%n'.$footer.'%R>->%n';
    $box =~ s/%.//g unless $colour;
    return $box;
}

sub call_openurl {
    my ($url) = @_;
    # check for a loaded openurl
    if (my $code = Irssi::Script::openurl::->can('launch_url')) {
	$code->($url);
    } else {
        print CLIENTCRAP "%R>>%n Please install openurl.pl";
        print CLIENTCRAP "%R>>%n    or open < $url > manually";
    }
}

sub bg_do {
    my ($func) = @_;
    my ($rh, $wh);
    pipe($rh, $wh);
    if ($forked) {
	print CLIENTCRAP "%R>>%n Please wait until your earlier request has been finished.";
	return;
    }
    my $pid = fork();
    $forked = 1;
    if ($pid > 0) {
	print CLIENTCRAP "%R>>%n Please wait...";
        close $wh;
        Irssi::pidwait_add($pid);
        my $pipetag;
        my @args = ($rh, \$pipetag, $func);
        $pipetag = Irssi::input_add(fileno($rh), INPUT_READ, \&pipe_input, \@args);
    } else {
	eval {
	    my @items = split(/ /, $func);
	    my %result;
	    my $ts1 = $remote_db{timestamp};
	    my $xml = get_scripts();
	    my $ts2 = $remote_db{timestamp};
	    if (not($ts1 eq $ts2) && Irssi::settings_get_bool('scriptassist_cache_sources')) {
		$result{db} = $remote_db{db};
		$result{timestamp} = $remote_db{timestamp};
	    }
	    if ($items[0] eq 'check') {
		$result{data}{check} = check_scripts($xml);
	    } elsif ($items[0] eq 'update') {
		shift(@items);
		$result{data}{update} = update_scripts(\@items, $xml);
	    } elsif ($items[0] eq 'search') {
		shift(@items);
		foreach (@items) {
		    $result{data}{search}{$_} = search_scripts($_, $xml);
		}
	    } elsif ($items[0] eq 'install') {
		shift(@items);
		$result{data}{install} = install_scripts(\@items, $xml);
	    } elsif ($items[0] eq 'debug') {
		shift(@items);
		$result{data}{debug} = debug_scripts(\@items);
	    } elsif ($items[0] eq 'ratings') {
		shift(@items);
		@items = @{ loaded_scripts() } if $items[0] eq "all";
		my %ratings = %{ get_ratings(\@items, '') };
		foreach (keys %ratings) {
		    $result{data}{rating}{$_}{rating} = $ratings{$_}->[0];
		    $result{data}{rating}{$_}{votes} = $ratings{$_}->[1];
		}
	    } elsif ($items[0] eq 'rate') {
		$result{data}{rate}{$items[1]} = rate_script($items[1], $items[2]);
	    } elsif ($items[0] eq 'info') {
		shift(@items);
		$result{data}{info} = script_info(\@items);
	    } elsif ($items[0] eq 'echo') {
		$result{data}{echo} = 1;
	    } elsif ($items[0] eq 'top') {
		my %ratings = %{ get_ratings([], $items[1]) };
		foreach (keys %ratings) {
                    $result{data}{rating}{$_}{rating} = $ratings{$_}->[0];
                    $result{data}{rating}{$_}{votes} = $ratings{$_}->[1];
                }
	    } elsif ($items[0] eq 'new') {
		my $new = get_new($items[1]);
		$result{data}{new} = $new;
	    } elsif ($items[0] eq 'unknown') {
		my $cmd = $items[1];
		$result{data}{unknown}{$cmd} = get_unknown($cmd, $xml);
	    }
	    my $yaml = CPAN::Meta::YAML->new(\%result);
	    my $data = $yaml->write_string();
	    print($wh $data);
	};
	if ($@) {
	    print($wh CPAN::Meta::YAML->new(+{data=>+{error=>$@}})
		      ->write_string());
	}
	close($wh);
	POSIX::_exit(1);
    }
}

sub get_unknown {
    my ($cmd, $db) = @_;
    foreach (keys %$db) {
	next unless defined $db->{$_}{commands};
	foreach my $item (split / /, $db->{$_}{commands}) {
	    return { $_ => +{%{$db->{$_}}} } if ($item =~ /^$cmd$/i);
	}
    }
    return undef;
}

sub get_names {
    my ($sname, $db, $votes) = @_;
    $sname =~ s/\s+$//;
    my $ext = 'pl';  # default extension
    if ($sname =~ s/\.(\w{2,3})$//) {
	$ext = $1;
    }
    my $plname = "$sname.$ext";
    $sname =~ s/^.*\///;
    my $xname = $sname;
    $xname =~ s/\W/_/g;
    my $pname = "${xname}::";
    if ($xname ne $sname || $sname =~ /_/) {
	my $dir = Irssi::get_irssi_dir()."/scripts/";
	if ($db && exists $db->{$plname}) {
	    # $found = 1;
	} elsif (-e $dir.$plname || -e $dir."autorun/".$plname) {
	    # $found = 1;
	} else {
	    # not found
	    my $pat = $xname; $pat =~ y/_/?/;
	    my $re = "\Q$xname"; $re =~ s/\Q_/./g;
	    if ($db) {
		my ($cand) = grep /^$re\.\Q$ext\E$/, sort keys %$db;
		if ($cand) {
		    return get_names($cand, $db, $votes);
		}
	    }
	    my ($cand) = glob "'$dir$pat.$ext' '${dir}autorun/$pat.$ext'";
	    if ($cand) {
		$cand =~ s/^.*\///;
		return get_names($cand, $db, $votes);
	    }
	}
    }
    my ($script_stash, $script_irssi, $script_db, $local_version);
    $script_db = $db->{$plname} if $db && exists $db->{$plname};
    if (lc $ext eq 'pl') {
	$script_stash = $Irssi::Script::{$pname};
    }
    elsif (lc $ext eq 'py' && is_python_loaded()) {
	my $filename;
	capture_print_text_command(
	    'py list',
	    sub {
		for my $line (@_[ 1 .. $#_ ]) {
		    my ($script, $fn) = split ' ', $line, 2;
		    if ($script eq $sname) {
			$filename = $fn;
		    }
		}
	    });
	if (defined $filename) {
	    my $filename_quoted = $filename;
	    $filename_quoted =~ s/[\\']/\\$&/g;
	    capture_print_text_command(
		# make sure the command line stays short
		'py exec ' .
		(join ';', split /\n/, <<PYTHON
import ast as A, types as _, json
i = 'IRSSI'
v = '__version__'
T = isinstance
f = '$filename_quoted'
a = lambda _: T(_, A.Assign)
n = lambda _: T(_, A.Name)
y = lambda _: _.id
t = lambda _: list(map(y, filter(n, _.targets)))
C = lambda e: lambda _: a(_) and t(_) == [e]
O = _.SimpleNamespace(value=A.Constant(None))
P = A.parse(open(f).read(), filename=f)
f = lambda e: A.literal_eval(next(filter(C(e), P.body), O).value)
print(json.dumps({ i: f(i), v: f(v) }))
PYTHON
		),
		sub {
		    eval {
			my $doc = decode_json("@_");
			$script_stash = { IRSSI => $doc->{IRSSI}, VERSION => \($doc->{__version__}) };
		    };
		}
	       );
	}
    }
    if (defined $script_stash) {
	$script_irssi = $script_stash->{IRSSI};
	$local_version = ${$script_stash->{VERSION}}
	  if $script_stash->{VERSION};
    }
    lock_ref_keys({
	sname => $ext eq 'pl' ? $sname : $plname,
	plname => $plname,
	pname => $pname,
	xname => $xname,
	stash => $script_stash,
	irssi => $script_irssi,
	db => $script_db,
	db_version => ($script_db ? $script_db->{version} : undef),
	local_version => $local_version,
	($votes ? (votes => $votes->{$plname}) : ()),
    })
}

sub script_info {
    my ($scripts) = @_;
    my %result;
    my $xml = get_scripts();
    my $py = is_python_loaded();
    foreach (@{$scripts}) {
	my %r;
	my $n = get_names($_, $xml);
	next unless (defined $n->{db} || defined $n->{irssi});
	$r{version} = $n->{db_version};
	my @headers = ('authors', 'contact', 'description', 'license', 'source');
	foreach my $entry (@headers) {
	    $r{$entry} = $n->{irssi}{$entry};
	    if ($n->{db} && defined $n->{db}{$entry}) {
		$r{$entry} = $n->{db}{$entry};
	    }
	}
	if ($n->{db} && $n->{db}{signature_available}) {
	    $r{signature_available} = 1;
	}
	if ($n->{db} && defined $n->{db}{modules}) {
	    my $modules = $n->{db}{modules};
	    foreach my $mod (split(/ /, $modules)) {
		my $opt = ($mod =~ /\((.*)\)/)? 1 : 0;
		$mod = $1 if $1;
		$r{modules}{$mod}{optional} = $opt;
		$r{modules}{$mod}{installed} = module_exist($mod);
	    }
	} elsif ($n->{irssi} && defined $n->{irssi}{modules}) {
	    my $modules = $n->{irssi}{modules};
	    foreach my $mod (split(/ /, $modules)) {
		my $opt = ($mod =~ /\((.*)\)/)? 1 : 0;
		$mod = $1 if $1;
		$r{modules}{$mod}{optional} = $opt;
		$r{modules}{$mod}{installed} = module_exist($mod);
	    }
	}
	if (!$py && $n->{db} && $n->{db}{language} eq 'Python') {  # py
	    $r{modules}{'irssi-python module'}{installed} = 0;
	}
	# if (defined $n->{db}{depends}) {
	#     my $depends = $n->{db}{depends};
	#     foreach my $dep (split(/ /, $depends)) {
	# 	$r{depends}{$dep}{installed} = 1; #(defined ${ 'Irssi::Script::'.$dep });
	#     }
	# }
	$result{$n->{sname}} = \%r;
    }
    return \%result;
}

sub get_rate_url {
    my ($src) = @_;
    if (ref $src) { ($src) = grep { $_ } map { $_->{source} } values %$src; }
    die("No script source address found\n") unless $src;
    my $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>30);
    $ua->agent('ScriptAssist/'.$VERSION);
    my $request = HTTP::Request->new('GET', $src);
    my $response = $ua->request($request);
    unless ($response->is_success) {
	my $error = join "\n", $response->status_line(), (grep / at .* line \d+/, split "\n", $response->content()), '';
	die("Fetching ratings location failed: $error");
    }
    if (my $error = $response->header('X-Died')) {
	die("$error\n");
    }
    my $votes_url;
    for my $tag ($response->content() =~ /<script([^>]*)>/g) {
	my $attr = " $tag ";
	($votes_url = $1) =~ s/\.\w+$/.yml/
	    if $attr =~ /\sasync\s/ && $attr =~ m{\ssrc="(https?://.*?/votes\.\w+)"\s};
    }
    unless ($votes_url) {
	die("Fetching ratings failed: Could not find votes script\n");
    }
    $request = HTTP::Request->new('GET', $votes_url);
    $response = $ua->request($request);
    if (!$response->is_success || $response->header('X-Died')) {
	my $error = join "\n", $response->status_line(), (grep / at .* line \d+/, split "\n", $response->content()), '';
	die("Fetching ratings failed: $error");
    }
    my $data = $response->content();
    utf8::decode($data);
    CPAN::Meta::YAML->read_string($data)->[0];
}

sub rate_script {
    my ($script, $stars) = @_;
    my $xml = get_scripts();
    my $votes = get_rate_url($xml);
    my $n = get_names($script, $xml, $votes);
    die "Script $script not found\n" unless $n->{votes};
    return $n->{votes}{u}
}

sub get_ratings {
    my ($scripts, $limit) = @_;
    my $xml = get_scripts();
    my $votes = get_rate_url($xml);
    foreach (keys %{$votes}) {
	if ($xml->{$_}) {
	    $xml->{$_}{votes} = $votes->{$_}{v};
	}
    }
    my %result;
    if (@{$scripts}) {
	foreach (@{$scripts}) {
	    my $n = get_names($_, $xml);
	    next unless ($n->{db} || $n->{irssi});
	    $result{$n->{plname}} = [$n->{db}{votes}];
	}
    } else {
	my @keys = sort { $xml->{$b}{votes} <=> $xml->{$a}{votes}
		  || $xml->{$b}{modified} cmp $xml->{$a}{modified} }
	    grep { !$xml->{$_}{HIDDEN} && $xml->{$_}{votes} ne '' } keys %$xml;
	foreach (splice @keys, 0, $limit) {
	    $result{$_} = [$xml->{$_}{votes}];
	}
    }
    die "No such script found\n" unless keys %result;
    return \%result;
}

sub get_new {
    my ($num) = @_;
    my $result;
    my $xml = get_scripts();
    foreach (sort {$xml->{$b}{modified} cmp $xml->{$a}{modified}} keys %$xml) {
	my %entry = %{ $xml->{$_} };
	next if $entry{HIDDEN};
	$result->{$_} = \%entry;
	$num--;
	last unless $num;
    }
    return $result;
}
sub module_exist {
    my ($module) = @_;
    $module =~ s/::/\//g;
    foreach (@INC) {
	return 1 if (-e $_."/".$module.".pm");
    }
    return 0;
}

sub debug_scripts {
    my ($scripts) = @_;
    my %result;
    my $xml = get_scripts();
    my $py = is_python_loaded();
    foreach (@{$scripts}) {
	my %r;
	my $n = get_names($_, $xml);
	if ($n->{db} && defined $n->{db}{modules}) {
	    my $modules = $n->{db}{modules};
	    foreach my $mod (split(/ /, $modules)) {
                my $opt = ($mod =~ /\((.*)\)/)? 1 : 0;
                $mod = $1 if $1;
                $r{$mod}{optional} = $opt;
                $r{$mod}{installed} = module_exist($mod);
	    }
	    $result{$n->{sname}} = \%r;
	}
	if (!$py && $n->{db} && $n->{db}{language} eq 'Python') {  # py
	    $result{$n->{sname}}{'irssi-python module'}{installed} = 0;
	}
    }
    return(\%result);
}

sub install_scripts {
    my ($scripts, $xml) = @_;
    my %success;
    my $dir = Irssi::get_irssi_dir()."/scripts/";
    foreach (@{$scripts}) {
	my $n = get_names($_, $xml);
	if ($n->{stash} && (-e $dir.$n->{plname})) {
	    $success{$n->{sname}}{installed} = -2;
	} else {
	    $success{$n->{sname}} = download_script($n->{sname}, $xml);
	}
    }
    return \%success;
}

sub update_scripts {
    my ($list, $database) = @_;
    $list = loaded_scripts() if ($list->[0] eq "all" || scalar(@$list) == 0);
    my %status;
    foreach (@{$list}) {
	my $n = get_names($_, $database);
	my $local = $n->{local_version};
	my $remote = $n->{db_version};
	next if $local eq '' || $remote eq '';
	if (compare_versions($local, $remote) eq "older") {
	    $status{$n->{sname}} = download_script($n->{sname}, $database);
	} else {
	    $status{$n->{sname}}{installed} = -2;
	}
	$status{$n->{sname}}{remote} = $remote;
	$status{$n->{sname}}{local} = $local;
    }
    return \%status;
}

sub search_scripts {
    my ($query, $database) = @_;
    $query =~ s/\.pl\Z//;  # pl
    my %result;
    foreach (sort keys %{$database}) {
	my %entry = %{$database->{$_}};
	next if $entry{HIDDEN};
	my $string = $_." ";
	$string .= $entry{description} if defined $entry{description};
	if ($string =~ /$query/i) {
	    my $name = $_;
	    $name =~ s/\.pl$//;  # pl
	    if (defined $entry{description}) {
		$result{$name}{desc} = $entry{description};
	    } else {
		$result{$name}{desc} = "";
	    }
	    if (defined $entry{authors}) {
		$result{$name}{authors} = $entry{authors};
	    } else {
		$result{$name}{authors} = "";
	    }
	    if (get_names($name, $database)->{stash}) {
		$result{$name}{installed} = 1;
	    } else {
		$result{$name}{installed} = 0;
	    }
	}
    }
    return \%result;
}

sub pipe_input {
    my ($rh, $pipetag) = @{$_[0]};
    my $text = do { local $/; <$rh>; };
    close($rh);
    Irssi::input_remove($$pipetag);
    $forked = 0;
    unless ($text) {
	print CLIENTCRAP "%R<<%n Something weird happend (no text)";
	return();
    }
    utf8::decode($text);
    my $incoming = CPAN::Meta::YAML->read_string($text)->[0];
    if ($incoming->{db} && $incoming->{timestamp}) {
    	$remote_db{db} = $incoming->{db};
    	$remote_db{timestamp} = $incoming->{timestamp};
    }
    unless (defined $incoming->{data}) {
	print CLIENTCRAP "%R<<%n Something weird happend (no data)";
	return;
    }
    my %result = %{ $incoming->{data} };
    @complist = ();
    if (defined $result{new}) {
	print_new($result{new});
	push @complist, $_ foreach keys %{ $result{new} };
    }
    if (defined $result{check}) {
	print_check(%{$result{check}});
	push @complist, $_ foreach keys %{ $result{check} };
    }
    if (defined $result{update}) {
	print_update(%{ $result{update} });
	push @complist, $_ foreach keys %{ $result{update} };
    }
    if (defined $result{search}) {
	foreach (keys %{$result{search}}) {
	    print_search($_, %{$result{search}{$_}});
	    push @complist, keys(%{$result{search}{$_}});
	}
    }
    if (defined $result{install}) {
	print_install(%{ $result{install} });
	push @complist, $_ foreach keys %{ $result{install} };
    }
    if (defined $result{debug}) {
	print_debug(%{ $result{debug} });
    }
    if (defined $result{rating}) {
	print_ratings(%{ $result{rating} });
	push @complist, $_ foreach keys %{ $result{rating} };
    }
    if (defined $result{rate}) {
	print_rate(%{ $result{rate} });
    }
    if (defined $result{info}) {
	print_info(%{ $result{info} });
    }
    if (defined $result{echo}) {
	Irssi::print "ECHO";
    }
    if ($result{unknown}) {
        print_unknown($result{unknown});
    }
    if (defined $result{error}) {
	print CLIENTCRAP "%R<<%n There was an error in background processing:"; chomp($result{error});
	print CLIENTERROR $result{error};
    }

}

sub print_unknown {
    my ($data) = @_;
    foreach my $cmd (keys %$data) {
	print CLIENTCRAP "%R<<%n No script provides '/$cmd'" unless $data->{$cmd};
	foreach (keys %{ $data->{$cmd} }) {
	    my $text .= "The command '/".$cmd."' is provided by the script '".$data->{$cmd}{$_}{name}."'.\n";
	    $text .= "This script is currently not installed on your system.\n";
	    $text .= "If you want to install the script, enter\n";
	    my $n = get_names($_);
	    $text .= "  %U/script install ".$n->{sname}."%U ";
	    my $output = draw_box("ScriptAssist", $text, "'".$_."' missing", 1);
	    print CLIENTCRAP $output;
	}
    }
}

sub check_autorun {
    my ($script) = @_;
    my $n = get_names($script);
    my $dir = Irssi::get_irssi_dir()."/scripts/";
    if (-e $dir."/autorun/".$n->{plname}) {
	if (readlink($dir."/autorun/".$n->{plname}) eq "../".$n->{plname}) {
	    return 1;
	}
    }
    return 0;
}

sub array2table {
    my (@array) = @_;
    my @width;
    foreach my $line (@array) {
        for (0..scalar(@$line)-1) {
            my $l = $line->[$_];
            $l =~ s/%[^%]//g;
            $l =~ s/%%/%/g;
            $width[$_] = length($l) if $width[$_]<length($l);
        }
    }
    my $text;
    foreach my $line (@array) {
        for (0..scalar(@$line)-1) {
            my $l = $line->[$_];
            $text .= $line->[$_];
            $l =~ s/%[^%]//g;
            $l =~ s/%%/%/g;
            $text .= " "x($width[$_]-length($l)+1) unless ($_ == scalar(@$line)-1);
        }
        $text .= "\n";
    }
    return $text;
}


sub print_info {
    my (%data) = @_;
    my $line;
    foreach my $script (sort keys(%data)) {
	my ($local, $autorun);
	my $n = get_names($script);
	if ($n->{stash}) {
	    $line .= "%go%n ";
	    $local = $n->{local_version};
	} else {
	    $line .= "%ro%n ";
	    $local = undef;
	}
	if ($n->{stash} || check_autorun($script)) {
	    $autorun = "no";
	    $autorun = "yes" if check_autorun($script);
	} else {
	    $autorun = undef;
	}
	$line .= "%9".$script."%9\n";
	$line .= "  Version    : ".$data{$script}{version}."\n";
	$line .= "  Source     : ".$data{$script}{source}."\n";
	$line .= "  Installed  : ".$local."\n" if defined $local;
	$line .= "  Autorun    : ".$autorun."\n" if defined $autorun;
	$line .= "  Authors    : ".$data{$script}{authors};
	$line .= " %Go-m signed%n" if $data{$script}{signature_available};
	$line .= "\n";
	$line .= "  Contact    : ".$data{$script}{contact}."\n";
	$line .= "  Description: ".$data{$script}{description}."\n";
	$line .= "\n" if $data{$script}{modules};
	$line .= "  Needed Perl modules:\n" if $data{$script}{modules};

        foreach (sort keys %{$data{$script}{modules}}) {
            if ( $data{$script}{modules}{$_}{installed} == 1 ) {
                $line .= "  %g->%n ".$_." (found)";
            } else {
                $line .= "  %r->%n ".$_." (not found)";
            }
	    $line .= " <optional>" if $data{$script}{modules}{$_}{optional};
            $line .= "\n";
        }
	$line .= "  Needed Irssi Scripts:\n" if $data{$script}{depends};
	foreach (sort keys %{$data{$script}{depends}}) {
	    if ( $data{$script}{depends}{$_}{installed} == 1 ) {
		$line .= "  %g->%n ".$_." (loaded)";
	    } else {
		$line .= "  %r->%n ".$_." (not loaded)";
	    }
	    $line .= "\n";
	}
    }
    print CLIENTCRAP draw_box('ScriptAssist', $line, 'info', 1) ;
}

sub print_rate {
    my (%data) = @_;
    my $line;
    foreach my $script (sort keys(%data)) {
	call_openurl($data{$script});
    }
}

sub print_ratings {
    my (%data) = @_;
    my @table;
    foreach my $script (sort {$data{$b}{rating}<=>$data{$a}{rating}} keys(%data)) {
	my @line;
	if (get_names($script)->{stash}) {
	    push @line, "%go%n";
	} else {
	    push @line, "%yo%n";
	}
        push @line, "%9".$script."%9";
	push @line, "[".(length $data{$script}{rating} ? $data{$script}{rating} : 'no')." votes]";
	push @table, \@line;
    }
    print CLIENTCRAP draw_box('ScriptAssist', array2table(@table), 'ratings', 1) ;
}

sub print_new {
    my ($list) = @_;
    my @table;
    foreach (sort {$list->{$b}{modified} cmp $list->{$a}{modified}} keys %$list) {
	my @line;
	my $n = get_names($_);
        if ($n->{stash}) {
            push @line, "%go%n";
        } else {
            push @line, "%yo%n";
        }
	push @line, "%9".$n->{sname}."%9";
	push @line, $list->{$_}{modified};
	push @table, \@line;
    }
    print CLIENTCRAP draw_box('ScriptAssist', array2table(@table), 'new scripts', 1) ;
}

sub print_debug {
    my (%data) = @_;
    my $line;
    foreach my $script (sort keys %data) {
	$line .= "%ro%n %9".$script."%9 failed to load\n";
	my $py = $data{$script}{'irssi-python module'};
	if ($py) {  # py
	    $line .= "  You are attempting to load a Python script!\n";
	} else {
	    $line .= "  Make sure you have the following perl modules installed:\n";
	}
	foreach (sort keys %{$data{$script}}) {
	    if ( $data{$script}{$_}{installed} == 1 ) {
		$line .= "  %g->%n ".$_." (found)";
	    } else {
		$line .= "  %r->%n ".$_." (not found)\n";
		$line .= "     [This module is optional]\n" if $data{$script}{$_}{optional};
		if ($py) {  # py
		    $line .= "     [If you have it installed, try: /load python]";
		} else {
		    $line .= "     [Try /scriptassist cpan ".$_."]";
		}
	    }
	    $line .= "\n";
	}
	print CLIENTCRAP draw_box('ScriptAssist', $line, 'debug', 1) ;
    }
}

sub load_script {
    my ($script) = @_;
    if ($script =~ s/\.py$//i) {  # py
	if (is_python_loaded()) {
	    Irssi::command('py load '.$script);
	}
    } else {
	Irssi::command('script load '.$script);  # pl
    }
}

sub print_install {
    my (%data) = @_;
    my $text;
    my ($crashed, @installed);
    foreach my $script (sort keys %data) {
	my $line;
	if ($data{$script}{installed} == 1) {
	    my $hacked;
	    if ($have_gpg && Irssi::settings_get_bool('scriptassist_use_gpg')) {
		if ($data{$script}{signed} >= 0) {
		    load_script($script) unless (lc($script) eq lc($IRSSI{name}));
		} else {
		    $hacked = 1;
		}
	    } else {
		load_script($script) unless (lc($script) eq lc($IRSSI{name}));
	    }
	    if (get_names($script)->{stash} && not lc($script) eq lc($IRSSI{name})) {
		$line .= "%go%n %9".$script."%9 installed\n";
		push @installed, $script;
	    } elsif (lc($script) eq lc($IRSSI{name})) {
		$line .= "%yo%n %9".$script."%9 installed, please reload manually\n";
	    } else {
    		$line .= "%Ro%n %9".$script."%9 fetched, but unable to load\n";
		$crashed .= $script." " unless $hacked;
	    }
	    if ($have_gpg && Irssi::settings_get_bool('scriptassist_use_gpg')) {
		foreach (split /\n/, check_sig($data{$script})) {
		    $line .= "  ".$_."\n";
		}
	    }
	} elsif ($data{$script}{installed} == -2) {
	    $line .= "%ro%n %9".$script."%9 already loaded, please try \"update\"\n";
	} elsif ($data{$script}{installed} <= 0) {
	    $line .= "%ro%n %9".$script."%9 not installed\n";
    	    foreach (split /\n/, check_sig($data{$script})) {
		$line .= "  ".$_."\n";
	    }
	} else {
	    $line .= "%Ro%n %9".$script."%9 not found on server\n";
	}
	$text .= $line;
    }
    # Inspect crashed scripts
    bg_do("debug ".$crashed) if $crashed;
    print CLIENTCRAP draw_box('ScriptAssist', $text, 'install', 1);
    list_sbitems(\@installed);
}

sub list_sbitems {
    my ($scripts) = @_;
    my $text;
    foreach (@$scripts) {
	my $n = get_names($_);
	next unless $n->{irssi}{sbitems};
	$text .= '%9"'.$_.'"%9 provides the following statusbar item(s):'."\n";
	$text .= '  ->'.$_."\n" foreach (split / /, $n->{irssi}{sbitems});
    }
    return unless $text;
    $text .= "\n";
    $text .= "Enter '/statusbar additem <item> window' to add an item.";
    print CLIENTCRAP draw_box('ScriptAssist', $text, 'sbitems', 1);
}

sub check_sig {
    my ($sig) = @_;
    my $line;
    my %trust = ( -1 => 'undefined',
                   0 => 'never',
		   1 => 'marginal',
		   2 => 'fully',
		   3 => 'ultimate'
		 );
    if ($sig->{signed} == 1) {
	$line .= "Signature found from ".$sig->{sig}{user}."\n";
	$line .= "Timestamp  : ".$sig->{sig}{date}."\n";
	$line .= "Fingerprint: ".$sig->{sig}{fingerprint}."\n";
	$line .= "KeyID      : ".$sig->{sig}{keyid}."\n";
	$line .= "Trust      : ".$trust{$sig->{sig}{trust}}."\n";
    } elsif ($sig->{signed} == -1) {
	$line .= "%1Warning, unable to verify signature%n\n";
    } elsif ($sig->{signed} == 0) {
	$line .= "%1No signature found%n\n" unless Irssi::settings_get_bool('scriptassist_install_unsigned_scripts');
    }
    return $line;
}

sub print_search {
    my ($query, %data) = @_;
    my $text;
    foreach (sort keys %data) {
	my $line;
	$line .= "%go%n" if $data{$_}{installed};
	$line .= "%yo%n" if not $data{$_}{installed};
	$line .= " %9".$_."%9 ";
	$line .= $data{$_}{desc};
	$line =~ s/($query)/%U$1%U/gi;
	$line .= ' ('.$data{$_}{authors}.')';
	$text .= $line." \n";
    }
    print CLIENTCRAP draw_box('ScriptAssist', $text, 'search: '.$query, 1) ;
}

sub print_update {
    my (%data) = @_;
    my $text;
    my @table;
    my $verbose = Irssi::settings_get_bool('scriptassist_update_verbose');
    foreach (sort keys %data) {
	my $signed = 0;
	if ($data{$_}{installed} == 1) {
	    my $local = $data{$_}{local};
	    my $remote = $data{$_}{remote};
	    push @table, ['%yo%n', '%9'.$_.'%9', 'upgraded ('.$local.'->'.$remote.')'];
	    foreach (split /\n/, check_sig($data{$_})) {
		push @table, ['', '', $_];
	    }
	    if (lc($_) eq lc($IRSSI{name})) {
		push @table, ['', '', "%R%9Please reload manually%9%n"];
	    } else {
		load_script($_);
	    }
	} elsif ($data{$_}{installed} == 0 || $data{$_}{installed} == -1) {
	    push @table, ['%yo%n', '%9'.$_.'%9', 'not upgraded'];
            foreach (split /\n/, check_sig($data{$_})) {
		push @table, ['', '', $_];
            }
	} elsif ($data{$_}{installed} == -2 && $verbose) {
	    my $local = $data{$_}{local};
	    push @table, ['%go%n', '%9'.$_.'%9', 'already at the latest version ('.$local.')'];
    	}
    }
    $text = array2table(@table);
    print CLIENTCRAP draw_box('ScriptAssist', $text, 'update', 1) ;
}

sub contact_author {
    my ($script) = @_;
    my $n = get_names($script);
    if ($n->{irssi} && defined $n->{irssi}{contact}) {
	my @ads = split(/ |,/, $n->{irssi}{contact});
	my $address = $ads[0];
	$address .= '?subject='.$script;
	$address .= '_'.$n->{local_version} if $n->{local_version};
	call_openurl($address) if $address =~ /[\@:]/;
    }
}

sub get_scripts {
    my $ua = LWP::UserAgent->new(env_proxy=>1, keep_alive=>1, timeout=>30);
    $ua->agent('ScriptAssist/'.$VERSION);
    $ua->env_proxy();
    my @mirrors = split(/ /, Irssi::settings_get_str('scriptassist_script_sources'));
    my %sites_db;
    my $not_modified = 0;
    my $fetched = 0;
    my @sources;
    my $error;
    foreach my $site (@mirrors) {
	my $request = HTTP::Request->new('GET', $site);
	if ($remote_db{timestamp}) {
	    $request->if_modified_since($remote_db{timestamp});
	}
	my $response = $ua->request($request);
	if ($response->code == 304) { # HTTP_NOT_MODIFIED
	    $not_modified = 1;
	    next;
	}
	unless ($response->is_success) {
	    $error = join "\n", $response->status_line(), (grep / at .* line \d+/, split "\n", $response->content()), '';
	    next;
	}
	if (my $died = $response->header('X-Died')) {
	    $error = $died;
	    next;
	}
	$fetched = 1;
	my $data = $response->content();
	my $src = $site;
	my $type = '';
	if ($site =~ /(.*\/).+\.(.+)/) {
	    $src = $1;
	    $type = $2;
	}
	push @sources, $src;
	#my @header = ('name', 'contact', 'authors', 'description', 'version', 'modules', 'modified');
	if ($type eq 'dmp') {
	    die("Support for $type script database has been removed. Please /set scriptassist_script_sources and change $type -> yml.\n");
	} elsif ($type eq 'yml') {
	    utf8::decode($data);
	    my $new_db = CPAN::Meta::YAML->read_string($data);
	    foreach (@{$new_db->[0]}) {
		my $K = $_->{filename};
		if (defined $sites_db{script}{$K}) {
		    my $old = $sites_db{$K}{version};
		    my $new = $_->{version};
		    next if (compare_versions($old, $new) eq 'newer');
		}
		#foreach my $key (@header) {
		foreach my $key (keys %$_) {
		    next unless defined $_->{$key};
		    $sites_db{$K}{$key} = $_->{$key};
		}
		$sites_db{$K}{source} = $src;
	    }
	} else {
	    die("Unknown script database type ($type).\n");
	}
    }
    if ($fetched) {
	# Clean database
	foreach (keys %{$remote_db{db}}) {
	    foreach my $site (@sources) {
		if ($remote_db{db}{$_}{source} eq $site) {
		    delete $remote_db{db}{$_};
		    last;
		}
	    }
	}
	$remote_db{db}{$_} = $sites_db{$_} foreach (keys %sites_db);
	$remote_db{timestamp} = time();
    } elsif ($not_modified) {
	# nothing to do
    } else {
	die("No script database sources defined in /set scriptassist_script_sources\n") unless @mirrors;
	die("Fetching script database failed: $error") if $error;
	die("Unknown error while fetching script database\n");
    }
    return $remote_db{db};
}

sub compare_versions {
    my ($ver1, $ver2) = @_;
    for ($ver1, $ver2) {
	$_ = "0:$_" unless /:/;
    }
    my @ver1 = split /[.:]/, $ver1;
    my @ver2 = split /[.:]/, $ver2;
    my $cmp = 0;
    ### Special thanks to Clemens Heidinger
    no warnings 'uninitialized';
    $cmp ||= $ver1[$_] <=> $ver2[$_] || $ver1[$_] cmp $ver2[$_] for 0..scalar(@ver2);
    return 'newer' if $cmp == 1;
    return 'older' if $cmp == -1;
    return 'equal';
}

sub is_python_loaded {
    !! grep { $_->{cmd} eq 'py' } Irssi::commands
}

my @print_text_capture;
sub capture_print_text {
    my ($dest, $text, $plain) = @_;
    push @print_text_capture, $plain;
    Irssi::signal_stop;
}

sub capture_print_text_command {
    my ($command, $sub) = @_;
    Irssi::signal_add_first('print text', 'capture_print_text');
    @print_text_capture = ();
    Irssi::command($command);
    my @capture = @print_text_capture;
    Irssi::signal_remove('print text', 'capture_print_text');
    @print_text_capture = ();
    $sub->(@capture);
}

sub loaded_scripts {
    my @modules;
    foreach (sort grep(s/::$//, keys %Irssi::Script::)) {  # pl
	push @modules, $_;
    }
    if (is_python_loaded()) {
	capture_print_text_command(
	    'py list', sub {
		for my $line (@_[ 1 .. $#_ ]) {
		    my ($script, $file) = split ' ', $line, 2;
		    push @modules, "$script.py";
		}
	    });
    }
    return \@modules;
}

sub check_scripts {
    my ($data) = @_;
    my %versions;
    foreach (@{loaded_scripts()}) {
	my $n = get_names($_, $data);
	my $remote = $n->{db_version};
	my $local = $n->{local_version};
	my $state;
	if ($local && $remote) {
	    $state = compare_versions($local, $remote);
	} elsif ($local) {
	    $state = 'noversion';
	    $remote = '/';
	} else {
	    $state = 'noheader';
	    $local = '/';
	    $remote = '/';
	}
	if ($state) {
	    $versions{$n->{sname}}{state} = $state;
	    $versions{$n->{sname}}{remote} = $remote;
	    $versions{$n->{sname}}{local} = $local;
	}
    }
    return \%versions;
}

sub download_script {
    my ($script, $xml) = @_;
    my $n = get_names($script, $xml);
    my $site = $n->{db}{source};
    my %result;
    $result{installed} = 0;
    $result{signed} = 0;
    my $dir = Irssi::get_irssi_dir();
    my $ua = LWP::UserAgent->new(env_proxy => 1, keep_alive => 1, timeout => 30);
    $ua->agent('ScriptAssist/'.2003020803);
    my $request = HTTP::Request->new('GET', $site.'/scripts/'.$n->{plname});
    my $response = $ua->request($request);
    if ($response->is_success() && !$response->header('X-Died')) {
	my $file = $response->content();
	mkdir $dir.'/scripts/' unless (-e $dir.'/scripts/');
	open(my $f, '>', $dir.'/scripts/'.$n->{plname}.'.new');
	print $f $file;
	close($f);
	if ($have_gpg && Irssi::settings_get_bool('scriptassist_use_gpg')) {
	    my $ua2 = LWP::UserAgent->new(env_proxy => 1,keep_alive => 1,timeout => 30);
	    $ua->agent('ScriptAssist/'.2003020803);
	    my $request2 = HTTP::Request->new('GET', $site.'/signatures/'.$n->{plname}.'.asc');
	    my $response2 = $ua->request($request2);
	    if ($response2->is_success() && !$response->header('X-Died')) {
		my $sig_dir = $dir.'/scripts/signatures/';
		mkdir $sig_dir unless (-e $sig_dir);
		open(my $s, '>', $sig_dir.$n->{plname}.'.asc');
		my $file2 = $response2->content();
		print $s $file2;
		close($s);
		my $sig;
		foreach (1..2) {
		    # FIXME gpg needs two rounds to load the key
		    my $gpg = new GnuPG();
		    eval {
			$sig = $gpg->verify( file => $dir.'/scripts/'.$n->{plname}.'.new', signature => $sig_dir.$n->{plname}.'.asc' );
		    };
		}
		if (defined $sig->{user}) {
		    $result{installed} = 1;
		    $result{signed} = 1;
		    $result{sig}{$_} = $sig->{$_} foreach (keys %{$sig});
		} else {
		    # Signature broken?
		    $result{installed} = 0;
		    $result{signed} = -1;
		}
	    } else {
		$result{signed} = 0;
		$result{installed} = -1;
		$result{installed} = 1 if Irssi::settings_get_bool('scriptassist_install_unsigned_scripts');
	    }
	} else {
	    $result{signed} = 0;
	    $result{installed} = -1;
	    $result{installed} = 1 if Irssi::settings_get_bool('scriptassist_install_unsigned_scripts');
	}
    }
    if ($result{installed}) {
	my $old_dir = "$dir/scripts/old/";
	mkdir $old_dir unless (-e $old_dir);
	rename "$dir/scripts/".$n->{plname}, "$old_dir/".$n->{plname}.".old" if -e "$dir/scripts/".$n->{plname};
	rename "$dir/scripts/".$n->{plname}.".new", "$dir/scripts/".$n->{plname};
    }
    return \%result;
}

sub print_check {
    my (%data) = @_;
    my $text;
    my @table;
    foreach (sort keys %data) {
	my $state = $data{$_}{state};
	my $remote = $data{$_}{remote};
	my $local = $data{$_}{local};
	if (Irssi::settings_get_bool('scriptassist_check_verbose')) {
	    push @table, ['%go%n', '%9'.$_.'%9', 'Up to date. ('.$local.')'] if $state eq 'equal';
	}
	push @table, ['%mo%n', '%9'.$_.'%9', "No version information available on network."] if $state eq "noversion";
	push @table, ['%mo%n', '%9'.$_.'%9', 'No header in script.'] if $state eq "noheader";
	push @table, ['%bo%n', '%9'.$_.'%9', "Your version is newer (".$local."->".$remote.")"] if $state eq "newer";
	push @table, ['%ro%n', '%9'.$_.'%9', "A new version is available (".$local."->".$remote.")"] if $state eq "older";;
    }
    $text = array2table(@table);
    print CLIENTCRAP draw_box('ScriptAssist', $text, 'check', 1) ;
}

sub toggle_autorun {
    my ($script) = @_;
    my $n = get_names($script);
    my $dir = Irssi::get_irssi_dir()."/scripts/";
    mkdir $dir."autorun/" unless (-e $dir."autorun/");
    return unless (-e $dir.$n->{plname});
    if (-e $dir."/autorun/".$n->{plname}) {
	if (readlink($dir."/autorun/".$n->{plname}) eq "../".$n->{plname}) {
	    if (unlink($dir."/autorun/".$n->{plname})) {
		print CLIENTCRAP "%R>>%n Autorun of ".$n->{sname}." disabled";
	    } else {
		print CLIENTCRAP "%R>>%n Unable to delete link";
	    }
	} else {
	    print CLIENTCRAP "%R>>%n ".$dir."/autorun/".$n->{plname}." is not a correct link";
	}
    } else {
	if (symlink("../".$n->{plname}, $dir."/autorun/".$n->{plname})) {
	    print CLIENTCRAP "%R>>%n Autorun of ".$n->{sname}." enabled";
	} else {
	    print CLIENTCRAP "%R>>%n Unable to create autorun link";
	}
    }
}

sub sig_script_error {
    my ($script, $msg) = @_;
    return unless Irssi::settings_get_bool('scriptassist_catch_script_errors');
    if ($msg =~ /Can't locate (.*?)\.pm in \@INC \(\@INC contains:(.*?) at/) {
        my $module = $1;
        $module =~ s/\//::/g;
	missing_module($module);
    }
}

sub missing_module {
    my ($module) = @_;
    my $text;
    $text .= "The perl module %9".$module."%9 is missing on your system.\n";
    $text .= "Please ask your administrator about it.\n";
    $text .= "You can also check CPAN via '/scriptassist cpan ".$module."'.\n";
    print CLIENTCRAP &draw_box('ScriptAssist', $text, $module, 1);
}

sub cmd_scripassist {
    my ($arg, $server, $witem) = @_;
    utf8::decode($arg);
    my @args = split(/ /, $arg);
    if ($args[0] eq 'help' || $args[0] eq '-h') {
	show_help();
    } elsif ($args[0] eq 'check') {
	bg_do("check");
    } elsif ($args[0] eq 'update') {
	shift @args;
	bg_do("update ".join(' ', @args));
    } elsif ($args[0] eq 'search' && defined $args[1]) {
	shift @args;
	bg_do("search ".join(" ", @args));
    } elsif ($args[0] eq 'install' && defined $args[1]) {
	shift @args;
	bg_do("install ".join(' ', @args));
    } elsif ($args[0] eq 'contact' && defined $args[1]) {
	contact_author($args[1]);
    } elsif ($args[0] eq 'ratings' && defined $args[1]) {
	shift @args;
	bg_do("ratings ".join(' ', @args));
    } elsif ($args[0] eq 'rate' && defined $args[1]) {
	shift @args;
	bg_do("rate ".join(' ', @args));
    } elsif ($args[0] eq 'info' && defined $args[1]) {
	shift @args;
	bg_do("info ".join(' ', @args));
    } elsif ($args[0] eq 'echo') {
	bg_do("echo");
    } elsif ($args[0] eq 'top') {
	my $number = defined $args[1] ? $args[1] : 10;
	bg_do("top ".$number);
    } elsif ($args[0] eq 'cpan' && defined $args[1]) {
	call_openurl('http://search.cpan.org/search?mode=module&query='.$args[1]);
    } elsif ($args[0] eq 'autorun' && defined $args[1]) {
	toggle_autorun($args[1]);
    } elsif ($args[0] eq 'new') {
	my $number = defined $args[1] ? $args[1] : 5;
	bg_do("new ".$number);
    }
}

sub cmd_help {
    my ($arg, $server, $witem) = @_;
    $arg =~ s/\s+$//;
    if ($arg =~ /^scriptassist/i) {
	show_help();
    }
}

sub sig_command_script_load {
    my ($script, $server, $witem) = @_;
    my $n = get_names($script);
    if ( $n->{stash} ) {
	if (my $code = ("Irssi::Script::".$n->{pname})->can('pre_unload')) {
	    print CLIENTCRAP "%R>>%n Triggering pre_unload function of $script...";
	    $code->();
	}
    }
}

sub sig_default_command {
    my ($cmd, $server) = @_;
    return unless Irssi::settings_get_bool("scriptassist_check_unknown_commands");
    return if ($cmd =~ /^\d+$/ && $irssi_version >= v1.2.0 && Irssi::settings_get_bool("window_number_commands"));
    bg_do('unknown '.$cmd);
}

sub sig_complete {
    my ($list, $window, $word, $linestart, $want_space) = @_;
    return unless $linestart =~ /^.script(assist)? (install|rate|ratings|update|check|contact|info|autorun)/i;
    my @newlist;
    my $str = $word;
    foreach (@complist) {
	if ($_ =~ /^(\Q$str\E.*)?$/) {
	    push @newlist, $_;
	}
    }
    foreach (@{loaded_scripts()}) {
	push @newlist, $_ if /^(\Q$str\E.*)?$/;
    }
    push @$list, $_ foreach @newlist;
    Irssi::signal_stop();
}


Irssi::settings_add_str($IRSSI{name}, 'scriptassist_script_sources', 'https://scripts.irssi.org/scripts.yml');
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_cache_sources', 1);
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_update_verbose', 1);
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_check_verbose', 1);
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_catch_script_errors', 1);

Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_install_unsigned_scripts', 1);
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_use_gpg', 1);
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_integrate', 1);
Irssi::settings_add_bool($IRSSI{name}, 'scriptassist_check_unknown_commands', 1);

Irssi::signal_add_first("default command", 'sig_default_command');
Irssi::signal_add_first('complete word', 'sig_complete');
Irssi::signal_add_first('command script load', 'sig_command_script_load');
Irssi::signal_add_first('command script unload', 'sig_command_script_load');

Irssi::signal_register({ 'script error' => [ 'Irssi::Script', 'string' ] });
Irssi::signal_add_last('script error', 'sig_script_error');

Irssi::command_bind('scriptassist', 'cmd_scripassist');
Irssi::command_bind('help', 'cmd_help');

Irssi::theme_register(['box_header', '%R,--[%n$*%R]%n',
'box_inside', '%R|%n $*',
'box_footer', '%R`--<%n$*%R>->%n',
]);

foreach my $cmd ( ( 'check',
		    'install',
		    'update',
		    'contact',
		    'search',
#		    '-h',
		    'help',
		    'ratings',
		    'rate',
		    'info',
#		    'echo',
		    'top',
		    'cpan',
		    'autorun',
		    'new' ) ) {
    Irssi::command_bind('scriptassist '.$cmd => sub {
			cmd_scripassist("$cmd ".$_[0], $_[1], $_[2]); });
    if (Irssi::settings_get_bool('scriptassist_integrate')) {
	Irssi::command_bind('script '.$cmd => sub {
    			    cmd_scripassist("$cmd ".$_[0], $_[1], $_[2]); });
    }
}

print CLIENTCRAP '%B>>%n '.$IRSSI{name}.' '.$VERSION.' loaded: /scriptassist help for help';
