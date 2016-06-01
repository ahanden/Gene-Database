#!/usr/bin/env perl

use strict;
use warnings;
use DBI;
use Term::ReadKey;
use IO::Handle;
STDOUT->autoflush(1);


sub main {
    my $usage = "Usage: perl gene2accession.pl [gene2accession]";
    my $updater = myUpdate->new(usage => $usage);
    $updater->update();
}

{
    package myUpdate;
    use base ("Update");
    use Getopt::Long;

    sub checkArgs {
        my $self = shift;
        my ($verbose, $db, $user, $password, $species, $cnf_file);
        if(GetOptions('verbose' => \$verbose,
                'database=s' => \$db,
                'username=s' => \$user,
                'password=s' => \$password,
                'species=i'  => \$species,
                'cnf_file=s' => \$cnf_file)  && @ARGV == 1) {
            $self->{fname}      = $ARGV[0];
            $self->{verbose}    = $verbose;
            $self->{dbname}     = $db;
            $self->{user}       = $user;
            $self->{password}   = $password;
            $self->{species}    = $species ? $species : 9606;
            $self->{cnf_file}   = $cnf_file;
            return 1;
        }
        return 0;
    }

    sub exec_main {
        my $self = shift;
       
        my $sth = $self->{dbh}->prepare("INSERT IGNORE INTO gene_xrefs (entrez_id, Xref_id, Xref_db) VALUES (?, ?, ?)");

        my $wc = `wc -l $self->{fname}`;
        my ($total) = $wc =~ /(^\d+)/;
        $self->{prog_total} = $total;

        open(IN,"<$self->{fname}") or die "Failed to open $self->{fname}: $!\n";
        while (my $line = <IN>) {
            $self->logProgress();
            next if $line =~ m/^#/; # discard comments
            next if $line !~ m/^$self->{species}\t/; #ignore non-human genes

            chomp $line;
            my @terms = split(/\t/,$line);

            my ($entrez_id)  = $terms[1] =~ /^(\d+)$/;
            my ($genbank_id) = $terms[6] =~ /^(\d+)$/;
            my ($refseq_id)  = $terms[5] =~ /(NP_\d+)/;

            if($entrez_id ne "-") {
                if($genbank_id) {
                    $sth->execute($entrez_id, $genbank_id, "GenBank");
                }
                if($refseq_id) {
                    $sth->execute($entrez_id, $refseq_id, "RefSeq");
                }
            }
        }
        close IN;
        $self->log("\nDone\n");
    
    }
}

main();
