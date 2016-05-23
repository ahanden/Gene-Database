#!/usr/bin/env perl

use strict;
use warnings;
use IO::Handle;
STDOUT->autoflush(1);


sub main {
    my $updater = myUpdate->new(usage => "Usage: perl sec_ac.pl [sec_ac.txt]");
    $updater->update();
}


{
    package myUpdate;
    use base ("Update");
    use Getopt::Long;

    sub checkArgs {
        my $self = shift;

        my $verbose = 0;
        if(GetOptions('verbose' => \$verbose)  && @ARGV == 1) {
            $self->{fname} = $ARGV[0];
            $self->{verbose} = $verbose;
            return 1;
        }
        return 0;
    }
    
    sub exec_main {
        my $self = shift;

        open my $IN, '<', $self->{fname} or die "Failed to open $self->{fname}: $!\n";

        $self->log("Filling database. This may take several minutes...\n");

        my $wc = `wc -l $self->{fname}`;
        my ($total) = $wc =~ /(^\d+)/;
        $self->{prog_total} = $total;

        # queries
        my $query =<<STH;
            INSERT IGNORE INTO gene_xrefs (entrez_id, Xref_db, Xref_id)
                SELECT entrez_id, 'UniProt', ?
                FROM gene_xrefs
                WHERE Xref_db = 'UniProt'
                AND Xref_id = ?
STH
        my $sth = $dbh->prepare($query);

        while (my $line = <$IN>) {
            $self->logProgress();
            chomp $line;

            my @genes;
            while($_ =~ m/([OPQ][0-9][A-Z0-9]{3}[0-9]|[A-NR-Z][0-9]([A-Z][A-Z0-9]{2}[0-9]){1,2})/g) {
                push(@genes, $1);
            }

            if(scalar(@genes) == 2) {
                my ($secondary, $primary) = @genes;
                $sth->execute($secondary, $primary);
            }
        }
        close $IN;
        $self->log("\n");
    }
}

main();
