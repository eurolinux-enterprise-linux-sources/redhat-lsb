#!/usr/bin/perl
use strict;
use warnings;
use feature qw(say);
use Getopt::Long;
use DBI;

use Cwd qw(abs_path getcwd);
use File::Basename;
use File::Temp qw(tempdir);
use Config::IniFiles;

#set up autoflush
$| = 1;
$ENV{LANG} = 'C';

sub usage;
sub clean_when_exit;
sub when_get_SIGINT;

my $default_SIGINT_func = $SIG{INT};
$SIG{INT} = \&when_get_SIGINT;

my ( $help, $like ) = qw( 0 0 );
my ( $sucess, $failed, ) = qw( 0 1 );
my ( $dbh, ) =qw();
my ( $db_source, %attr );
my ( $filelist, $pkg, ) = ( '', '', );
my $st = '';
my ( $rf_pkg, ) = ( '', '', );
my $pkg_found = 0;

GetOptions(
    'help'       => \$help,
    'like'       => \$like,
    'pkg=s'      => \$pkg,
    'filelist=s' => \$filelist,
    
);

%attr = (
    RaiseError => 1,
    AutoCommit => 1,
    PrintError => 1,
);

if ($help) {
    usage;
    goto EXIT;
}

if ( -e $pkg && -r $pkg ) {
    $db_source = 'dbi:SQLite:' . $pkg;
    $dbh = DBI->connect( $db_source, '', '', \%attr )
	or die "Failed to connect $pkg: $!";
    if ( !defined( $dbh ) ) {
	say STDERR 'Failed to connect ' . $pkg . ': $!';
	goto FAILED;
    }
}
else {
    say STDERR "$pkg: can not be open";
    goto FAILED;
}

foreach my $pp (@ARGV) { 
    $pkg_found = 0;
    my ( $pkg, $pkgKey, $provides ) = qw();
    $st = '';
    $st .= 'select provides.name, provides.pkgKey, ';
    $st .= 'packages.name ';
    $st .= 'from provides ';
    $st .= 'left join packages ';
    $st .= 'where provides.pkgKey = packages.pkgKey ';
    $st .= 'and ( ';
    if ($like) {
    $st .= 'provides.name like ' . "'%$pp%' ";
    } else {
    $st .= 'provides.name = ' . "'$pp' ";
    }
    $st .= ' ) ';
    $rf_pkg = $dbh->selectall_arrayref($st);
    foreach my $row (@$rf_pkg) {
	$pkg_found = 1;
	$provides=$row->[0];
	$pkgKey=$row->[1];
	$pkg=$row->[2];
	if ($like) {
	    say $pkg . ' - ' . $pkgKey . ' - ' . $pp . ' - ' . $provides;
	} else {
	    say $pkg . ' - ' . $pkgKey . ' - ' . $provides;
	}
    }
    say STDERR $pp if (!$pkg_found);
}

EXIT:
clean_when_exit;
exit $sucess;
FAILED:
clean_when_exit;
exit $failed;

sub clean_when_exit {
        $dbh->disconnect if ( defined( $dbh ) );
}

sub when_get_SIGINT {
    clean_when_exit;
    $SIG{INT} = \&$default_SIGINT_func;
    &$default_SIGINT_func;
    goto FAILED;
}

sub usage {
    say <<'EOF'
USAGE
     pl2pkg.pl --pkg db provides

DESCRIPTION
  pl2pkg output format as follows:
  when enable --like:
    pkg - pkgKey - pp -- provides
  when disable --like:
    pkg - pkgKey - provides

OPTIONS
    --help               => display this help page 
    --like               => use 'like' replace of '=' in sql
    --pkg pkg            => give the repo package database

EXAMPLE
   ./pl2pkg.pl --pkg primary.sqlite ls bash
   ./pl2pkg.pl --pkg primary.sqlite 'Perl(strict)' 'Perl(warnings)'

REPORT BUG
Pls report bugs to xning@redhat.com.
EOF
}
