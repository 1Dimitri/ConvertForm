﻿ConvertFrom-StringData @'
 FileSystemPathRequired=Le chemin doit pointer sur le FileSystem : {0}
 FileSystemPathRequiredForCurrentLocation=L'usage de chemin relatif, nécessite que le chemin courant pointe sur le système de fichier : {0}
 GlobbingUnsupported=Le globbing n'est pas supporté pour ce paramètre : {0} 
 ParameterMustBeAfile=Le paramètre doit être un nom de fichier : {0}
 DriveNotFound=Le lecteur indiqué n'existe pas : '{0}'  
 ItemNotFound=Le fichier n'existe pas : '{0}'
 PathNotFound=Le répertoire n'existe pas : '{0}'  
 
 BeginAnalyze=Démarrage de l'analyse du fichier '{0}'
 ComponentRequireSTA=Le composant suivant ou une de ces fonctionnalités, requiert le modèle de thread STA (Single Thread Apartment)). Réessayez avec le paramètre -STA.
 InitializeComponentNotFound=La méthode InitializeComponent() est introuvable dans le fichier {0}. La conversion ne peut s'effectuer.
 
 DesignerNameNotFound=Vérifiez que le nom du fichier source est bien celui généré par le designer de Visual Studio.
 FormNameNotFound=Le nom de la Form est introuvable dans la méthode InitializeComponent() du fichier '{0}'. La conversion ne peut s'effectuer.{1}  
 TransformationProgress=Transformation du code source ({0}) lignes
 TransformationProgressStatus=Veuillez patienter
 ReadChoiceCaption=Le fichier de destination existe déjà : '{0}'
 ReadChoiceMessage=Voulez-vous le remplacer ?
 OperationCancelled=Opération abandonnée.
 
 GenerateScript=Génération du script '{0}'
 SyntaxVerification=Vérification de la syntaxe du script généré.
 SyntaxError=La syntaxe du script généré contient des erreurs. Pour obtenir le détail des erreurs, exécutez : Test-PSScript '{0}' 
 
 ConversionComplete=Conversion terminée : '{0}' 
 
 ParameterHideConsoleNotNecessary=Si vous convertissez une form secondaire l'usage du switch -HideConsole n'est pas nécessaire. Si c'est le cas, réexécutez votre appel sans préciser ce switch. 
 ParameterStringEmpty=Le paramètre '{0}' ne peut être une chaîne vide.
 ThisParameterRequiresThisParameter=Le paramètre '{0}' nécessite de déclarer le paramètre '{1}'.
 AddSTARequirement=Ajout du contrôle du modéle de thread STA. Raison : {0}

 LoadingAssemblies=# Chargement des assemblies externes
 DisposeResources=# Libération des ressources
 DisposeForm=# Libération de la Form 
'@ 

