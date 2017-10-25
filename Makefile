
#############
#           #
# VARIABLES #
#           #
#############

# Today's date
DATE ?= `date +%Y_%m_%d`

# Directory to store data in
DATA_DIR ?= data

# Species code
SPECIES=9606

# Broad Institute release number
BI_VERSION=5.1

###############
#             #
# Main target #
#             #
###############
all : $(DATA_DIR)/genes.sql \
      $(DATA_DIR)/gene_synonyms.sql \
      $(DATA_DIR)/discontinued_genes.sql \
      $(DATA_DIR)/gene_xrefs.gene_info.sql \
      $(DATA_DIR)/gene_Xrefs.gene2accession.sql
	tar -cvf backup.$(DATE).tar $(DATA_DIR)/
	7z a backup.$(DATE).tar.7z backup.$(DATE).tar
	rm backup.$(DATE).tar
	rm -f auth.cnf

##########################
#                        #
# Generate table content #
#                        #
##########################

# The gene_info file has to be read several times through. Only selecting genes
# of the specified species saves a lot of time.
$(DATA_DIR)/gene_info.$(SPECIES): $(DATA_DIR)/gene_info
	grep -P "^(#|$(SPECIES)\t)" $< > $@

# Insert statement for the entire genes table
sql/genes.sql: $(DATA_DIR)/gene_info.$(SPECIES)
	echo "INSERT INTO genes (entrez_id, symbol, name, species) VALUES" > $@
	grep -v "^#" $< | \
		awk -F "\t" -v OFS="," '{print "\t(" $$2, "\""$$11"\"", "\""$$12"\"", $$1 "),"}' | \
			sed -e 's/"-"/NULL/g' \
	    		    -e '$$ s/,$$/;/' >> $@

# Insert statement for the entire gene_synonyms table
sql/gene_synonyms.sql: $(DATA_DIR)/gene_info.$(SPECIES)
	echo "INSERT INTO gene_synonyms (entrez_id, symbol) VALUES" > $@
	grep -v "^#" $< | \
		awk -F "\t" -v OFS="," '{split($$5, s, "|"); for(i in s) { print "\t(" $$2, "\""s[i]"\")," }}' | \
		sed -e '/"-"/d' -e '$$ s/,$$/;/' >> $@

# Insert statement for the entire discontinued_genes table
sql/discontinued_genes.sql: $(DATA_DIR)/gene_history
	echo "INSERT INTO discontinued_genes (entrez_id, discontinued_symbol, discontinued_id) VALUES" > $@ 
	awk -F "\t" -v OFS="," '{ \
		if($$1 == "$(SPECIES)") { \
			print "\t("$$2, "\""$$4"\"", "\""$$3"\")," \
		} \
	}' $< | \
	sed -e '/^\t(-/d' \
	    -e 's/"-"/NULL/g' \
	    -e '$$ s/,$$/;/' >> $@

# Insert statement for gene_info's portion of the gene_Xrefs table
sql/gene_Xrefs.gene_info.sql: $(DATA_DIR)/gene_info.$(SPECIES)
	echo "INSERT INTO gene_Xrefs (entrez_id, Xref_id, Xref_db) VALUES" > $@
	grep -v "^#" $< | \
		awk -F "\t" -v OFS="," '{ \
			split($$6, x, "|"); \
			for(i in x) { \
				print "\t(" $$1, "\""x[i]"\")," \
			} \
		}' | \
		sed -e '/"-"/d' \
		    -e 's/"\([^:]\+\):\([^"]\+\)"/"\1","\2"/' >> $@
# Insert statement for gene2accession's portion of the gene_Xrefs table
sql/gene_Xrefs.gene2accession.sql: $(DATA_DIR)/gene2accession
	echo "INSERT INTO gene_Xrefs (entrez_id, Xref_id, Xref_db) VALUES" > $@
	awk -F "\t" '{ \
		if($$1 == "$(SPECIES)") { \
			if($$6 != "-") { \
				print "\t(" $$2 ",\"" $$6 "\",\"RefSeq\"),"; \
			} \
			if($$7 != "-") { \
				print "\t(" $$2 ",\"" $$7 "\",\"GenBank\")," \
			} \
		} \
	}' $< >> $@

# Insert statement for Gene Ontology annotations
sql/annotations.go.sql: $(DATA_DIR)/gene2go
	echo "INSERT IGNORE INTO annotations (entrez_id, annotations, db) VALUES" > $@
	awk -F "\t" '{ \
		if($$1 == "$(SPECIES)") { \
			print "\t(" $$2 ",\"" $$6 "\",\"GO\")," \
		} \
	}' $< | \
	sed '$$ s/,$$/;/' >> $@

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

#####################
#                   #
# Primary NCBI data #
#                   #
#####################

# Gene To Accession
$(DATA_DIR)/gene_xrefs.sql : structure $(DATA_DIR)/genes.sql $(DATA_DIR)/gene2accession $(DATA_DIR)/gene_refseq_uniprotkb_collab $(DATA_DIR)/sec_ac.txt
	perl gene2accession.pl -s $(SPECIES) -c auth.cnf -v $(DATA_DIR)/gene2accession
	perl uniprot.pl -s $(SPECIES) -c auth.cnf -v $(DATA_DIR)/gene2accession $(DATA_DIR)/gene_refseq_uniprotkb_collab
	perl sec_ac.pl -c auth.cnf -v $(DATA_DIR)/sec_ac.txt
	DB=$$(grep -P "^database=" auth.cnf | sed 's/^database=//'); \
	mysqldump --defaults-file=auth.cnf $${DB} gene_xrefs> $(DATA_DIR)/gene_xrefs.sql

####################
#                  #
# Gene Annotations #
#                  #
####################

$(DATA_DIR)/annotations.sql : structure $(DATA_DIR)/UniProt2Reactome_All_Levels.txt $(DATA_DIR)/c2.cp.kegg.v$(BI_VERSION).entrez.gmt $(DATA_DIR)/c2.cp.biocarta.v$(BI_VERSION).entrez.gmt $(DATA_DIR)/gene2go $(DATA_DIR)/variant_summary.txt
	# REACTOME
	perl reactome.pl -c auth.cnf -s $(SPECIES) -v $(DATA_DIR)/UniProt2Reactome_All_Levels.txt
	# KEGG and BioCarta (by way of the Broad Institute)
	perl broad.pl -c auth.cnf -v $(DATA_DIR)/c2.cp.kegg.v$(BI_VERSION).entrez.gmt
	perl broad.pl -c auth.cnf -v $(DATA_DIR)/c2.cp.biocarta.v$(BI_VERSION).entrez.gmt
	# Gene Ontology
	perl gene2go.pl -c auth.cnf -s $(SPECIES) -v $(DATA_DIR)/gene2go
	# ClinVar
	perl variant_summary.pl -c auth.cnf -v $(DATA_DIR)/variant_summary.txt
	DB=$$(grep -P "^database=" auth.cnf | sed 's/^database=//'); \
	mysqldump --defaults-file=auth.cnf $${DB} annotations> $(DATA_DIR)/annotations.sql
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
# ClinVar
$(DATA_DIR)/variant_summary.txt :
	wget ftp://ftp.ncbi.nlm.nih.gov/pub/clinvar/tab_delimited/variant_summary.txt.gz --output-document=$(DATA_DIR)/variant_summary.txt.gz
	gunzip $(DATA_DIR)/variant_summary.txt.gz

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
