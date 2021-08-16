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
nom_onglet_tailles      <- "Tailles"

# -----------------------------------------------------------------------------
# Codes de produit, d'unité, et de taille attendus
# -----------------------------------------------------------------------------

# produits de consommation
codes_cereales <- c(1:26)
codes_viande <- c(27:39)
codes_poisson <- c(40:51)
codes_laitier <- c(52:60)
codes_huiles <- c(61:70)
codes_fruits <- c(71:87)
codes_legumes <- c(88:108)
codes_legumineuses <- c(109:133)
codes_sucreries <- c(134:138) 
codes_epices <- c(139:154)
codes_boissons <- c(155:165)
codes_produits <- c(codes_cereales, codes_viande, codes_poisson, codes_laitier, codes_huiles, codes_fruits, codes_legumes, codes_legumineuses, codes_sucreries, codes_epices, codes_boissons)

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
# Ingérer l'onglet sur les unités afin d'établir un inventaire exhaustif de codes
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Unités
# -----------------------------------------------------------------------------

# ingérer et vérifer l'onglet sur les unités
nsu_unites_brutes <- readxl::read_excel(
        path = paste0(entree_dir, nom_fichier) , 
        sheet = nom_onglet_unites
    ) %>%
    # prendre les lignes avec des données
    filter(row_number() >= 3)

# prendre les unités dans les 2 premières colonnes
nsu_unites_colonne1 <- select(nsu_unites_brutes, 1, 2) %>%
    rename(
        unite_nom = 1,
        unite_val = 2
    )
    ) %>%
    dplyr::filter(!is.na(unite_nom) & !is.na(unite_val))

# prendre les unités dans les 2 dernières colonnes
nsu_unites_colonne2 <- select(nsu_unites_brutes, 4, 5) %>%
    rename(
        unite_nom = 1,
        unite_val = 2
    ) %>%
    dplyr::filter(!is.na(unite_nom) & !is.na(unite_val))

# mettre ensemble
nsu_unites_df <- rbind(nsu_unites_colonne1, nsu_unites_colonne2)

# créer un vecteur avec des noms
# utile à la fois pour trier les bases et appliquer les étiquettes de valeur
nsu_unites <- setNames(
    nm = nsu_unites_df$unite_nom, 
    object = as.integer(nsu_unites_df$unite_val)
)

# -----------------------------------------------------------------------------
# Tailles
# -----------------------------------------------------------------------------

# ingérer et vérifer l'onglet sur les unités
nsu_tailles_df <- readxl::read_excel(
        path = paste0(entree_dir, nom_fichier) , 
        sheet = nom_onglet_tailles
    ) %>%
    # sélectionner les colonnes avec données
    select(1, 2) %>%
    # modifier le nom des colonnes
    rename(
        taille_nom = 1,
        taille_val = 2
    )

# créer un vecteur avec des noms
# utile à la fois pour trier les bases et appliquer les étiquettes de valeur
nsu_tailles <- setNames(
    nm = nsu_tailles_df$taille_nom, 
    object = as.integer(nsu_tailles_df$taille_val)
)

# -----------------------------------------------------------------------------
# Ingérer les produits de consommation
# -----------------------------------------------------------------------------

# ingérer et vérifier l'onglet sur la consommation alimentaire
nsu_consommation_df <- readxl::read_excel(
        path = paste0(entree_dir, nom_fichier) , 
        sheet = nom_onglet_consommation
    ) %>%
    # retenir les lignes avec des données
    filter(row_number() >= 5) %>%
    # renommer les colonnes pertinentes
    rename(
        nom_produit = 1,
        produit = 2,
        unite = 4,
        taille = 7
    ) %>%
    # retenir les lignes avec un contenu non-vide
    filter(!(is.na(produit) & is.na(unite) & is.na(taille)))

# confirmer qu'il existe 13 colonnes
nsu_consommation_ncol <- ncol(nsu_consommation_df)
assert_that(
    nsu_consommation_ncol == 13,
    msg = glue::glue("//
        L'onglet {nom_onglet_consommation} devrait avoir 13 colonnes, \\
        mais l'on en a détecté {nsu_consommation_ncol}
    ")
)

# créer des étiquettes de produit à partir du nom et du code des produits
produits_distincts <- distinct(nsu_consommation_df, nom_produit, produit)
nsu_produits <- setNames(
    nm = produits_distincts$nom_produit,
    object = as.integer(produits_distincts$produit)
)

# préparer la base pour la suite
nsu_consommation <- nsu_consommation_df %>%
    # retenir ces colonnes pertinentes
    select(produit, unite, taille) %>%
    # les convertir en numéros
    mutate(
        across(
            .cols = c(produit, unite, taille),
            .fns = as.numeric
        ), 
        produit = haven::labelled(produit, labels = nsu_produits),
        unite = haven::labelled(unite, labels = nsu_unites),
        taille = haven::labelled(taille, labels = nsu_tailles),
        groupe = case_when(
            produit %in% codes_cereales ~ "cereales",
            produit %in% codes_viande ~ "viande",
            produit %in% codes_poisson ~ "poisson",
            produit %in% codes_laitier ~ "laitier",
            produit %in% codes_huiles ~ "huiles",
            produit %in% codes_fruits ~ "fruits",
            produit %in% codes_legumes ~ "legumes",
            produit %in% codes_legumes ~ "legumes",
            produit %in% codes_legumineuses ~ "legumineuses",
            produit %in% codes_sucreries ~ "sucreries",
            produit %in% codes_epices ~ "epices",
            produit %in% codes_boissons ~ "boissons"
        )        
    )

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Vérifier le contenu des colonnes; avertir en cas de problème
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# créer un agent de vérification et intéroger la base
agent_conso <- pointblank::create_agent(
        tbl = nsu_consommation,
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
    pointblank::col_vals_in_set(
        label = "Toutes les tailles ont un code valide",
        step = 3,
        columns = vars(taille),
        set = nsu_tailles
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

    # Toutes les tailles ont un code valide
    if (3 %in% which_steps_failed) {

        fails_step3 <- get_data_extracts(agent = agent_conso, i = 3)
        print(fails_step3)
        assert_that(
            1 == 0,
            msg = glue::glue(
                "Certaines tailles n'ont pas de codes valide. 
                Veuillez saisir `View(fails_step3)` pour visualiser les codes de produit problématiques
                La colonne `produit` correspond à la colonne `B` chez Excel, la colonne `unite` à la colonne `D`, `taille` à `G`."
            )
        )

    }

}

# =============================================================================
# Sauvegarder les bases sous format tab
# =============================================================================

# -----------------------------------------------------------------------------
# Produits de consommation
# -----------------------------------------------------------------------------

#' Sauvegarder un tableau de référence pour une groupe de produits
#' 
#' @param df
#' @param produit_codes Caractère. Nom du vecteur qui contient les codes du groupe de produits
#' @param dir Caractère. Répertoire où sauvegarder le tableau de référence.
#' @param file_name Caractère. Nom du fichier pour le tableau de référence. Inclure l'extension.
#' 
#' @return Effet secondaire: sauvegarder un fichier sur disque
#' 
#' @importFrom dplyr `%>%` filter mutate row_number rename
#' @importFrom readr write_tsv
sauvegarder_tableau <- function(
    df = nsu_consommation,
    produit_codes,
    dir,
    file_name
) {

    # trier la base et sélectionner les produits du groupe
    df <- df %>%
        dplyr::filter(produit %in% get(x = produit_codes, envir = .GlobalEnv)) %>%
        # !!rlang::sym(produit_codes)
        dplyr::mutate(rowcode = dplyr::row_number()) %>%
        dplyr::rename(
            produitCode = produit,
            uniteCode = unite,
            tailleCode = taille
        ) %>%
        select(produitCode, uniteCode, tailleCode, groupe, rowcode)

    # compter les lignes du fichier
    n_obs <- nrow(df)

    # si aucune, avertir par message
    if (n_obs == 0) {
        message(glue::glue("Aucun produit. Fichier {file_name} n'a pas été sauvegardé"))
    # si au moins une, sauvegarder sous format tab
    } else if (n_obs > 0) {
        readr::write_tsv(df, file = paste0(dir, file_name))
    }

}

# sauvegarder un fichier par groupe
nom_produits <- c("codes_cereales", "codes_viande", "codes_poisson", "codes_laitier", "codes_huiles", "codes_fruits", "codes_legumes", "codes_legumineuses", "codes_sucreries", "codes_epices", "codes_boissons")

purrr::walk(
    .x = nom_produits,
    .f = ~ sauvegarder_tableau(produit_codes = .x, dir = sortie_dir, file_name = paste0(.x, ".tab"))
)

# =============================================================================
# Créer un document HTML qui capte les unités et tailles pour chaque produit
# =============================================================================

rmarkdown::render(
    input = paste0(proj_dir, "nsu_codes_appli_conso.Rmd"),
    output_dir = sortie_dir,
    output_file = "nsu_codes_appli_conso.html",
    encoding = "UTF-8"
)
