# =============================================================================
# Spécifier les paramètres du projet
# =============================================================================

# -----------------------------------------------------------------------------
# Répertories, fichiers, et onglets
# -----------------------------------------------------------------------------

proj_dir <- "C:/votre/chemin/"
entree_dir <- paste0(proj_dir, "entree/")
sortie_dir <- paste0(proj_dir, "sortie/")
nom_fichier <- "Qx_NSU_UEMOA_EHCVM2.xlsx"
nom_onglet_consommation <- "S1_Releves_Consommation"
nom_onglet_production   <- "S2_Releves_Production"
nom_onglet_unites       <- "Unités"

# -----------------------------------------------------------------------------
# Codes de produit, d'unité, et de taille attendus
# -----------------------------------------------------------------------------

# produits agricoles
codes_produits_ag <- c(1:55)
codes_unites_ag <- c(1:10) # TODO: Identifier l'univers de codes

# =============================================================================
# Charger les packages requis
# =============================================================================

# packages needed for this program 
packagesNeeded <- c(
    "readxl", 	    # transformer les fichiers Excel en data frame
    "assertthat",   # confronter les données aux attentes
    "pointblank",   # valider les bases et faire resortir les observations problématiques
    "glue",         # concevoir des messages d'erreur avec plus de facilité
    "gluedown",     # créer Markdown depuis {glue}
	"dplyr",	    # manipuler les données
    "haven",        # appliquer des étiquettes de valeur aux variables
    "rlang",        # evaluation non-standard
    "readr"         # sauvegarder sous format délimité par tab
)

# identify and install those packages that are not already installed
packagesToInstall <- packagesNeeded[!(packagesNeeded %in% installed.packages()[,"Package"])]
if(length(packagesToInstall)) 
	install.packages(packagesToInstall, quiet = TRUE, 
		repos = 'https://cloud.r-project.org/', dep = TRUE)

# load all needed packages
lapply(packagesNeeded, library, character.only = TRUE)

# =============================================================================
# Confirmer les inputs
# =============================================================================

# `proj_dir` existe
assertthat::assert_that(
    dir.exists(proj_dir),
    msg = glue::glue(
        "Le répertoire du projet n'existe pas.",
        "Répertoire indiqué dans `proj_dir`: {proj_dir}",
        "Veuillez composer un répertoire.", 
        .sep = "\n"
    ) 
)

# créer les répertoires s'ils n'existent pas
# entree
if (!dir.exists(entree_dir)) {
    dir.create(entree_dir)
}

# sortie
if (!dir.exists(sortie_dir)) {
    dir.create(sortie_dir)
}

# `nom_fichier` existe dans `proj_dir`
assertthat::assert_that(
    file.exists(paste0(entree_dir, nom_fichier)),
    msg = glue::glue(
        "Le questionnaire dans `nom_fichier` n'existe pas dans le répertoire `proj_dir`.",
        "Répertoire: {proj_dir}",
        "Fichier indiqué: {nom_fichier}",
        .sep = "\n"
    )
)

# fichier `nom_fichier` n'est pas un fichier Excel
assertthat::assert_that(
    readxl::excel_format(path = paste0(entree_dir, nom_fichier)) %in% c("xlsx", "xls"),
    msg = glue::glue(
        "Le fichier désigné comme questionnaire n'est pas un fichier Excel",
        "Veuillez saisir un fichier Excel dans `nom_fichier`",
        .sep = "\n"
    )
)

# =============================================================================
# Ingérer et préparer les info de différents onglets
# =============================================================================

# -----------------------------------------------------------------------------
# Vérifier les onglets avant de tenter d'ingérer des données
# -----------------------------------------------------------------------------

# confirmer que le fichier Excel contient les onglets attendus
onglets_attendus <- c(nom_onglet_consommation, nom_onglet_production, nom_onglet_unites)
onglets_retrouves <- readxl::excel_sheets(path = paste0(entree_dir, nom_fichier))
assert_that(
    all(onglets_attendus %in% onglets_retrouves), 
    msg = glue::glue("\\
        Le fichier {nom_fichier} ne contient pas les onglets nécessaires
        Onglets attendus: {paste(onglets_attendus, collapse = ', ')}
        Onglets retrouvés: {paste(onglets_retrouves, collapse = ', ')}")
)

# -----------------------------------------------------------------------------
# Ingérer les produits de production
# -----------------------------------------------------------------------------

# ingérer et vérifier l'onglet sur la consommation alimentaire
nsu_production_df <- readxl::read_excel(
        path = paste0(entree_dir, nom_fichier) , 
        sheet = nom_onglet_production
    ) %>%
    # retenir les lignes avec des données
    filter(row_number() >= 6) %>%
    # renommer les colonnes pertinentes
    rename(
        nom_produit = 1,
        produit = 2,
        nom_unite = 3,
        unite = 4
    ) %>%
    # retenir les lignes avec un contenu non-vide
    filter(!(is.na(produit) & is.na(unite)))

# confirmer qu'il existe 13 colonnes
nsu_consommation_ncol <- ncol(nsu_consommation_df)
assert_that(
    nsu_consommation_ncol == 13,
    msg = glue::glue("//
        L'onglet {nom_onglet_consommation} devrait avoir 13 colonnes, \\
        mais l'on en a détecté {nsu_consommation_ncol}
    ")
)

# créer des étiquettes de produit à partir du nom et du code
# ... des produits
produits_distincts <- distinct(nsu_production_df, nom_produit, produit)
nsu_produits <- setNames(
    nm = produits_distincts$nom_produit,
    object = as.integer(produits_distincts$produit)
)
# ... des unités
unites_distinctes <- distinct(nsu_production_df, nom_unite, unite)
nsu_unites <- setNames(
    nm = unites_distinctes$nom_unite,
    object = as.integer(unites_distinctes$unite)
)
nsu_unites <- nsu_unites[which(!is.na(nsu_unites))]

# préparer la base pour la suite
nsu_production <- nsu_production_df %>%
    # retenir ces colonnes pertinentes
    select(produit, unite) %>%
    # les convertir en numéros
    mutate(
        across(
            .cols = c(produit, unite),
            .fns = as.numeric
        ), 
        produit = haven::labelled(produit, labels = nsu_produits),
        unite = haven::labelled(unite, labels = nsu_unites)      
    )

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Vérifier le contenu des colonnes; avertir en cas de problème
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# créer un agent de vérification et intéroger la base
agent_conso <- pointblank::create_agent(
        tbl = nsu_production,
        label = "Vérifier le contenu du questionnaire Excel",
        actions = pointblank::action_levels(stop_at = 1)
    ) %>%
    pointblank::col_vals_in_set(
        label = "Tous les produits ont un code valide", 
        step_id = 1, 
        columns = vars(produit), 
        set = codes_produits
    ) %>%
    pointblank::col_vals_in_set(
        label = "Toutes les unités ont un code valide",
        step = 2,
        columns = vars(unite),
        set = nsu_unites
    ) %>%
    pointblank::interrogate()


# émettre des erreurs si des problèmes ont été repérés
if(pointblank::all_passed(agent = agent_conso) == FALSE) {

    # get agent's x-list
    nsu_conso_xlist <- pointblank::get_agent_x_list(agent = agent_conso)
    
    # determine which didn't pass
    which_steps_failed <- which(nsu_conso_xlist$n_failed > 0)

    # Tous les produits ont un code valide
    if (1 %in% which_steps_failed) {

        fails_step1 <- get_data_extracts(agent = agent_conso, i = 1)
        print(fails_step1)
        assert_that(
            1 == 0,
            msg = glue::glue(
                "Certains produits n'ont pas de codes valide.
                Veuillez saisir `View(fails_step1)` pour visualiser les codes de produit problématiques
                La colonne `produit` correspond à la colonne `B` chez Excel, la colonne `unite` à la colonne `D`, `taille` à `G`."
            )
        )

    }

    # Toutes les unités ont un code valide
    if (2 %in% which_steps_failed) {

        fails_step2 <- get_data_extracts(agent = agent_conso, i = 2)
        print(fails_step2)
        assert_that(
            1 == 0,
            msg = glue::glue(
                "Certaines unités n'ont pas de codes valide.
                Veuillez saisir `View(fails_step2)` pour visualiser les codes d'unité problématiques
                La colonne `produit` correspond à la colonne `B` chez Excel, la colonne `unite` à la colonne `D`, `taille` à `G`."
            )
        )

    }

}

# =============================================================================
# Créer un document HTML qui capte les unités et tailles pour chaque produit
# =============================================================================

rmarkdown::render(
    input = paste0(proj_dir, "nsu_codes_appli_prod.Rmd"),
    output_dir = sortie_dir,
    output_file = "nsu_codes_appli_prod.html",
    encoding = "UTF-8"
)
