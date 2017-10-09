
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
      $(DATA_DIR)/gene_xrefs.sql \
      $(DATA_DIR)/annotations.sql \
      $(DATA_DIR)/atlas.sql
	tar -cvf backup.$(DATE).tar $(DATA_DIR)/
	7z a backup.$(DATE).tar.7z backup.$(DATE).tar
	rm backup.$(DATE).tar
	rm -f auth.cnf

#####################
#                   #
# Primary NCBI data #
#                   #
#####################

# Gene Info
$(DATA_DIR)/genes.sql $(DATA_DIR)/gene_synonyms.sql : structure $(DATA_DIR)/gene_info
	perl gene_info.pl -s $(SPECIES) -c auth.cnf -v $(DATA_DIR)/gene_info
	DB=$$(grep -P "^database=" auth.cnf | sed 's/^database=//'); \
	mysqldump --defaults-file=auth.cnf $${DB} genes > $(DATA_DIR)/genes.sql; \
	mysqldump --defaults-file=auth.cnf $${DB} gene_synonyms > $(DATA_DIR)/gene_synonyms.sql;
$(DATA_DIR)/gene_info :
	wget ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene_info.gz --output-document=$(DATA_DIR)/gene_info.gz
	gunzip $(DATA_DIR)/gene_info.gz

# Gene History
$(DATA_DIR)/discontinued_genes.sql : structure $(DATA_DIR)/gene_history
	perl gene_history.pl -s $(SPECIES) -c auth.cnf -v $(DATA_DIR)/gene_history
	DB=$$(grep -P "^database=" auth.cnf | sed 's/^database=//'); \
	mysqldump --defaults-file=auth.cnf $${DB} discontinued_genes> $(DATA_DIR)/discontinued_genes.sql
$(DATA_DIR)/gene_history :
	wget ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene_history.gz --output-document=$(DATA_DIR)/gene_history.gz
	gunzip $(DATA_DIR)/gene_history.gz

# Gene To Accession
$(DATA_DIR)/gene_xrefs.sql : structure $(DATA_DIR)/genes.sql $(DATA_DIR)/gene2accession $(DATA_DIR)/gene_refseq_uniprotkb_collab $(DATA_DIR)/sec_ac.txt
	perl gene2accession.pl -s $(SPECIES) -c auth.cnf -v $(DATA_DIR)/gene2accession
	perl uniprot.pl -s $(SPECIES) -c auth.cnf -v $(DATA_DIR)/gene2accession $(DATA_DIR)/gene_refseq_uniprotkb_collab
	perl sec_ac.pl -c auth.cnf -v $(DATA_DIR)/sec_ac.txt
	DB=$$(grep -P "^database=" auth.cnf | sed 's/^database=//'); \
	mysqldump --defaults-file=auth.cnf $${DB} gene_xrefs> $(DATA_DIR)/gene_xrefs.sql
$(DATA_DIR)/gene2accession :
	wget ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene2accession.gz --output-document=$(DATA_DIR)/gene2accession.gz
	gunzip $(DATA_DIR)/gene2accession.gz
$(DATA_DIR)/gene_refseq_uniprotkb_collab :
	wget ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene_refseq_uniprotkb_collab.gz --output-document=$(DATA_DIR)/gene_refseq_uniprotkb_collab.gz 
	gunzip $(DATA_DIR)/gene_refseq_uniprotkb_collab.gz
$(DATA_DIR)/sec_ac.txt :
	wget ftp://ftp.uniprot.org/pub/databases/uniprot/knowledgebase/docs/sec_ac.txt --output-document=$(DATA_DIR)/sec_ac.txt

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
# REACTOME
$(DATA_DIR)/UniProt2Reactome_All_Levels.txt :
	wget http://www.reactome.org/download/current/UniProt2Reactome_All_Levels.txt --output-document=$(DATA_DIR)/UniProt2Reactome_All_Levels.txt
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
# Gene Ontology
$(DATA_DIR)/gene2go :
	wget ftp://ftp.ncbi.nlm.nih.gov/gene/DATA/gene2go.gz --output-document=$(DATA_DIR)/gene2go.gz
	gunzip $(DATA_DIR)/gene2go.gz
# ClinVar
$(DATA_DIR)/variant_summary.txt :
	wget ftp://ftp.ncbi.nlm.nih.gov/pub/clinvar/tab_delimited/variant_summary.txt.gz --output-document=$(DATA_DIR)/variant_summary.txt.gz
	gunzip $(DATA_DIR)/variant_summary.txt.gz

###################
#                 #
# Gene atlas data #
#                 #
###################

$(DATA_DIR)/atlas.sql: $(DATA_DIR)/normal_tissue.tsv
	perl atlas.pl -c auth.cnf -v $(DATA_DIR)/normal_tissue.tsv
	mysqldump --defaults-file=auth.cnf $${DB} atlas> $(DATA_DIR)/atlas.sql

$(DATA_DIR)/normal_tissue.tsv:
	wget https://www.proteinatlas.org/download/normal_tissue.tsv.zip --output-document=$(DATA_DIR)/normal_tissue.tsv.zip
	unzip $(DATA_DIR)/normal_tissue.tsv.zip -d $(DATA_DIR)

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
