import 'package:flutter/material.dart';

class L10n {
  static const Map<String, Map<String, String>> _localizedValues = {
    'fr': {
      // Home Screen
      'dashboard': 'Tableau de bord',
      'welcome': 'Bonjour,',
      'chef_fallback': 'Chef',
      'kitchen_status': 'Voici ce qui se passe dans votre cuisine.',
      'recent': 'Récemment utilisés',
      'active_group_label': 'Groupe actif',
      'quick_access': 'Accès rapide',
      'recipes': 'Recettes familiales',
      'invitations': 'Invitations',

      // Status Banner
      'status_online': 'Serveur Connecté',
      'status_offline': 'Mode Local',
      'sync_info': 'Synchronisation avec gab-server',
      'sync_disabled': 'Sync désactivée - Aucun compte',
      'no_account': 'Veuillez lier un compte pour voir les invitations',

      // Main Layout / Drawer
      'create_group': 'Créer un nouveau groupe',
      'received_invites': 'Invitations reçues',
      'force_sync': 'Forcer la synchro',
      'settings': 'Paramètres',
      'active_group_heading': 'Groupe Actif',
      'select_group_hint': 'Sélectionner un groupe',

      // Dialogs
      'cancel': 'Annuler',
      'create': 'Créer',
      'group_name_hint': 'Nom du groupe (ex: Camping)',
      'share_group_toggle': 'Partager ce groupe',
      'share_group_subtitle': 'Synchronise avec le serveur pour tous',

      'setup_title': 'Bienvenue sur Grocery Master',
      'sync_title': 'Synchroniser votre compte',
      'setup_subtitle': 'Entrez vos informations pour commencer à partager.',
      'sync_subtitle': 'Entrez le code de synchro de votre autre appareil.',
      'first_name': 'Prénom',
      'last_name': 'Nom',
      'email_address': 'Adresse Courriel',
      'sync_code': 'Code de Synchro',
      'sync_hint': 'Coller le code ici',
      'get_started': 'Commencer',
      'sync_now': 'Synchroniser',
      'already_account': 'Déjà un compte ? Synchro ici',
      'back_to_reg': 'Retour à l\'inscription',
      'sync_error': 'Code invalide ou erreur de connexion',

      'profile_header': 'Profil Utilisateur',
      'save_profile': 'Enregistrer les modifications',
      'profile_updated': 'Profil mis à jour avec succès !',
      'update_failed': 'Échec de la mise à jour',
      'email_conflict': 'Ce courriel est déjà lié à un autre compte.',
      'update_error': 'Impossible de mettre à jour. Vérifiez votre connexion.',
      'sync_header': 'Synchronisation d\'appareil',
      'your_sync_code': 'Votre code de synchro',
      'copy_clipboard': 'Code copié dans le presse-papiers',
      'sync_description': 'Utilisez ce code sur un autre appareil pour accéder à vos recettes et listes.',
      'connect_existing': 'Se connecter à un compte existant',
      'sync_phone_subtitle': 'Synchroniser ce téléphone avec un autre appareil',
      'appearance_header': 'Apparence',
      'theme_mode': 'Mode de thème',
      'follow_system': 'Système',
      'light_mode': 'Mode clair',
      'dark_mode': 'Mode sombre',
      'primary_color': 'Couleur thématique principale',
      'danger_zone': 'Zone de danger',
      'factory_reset': 'Réinitialisation d\'usine',
      'reset_subtitle': 'Effacer toutes les données locales et préférences',
      'reset_confirm_title': 'Réinitialiser l\'application ?',
      'reset_confirm_body': 'Cela supprimera définitivement toutes les recettes, listes et paramètres locaux. Cette action est irréversible.',
      'wipe_all': 'Tout effacer',

      'items_title': 'Articles',
      'add_to_list': 'Ajouter à la liste',
      'item_hint': 'ex: Lait',
      'add': 'Ajouter',
      'no_items': 'Aucun article trouvé.',
      'item_discarded': 'Article écarté',
      'mark_pending': 'Marquer en attente',
      'discard': 'Écarter',
      'delete': 'Supprimer',
      'error_no_list': 'Aucune liste sélectionnée.',

      'my_lists': 'Mes Listes',
      'new_list_title': 'Nouvelle liste de courses',
      'list_hint': 'ex: Courses hebdo, BBQ Party',
      'no_lists_found': 'Aucune liste trouvée pour ce groupe.',
      'create_first_list': 'Créer votre première liste',
      'created_on': 'Créée le',
      'add_list_tooltip': 'Ajouter une liste',

      'archived_lists': 'Listes archivées',
      'no_archived_trips': 'Aucun voyage archivé pour le moment.',
      'completed_on': 'Terminée le',
      'at_time': 'à',

      'notif_channel_name': 'Mises à jour des courses',
      'notif_channel_desc': 'Notifications pour les changements dans les listes de courses',

      'language_label': 'Langue de l\'application',
      'lang_fr': 'Français',
      'lang_en': 'English',

      'add_note': 'Ajouter une note',
      'note_hint': 'Note (ex: Prendre la marque maison)',
      'take_photo': 'Prendre une photo',
      'select_photo': 'Choisir une photo',
      'item_details': 'Détails de l\'article',
      'details': 'Details',

      "groceries": "Épicerie",
      "finish_shopping_title": "Terminer les courses?",
      "carry_over_warning": "Les articles restants iront dans une nouvelle liste et celle-ci sera archivée.",
      "new_list_name_hint": "Nom de la nouvelle liste",
      "archive_and_carry": "Archiver et Continuer",

      "delete_group_title": "Supprimer le groupe",
      "delete_group_warning": "Êtes-vous sûr ? Cela supprimera toutes les listes de ce groupe.",
      "delete_group_tooltip": "Supprimer ce groupe",
      "unauthorized_delete": "Vous n'êtes pas le propriétaire de ce groupe.",

      "delete_list_title": "Supprimer la liste",
      "delete_list_warning": "Êtes-vous sûr de vouloir supprimer cette liste ? Cette action est irréversible.",
      "unauthorized_list_delete": "Vous n'avez pas l'autorisation de supprimer cette liste."
    },
    'en': {
      // Home Screen
      'dashboard': 'Dashboard',
      'welcome': 'Hello,',
      'chef_fallback': 'Chef',
      'kitchen_status': "Here's what's happening in your kitchen.",
      'recent': 'Recently Used',
      'active_group_label': 'Active Group',
      'quick_access': 'Quick Access',
      'recipes': 'Family Recipes',
      'invitations': 'Invitations',

      // Status Banner
      'status_online': 'Server Connected',
      'status_offline': 'Local Mode',
      'sync_info': 'Syncing to gab-server',
      'sync_disabled': 'Sync disabled - No account',
      'no_account': 'Please link an account to see invitations',

      // Main Layout / Drawer
      'create_group': 'Create New Group',
      'received_invites': 'Received Invitations',
      'force_sync': 'Force Sync',
      'settings': 'Settings',
      'active_group_heading': 'Active Group',
      'select_group_hint': 'Select Group',

      // Dialogs
      'cancel': 'Cancel',
      'create': 'Create',
      'group_name_hint': 'Group Name (e.g., Camping Trip)',
      'share_group_toggle': 'Share this group',
      'share_group_subtitle': 'Syncs with the server for everyone',

      'setup_title': 'Welcome to Grocery Master',
      'sync_title': 'Sync Your Account',
      'setup_subtitle': 'Enter your details to start sharing lists.',
      'sync_subtitle': 'Enter the Sync Code from your other device.',
      'first_name': 'First Name',
      'last_name': 'Last Name',
      'email_address': 'Email Address',
      'sync_code': 'Sync Code',
      'sync_hint': 'Paste code here',
      'get_started': 'Get Started',
      'sync_now': 'Sync Now',
      'already_account': 'Already have an account? Sync here',
      'back_to_reg': 'Back to Registration',
      'sync_error': 'Invalid Sync Code or Connection Error',

      'profile_header': 'User Profile',
      'save_profile': 'Save Profile Changes',
      'profile_updated': 'Profile Updated Successfully!',
      'update_failed': 'Update Failed',
      'email_conflict': 'This email is already linked to another account.',
      'update_error': 'Could not update profile. Check your connection.',
      'sync_header': 'Device Sync',
      'your_sync_code': 'Your Sync Code',
      'copy_clipboard': 'Code copied to clipboard',
      'sync_description': 'Use this code on another device to access your recipes and lists.',
      'connect_existing': 'Connect to Existing Account',
      'sync_phone_subtitle': 'Sync this phone to another device',
      'appearance_header': 'Appearance',
      'theme_mode': 'Theme Mode',
      'follow_system': 'Follow System',
      'light_mode': 'Light Mode',
      'dark_mode': 'Dark Mode',
      'primary_color': 'Primary Color Theme',
      'danger_zone': 'Danger Zone',
      'factory_reset': 'Factory Reset',
      'reset_subtitle': 'Wipe all local data and preferences',
      'reset_confirm_title': 'Reset App?',
      'reset_confirm_body': 'This will permanently delete all local recipes, lists, and settings. This cannot be undone.',
      'wipe_all': 'Wipe Everything',

      'items_title': 'Items',
      'add_to_list': 'Add to List',
      'item_hint': 'e.g., Milk',
      'add': 'Add',
      'no_items': 'No items found.',
      'item_discarded': 'Item discarded',
      'mark_pending': 'Mark Pending',
      'discard': 'Discard',
      'delete': 'Delete',
      'error_no_list': 'No list selected.',

      'my_lists': 'My Lists',
      'new_list_title': 'New Grocery List',
      'list_hint': 'e.g., Weekly Groceries, BBQ Party',
      'no_lists_found': 'No lists found for this group.',
      'create_first_list': 'Create your first list',
      'created_on': 'Created on',
      'add_list_tooltip': 'Add New List',

      'archived_lists': 'Archived Lists',
      'no_archived_trips': 'No archived trips yet.',
      'completed_on': 'Completed on',
      'at_time': 'at',

      'notif_channel_name': 'Grocery Updates',
      'notif_channel_desc': 'Notifications for grocery list changes',

      'language_label': 'App Language',
      'lang_fr': 'Français',
      'lang_en': 'English',

      'add_note': 'Add a note',
      'note_hint': 'Note (e.g., Get the store brand)',
      'take_photo': 'Take a photo',
      'select_photo': 'Select photo',
      'item_details': 'Item Details',
      'details': 'Details',

      "groceries": "Groceries",
      "finish_shopping_title": "Finish Weekly Shopping?",
      "carry_over_warning": "Pending items will move to a new list and this one will be archived.",
      "new_list_name_hint": "New List Name",
      "archive_and_carry": "Archive & Carry Over",

      "delete_group_title": "Delete Group",
      "delete_group_warning": "Are you sure? This will delete all lists in this group.",
      "delete_group_tooltip": "Delete this group",
      "unauthorized_delete": "You are not the owner of this group.",

      "delete_list_title": "Delete List",
      "delete_list_warning": "Are you sure you want to delete this list? This action cannot be undone.",
      "unauthorized_list_delete": "You do not have permission to delete this list."
    },
  };

  /// Returns the localized string for the given [key].
  /// Defaults to French ('fr') if the system language is not supported.
  static String of(BuildContext context, String key) {
    String languageCode = Localizations.localeOf(context).languageCode;

    // Default to 'fr' if language is not supported
    if (!_localizedValues.containsKey(languageCode)) {
      languageCode = 'fr';
    }

    return _localizedValues[languageCode]![key] ?? key;
  }
}