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

my ($help) = 0;
my ( $sucess, $failed, ) = qw( 0 1 );
my ( @dbh, @db );
my ( $db_source, %attr );
my ( $filelist, $pkg, ) = ( '', '', );
my ( $pkgKey, ) = ( '', );

GetOptions(
    'help'       => \$help,
    'pkg=s'      => \$pkg,
    'filelist=s' => \$filelist,
);

$db[0] = $filelist;
$db[1] = $pkg;

%attr = (
    RaiseError => 1,
    AutoCommit => 1,
    PrintError => 1,
);

if ($help) {
    usage;
    goto EXIT;
}

foreach ( 0 .. $#db ) {
    if ( -e $db[$_] ) {
        if ( -f $db[$_] and -r $db[$_] ) {
            $db_source = 'dbi:SQLite:' . $db[$_];
            $dbh[$_] = DBI->connect( $db_source, '', '', \%attr )
              or die "Failed to connect $db[$_]: $!";
            goto FAILED if ( !defined( $dbh[$_] ) );
        }
        else {
            say STDERR "$db[$_]: can not be open";
            goto FAILED;
        }
    }
    else {
        say STDERR "filelist db do not exists" if ( $_ == 0 );
        say STDERR "pkg db do not exists"      if ( $_ == 1 );
        goto FAILED;
    }
}

foreach my $n (@ARGV) {
    my $statement = '';
    my ( $rf_file, $rf_pkg ) = qw();
    my ( $pkg, $pkg_grp, $pkgKey, $dir, @files, @types, ) = qw();
    my ( $n_dir, $n_file) = qw();
    my $pkg_found = 0;
    $n_dir=dirname $n;
    $n_file=basename $n;
    $statement .= 'select filelist.pkgKey, filelist.dirname, ';
    $statement .= 'filelist.filenames, filelist.filetypes ';
    $statement .= 'from filelist ';
    $statement .= 'where ';
    $statement .= '(  filenames = "' . $n_file . '" ';
    $statement .= 'or filenames like "' . $n_file . '/%" ';
    $statement .= 'or filenames like "%/' . $n_file . '/%" ';
    $statement .= 'or filenames like "%/' . $n_file . '") ';
    if ($n_dir =~ m!^/!mx) {
	$statement .= 'and filelist.dirname = "' . $n_dir . '" ';
    }
#    say $statement;
    $rf_file = $dbh[0]->selectall_arrayref($statement)
      or die "failed to execute \"$statement\": $!";
#    say 'partial path name: ' . $n;
    foreach my $row (@$rf_file) {
        $pkgKey = $row->[0];
        $dir    = $row->[1];
        @files  = split m!/!, $row->[2];
        @types  = split m!!, $row->[3];
        $files[ $#files + 1 ] = '' if ( $row->[2] =~ m!/$!mx );

        if ( $#files == $#types ) {
            foreach my $inx ( 0 .. $#files ) {
		next if ($types[$inx] eq 'd');
		if ($files[$inx] eq $n_file) {
		    $pkg_found = 1 if ( !$pkg_found  );
		    $statement = '';
		    $statement .= 'select packages.pkgKey, packages.name, ';
		    $statement .= 'packages.rpm_group, packages.rpm_packager ';
		    $statement .= 'from packages ';
		    $statement .= 'where packages.pkgKey = ' . $pkgKey . ' ';
		    $statement .= '';
		    $rf_pkg = $dbh[1]->selectall_arrayref($statement)
			or die "failed to execute \"$statement\": $!";
		    if ( ( scalar @$rf_pkg ) != 1 ) {
			say STDERR $pkgKey
			    . ': more than one packages have this id';
			goto FAILED;
		    }
		    $pkg = $rf_pkg->[0]->[1];
		    $pkg_grp = $rf_pkg->[0]->[2];
		    say '"' . $pkg_grp . '"'  . ' - ' . $pkg . ' - '
			. $types[$inx] . ' - '
			. $dir . '/'
			. $files[$inx] . ' - ' . ${n};
		}
	    }
	}
	else {
	    my $errstr = 'pkgKey ' . $pkgKey;
	    $errstr .= ': files and types not one-to-one: ';
	    $errstr .= $#files . ' - ' . $#types;
	    say STDERR $errstr;
	    goto FAILED;
	}
    }
    say STDERR $n if (!$pkg_found);
    next;
}

EXIT:
clean_when_exit;
exit $sucess;
FAILED:
clean_when_exit;
exit $failed;

sub clean_when_exit {
    for ( 0 .. $#db ) {
        $dbh[$_]->disconnect if ( defined( $dbh[$_] ) );
    }
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
     pp2pkg.pl --pkg pkg --filelist filelist ppname

DESCRIPTION
  pp2pkg.pl output format as follows:
   rpm group - package name - file type - match file - ppname

OPTIONS
    --help               => display this help page 
    --pkg pkg            => give the repo package database
    --filelist filelist  => give the repo filelist database

EXAMPLE
  ./pp2pkg --pkg primary.sqlite --filelist filelists.sqlite ls cmp

REPORT BUG
Pls report bugs to xning@redhat.com.
EOF
}
