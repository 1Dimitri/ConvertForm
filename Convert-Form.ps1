##########################################################################
#                               Add-Lib
#                      PowerShell Form Converter
#
# Version : 1.2.1
#
# R�vision : $Rev: 180 $
#
# Date    : 1 ao�t 2010
#
# Nom     : Convert-Form.ps1
#
# Usage   : Voir documentation : .\Convert-Form.ps1
#
# Objet   : Conversion d'un formulaire graphique C# (WinForm) cr�� � partir 
#           de Visual C# 2005/2008 (Express Edition ou sup�rieure) en un script PowerShell.
#
# D�apr�s une id�e originale de Jean-Louis, Robin Lemesle et Arnaud Petitjean.
# La version d�origine a �t� publi�e sur le site PowerShell-Scripting.com.
##########################################################################


Param([string] $Source, 
      [string] $Destination, 
      [switch] $AddInitialize,
      [switch] $DontLoad,
      [switch] $DontShow, 
      [switch] $Force, 
      [switch] $HideConsole,
      [switch] $InvokeInRunspace,
      [switch] $PassThru, 
      [switch] $STA)

#-------------------- Contr�les divers ----------------------------------------------------------------------
Function Get-Usage {
@"
  NAME
    Convert-Form
    
  SYNOPSIS
    Converti un fichier xxx.Designer.cs en un script PowerShell.

  SYNTAX
    Convert-Form.ps1 -Source Form1.Designer.cs -Destination Form1.ps1 [-DontShow] [-DontLoad] [-Force]	

  DETAILED DESCRIPTION
    Ce script permet de convertir un fichier Csharp contenant les d�clarations d'une WinForm en un script PowerShell. 
    La construction d'une fen�tre dans Visual Studio g�n�re un fichier nomm� NomDuFichier.Designer.cs.
    C'est ce fichier qui constitue la source de ce script, on en extrait les lignes de d�claration des composants ins�r�s 
    sur la fen�tre de votre projet Winform. Si votre projet contient plusieurs Forms, vous devrez ex�cuter ce script 
    pour chacune d'entre elles.
    
    Si dans Visual Studio vous d�clarez des �v�nements sp�cifiques pour chaque composant, ce script construira une fonction
    pour chacun de ces �v�nements. Le code Csharp contenu dans le corps de la m�thode n'est pas converti.  
    
    L'usage de certains composants graphique n�cessite le mod�le de thread STA, celui-ci ne peut �tre modifi� qu'� l'aide 
    du cmdlet Invoke-Apartment, disponible dans la distribution de ce script ou avec le projet PSCX 1.2 et sup�rieure.
    
    Il est possible d'ex�cuter une fen�tre au sein d'un runspace. Pour plus de d�tails consultez le tutoriel 
    "La notion de runspace sous PowerShell version 1" disponible le site http://laurent-dardenne.developpez.com/

  SYSTEM REQUIREMENTS
    Scripts :
            PackageConvert-Form.ps1
            PackageScripts.ps1
            APIWindows.ps1   (-HideConsole)
            New-Runspace.ps1 (-InvokeInRunspace)  
                PackageWinform.ps1 (optionnel)
    Programme 
            Resgen.exe (SDK .NET)
            PSInvokeApartment.dll (-STA) (cmdlet Invoke-Apartment n�cessaire pour PowerShell  V1)
            Visual-Studio Express ou sup�rieure (optionnel) 
    
  PARAMETERS
    -Source <String>
      Nom du fichier C# � convertir.
      Ne supporte pas le globbing (*, ?, [abc], etc)
	    Le chemin peut �tre relatif au drive courant.
	    
      Required?         True
      Position?         1
      Default value     <required>
      Accept pipeline?  False
      Accept wildcards? False

    -Destination <String>
      Nom du fichier g�n�r�. On cr�e un nouveau fichier contenant un script PowerShell.
      Ne supporte pas le globbing (*, ?, [abc], etc).
      Le chemin peut �tre relatif au drive courant. 
      Si ce param�tre n'est pas pr�cis� on construit le nom du fichier g�n�r� de la fa�on suivante :
       ($Source.FullPathName)\($Source.FileName).ps1

      Required?         False
      Position?          2
      Default value     SourcePath\SourceNameWithoutExtension.ps1
      Accept pipeline?  False
      Accept wildcards? False
			
    -AddInitialize <switch>
      Ins�re l'appel pr�alable au script APIWindows.ps1 contenant les fonctions Hide-PSWindow et Show-PsWindow.     
      ATTENTION si vous ne pr�cisez pas ce switch, mais pr�cisez le switch -HideConsole, vous devrez au pr�alable 
      charger en dot source le fichier APIWindows.ps1
        . .\APIWindows.ps1; .\MaForm.ps1
      Le switch -HideConsole doit �tre �galement pr�cis� pour activer cette insertion. 

      Required?         False
      Position?         named
      Default value     False
      Accept pipeline?  False
      Accept wildcards? False			

    -DontLoad <switch>
      Sp�cifie de ne pas ins�rer, dans le fichier g�n�r�, les appels aux assemblies Winform, etc.

      C'est par exemple le cas d'une fen�tre secondaire n'utilisant pas d'assemblies sp�cifique (cas le plus probable)
      Dans ce cas l�usage du param�tre �DontShow est recommand� car c�est vous qui d�ciderez quand afficher ces 
      fen�tres secondaires. Vous devrez donc modifier le script d'appel de la fen�tre principale afin qu�il prenne 
      en charge la cr�ation, l'affichage et la destruction des fen�tres secondaires.

      Required?         False
      Position?         named
      Default value     False
      Accept pipeline?  False
      Accept wildcards? False			

    -DontShow <switch>
      Indique de ne pas ins�rer � la fin du script PS1 g�n�r� l'appel � la m�thode ShowDialog().
      Dans ce cas on n'ins�re pas d'appel � `$Form.Dispose(), ni � Show-PSWindow.
      cf. -HideConsole 

      Required?         False
      Position?         named
      Default value     False
      Accept pipeline?  False
      Accept wildcards? False			

    -Force <switch>
      Si le fichier Destination existe il est �cras� sans demande de confirmation. 
      
      Par d�faut si vous r�pondez "Oui" � la question : 
       "Le fichier de destination existe d�j�, voulez-vous le remplacer ?" 
      le fichier existant est �cras�.
      Si vous r�pondez "Non" le script s'arr�te sur un avertissement, le fichier destination 
      n'est pas modifi�.
      
      Dans tous les cas si le fichier est prot�g� en �criture ou verrouill� par un 
      autre programme l'op�ration �choue.

     Note: 
      Apr�s avoir mis � jour votre projet Winform dans Visual Studio, ce qui est souvent le cas, car on ne cr�e pas 
      une interface graphique en une seule op�ration, et qu'en suite vous convertissez
      la nouvelle version du fichier Designer.cs, veillez � ne pas pr�ciser ce switch.
      Ainsi vous n'�craserez pas le script existant que vous avez modifi� ou alors pr�cisez un nom de fichier diff�rent.
      Pour reporter les modifications du nouveau script dans l'ancien script, l'outil Winmerge vous facilitera la t�che.  

      Required?         False
      Position?         named
      Default value     False
      Accept pipeline?  False
      Accept wildcards? False			

    -HideConsole <switch>
      Sp�cifie l'insertion des appels � Hide-PSWindow dans le code du gestionnaire d'�v�nement `$Form1.Add_Shown,
      et l'appel � Show-PSWindow apr�s l'appel � `$Form1.Dispose().
      Ainsi au d�marrage de la form on cache la console et on la r�affiche une fois la forme close.

      Required?         False
      Position?         named
      Default value     False
      Accept pipeline?  False
      Accept wildcards? False			

    -InvokeInRunspace <switch>
      Indique l'insertion d'un code de cr�ation et d'initialisation d'un runspace, dans lequel on ex�cute l'appel � 
      ShowDialog de la form d�clar�e dans le fichier g�n�r�.  
      
      Exemple de code g�n�r� :
         $RSShowDialog=New-RunSpace {$Form1.ShowDialog()} $configurationRS
        
      Required?         False
      Position?         named
      Default value     False
      Accept pipeline?  False
      Accept wildcards? False
      
    -passThru <switch>
      Passe l'objet fichier r�cemment cr�� par ce script le long du pipeline. 
      Par d�faut, ce script ne passe aucun objet le long du pipeline.      

      Required?         False
      Position?         named
      Default value     False
      Accept pipeline?  False
      Accept wildcards? False			
    
    -STA <switch>
      Autorise les composants n�cessitant le mod�le de thread STA.
      Dans ce cas on ins�re dans le script g�n�r�, un test de contr�le sur l'�tat de cloisonnement du thread courant.
      Beta (en cours de test).
      N�cessite sous PowerShell v1, la pr�sence du cmdlet Invoke-Apartment.
      N�cessite sous PowerShell v2, d'ex�cuter PowerShell en pr�cisant le switch -STA.

      Required?         False
      Position?         named
      Default value     False
      Accept pipeline?  False
      Accept wildcards? False			
  
  INPUT TYPE
   N/A
    	
  RETURN TYPE
    System.IO.FileInfo, SI le switch -passThru est pr�cis�, sinon ne renvoi aucune donn�e. 
	
  ERROR MESSAGE
   http://projets.developpez.com/wiki/add-lib/Convert-Form#Code-couleur-des-messages-derreur

  NOTES
  Site : http://projets.developpez.com/wiki/add-lib/Convert-Form 
    

    -------------------------- EXAMPLE 1 --------------------------
     #Pr�cise des noms de chemin complet
    $PathOfForm ="$Home\Mes documents\Visual Studio 2008\Projects\MyForms\MyForms\Form1.Designer.cs"
    .\Convert-Form $PathOfForm C:\Temp\FrmTest.ps1 
    
    -------------------------- EXAMPLE 2 --------------------------
     #Lit le fichier source et �crit le fichier cible dans le r�pertoire courant.
     #Pas de demande confirmation si le fichier existe d�j�
     #Le nom du fichier cible est �gal � :
     # "$Home\Mes documents\Visual Studio 2008\Projects\MyForms\MyForms\Form1.ps1
    cd "$Home\Mes documents\Visual Studio 2008\Projects\MyForms\MyForms\ 
    .\Convert-Form Form1.Designer.cs -Force
    
    -------------------------- EXAMPLE 3 --------------------------
     #Converti la form en lui ajoutant le code cachant la fen�tre de la console 
     # durant le temps d'ex�cution de la fen�tre.
     #On ajoute �galement l'appel au script APiWindows.ps1. 
    .\Convert-Form Form1.Designer.cs FrmTest.ps1 -HideConsole -AddInitialize

    -------------------------- EXAMPLE 3 --------------------------
     #Autorise la conversion des composants utilisant le model de thread STA
    .\Convert-Form Form1.Designer.cs FrmTest.ps1 -STA

    -------------------------- EXAMPLE 4 --------------------------
     #G�n�re l'appel � ShowDialog au sein d'un runspace.
     #On �met le nom du fichier g�n�r� dans le pipeline afin de lui 
     #ajouter une signature Authenticode 
    .\Convert-Form Form1.Designer.cs FrmTest.ps1 -$InvokeInRunspace -Pass|Signe
    
    Afficher la documentaion page par page :
     .\Convert-From|More
"@
}

if ((!$Source) -and ($Destination))
{ Throw "Vous devez pr�ciser un fichier source."}

if (!$Source)  
   { Get-Usage
     Write-Host "`r`n Codes couleur :"
     Write-Host "`tInformation : Message d'information."
     Write-Host -noNewLine "`tInformation : ";Write-Host "op�ration r�ussie." -f Green
     Write-Host -noNewLine "`tInformation : ";Write-Host "op�ration en �chec" -f DarkYellow 
     Write-Host -noNewLine "`tErreur      : ";Write-Host "non-bloquante." -f Yellow 
     Write-Host -noNewLine "`tErreur      : ";Write-Host "grave." -f red 
     Return
   }   

#-------------------------------------------------------------------------------
 #Teste l'existence des scripts n�cessaires, puis les charges

     #On charge les m�thodes de v�rification des pr�s-requis, 
     # du contr�le de la syntaxe et de la localisation.
if (!(Test-Path function:Test-RequiredItem)) 
 { 
   Throw "La fonction Test-RequiredItem n'existe pas." +
         "Chargez le script PackageScripts.ps1"
 }     

$ScriptPath = Get-ScriptDirectory

     #On charge les m�thodes de construction et d'analyse du fichier C#
$PckConvertForm = Join-Path $ScriptPath PackageConvert-Form.ps1
Test-RequiredScripts $PckConvertForm 
 #Test-RequiredCommands aucune
 #Test-RequiredFunctions aucune
.{
  trap [System.Management.Automation.PSSecurityException]
   { Throw $($_.Exception.Message)}
  .$PckConvertForm
}

#-------------------------------------------------------------------------------
 #Load the localized datas for this script
 #Todo
#$ConverFormDatas=import-localizeddata "$ScriptPath\Convert-Form.ps1" #-UICulture:$LocalizedDataCulture


#-------------------------------------------------------------------------------
 #Source est renseign�, on v�rifie sa validit�  
if (($Source -eq $null) -or ($Source -eq [String]::Empty))
 {Throw "Le param�tre Source ne doit pas �tre Null ni �tre une cha�ne vide."}
if ([Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Source))
 {Throw "Le globbing n'est pas support� pour le param�tre `$Source -> $Source"}
   #Le lecteur est-il renseign� ?
if ((Get-QualifierPath $Source)) 
 {   #Oui, mais existe-t-il ?
  if (!(Test-PSDrive $Source -Extract)) 
   {Throw "Le lecteur indiqu� n'existe pas -> $Source."}  
 }
else
{  #C'est un chemin relatif
 if (!(split-path $Source -isabsolute))
      #On lit le fichier sur le lecteur courant
  {
    $Source=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Source)
    Write-debug "Resolved Path : $Source"   
  }
}

if (!(Test-Path $Source))
 {Throw "Le fichier source n'existe pas -> $Source"} 

 #Destination est renseign�, on v�rifie sa validit�  
if ($Destination -ne [String]::Empty)
{
  if ([Management.Automation.WildcardPattern]::ContainsWildcardCharacters($Destination))
   {Throw "le globbing n'est pas support� pour le param�tre `$Destination -> $Destination"}
  
  $Drv=Get-QualifierPath $Destination
  Write-Debug "Get-QualifierPath = $Drv"
    #Le lecteur est-il renseign� ?
  if ($Drv) 
  {  #Oui, mais Existe-t-il ?
    if (!(Test-PSDrive $Drv)) 
     {Throw "Le lecteur indiqu� n'existe pas -> $Destination."}
     #Encore faut-il pouvoir y �crire un fichier ;-)
    if ((Get-PSDrive (($Drv).Replace(":",""))).Provider.Name -ne "FileSystem")
     {Throw "Le PSDrive ($Drv) de destination doit �tre un PSDrive du fournisseur FileSystem."} 
  }
   #C'est un chemin relatif
   #Le drive courant appartient-il au provider FS ? 
  if (!(Test-CurrentPSProvider "FileSystem"))
   { Throw "Ex�cutez ce script � partir d'un drive FileSystem ou r�f�rencez en un dans le nom du fichier Destination  -> $Destination."}
    #On �crira le fichier sur le lecteur courant
    #On r�cup�re le nom complet du fichier � partir d'un chemin relatif  
    # g:..\test.ps1 ..\t.ps1 .\ts.ps1  ..\..\t.ps1
   $Destination=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
   Write-debug "Resolved Path : $Destination"   
   $Ext=[System.IO.Path]::GetExtension($Destination)
   if ($Ext -eq [string]::Empty)
    {
      [System.IO.Path]::ChangeExtension($Destination,".ps1")
      Write-Host "L'extension .PS1 a �t� ajout� au nom du fichier Destination."
    }
   elseif ($Ext -ne ".ps1")
    {
      Write-Warning "Le nom du fichier cible doit �tre .PS1"
      #[System.IO.Path]::ChangeExtension($Destination,".ps1")
    }
} 
 #On construit les noms de fichier, notamment Destination s'il n'est pas renseign�. 
MakeFilesName

 #Affichage de debug
"Source","Destination","SourceName","SourcePath","DestinationName","DestinationPath"|
 Gv |
 % {Write-Debug ("{0}={1}" -F $_.Name,$_.Value)}

  #Teste s'il n'y a pas de conflit dans les switchs
  #Probl�me potentiel: la form principale masque la console, la fermeture de la seconde fen�tre r�affichera la console
 If ( ($HideConsole.ISPresent ) -and ($DontLoad.ISPresent) )
  {Write-Warning "Si vous convertissez une form secondaire l'usage du switch -HideConsole n'est pas n�cessaire.`n`rSi c'est le cas, r�ex�cutez votre appel sans pr�ciser ce switch."} 
 
 if ($InvokeInRunspace -and $DontShow.IsPresent -eq $false)
   {Write-Warning "Conflit d�tect�, attention vous appelez deux fois ShowDialog()."} 
 
Write-Debug "Fin des contr�les."
function Finalyze
{
  Write-Debug "[Finalyze] Lib�ration des listes"
  "LinesNewScript","Components","ErrorProviders"|
   Foreach {
    if (Test-Path Variable:$_) 
     {
      $Lst=GV $_
      $Lst.Value.Clear()
      $Lst.Value=$null
     } 
   }
  $ConverFormDatas=$null 
}
 
#-------------------- Fin des Contr�les --------------------------------------------------------------------

# Collection des lignes utiles de InitializeComponent() : $Components
# Note:
# Le code g�n�r� automatiquement par le concepteur Windows Form est ins�r� 
# dans la m�thode InitializeComponent. 
# L'int�gralit� du code d'une m�thode C# est d�limit� par { ... } 
# On ins�re ces lignes de code et uniquement celles-ci dans le tableau $Component.
# -----------------------------------------------------------------------------
$Components = New-Object System.Collections.ArrayList(400)
$ErrorProviders =New-Object System.Collections.ArrayList(5)
[boolean] $isDebutCodeInit = $false
[string] $FormName=[string]::Empty

Write-Host "`r`nD�marrage de l'analyse du fichier $Source"
.{
  trap  [System.NotSupportedException]
  { 
    Write-Warning "Le composant suivant ou une de ces fonctionnalit�s, requiert le mod�le de thread STA (Single Thread Apartment)).`r`nR�essayez avec le param�tre -STA."
    Finalyze
    Throw $_
  }
  trap 
  { 
    Finalyze
    Throw $_
  }
                                           #Tout ou partie du fichier peut �tre verrouill�
  foreach ($Ligne in Get-Content $Source -ErrorAction Stop)
    {
     if (! $isDebutCodeInit)
        {  # On d�marre l'insertion � partir de cette ligne
           # On peut donc supposer que l'on parse un fichier cr�� par le designer VS
          if ($Ligne.contains("InitializeComponent()")) {$isDebutCodeInit= $true}
        }
     else 
        {  
         #todo le 19/08/2014 une ligne vide entre deux d�clarations et/ou contenant des tabulation
         #arr�te le traitement
# 			this.txt_name.TabIndex = 2;
# 
# 			this.txt_name.Validating += new System.ComponentModel.CancelEventHandler(this.Txt_nameValidating);         
         
         # Fin de la m�thode rencontr�e ou ligne vide, on quitte l'it�ration. 
          if (($Ligne.trim() -eq "}") -or ($Ligne.trim() -eq "")) {break}
           # C'est une ligne de code, on l'ins�re 
          if ($Ligne.trim() -ne "{") 
           {    
              # On r�cup�re le nom de la form dans $FormName
              # Note:  On recherche la ligne d'affectation du nom de la Form :  this.Name = "Form1";  
            if ($Ligne -match '^\s*this\.Name\s*=\s*"(?<nom>[^"]+)"\w*' ) 
              { 
                $FormName = $matches["nom"]
                Write-debug "Nom de la forme trouv� : '$FormName'"
              }
            
            [void]$Components.Add($Ligne)
            Write-Debug "`t`t$Ligne"
            if (! $STA.IsPresent)
            { 
              if ( $Ligne.contains("System.Windows.Forms.WebBrowser") )
               {Throw  new-object System.NotSupportedException "Par d�faut le composant WebBrowser ne peut fonctionner sous PowerShell V1.0."}
              if ( $Ligne.contains("System.ComponentModel.BackgroundWorker") )
               {Write-Warning "Par d�faut les m�thodes de thread du composant BackgroundWorker ne peuvent fonctionner sous PowerShell V1.0."}
              if ( $Ligne -match "\s*this\.(.*)\.AllowDrop = true;$")
               {Throw new-object System.NotSupportedException "Par d�faut l'op�ration de drag and drop ne peut fonctionner sous PowerShell V1.0."}
              if ( $Ligne -match "\s*this\.(.*)\.(AutoCompleteMode|AutoCompleteSource) = System.Windows.Forms.(AutoCompleteMode|AutoCompleteSource).(.*);$")
               {Throw new-object System.NotSupportedException "Par d�faut la fonctionnalit� de saisie semi-automatique pour les contr�les ComboBox,TextBox et ToolStripTextBox doit �tre d�sactiv�e."}
           }#STA
          }
        }#else
    } #foreach
}

Write-debug "Nom de la forme: '$FormName'"
if (!$isDebutCodeInit)
  { Throw "La m�thode InitializeComponent() est introuvable dans le fichier $Source.`n`rLa conversion ne peut s'effectuer."}
 
if ($FormName -eq "") 
{
   $BadName=""
   if ($Source -notMatch "(.*)\.designer\.cs$")
    {$BadName="V�rifiez que le nom du fichier est bien celui g�n�r� par le designer de Visual Studio : Form.Designer.cs."}
   Throw "Le nom de la form est introuvable dans la m�thode InitializeComponent() du fichier $Source.`n`rLa conversion ne peut s'effectuer.`n`r$BadName"  
}

Backup-Collection $Components "R�cup�ration des lignes de code, de la m�thode InitializeComponent, effectu�e."
# Collection de lignes constituant le nouveau script :  $LinesNewScript
# Note:
# Les d�clarations des composants d'une Form se situent entre les lignes suivantes :
#
#   this.SuspendLayout();
#   ...
#   // Form 
#
# ----------------------------------------
$LinesNewScript = New-Object System.Collections.ArrayList(600)
[void]$LinesNewScript.Add( (Create-Header $Destination $($MyInvocation.Line) ))

if ($STA.IsPresent)
  { 
   Write-Debug "[Ajout Code] Add-TestApartmentState"
   [void]$LinesNewScript.Add( (Add-TestApartmentState) ) 
  } 
  
If ( ($HideConsole.ISPresent ) -and ($AddInitialize.ISPresent) )
  { 
   Write-Debug "[Ajout Code] . .\APIWindows.ps1"
   [void]$LinesNewScript.Add(". .\APIWindows.ps1" )
  } 

[boolean] $IsTraiteMethodesForm = $False # Jusqu'� la rencontre de la cha�ne " # Form1  "
[boolean] $IsUsedResources= $false       # On utilise un fichier de ressources

#-----------------------------------------------------------------------------
#  Transforme les d�clarations de propri�t�s sur plusieurs lignes 
#  en une d�claration sur une seule lignes.   
#----------------------------------------------------------------------------- 
if (Test-Path Variable:Ofs)
 {$oldOfs,$Ofs=$Ofs,"`r`n" }
else 
 { #TestLib : set-psdebug -strict
  $Ofs=""
  $oldOfs,$Ofs=$Ofs,"`r`n"
 }

 #Transforme une collection en une string
$Temp="$Components"
 #Logiquement on utilise VS et Convert-Form pour le designer graphique et les event 
 #pas pour renseigner toutes les propri�t�s texte 
$Temp=$Temp -replace "\s{2,}\| ","| "
$Ofs=$oldOfs
$Components = New-Object System.Collections.ArrayList($null)
 #Transforme une string en une collection
$Components.AddRange($Temp.Split("`r`n"))
rv Temp


Write-Debug "D�but de la seconde analyse"
for ($i=0; $i -le $Components.Count-1 ;$i++)
{    
    #Contr�le la pr�sence d'un composant de gestion de ressources (images graphique principalement)
   if ($IsUsedResources -eq $false){
     $crMgr=[regex]::match($Components[$i],"\s= new System\.ComponentModel\.ComponentResourceManager\(typeof\((.*)\)\);$")
     if ($crMgr.success){
       Write-Debug "IsUsedResources : True"
       $IsUsedResources = $True
       $Components[$i]=AjouteGestionRessources
       continue
     }
   }
    # Recherche les noms des possibles ErrorProvider 
    #Ligne :  this.errorProvider2 = new System.Windows.Forms.ErrorProvider(this.components);
    #Write-Debug "Test ErrorProviders: $($Components[$i])"
   if ($Components[$i] -match ("^\s*this\.(.*) = new System.Windows.Forms.ErrorProvider\(this.components\);$"))
     { 
       [void]$ErrorProviders.Add($Matches[1])
       Write-Debug "Find ErrorProviders : $Matches[1]"
       continue
    }
  
  # -----------------------------------------------------------------------------------------------------------------
    #On supprime les lignes ressemblant � : 
       # // 
       # // errorProviderN
       # // 
       # this.errorProviderN.ContainerControl = this;
    # Elles seront recr�es lors de la phase d'analyse des lignes restantes
    # A ce point on connait tous les ErrorProvider d�clar�s
     
     #on test si la ligne courante contient une affectation concernant un des Errorproviders trouv� pr�c�dement
    $ErrorProviders |`
      #Pour chaque �l�ments on construit la regex
     ForEach  {
       $StrMatch="^\s*this.$_.ContainerControl = this;$"
       if ($Components[$i] -match $StrMatch)
        {
          Write-Debug "Match Foreach ErrorProvider"
           #On efface le contenu de la ligne et les 3 pr�c�dentes
          -3..0|%{ $Components[$i+$_]=""}
        }#If
     }#ForEach
   # -----------------------------------------------------------------------------------------------------------------
    
    # Suppression des lignes contenant un appel aux m�thodes suivantes : SuspendLayout, ResumeLayout et PerformLayout 
    #Ligne se terminant seulement par Layout(false); ou Layout(true); ou Layout();
   if ($Components[$i] -match ("Layout\((false|true)??\);$"))
     {$Components[$i]="";continue}
    
   if ($Components[$i].Contains("AutoScale"))
     {$Components[$i]="";Continue}

    # Aucun �quivalent ne semble exister en Powershell pour ces commandes :
    # Pour les contr�les : DataGridView, NumericUpDown et PictureBox
    # Suppression des lignes de gestion du DataBinding. 
   if ($Components[$i].Contains("((System.ComponentModel.ISupportInitialize)(" ))
     {$Components[$i]="";Continue}
}#for
Backup-Collection $Components "Modifications des d�clarations multi-lignes effectu�es."
#-----------------------------------------------------------------------------
#  Fin de traitements des propri�t�s "multi-lignes"
#----------------------------------------------------------------------------- 

if ($IsUsedResources -eq $true)
 { CompileRessources }

If($DontLoad.ISPresent -eq $False)
 {
   Write-Debug "[Ajout Code] chargement des assemblies"
   $Assemblies=@("System.Windows.Forms","System.Drawing")
   if ($IsUsedResources)
    {$Assemblies +="System.Resources"}
     
	 [void]$LinesNewScript.Add("# Chargement des assemblies externes")
	 Create-LoadAssembly $LinesNewScript $Assemblies
 }

Write-Debug "D�but de la troisi�me analyse"
$progress=0
 #Lance la modification du texte d'origine
foreach ($Ligne in $Components)
 {
    $progress++                     
    write-progress -id 1 -activity "Transformation du code source ($($Components.count) lignes)" -status "Patientez" -percentComplete (($progress/$Components.count)*100)
      #On supprime les espaces en d�but et en fin de cha�nes
      #Cela facilite la construction des expressions r�guli�res
    $Ligne = $Ligne.trim()
    if ($Ligne -eq "") {Continue} #Ligne suivante

     # On ajoute la cr�ation d'un �v�nement
     # Gestion d'un event d'un composant :  this.btnRunClose.Click += new System.EventHandler(this.btnRunClose_Click);

      # La ligne d�bute par "this" suivi d'un point puis du nom du composant puis du nom de l'event
      # this.TxtBoxSaisirNombre.Validating += new System.ComponentModel.CancelEventHandler(this.TxtBox1_Validating);
    if ($Ligne -match "^this\.?[^\.]+\.\w+ \+= new [A-Za-z0-9_\.]+EventHandler\(") 
     { 
        # On r�cup�re le nom du composant et le nom de l'�v�nement dans $T[1],$T[2]
       $T=$Ligne.Split(@(".","+"))
        #On ajoute le scriptblock g�rant l'�v�nement
       [void]$LinesNewScript.Add( (Create-EventComponent $T[1] $T[2].Trim()) )
       Continue
     }
        #Gestion d'un event de la form : this.Load += new System.EventHandler(this.Form1_Load);
    elseif ($Ligne -match "^this\.?\w+ \+= new [A-Za-z0-9_\.]+EventHandler\(") 
      {
        # On r�cup�re le nom du composant et le nom de l'�v�nement dans $T[1],$T[2]
       $T=$Ligne.Split(@(".","+"))
       $EventName=$T[1].Trim()
        #On g�n�re par d�faut ces deux �v�nements
       if (($EventName -eq "FormClosing") -or ($EventName -eq "Shown")) {continue}
        #On ajoute le scriptblock g�rant l'�v�nement
       [void]$LinesNewScript.Add( (Create-EventComponent $FormName $EventName) )
       Continue
     }
      
# ------------ Traitement des lignes. Toutes ne sont pas encore support�es, i.e. correctement analys�es

     #Recherche l'affectation d'une valeur d'�num�ration par une capture
     # Trois groupe: 1- Les caract�res � gauche de '= ', i.e. en d�but de ligne
     #				       2- Les caract�res � droite de '= ' et avant le dernier '.'
     #				       3- Les caract�res apr�s le dernier '.'
     # Pour renforcer la reconnaissance on op�re avant la suppression du ';' ( fin d'instruction C#)

     # On ne modifie pas les lignes du type :
     #       this.bindingNavigator1.AddNewItem = this.bindingNavigatorAddNewItem;
    $MatchTmp =[Regex]::Match($Ligne,"^.*= this.*")   
    if ($MatchTmp.Success -eq $false)
     {$Ligne = $Ligne -replace "^(.*)= (.*)\.(\w+);$", '$1=[$2]::$3'}

     # Suppression du token C# de fin de ligne 
    $Ligne = $Ligne -replace ";$",''

     # Suppression du token d'appel de m�thode. ATTENTION. Utile uniquement pour les constructeurs !
    $Ligne = $Ligne -replace "\(\)$",''

     # Les lignes comment�es le restent mais le traitement de la ligne courante se poursuit
    $Ligne = $Ligne -replace "^//",'#'
    
     # Remplacement des types boolean par les variables d�di�es 
    $Ligne = $Ligne -replace " true",' $true'
    $Ligne = $Ligne -replace " false",' $false'

     # Remplacement du format de typage des donn�es
     #PB A quoi cela correspond-il ? si on remplace ici pb par la suite sur certaine ligne
     # A prioris le traitement n'est pas complet et fausse les analyses suivantes.
    #$Ligne = $Ligne -replace "\((\w+\.\w+\.\w+\.\w+)\)", '[$1]' 
     
      # Remplacement, dans le cadre du remplissage d'objets avec des valeurs, de 
      # la cha�ne "new XXXXXX[] {" 
    $Ligne = $Ligne -replace "new [A-Za-z0-9_\.]+\[\] \{",'@('
     # Tjs dans le cadre du remplissage de listbox, remplacement de "})" par "))"
     #if ($Ligne.EndsWith("})")) {$Ligne = $Ligne.replace("})", '))')}
     $Ligne = $Ligne -replace "}\)$",'))'

#TODO : BUG dans la reconnaissance du pattern. D�composer la ligne qui peut �tre complexe
#				  Saisie : "Test : &�"''((--��_��)=+-*/.$�^%,?;:�~#{'[(-|�`_\�^�@)]=}"
#				  C#     : "Test : &é\"\'\'((--èè_çà)=+-*/.$¨^%,?;:§~#{\'[(-|è`_\\ç^à@)]=}"});
#				  PS     : "Test : &�\"\'\'((--��_��)=+-*/.$�^%,?;:�~#{\'[(--bor�`_\\�^�@)]=}"))

     # si on trouve \'  entre 2 guillemets on le remplace par '
     # si on trouve \" entre 2 guillemets on le remplace par "
     # si on trouve \\ entre 2 guillemets on le remplace par \
     # si on trouve | entre 2 guillemets on ne le remplace pas
     # si on trouve || et qu'il n'est pas entre 2 guillemets on le remplace par -or (OR logique)

     # BUG : Remplacement de l'op�rateur binaire OR
     #ATTENTION ne pas le modifier avant l'analyse des lignes de d�claration de fontes !!!
    #$ligne = $ligne.replace("|", '-bor')

     # Recherche dans les lignes comment�es le nom de la form, 
     # le nombre d'espace entre # et Form1 importe peu mais il doit y en avoir au moins un.
    if ($Ligne -match "^#\s+" + $FormName) 
       {
        $IsTraiteMethodesForm = $True
         # On ajoute le constructeur de la Form
        [void]$LinesNewScript.Add("`$$FormName = new-object System.Windows.Forms.form")
         #On ajoute les possibles ErrorProvider
         if ($ErrorProviders.Count -gt 0)
          { [void]$LinesNewScript.Add( ($ErrorProviders|% {Add-ErrorProvider $_ $FormName} ) ) }
         # Il n'existe qu'une ligne de ce type
        Continue 
       }
    if ($IsTraiteMethodesForm)
       {  # On modifie les cha�nes d�butant par "this"
          # Ex : "this.Controls.Add(this.maskedTextBox1) devient "$Form1.Controls.Add(this.maskedTextBox1)" 
         $Ligne = $Ligne -replace "^this.(.*)", "`$$FormName.`$1"
          # Ensuite on remplace toutes les occurences de "this". 
          # Ex :"$Form.Controls.Add(this.button1)" devient "$Form1.Controls.Add($button1)"         
         if ($Ligne.Contains("this."))  
          {$ligne = $Ligne.replace("this.", "$")}
       }
    else
       {  # On modifie les cha�nes d�butant par "this" qui op�rent sur les composants
          # ,on remplace toutes les occurences de "this". 
          # Ex : "this.treeView1.TabIndex = 18" devient "$treeView1.TabIndex = 18" 
         if ($Ligne.StartsWith("this.")) 
           {$Ligne = $Ligne.replace("this.",'$')}
       }
      
      #Remplace le token d'appel d'un constructeur d'instance des composants graphiques. 
      # this.PanelMainFill = new System.Windows.Forms.Panel();
    $Ligne = $Ligne.replace(" new ", " new-object ")
     #Todo this.tableLayoutPanelFill.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 50F));
    $ligne = $Ligne.replace("(new ", "(new-object ")
    
    $Ligne = $Ligne -replace "(^.*= new-object System.Drawing.SizeF\()([0-9]+)F, ([0-9]+)F\)$", '$1$2, $3)'
     #Traite les ressources 
    If ($IsUsedResources)
     {   
       $Ligne = $Ligne -replace "^(.*)= \(\((.*)\)\(resources.GetObject\(`"(.*)`"\)\)\)$", '$1= [$2] $Ressources["$3"]'
# todo
# r�vision de la gestion des ressources
#       Write-host $ligne
#        $Ligne = $Ligne -replace "^(.*)= \(\((.*)\)\(resources.GetObject\((.*)\)\)\)$", '$1= [$2] $Ressources[$3]'
#        Write-host $ligne
#          #$$$2 �chappe le caract�re dollar dans une regex
#        $Ligne = $Ligne -replace "^(.*)\(this.(.*), resources.GetString\((.*)\)\)$", '$1($$$2, $Ressources[$3])'
#        Write-host $ligne
        
     }
     
# -------  Traite les propri�t�s .Font
    $MatchTmp =[Regex]::Match($Ligne,'^(.*)(\.Font =.*System.Drawing.Font\()(.*)\)$')   
    if ($MatchTmp.Success -eq $true)
     { 
        #On traite la partie param�tres d'une d�claration 
       $ParametresFont = ParseProprieteFONT $MatchTmp
       $ligne = ReconstruitLigne $MatchTmp (1,2) $ParametresFont
       [void]$LinesNewScript.Add($ligne+")")
       continue
     }

# -------  Traite les propri�t�s .Anchor
   #la ligne suivante est trait� pr�c�dement et ne match pas
   # this.button2.Anchor = System.Windows.Forms.AnchorStyles.None;
   #$button5.Anchor = ((System.Windows.Forms.AnchorStyles)(((System.Windows.Forms.AnchorStyles.Top | System.Windows.Forms.AnchorStyles.Left)| System.Windows.Forms.AnchorStyles.Right)))
   $MatchTmp =[Regex]::Match($Ligne,'^(.*)(\.Anchor =.*System.Windows.Forms.AnchorStyles\))(.*)\)$')   
    if ($MatchTmp.Success -eq $true)
     { 
        #On traite la partie param�tres d'une d�claration 
       $ParametresAnchor = ParseProprieteANCHOR $MatchTmp
       $Ligne = ReconstruitLigne $MatchTmp (1) $ParametresAnchor
        #todo la function ReconstruitLigne est � revoir. Inadapt� dans ce cas
        #$button1[System.Windows.Forms.AnchorStyles]"Top,Bottom,Left"
       $ligne = $ligne.replace("[System.",".Anchor = [System.")
       [void]$LinesNewScript.Add($Ligne)
       continue
     }

# -------  Traite les propri�t�s .ShortcutKeys
   #this.toolStripMenuItem2.ShortcutKeys = ((System.Windows.Forms.Keys)((System.Windows.Forms.Keys.Alt | System.Windows.Forms.Keys.A)));
   $MatchTmp =[Regex]::Match($Ligne,'^(.*)(\.ShortcutKeys = \(\(System.Windows.Forms.Keys\))(.*)\)$')   
    if ($MatchTmp.Success -eq $true)
     { 
        #On traite la partie param�tres d'une d�claration 
       $ParametresShortcutKeys = ParseProprieteSHORTcutKeys $MatchTmp
       $Ligne = ReconstruitLigne $MatchTmp (1) $ParametresShortcutKeys
        #todo la function ReconstruitLigne est � revoir. Inadapt� dans ce cas
        #$button1[System.Windows.Forms.AnchorStyles]"Top,Bottom,Left"
       $ligne = $ligne.replace("[System.",".ShortcutKeys = [System.")
       [void]$LinesNewScript.Add($Ligne)
       continue
     }

# -------  Traite les appels de la m�thode FormArgb
    $MatchTmp =[Regex]::Match($Ligne,'^(.*)( = System.Drawing.Color.FromArgb\()(.*)\)$') 
    if ($MatchTmp.Success -eq $true)
      { 
         #On traite la partie param�tres d'une d�claration 
        $ParametresRGB = ParseParametres_rgb $MatchTmp
        $Ligne = ReconstruitLigne $MatchTmp (1,2) $ParametresRGB
        $Ligne = $Ligne.Replace("System.Drawing.Color.FromArgb","[System.Drawing.Color]::FromArgb")
        [void]$LinesNewScript.Add($Ligne+")")
        continue
      }
# ------- Fertig !     
    [void]$LinesNewScript.Add($Ligne)
 }  # foreach
Write-Debug "Conversion du code CSharp effectu�e."

 [void]$LinesNewScript.Add( (Add-SpecialEventForm $FormName))
 If ($IsUsedResources)
  {  
    Write-Debug "[Ajout Code]Lib�ration des ressources"
    [void]$LinesNewScript.Add(" #Lib�ration des ressources")
    [void]$LinesNewScript.Add("`$Reader.Close()  #Appel Dispose") 
  }
 
 If( $dontShow.ISPresent -eq $false)
  { 
    Write-Debug "[Ajout Code] Appel � la m�thode ShowDialog/Dispose"
    [void]$LinesNewScript.Add("`$ModalResult=`$$FormName.ShowDialog()") 
    [void]$LinesNewScript.Add(" #Lib�ration de la Form")
    [void]$LinesNewScript.Add("`$$FormName.Dispose()")
 }
 If (!$dontShow.ISPresent -and $HideConsole.ISPresent )
  {
    Write-Debug "[Ajout Code] Show-PSWindow"
    [void]$LinesNewScript.Add("Show-PSWindow")
  }

 if ($InvokeInRunspace)
  { 
    Write-Debug "[Ajout Code] Invoke Form in Runspace"
    [void]$LinesNewScript.Add( (Add-InvokeFormInRunspace $Destination $FormName)) 
  }
 
   # Ecriture du fichier de sortie
 &{
    # On utilise un scriptblock pour b�n�ficier d'un trap local,
    # sinon le trap est global au script 
   trap [System.UnauthorizedAccessException] #fichier prot�g� en �criture
    { Finalyze; throw $_} 
   trap [System.IO.IOException] #Espace insuffisant sur le disque.
    { Finalyze; throw $_} 
   
   &{ 
     if ((!$Force) -and (Test-Path $Destination))
     {  
        #Affiche le d�tail du fichier concern�
      gci $Destination|Select LastWriteTime,mode,FullName|fl|out-host
      Write-Host "Le fichier de destination existe d�j�, voulez-vous le remplacer ?`n`r$Destination"
      $Continuer =$True
      $Reponse = Read-Host "[O] Oui [N] Non"
      while ($Continuer) 
       {
        Switch ($Reponse)
        {
         "O" {$Continuer =$false}
         "N" {Write-Warning "Op�ration abandonn�e."; Finalyze;exit}
         default {$Reponse = Read-Host "[O] Oui [N] Non"}
        }
       }
     }

     $LinesNewScript | Out-File -FilePath $Destination -Encoding Default
     Write-Host "G�n�ration du script $Destination`r`n" -F Green
     Write-Host "-------- D�but de la v�rification de la syntaxe du script g�n�r� ----------" 
      $CheckResult=CheckSyntaxErrors $Destination -verbose
     Write-Host "-------- Fin de la v�rification de la syntaxe du script g�n�r� ----------"
     if (!$CheckResult)
      {Write-Host "La syntaxe du script g�n�r� est invalide." -f DarkYellow }
   }
 }

  If ($dontShow.ISPresent -and $HideConsole.ISPresent )
  {
    Write-host "Pensez � appeler la m�thode Show-PSWindow apr�s `$$FormName.ShowDialog()."
  }
 
 Finalyze
 
 if ($passThru)
 {
   Write-Debug "Emission de l'objet fichier : $Destination"
   gci $Destination
 } 
 Write-Debug ("[{0}] Fin du script atteinte." -F $MyInvocation.MyCommand)
