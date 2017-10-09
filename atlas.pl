#!/usr/bin/env perl

use strict;
use warnings;
use IO::Handle;
STDOUT->autoflush(1);


sub main {
    my $updater = myUpdate->new(usage => "Usage: perl atlas.pl [normal_tissue.tsv]");
    $updater->update(); 
}


{
    package myUpdate;
    use base ("Update");
    use Getopt::Long;

    sub checkArgs {
        my $self = shift;

        $self->{ensembl_cache} = {};

        my ($verbose, $db, $user, $password, $species, $cnf_file);
        if(GetOptions('verbose' => \$verbose,
                'database=s' => \$db,
                'username=s' => \$user,
                'password=s' => \$password,
                'cnf_file=s' => \$cnf_file)  && @ARGV == 1) {
            $self->{fname}      = $ARGV[0];
            $self->{verbose}    = $verbose ? $verbose : 0;
            $self->{dbname}     = $db;
            $self->{user}       = $user;
            $self->{password}   = $password;
            $self->{cnf_file}   = $cnf_file;

            return 1;
        }
        return 0;
    }
   
    sub getEIDs {
        my ($self, $ensembl, $symbol) = @_;

        if(!exists($self->{ensembl_cache}->{$ensembl})) {
            my @eids;
            $self->{ensembl_query}->execute($ensembl);
            while(my $ref = $self->{ensembl_query}->fetch()) {
                push(@eids, $ref->[0]);
            }

            if(! @eids) {
                $self->{symbol_query}->execute($symbol);
                while(my $ref = $self->{symbol_query}->fetch()) {
                    push(@eids, $ref->[0]);
                }
            }
            
            if(! @eids) {
                $self->{synonym_query}->execute($symbol);
                while(my $ref = $self->{synonym_query}->fetch()) {
                    push(@eids, $ref->[0]);
                }
            }
            
            if(! @eids) {
                $self->{discontinued_query}->execute($symbol);
                while(my $ref = $self->{discontinued_query}->fetch()) {
                    push(@eids, $ref->[0]);
                }
            }

            $self->{ensembl_cache}->{$ensembl} = \@eids;

        }
        return @{$self->{ensembl_cache}->{$ensembl}};

    }

    sub exec_main {
        my $self = shift;

        open my $IN, '<', $self->{fname} or die "Failed to open $self->{fname}: $!\n";

        my $wc = `wc -l $self->{fname}`;
        my ($total) = $wc =~ /(^\d+)/;
        $self->{prog_total} = $total;

        $self->{ensembl_query}      = $self->{dbh}->prepare("SELECT entrez_id FROM gene_Xrefs WHERE Xref_id = ?");
        $self->{symbol_query}       = $self->{dbh}->prepare("SELECT entrez_id FROM genes WHERE symbol = ?");
        $self->{synonym_query}      = $self->{dbh}->prepare("SELECT entrez_id FROM gene_synonyms WHERE symbol = ?");
        $self->{discontinued_query} = $self->{dbh}->prepare("SELECT entrez_id FROM discontinued_genes WHERE discontinued_symbol = ?");

        my $sql =<<SQL;
            INSERT IGNORE INTO atlas (
               `entrez_id`,
               `tissue`,
               `cell_type`,
               `level`,
               `reliability`)
            VALUES (?, ?, ?, ?, ?)
SQL

        my $insert_query = $self->{dbh}->prepare($sql);

        my $header = <$IN>;
        while (my $line = <$IN>) {
            $self->logProgress();
            chomp $line;
            my ($ensembl, $symbol, $tissue, $cell_type, $level, $reliability) = split(/\t/, $line);

            my @eids = $self->getEIDs($ensembl, $symbol);

            foreach my $eid(@eids) {
                $insert_query->execute($eid, $tissue, $cell_type, $level, $reliability);
            }
        }
        close $IN;
        $self->log("\n");
    }
}
main();
