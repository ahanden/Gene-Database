#!/usr/bin/env perl

use strict;
use warnings;
use IO::Handle;
STDOUT->autoflush(1);


sub main {
    my $updater = myUpdate->new(usage => "Usage: perl reactome.pl [UniProt2Reactome_All_Levels.txt]");
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

            my %species_map = (
                3702  => "Arabidopsis thaliana",
                9913  => "Bos taurus",
                6239  => "Caenorhabditis elegans",
                9615  => "Canis familiaris",
                7955  => "Danio rerio",
                44689 => "Dictyostelium discoideum",
                7227  => "Drosophila melanogaster",
                9031  => "Gallus gallus",
                9606  => "Homo sapiens", 
                10090 => "Mus musculus",
                1773  => "Mycobacterium tuberculosis",
                4530  => "Oryza sativa",
                5833  => "Plasmodium falciparum",
                10116 => "Rattus norvegicus",
                4932  => "Saccharomyces cerevisiae",
                4896  => "Schizosaccharomyces pombe",
                9823  => "Sus scrofa",
                59729 => "Taeniopygia guttata",
                8364  => "Xenopus tropicalis"
            );

            $self->{species} = $species ? $species_map{$species} : $species_map{9606};

            return 1;
        }
        return 0;
    }
    
    sub exec_main {
        my $self = shift;

        open my $IN, '<', $self->{fname} or die "Failed to open $self->{fname}: $!\n";

        my $wc = `wc -l $self->{fname}`;
        my ($total) = $wc =~ /(^\d+)/;
        $self->{prog_total} = $total;

        my $insert_query = $self->{dbh}->prepare("INSERT IGNORE INTO annotations (entrez_id, annotation, db) VALUES (?, ?, 'REACTOME')");
        my $xref_query   = $self->{dbh}->prepare("SELECT entrez_id FROM gene_xrefs WHERE Xref_id = ? AND Xref_db = 'UniProt'");

        while (my $line = <$IN>) {
            $self->logProgress();
            chomp $line;
            my @terms = split(/\t/,$line);

            my $uniprot_id = $terms[0];
            my $pathway    = $terms[3];
            my $taxonomy   = $terms[5];

            next unless $taxonomy eq $self->{species};

            $xref_query->execute($uniprot_id);
            while(my $ref = $xref_query->fetch()) {
                $insert_query->execute($ref->[0], $pathway);
            }
        }
        close $IN;
        $self->log("\n");
    }
}

main();
