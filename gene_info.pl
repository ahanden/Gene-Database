#!/usr/bin/env perl

use strict;
use warnings;
use IO::Handle;
STDOUT->autoflush(1);


sub main {
    my $updater = myUpdate->new(usage => "Usage: perl gene_info.pl [gene_info]");
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
            $self->{verbose}    = $verbose ? $verbose : 0;
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

        open my $IN, '<', $self->{fname} or die "Failed to open $self->{fname}: $!\n";

        $self->log("Filling database. This may take several minutes...\n");

        my $wc = `wc -l $self->{fname}`;
        my ($total) = $wc =~ /(^\d+)/;
        $self->{prog_total} = $total;

        my $genes_query    = $self->{dbh}->prepare("INSERT IGNORE INTO genes (entrez_id, symbol, name, tax_id) VALUES (?, ?, ?, ?)");
        my $xref_query     = $self->{dbh}->prepare("INSERT IGNORE INTO gene_xrefs (entrez_id, Xref_db, Xref_id) VALUES (?, ?, ?)");
        my $synonym_query  = $self->{dbh}->prepare("INSERT IGNORE INTO gene_synonyms (entrez_id, symbol) VALUES (?, ?)");

        while (my $line = <$IN>) {
            $self->logProgress();
            next if $line =~ m/^#/;
            chomp $line;
            my @terms = split(/\t/,$line);

            my $tax         = $terms[0];
            next unless $tax == $self->{species};
            my $id          = $terms[1];
            my @synonyms    = $terms[4] eq "-" ? () : split(/\|/,$terms[4]);
            my @xrefs       = $terms[5] eq "-" ? () : split(/\|/,$terms[5]);
            my $symbol      = $terms[10] eq "-" ? undef : $terms[10];
            my $name        = $terms[11] eq "-" ? undef : $terms[11];
            if($terms[2] ne "-" && ($terms[10] eq "-" || $terms[2] ne $terms[10])) {
                push(@synonyms,$terms[2]);
            }

            $genes_query->execute($id,$symbol,$name,$tax);

            foreach my $xref(@xrefs) {
                $xref =~ /(.*):(.*)/;
                $xref_query->execute($id,$1,$2);
            }

            foreach my $synonym(@synonyms) {
                $synonym_query->execute($id,$synonym);
            }
        }
        close $IN;
        $self->log("\n");
    }
}

main();
