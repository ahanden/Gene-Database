#!/usr/bin/env perl

use strict;
use warnings;
use IO::Handle;
STDOUT->autoflush(1);


sub main {
    my $updater = myUpdate->new(usage => "Usage: perl variant_summary.pl [variant_summary.txt]");
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
        my ($self, $eid) = @_;
        if(!exists($self->{eid_cache}->{$eid})) {
            my @eids;

            $self->{valid_eid_query}->execute($eid);
            if($self->{valid_eid_query}->fetch()->[0]) {
                push(@eids, $eid);
            }

            if(!@eids) {
                $self->{discontinued_query}->execute($eid);
                while(my $ref = $self->{discontinued_query}->fetch()) {
                    push(@eids, $ref->[0]);
                }
            }

            $self->{eid_cache}->{$eid} = \@eids;

        }
        return @{$self->{eid_cache}->{$eid}};
    }

    sub exec_main {
        my $self = shift;

        open my $IN, '<', $self->{fname} or die "Failed to open $self->{fname}: $!\n";

        my $wc = `wc -l $self->{fname}`;
        my ($total) = $wc =~ /(^\d+)/;
        $self->{prog_total} = $total;

        $self->{eid_cache} = {};
        $self->{valid_eid_query}    = $self->{dbh}->prepare("SELECT EXISTS(SELECT * FROM genes WHERE entrez_id = ?)");
        $self->{discontinued_query} = $self->{dbh}->prepare("SELECT entrez_id FROM discontinued_genes WHERE discontinued_id = ?");

        my $insert_query = $self->{dbh}->prepare("INSERT IGNORE INTO annotations (entrez_id, annotation, db) VALUES (?, ?, ?)");

        while (my $line = <$IN>) {
            $self->logProgress();
            chomp $line;

            next if $line =~ m/^#/;

            my @terms = split(/\t/,$line);

            my $gene = $terms[3];
            my @rcva = $terms[8] =~ /(RCV\d+)/;
            my @omim = $terms[10] =~ /OMIM:(\d+)/;

            foreach my $eid($self->getEIDs($gene)) {
                foreach my $r(@rcva) {
                    $insert_query->execute($eid,$r,"ClinVar");
                }
                foreach my $o(@omim) {
                    $insert_query->execute($eid,$o,"OMIM");
                }
            }
        }
        close $IN;
        $self->log("\n");
    }
}

main();
