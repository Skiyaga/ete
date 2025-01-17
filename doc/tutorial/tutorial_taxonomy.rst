.. currentmodule:: ete4

Taxonomy databases
==================

.. contents::

Overview
--------

ETE4 contains the *ncbi_taxonomy* and *gtdb_taxonomy* modules which
provide utilities to efficiently query a local copy of the NCBI or
GTDB taxonomy databases. The classes :class:`NCBITaxa` and
:class:`GTDBTaxa` offer methods to convert from taxid to names (and
vice versa), to fetch pruned topologies connecting a given set of
species, or to download rank, names and lineage track information.

It is also fully integrated with :class:`PhyloTree` instances through
the :func:`~PhyloTree.annotate_ncbi_taxa` and
:func:`~PhyloTree.annotate_gtdb_taxa` methods.


Differences between NCBI and GTDB taxonomies in ETE4
----------------------------------------------------

The NCBI taxonomy database is a comprehensive resource for organism
names and classifications.It is updated daily and offers multiple
access points including a web portal, an FTP server. The database
releases its data in a package called "taxdump.tar.gz" which contains
several .dmp files.

Taxon in NCBI taxonomyis usually a numeric identifier, commonly
representing taxa ("TaxID"), but it can also signify other entities
like genetic codes or citations, such as 9606 represents Homo Sapiens.

On the other hand, GTDB taxonomy is distributed as simple text files,
uses a genome-based approach for classification, and the identifiers
are usually specific to genomes rather than taxa.

Since ETE Toolkit version 3, ETE parses taxdump file and stores it in
a local sqlite database to fullfill the methods in ncbi_taxonomy
module. We applied the same strategy to GTDBTaxa. While the original
GTDB taxonomy data differs from NCBI taxonomy files, a conversion step
is essential for integration.

To integrate GTDB into the ETE Toolkit v4, a conversion process is
necessary. A third-party script
(https://github.com/nick-youngblut/gtdb_to_taxdump) is employed to
convert the GTDB taxonomy to the NCBI-like taxdump format. We already
preprared GTDB taxonomy dump file from different releases version and
store in
https://github.com/etetoolkit/ete-data/tree/main/gtdb_taxonomy.


Setting up local copies of the NCBI and GTDB taxonomy databases
---------------------------------------------------------------

The first time you attempt to use NCBITaxa or GTDBTaxa, ETE will
detect that your local database is empty and will attempt to download
the latest taxonomy database (NCBI ~600MB, GTDB ~72MB) and will store
a parsed version of it in `~/.local/share/ete/` by default. All future
imports of NCBITaxa or GTDBTaxa will detect the local database and
will skip this step.

Example::

  # Load NCBI module
  from ete4 import NCBITaxa
  ncbi = NCBITaxa()
  ncbi.update_taxonomy_database()

  # Load GTDB module
  from ete4 import GTDBTaxa
  gtdb = GTDBTaxa()
  gtdb.update_taxonomy_database()

  # Load GTDB module with specific release version
  from ete4 import GTDBTaxa
  gtdb = GTDBTaxa()

  # latest release updated in https://github.com/dengzq1234/ete-data/tree/main/gtdb_taxonomy
  gtdb.update_taxonomy_database()
  # or
  gtdb.update_taxonomy_database("gtdbdump.tar.gz")

  # update with custom release 202
  gtdb.update_taxonomy_database('gtdb202dump.tar.gz')


Getting taxid information
-------------------------

NCBI taxonomy
~~~~~~~~~~~~~

You can fetch species names, ranks and linage track information for
your taxids using the following methods:

.. autosummary::

   NCBITaxa.get_rank
   NCBITaxa.get_lineage
   NCBITaxa.get_taxid_translator
   NCBITaxa.get_name_translator
   NCBITaxa.translate_to_names

The so called get-translator functions will return a dictionary
converting between taxids and species names. Either species or linage
names/taxids are accepted as input.

Example::

  from ete4 import NCBITaxa
  ncbi = NCBITaxa()
  taxid2name = ncbi.get_taxid_translator([9606, 9443])
  print(taxid2name)
  # {9443: 'Primates', 9606: 'Homo sapiens'}

  name2taxid = ncbi.get_name_translator(['Homo sapiens', 'primates'])
  print(name2taxid)
  # {'Homo sapiens': [9606], 'primates': [9443]}

  # when the same name points to several taxa, all taxids are returned
  name2taxid = ncbi.get_name_translator(['Bacteria'])
  print(name2taxid)
  # {'Bacteria': [2, 629395]}

Other functions allow to extract further information using taxid
numbers as a query.

Example::

  from ete4 import NCBITaxa
  ncbi = NCBITaxa()

  print(ncbi.get_rank([9606, 9443]))
  # {9443: 'order', 9606: 'species'}

  print(ncbi.get_lineage(9606))
  # [1, 131567, 2759, 33154, 33208, 6072, 33213, 33511, 7711, 89593, 7742,
  # 7776, 117570, 117571, 8287, 1338369, 32523, 32524, 40674, 32525, 9347,
  # 1437010, 314146, 9443, 376913, 314293, 9526, 314295, 9604, 207598, 9605,
  # 9606]

Example combining all at once::

  from ete4 import NCBITaxa
  ncbi = NCBITaxa()

  lineage = ncbi.get_lineage(9606)
  print(lineage)

  # [1, 131567, 2759, 33154, 33208, 6072, 33213, 33511, 7711, 89593, 7742,
  # 7776, 117570, 117571, 8287, 1338369, 32523, 32524, 40674, 32525, 9347,
  # 1437010, 314146, 9443, 376913, 314293, 9526, 314295, 9604, 207598, 9605,
  # 9606]

  names = ncbi.get_taxid_translator(lineage)
  print([names[taxid] for taxid in lineage])

  # ['root', 'cellular organisms', 'Eukaryota', 'Opisthokonta', 'Metazoa',
  # 'Eumetazoa', 'Bilateria', 'Deuterostomia', 'Chordata', 'Craniata',
  # 'Vertebrata', 'Gnathostomata', 'Teleostomi', 'Euteleostomi',
  # 'Sarcopterygii', 'Dipnotetrapodomorpha', 'Tetrapoda', 'Amniota',
  # 'Mammalia', 'Theria', 'Eutheria', 'Boreoeutheria', 'Euarchontoglires',
  # 'Primates', 'Haplorrhini', 'Simiiformes', 'Catarrhini', 'Hominoidea',
  # 'Hominidae', 'Homininae', 'Homo', 'Homo sapiens']


GTDB taxonomy
~~~~~~~~~~~~~

In the NCBI taxonomy database, each species is assigned a unique numeric taxid.
For example, the taxid 9606 refers to Homo sapiens. These taxids serve as
essential keys for tracking lineages within the database.

However, the GTDB database doesn't originally offer numeric taxids like NCBI
does. In the GTDBTaxa module, we've introduced taxids for each species to
facilitate lineage tracking. These taxids, while not officially recognized in
the GTDB database, serve as convenient keys. They help in connecting the lineage
and taxonomic ranks within the local database, making it easier for users to
fetch and relate taxonomic information.

Like NCBITaxa, GTDBTaxa contains similar methods:

.. autosummary::

   GTDBTaxa.get_rank
   GTDBTaxa.get_lineage
   GTDBTaxa.get_taxid_translator
   GTDBTaxa.get_name_translator
   GTDBTaxa.translate_to_names
   GTDBTaxa.get_name_lineage


Getting descendant taxa
-----------------------

Given a taxid or a taxa name from an internal node in the NCBI/GTDB taxonomy tree,
their descendants can be retrieved as follows:

NCBI taxonomy example::

  from ete4 import NCBITaxa
  ncbi = NCBITaxa()

  descendants = ncbi.get_descendant_taxa('Homo')
  print(ncbi.translate_to_names(descendants))

  # ['Homo heidelbergensis', 'Homo sapiens ssp. Denisova',
  # 'Homo sapiens neanderthalensis']

  # You can easily ignore subspecies, so only taxa labeled as "species" will be reported:
  descendants = ncbi.get_descendant_taxa('Homo', collapse_subspecies=True)
  print(ncbi.translate_to_names(descendants))

  # ['Homo sapiens', 'Homo heidelbergensis']

  # or even returned as an annotated tree
  tree = ncbi.get_descendant_taxa('Homo', collapse_subspecies=True, return_tree=True)

  print(tree.to_str(props=['sci_name','taxid']))
  #            ╭╴environmental samples,2665952╶╌╴Homo sapiens environmental sample,2665953
  #            │
  #            ├╴Homo sapiens,9606
  # ╴Homo,9605╶┤
  #            ├╴Homo heidelbergensis,1425170
  #            │
  #            ╰╴unclassified Homo,2813598╶╌╴Homo sp.,2813599

GTDB taxonomy example::

  from ete4 import GTDBTaxa
  gtdb = GTDBTaxa()
  descendants = gtdb.get_descendant_taxa('f__Thorarchaeaceae')
  print(descendants)
  # ['GB_GCA_003662765.1', 'GB_GCA_003662805.1', ..., 'GB_GCA_013138615.1']

  # Ignore subspecies, so only taxa labeled as "species" will be reported.
  descendants = gtdb.get_descendant_taxa('f__Thorarchaeaceae', collapse_subspecies=True)
  print(descendants)
  # ['s__MP8T-1 sp002825535', 's__MP8T-1 sp003345545', ..., 's__TEKIR-12S sp004524435']

  # Returned as an annotated tree.
  descendants = gtdb.get_descendant_taxa('f__Thorarchaeaceae', collapse_subspecies=True, return_tree=True)
  print(descendants.to_str(props=['sci_name','rank']))
  #                                ╭╴s__MP8T-1 sp002825535,species
  #                                │
  #                                ├╴s__MP8T-1 sp003345545,species
  #                                │
  #              ╭╴g__MP8T-1,genus╶┼╴s__MP8T-1 sp002825465,species
  #              │                 │
  #              │                 ├╴s__MP8T-1 sp004524565,species
  #              │                 │
  #              │                 ╰╴s__MP8T-1 sp004524595,species
  #              │
  #              │                   ╭╴s__SMTZ1-83 sp011364985,species
  #              │                   │
  #              ├╴g__SMTZ1-83,genus╶┼╴s__SMTZ1-83 sp011365025,species
  #              │                   │
  #              │                   ╰╴s__SMTZ1-83 sp001563325,species
  #              │
  #              ├╴g__TEKIR-14,genus╶╌╴s__TEKIR-14 sp004524445,species
  #              │
  #              ├╴g__SHMX01,genus╶╌╴s__SHMX01 sp008080745,species
  #              │
  #              │               ╭╴s__OWC5 sp003345595,species
  #              ├╴g__OWC5,genus╶┤
  # ╴f__Tho[...]╶┤               ╰╴s__OWC5 sp003345555,species
  #              │
  #              ├╴g__JACAEL01,genus╶╌╴s__JACAEL01 sp013388835,species
  #              │
  #              ├╴g__B65-G9,genus╶╌╴s__B65-G9 sp003662765,species
  #              │
  #              │                   ╭╴s__SMTZ1-45 sp001563335,species
  #              │                   │
  #              │                   ├╴s__SMTZ1-45 sp011364905,species
  #              │                   │
  #              ├╴g__SMTZ1-45,genus╶┼╴s__SMTZ1-45 sp001940705,species
  #              │                   │
  #              │                   ├╴s__SMTZ1-45 sp004376265,species
  #              │                   │
  #              │                   ╰╴s__SMTZ1-45 sp002825515,species
  #              │
  #              ├╴g__WTCK01,genus╶╌╴s__WTCK01 sp013138615,species
  #              │
  #              ╰╴g__TEKIR-12S,genus╶╌╴s__TEKIR-12S sp004524435,species


Getting species tree topology
-----------------------------

Getting the taxonomy tree for a given set of species is one of the
most useful ways to get all information at once. The methods
:func:`NCBITaxa.get_topology` or :func:`GTDBTaxa.get_topology` allow
to query your local NCBI/GTDB database and extract the smallest tree
that connects all your query taxids. It returns a normal ETE tree in
which all nodes, internal or leaves, are annotated for lineage,
scientific names, ranks, and so on.

NCBI taxonomy example::

  from ete4 import NCBITaxa
  ncbi = NCBITaxa()

  tree = ncbi.get_topology([9606, 9598, 10090, 7707, 8782])

  print(tree.to_str(props=["sci_name", "rank"]))
  #                      ╭╴Dendrochirotida,order
  #                      │
  #                      │                                                                   ╭╴Homo sapiens,species
  # ╴Deuterostomia,clade╶┤                                             ╭╴Homininae,subfamily╶┤
  #                      │               ╭╴Euarchontoglires,superorder╶┤                     ╰╴Pan troglodytes,species
  #                      │               │                             │
  #                      ╰╴Amniota,clade╶┤                             ╰╴Mus musculus,species
  #                                      │
  #                                      ╰╴Aves,class

  # All intermediate nodes connecting the species can also be kept in the tree.
  tree = ncbi.get_topology([2, 33208], intermediate_nodes=True)
  print(tree.to_str(props=["sci_name"]))
  #                     ╭╴Eukaryota╶╌╴Opisthokonta╶╌╴Metazoa
  # ╴cellular organisms╶┤
  #                     ╰╴Bacteria

GTDB taxonomy example::

  from ete4 import GTDBTaxa
  gtdb = GTDBTaxa()

  tree = gtdb.get_topology(["p__Huberarchaeota", "o__Peptococcales", "f__Korarchaeaceae"])
  print(tree.to_str(props=['sci_name', 'rank']))
  #                                         ╭╴p__Huberarchaeota,phylum
  #               ╭╴d__Archaea,superkingdom╶┤
  # ╴root,no rank╶┤                         ╰╴f__Korarchaeaceae,family
  #               │
  #               ╰╴o__Peptococcales,order

  # All intermediate nodes connecting the species can also be kept in the tree.
  tree = gtdb.get_topology(["p__Huberarchaeota", "o__Peptococcales", "f__Korarchaeaceae"], intermediate_nodes=True, collapse_subspecies=True, annotate=True)
  print(tree.to_str(props=['sci_name', 'rank']))
  #                                         ╭╴p__Huberarchaeota,phylum
  #               ╭╴d__Archaea,superkingdom╶┤
  # ╴root,no rank╶┤                         ╰╴p__Thermoproteota,phylum╶╌╴c__Korarchaeia,class╶╌╴o__Korarchaeales,order╶╌╴f__Korarchaeaceae,family
  #               │
  #               ╰╴d__Bacteria,superkingdom╶╌╴p__Firmicutes_B,phylum╶╌╴c__Peptococcia,class╶╌╴o__Peptococcales,order


Automatic tree annotation using NCBI/GTDB taxonomy
--------------------------------------------------

NCBI/GTDB taxonomy annotation consists of adding additional
information to any internal or leaf node in a tree. Only a property
containing the taxid associated to each node is required for the nodes
in the query tree. The annotation process will add the following
features to the nodes:

- sci_name
- taxid
- named_lineage
- lineage
- rank

Note that, for internal nodes, taxid can be automatically inferred
based on their sibling nodes. The easiest way to annotate a tree is to
use a PhyloTree instance where the species name attribute is
transparently used as the taxid attribute. Note that the
:func:`~PhyloTree.annotate_ncbi_taxa` or
:func:`~PhyloTree.annotate_gtdb_taxa` function will also return the
used name, lineage and rank translators.

Remember that species names in PhyloTree instances are automatically
extracted from leaf names. The parsing method can be easily adapted to
any formatting:

NCBI taxonomy example::

  from ete4 import PhyloTree

  # Load the whole leaf name as species taxid.
  tree = PhyloTree('((9606, 9598), 10090);', sp_naming_function=lambda name: name)
  tax2names, tax2lineages, tax2rank = tree.annotate_ncbi_taxa()

  # Split names by '|' and return the first part as the species taxid.
  tree = PhyloTree('((9606|protA, 9598|protA), 10090|protB);', sp_naming_function=lambda name: name.split('|')[0])
  tax2names, tax2lineages, tax2rank = tree.annotate_ncbi_taxa()

  print(tree.to_str(props=["name", "sci_name", "taxid"]))
  #                                                             ╭╴9606|protA,Homo sapiens,9606
  #                                  ╭╴(empty),Homininae,207598╶┤
  # ╴(empty),Euarchontoglires,314146╶┤                          ╰╴9598|protA,Pan troglodytes,9598
  #                                  │
  #                                  ╰╴10090|protB,Mus musculus,10090

GTDB taxonomy example::

  from ete4 import PhyloTree

  # Load the whole leaf name as species taxid.
  newick = '((p__Huberarchaeota,f__Korarchaeaceae)d__Archaea,o__Peptococcales);'

  tree = PhyloTree(newick)
  tax2name, tax2track, tax2rank = gtdb.annotate_tree(tree, taxid_attr="name")

  print(tree.to_str(props=['sci_name', 'rank']))
  #                                         ╭╴p__Huberarchaeota,phylum
  #               ╭╴d__Archaea,superkingdom╶┤
  # ╴root,no rank╶┤                         ╰╴f__Korarchaeaceae,family
  #               │
  #               ╰╴o__Peptococcales,order
