
#############
#           #
# VARIABLES #
#           #
#############

# Today's date
DATE ?= `date +%Y_%m_%d`

# Directory to store data in
DATA_DIR ?= data

# Directory to store SQL files
SQL_DIR ?= sql

# Species code
SPECIES=9606

# Broad Institute release number
BI_VERSION=5.1

# Number of rows to insert at a time
CHUNK_SIZE=1000

###############
#             #
# Main target #
#             #
###############

all: structure \
     $(SQL_DIR)/genes.sql \
     $(SQL_DIR)/gene_synonyms.sql \
     $(SQL_DIR)/discontinued_genes.sql \
     $(SQL_DIR)/gene_Xrefs.gene_info.sql \
     $(SQL_DIR)/gene_Xrefs.gene2accession.sql \
     $(SQL_DIR)/gene_Xrefs.gene_refseq_uniprotkb_collab.sql \
     $(SQL_DIR)/gene_Xrefs.sec_ac.sql \
     $(SQL_DIR)/annotations.go.sql \
     $(SQL_DIR)/annotations.reactome.sql \
     $(SQL_DIR)/annotations.kegg.sql \
     $(SQL_DIR)/annotations.biocarta.sql
	mysql --defaults-file=auth.cnf < $(SQL_DIR)/genes.sql
	mysql --defaults-file=auth.cnf < $(SQL_DIR)/gene_synonyms.sql
	mysql --defaults-file=auth.cnf < $(SQL_DIR)/discontinued_genes.sql
	mysql --defaults-file=auth.cnf < $(SQL_DIR)/gene_Xrefs.gene_info.sql
	mysql --defaults-file=auth.cnf < $(SQL_DIR)/gene_Xrefs.gene2accession.sql
	mysql --defaults-file=auth.cnf < $(SQL_DIR)/gene_Xrefs.gene_refseq_uniprotkb_collab.sql
	mysql --defaults-file=auth.cnf < $(SQL_DIR)/gene_Xrefs.sec_ac.sql
	mysql --defaults-file=auth.cnf < $(SQL_DIR)/annotations.go.sql
	mysql --defaults-file=auth.cnf < $(SQL_DIR)/annotations.reactome.sql
	mysql --defaults-file=auth.cnf < $(SQL_DIR)/annotations.kegg.sql
	mysql --defaults-file=auth.cnf < $(SQL_DIR)/annotations.biocarta.sql


##################
#                #
# Pre-Processing #
#                #
##################

# The gene_info file has to be read several times through. Only selecting genes
# of the specified species saves a lot of time.
$(DATA_DIR)/gene_info.$(SPECIES): $(DATA_DIR)/gene_info
	grep -P "^(#|$(SPECIES)\t)" $< > $@

##########################
#                        #
# Generate table content #
#                        #
##########################

# Insert statement for the entire genes table
$(SQL_DIR)/genes.sql: $(DATA_DIR)/gene_info.$(SPECIES)
	awk -F "\t" 'BEGIN{ \
		values = "\t(%s, \"%s\", \"%s\", %s, \"%s\"),\n"; \
	} /^[^#]/ { \
		printf values, $$2, $$11, $$12, $$1, $$10; \
	}' $< | \
	sed -e 's/"-"/NULL/g' \
	    -e '0~$(CHUNK_SIZE) s/,$$/;/' \
	    -e '$$ s/,$$/;/' \
	    -e '1~$(CHUNK_SIZE) iINSERT INTO genes (entrez_id, symbol, name, tax_id, `type`) VALUES' \
	    > $@

# Insert statement for the entire gene_synonyms table
$(SQL_DIR)/gene_synonyms.sql: $(DATA_DIR)/gene_info.$(SPECIES)
	awk -F "\t" -v OFS="," '/^[^#]/{ \
		if($$3 != $$11) { \
			print "\t(" $$2, "\""$$3"\"),"; \
		} \
		split($$5, s, "|"); \
		for(i in s) { \
			print "\t(" $$2, "\""s[i]"\"),"; \
		} \
	}' $< | \
	sed -e '/"-"/d' | \
	sed -e '0~$(CHUNK_SIZE) s/,$$/;/' \
	    -e '$$ s/,$$/;/' \
	    -e '1~$(CHUNK_SIZE) iINSERT IGNORE INTO gene_synonyms (entrez_id, symbol) VALUES' \
	    > $@


# Insert statement for the entire discontinued_genes table
$(SQL_DIR)/discontinued_genes.sql: $(DATA_DIR)/gene_history
	awk -F "\t" -v OFS="," '{ \
		if($$1 == "$(SPECIES)") { \
			print "\t("$$2, "\""$$4"\"", "\""$$3"\")," \
		} \
	}' $< | \
	sed -e '/^\t(-/d' | \
	sed -e 's/"-"/NULL/g' \
	    -e '0~$(CHUNK_SIZE) s/,$$/;/' \
	    -e '$$ s/,$$/;/' \
	    -e '1~$(CHUNK_SIZE) iINSERT INTO discontinued_genes (entrez_id, discontinued_symbol, discontinued_id) VALUES' \
	    > $@ 

# Insert statement for gene_info's portion of the gene_Xrefs table
$(SQL_DIR)/gene_Xrefs.gene_info.sql: $(DATA_DIR)/gene_info.$(SPECIES)
	awk -F "\t" -v OFS="," '/^[^#]/{ \
		split($$6, x, "|"); \
		for(i in x) { \
			print "\t(" $$1, "\""x[i]"\")," \
		} \
	}' $< | \
	sed '/"-"/d' | \
	sed -e 's/"\([^:]\+\):\([^"]\+\)"/"\1","\2"/' \
	    -e '0~$(CHUNK_SIZE) s/,$$/;/' \
	    -e '$$ s/,$$/;/' \
	    -e '1~$(CHUNK_SIZE) iINSERT IGNORE INTO gene_Xrefs (entrez_id, Xref_id, Xref_db) VALUES' \
	    > $@

# Insert statement for gene2accession's portion of the gene_Xrefs table
$(SQL_DIR)/gene_Xrefs.gene2accession.sql: $(DATA_DIR)/gene2accession
	awk -F "\t" 'BEGIN{\
		values = "\t(%s, \"%s\", \"%s\"),\n"; \
	} /^$(SPECIES)\t/ { \
		printf values, $$2, $$6, "RefSeq"; \
		printf values, $$2, $$7, "GenBank"; \
	}' $< | \
	sed '/"-"/d' | \
	sed -e '0~$(CHUNK_SIZE) s/,$$/;/' \
	    -e '$$ s/,$$/;/' \
	    -e '1~$(CHUNK_SIZE) iINSERT IGNORE INTO gene_Xrefs (entrez_id, Xref_id, Xref_db) VALUES' \
	    > $@

# Insert statement for gene_refseq_uniprotkb_collab portion of the gene_Xrefs
# table
$(SQL_DIR)/gene_Xrefs.gene_refseq_uniprotkb_collab.sql: \
		$(DATA_DIR)/gene_refseq_uniprotkb_collab
	awk -F "\t" 'BEGIN{ \
		values = "\t((SELECT xrefeid(\"%s\", \"RefSeq\")), \"%s\", \"UniProt\"),\n"; \
	} /^[^#]/ { \
		printf values, $$1, $$2; \
	}' $< | \
	sed -e '0~$(CHUNK_SIZE) s/,$$/;/' \
	    -e '$$ s/,$$/;/' \
	    -e '1~$(CHUNK_SIZE) iINSERT IGNORE INTO gene_Xrefs (entrez_id, Xref_id, Xref_db) VALUES' \
	    > $@

# Insert statement for sec_ac portion of the gene_Xrefs table
$(SQL_DIR)/gene_Xrefs.sec_ac.sql: $(DATA_DIR)/sec_ac.txt
	awk 'BEGIN{ \
		values = "\t((SELECT xrefeid(\"%s\", \"UniProt\")), \"%s\", \"UniProt\"),\n"; \
	} /^[^:_]+$$/ { \
		if(NF == 2) \
			printf values, $$2, $$1; \
	}' $< | \
	sed -e '0~$(CHUNK_SIZE) s/,$$/;/' \
	    -e '$$ s/,$$/;/' \
	    -e '1~$(CHUNK_SIZE) iINSERT IGNORE INTO gene_Xrefs (entrez_id, Xref_id, Xref_db) VALUES' \
	    > $@

# Insert statement for Gene Ontology annotations
$(SQL_DIR)/annotations.go.sql: $(DATA_DIR)/gene2go
	awk -F "\t" '/^9606\t/ { \
		print "\t(" $$2 ",\"" $$6 "\",\"GO\")," \
	}' $< | \
	sed -e '0~$(CHUNK_SIZE) s/,$$/;/' \
	    -e '$$ s/,$$/;/' \
	    -e '1~$(CHUNK_SIZE) iINSERT IGNORE INTO annotations (entrez_id, annotation, db) VALUES' \
	    > $@

# Insert statement for REACTOME annotations
$(SQL_DIR)/annotations.reactome.sql: $(DATA_DIR)/UniProt2Reactome_All_Levels.txt
	awk -F "\t" '{ \
		print "\t((SELECT xrefeid(\""$$1"\", \"UniProt\")), \""$$4"\", \"REACTOME\"),"; \
	}' $< | \
	sed -e '0~$(CHUNK_SIZE) s/,$$/;/' \
	    -e '$$ s/,$$/;/' \
	    -e '1~$(CHUNK_SIZE) iINSERT IGNORE INTO annotations (entrez_id, annotation, db) VALUES' \
	    > $@

# Insert statement for KEGG annotations (from the Broad Institute)
$(SQL_DIR)/annotations.kegg.sql: $(DATA_DIR)/c2.cp.kegg.v5.1.entrez.gmt
	awk -F "\t" '{ \
		for(i = 3; i <= NF; i++) \
			print "\t((SELECT valideid("$$i")), \""substr($$1,6)"\", \"KEGG\"),"; \
	}' $< | \
	sed -e '0~$(CHUNK_SIZE) s/,$$/;/' \
	    -e '$$ s/,$$/;/' \
	    -e '1~$(CHUNK_SIZE) iINSERT IGNORE INTO annotations (entrez_id, annotation, db) VALUES' \
	    > $@

# Insert statement for BioCarta annotations (from the Broad Institute)
$(SQL_DIR)/annotations.biocarta.sql: $(DATA_DIR)/c2.cp.biocarta.v5.1.entrez.gmt
	awk -F "\t" '{ \
		for(i = 3; i <= NF; i++) \
			print "\t((SELECT valideid("$$i")), \""substr($$1,10)"\", \"BIOCARTA\"),"; \
	}' $< | \
	sed -e '0~$(CHUNK_SIZE) s/,$$/;/' \
	    -e '$$ s/,$$/;/' \
	    -e '1~$(CHUNK_SIZE) iINSERT IGNORE INTO annotations (entrez_id, annotation, db) VALUES' \
	    > $@

###############################
#                             #
# External files for download #
#                             #
###############################

# NCBI Data
$(DATA_DIR)/gene_info :
	wget ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene_info.gz \
		--output-document=$(DATA_DIR)/gene_info.gz
	gunzip $(DATA_DIR)/gene_info.gz
$(DATA_DIR)/gene_history :
	wget ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene_history.gz \
		--output-document=$(DATA_DIR)/gene_history.gz
	gunzip $(DATA_DIR)/gene_history.gz
$(DATA_DIR)/gene2accession :
	wget ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene2accession.gz \
		--output-document=$(DATA_DIR)/gene2accession.gz
	gunzip $(DATA_DIR)/gene2accession.gz

# UniProt Identifiers
$(DATA_DIR)/gene_refseq_uniprotkb_collab :
	wget ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene_refseq_uniprotkb_collab.gz \
		--output-document=$(DATA_DIR)/gene_refseq_uniprotkb_collab.gz 
	gunzip $(DATA_DIR)/gene_refseq_uniprotkb_collab.gz
$(DATA_DIR)/sec_ac.txt :
	wget ftp://ftp.uniprot.org/pub/databases/uniprot/knowledgebase/docs/sec_ac.txt \
		--output-document=$(DATA_DIR)/sec_ac.txt

# REACTOME
$(DATA_DIR)/UniProt2Reactome_All_Levels.txt :
	wget http://www.reactome.org/download/current/UniProt2Reactome_All_Levels.txt --output-document=$(DATA_DIR)/UniProt2Reactome_All_Levels.txt

# Gene Ontology
$(DATA_DIR)/gene2go :
	wget ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene2go.gz --output-document=$(DATA_DIR)/gene2go.gz
	gunzip $(DATA_DIR)/gene2go.gz

# Human gene atlas
$(DATA_DIR)/normal_tissue.tsv:
	wget https://www.proteinatlas.org/download/normal_tissue.tsv.zip --output-document=$(DATA_DIR)/normal_tissue.tsv.zip
	unzip $(DATA_DIR)/normal_tissue.tsv.zip -d $(DATA_DIR)

# Broad Institute (KEGG and BioCarta)
$(DATA_DIR)/c2.cp.kegg.v$(BI_VERSION).entrez.gmt $(DATA_DIR)/c2.cp.biocarta.v$(BI_VERSION).entrez.gmt :
	@echo "Downloading Broad Institute GSEA version $(BI_VERSION)"
	@echo "Please remember to check the latest Broad Institute version and update the Makefile as needed"
	wget http://software.broadinstitute.org/gsea/j_spring_security_check \
		--post-data="j_username=handena@pitt.edu&j_password=password" \
		--save-cookies="$(DATA_DIR)/cookies.txt" \
		--output-document=- \
		--keep-session-cookies > /dev/null
	wget http://software.broadinstitute.org/gsea/msigdb/download_file.jsp?filePath=/resources/msigdb/$(BI_VERSION)/c2.cp.kegg.v$(BI_VERSION).entrez.gmt \
		--load-cookies="$(DATA_DIR)/cookies.txt" \
		--output-document="$(DATA_DIR)/c2.cp.kegg.v$(BI_VERSION).entrez.gmt"
	wget http://software.broadinstitute.org/gsea/msigdb/download_file.jsp?filePath=/resources/msigdb/$(BI_VERSION)/c2.cp.biocarta.v$(BI_VERSION).entrez.gmt \
		--load-cookies="$(DATA_DIR)/cookies.txt" \
		--output-document="$(DATA_DIR)/c2.cp.biocarta.v$(BI_VERSION).entrez.gmt"
	rm $(DATA_DIR)/cookies.txt

#########################
#                       #
# Remove the data files #
#                       #
#########################
clean :
	rm $(DATA_DIR)/*
	rm -f auth.cnf

################################
#                              #
# Apply the database structure #
#                              #
################################

structure : auth.cnf
	mysql --defaults-file=auth.cnf < structure.sql
	mysql --defaults-file=auth.cnf < functions.sql

########################
#                      #
# Database credentials #
#                      #
########################
auth.cnf :
	@echo "[client]" > auth.cnf
	@read -p "Database: " db; echo "database=$$db" >> auth.cnf
	@read -p "Username: " user; echo "user=$$user" >> auth.cnf
	@read -s -p "Password: " passwd; echo "password=$$passwd" >> auth.cnf
	@echo
	chmod 400 auth.cnf
