#PowerShell Form Converter
#
# Objet   : Conversion d'un formulaire graphique C# (WinForm) cr�� � partir 
#           de Visual C# 2005/2008 (Express Edition ou sup�rieure) en un script PowerShell.

   #R�cup�re le code d'une fonction publique du module Log4Posh (Pr�requis)
   #et l'ex�cute dans la port�e du module
$Script:lg4n_ModuleName=$MyInvocation.MyCommand.ScriptBlock.Module.Name
$InitializeLogging=$MyInvocation.MyCommand.ScriptBlock.Module.NewBoundScriptBlock(${function:Initialize-Log4NetModule})
&$InitializeLogging $Script:lg4n_ModuleName "$psScriptRoot\Log4Net.Config.xml"

Import-LocalizedData -BindingVariable ConvertFormMsgs -Filename ConvertFormLocalizedData.psd1 -EA Stop

function Convert-Form {
# .ExternalHelp ConvertForm-Help.xml           
  [CmdletBinding()] 
    [OutputType([System.String])] 
 Param(
      [ValidateNotNullOrEmpty()]
      [Parameter(Position=0,Mandatory=$True,ValueFromPipeline=$True)]   
      #[Alias()] 
    [string] $Source, 
     
     [Parameter(Position=1,Mandatory=$false)]
    [string] $Destination,
     
    [switch] $AddInitialize,
    
    [switch] $DontLoad, #inverser la logique ?
    
    [switch] $DontShow,
     
    [switch] $Force,
     
    [switch] $HideConsole,
    
    [switch] $PassThru,
     
    [switch] $STA
 )

$Source=$Source.Trim()
$Destination=$Destination.Trim()

 #On charge les m�thodes de construction et d'analyse du fichier C#
Import-Module "$psScriptRoot\Transform.psm1" -DisableNameChecking -Verbose:$false

 #Analyse d'un pspath
."$psScriptRoot\Tools\New-PSPathInfo.ps1"
 #valdiation du fichier PS1 g�n�r�
."$psScriptRoot\Tools\Test-PSScript.Ps1"

 #Source est renseign�, on v�rifie sa validit�   
$SourcePathInfo=New-PSPathInfo -Path $Source|Add-FileSystemValidationMember

 #todo v�rifier les causes d'invalidation port�es par la m�thode appell�e
         
 #Le PSPath doit exister, ne pas contenir de globbing et �tre sur le FileSystem
if (!$SourcePathInfo.isFileSystemItemFound()) 
{
  if ($SourcePathInfo.isFileSystemProvider)
  {Throw "Le param�tre Source doit pointer sur le FileSystem."}
  if ($SourcePathInfo.isWildcard)
  {Throw "Le globbing n'est pas support� pour le param�tre Source ; $Source"}
  elseif (!$SourcePathInfo.isDriveExist) 
  {Throw "Le lecteur indiqu� n'existe pas : $Source"}  
  elseif(!$SourcePathInfo.isItemExist)
  {Throw "Le fichier source n'existe pas : $Source"} 
}
$SourceFI=$SourcePathInfo.GetFileName().GetasFileInfo()
  
 #Destination est renseign�, on v�rifie sa validit�  
if ($Destination -ne [String]::Empty)
{
  #Le PSPath doit �tre valide, ne pas contenir de globbing et �tre sur le FileSystem
  $DestinationPathInfo=New-PSPathInfo -Path $Destination|Add-FileSystemValidationMember
  if (!$DestinationPathInfo.IsaValidNameForTheFileSystem()) 
  {
    if ($DestinationPathInfo.isFileSystemProvider)
    {Throw "Le param�tre Destination doit pointer sur le FileSystem."}
    if ($DestinationPathInfo.isWildcard)
    {Throw "Le globbing n'est pas support� pour le param�tre Destination : $Destination"}
    elseif (!$DestinationPathInfo.isDriveExist) 
    {Throw "Le lecteur indiqu� n'existe pas -> $Destination."}  
  
     #C'est un chemin relatif
     #Le drive courant appartient-il au provider FS ? 
    if (!$DestinationPathInfo.isAbsolute -and !$DestinationPathInfo.isCurrentLocationFileSystem)
    { Throw "Le param�tre Destination doit pointer sur le FileSystem : $Destination"}
  }
  $ProjectPaths=New-FilesName $psScriptRoot $SourceFI  $DestinationPathInfo
}
else 
{  $ProjectPaths=New-FilesName $psScriptRoot $SourceFI $Destination}
     

 #Teste s'il n'y a pas de conflit dans les switchs
 #Probl�me potentiel: la form principale masque la console, la fermeture de la seconde fen�tre r�affichera la console
If ( $HideConsole -and $DontLoad )
{Write-Warning "Si vous convertissez une form secondaire l'usage du switch -HideConsole n'est pas n�cessaire.`n`rSi c'est le cas, r�ex�cutez votre appel sans pr�ciser ce switch."} 
 
Write-Debug "Fin des contr�les."

function Finalyze
{
  Write-Debug "[Finalyze] Lib�ration des listes"
  "LinesNewScript","Components","ErrorProviders"|
   Foreach {
    if (Test-Path Variable:$_) 
     {
      $Lst=GV $_
      if ($Lst.Value -ne $null)
       {
         $Lst.Value.Clear()
         $Lst.Value=$null
       }
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

Write-Verbose "D�marrage de l'analyse du fichier $Source"
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
         #todo le 19/08/2014 une ligne vide entre deux d�clarations et/ou contenant des tabulations
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
            if (! $STA)
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
[void]$LinesNewScript.Add( (Add-Header $ProjectPaths.Destination $($MyInvocation.Line) ))

if ($STA)
  { 
   Write-Debug "[Ajout Code] Add-TestApartmentState"
   [void]$LinesNewScript.Add( (Add-TestApartmentState) ) 
  } 
  
If ( $HideConsole -and $AddInitialize )
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
 { 
  $Ofs=""
  $oldOfs,$Ofs=$Ofs,"`r`n"
 }

 #Transforme une collection en une string
$Temp="$Components"
 #Logiquement on utilise VS et Convert-Form pour le designer graphique et les event 
 #pas pour renseigner toutes les propri�t�s de type texte 
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
       $Components[$i]=Add-ManageRessources
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
 { New-RessourcesFile $ProjectPaths }

If($DontLoad -eq $False)
 {
   Write-Debug "[Ajout Code] chargement des assemblies"
   $Assemblies=@("System.Windows.Forms","System.Drawing")
   if ($IsUsedResources)
    {$Assemblies +="System.Resources"}
     
	 [void]$LinesNewScript.Add("# Chargement des assemblies externes")
	 Add-LoadAssembly $LinesNewScript $Assemblies
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
       [void]$LinesNewScript.Add( (Add-EventComponent $T[1] $T[2].Trim()) )
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
       [void]$LinesNewScript.Add( (Add-EventComponent $FormName $EventName) )
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
       $ParametresFont = Select-PropertyFONT $MatchTmp
       $ligne = ConvertTo-Line $MatchTmp (1,2) $ParametresFont
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
       $ParametresAnchor = Select-PropertyANCHOR $MatchTmp
       $Ligne = ConvertTo-Line $MatchTmp (1) $ParametresAnchor
        #todo la function ConvertTo-Line est � revoir. Inadapt� dans ce cas
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
       $ParametresShortcutKeys = Select-PropertyShortcutKeys $MatchTmp
       $Ligne = ConvertTo-Line $MatchTmp (1) $ParametresShortcutKeys
        #todo la function ConvertTo-Line est � revoir. Inadapt� dans ce cas
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
        $ParametresRGB = Select-ParameterRGB $MatchTmp
        $Ligne = ConvertTo-Line $MatchTmp (1,2) $ParametresRGB
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
 
 If( $dontShow -eq $false)
  { 
    Write-Debug "[Ajout Code] Appel � la m�thode ShowDialog/Dispose"
    [void]$LinesNewScript.Add("`$ModalResult=`$$FormName.ShowDialog()") 
    [void]$LinesNewScript.Add(" #Lib�ration de la Form")
    [void]$LinesNewScript.Add("`$$FormName.Dispose()")
 }
 If (!$dontShow -and $HideConsole )
  {
    Write-Debug "[Ajout Code] Show-PSWindow"
    [void]$LinesNewScript.Add("Show-PSWindow")
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
     if ((!$Force) -and (Test-Path $ProjectPaths.Destination))
     {  
      $Choice=Read-Choice "Le fichier de destination existe d�j� : $($ProjectPaths.Destination)" "Voulez-vous le remplacer ?"
      if ($Choice -eq 1)
      { Write-Warning "Op�ration abandonn�e."; Finalyze; Return }
     }

     Write-Verbose "G�n�ration du script $($ProjectPaths.Destination)`r`n"
     #$LinesNewScript | Out-File -FilePath $ProjectPaths.Destination -Encoding Default -Width 999
     Out-File -InputObject $LinesNewScript -FilePath $ProjectPaths.Destination -Encoding Default -Width 999
     Write-Verbose "V�rification de la syntaxe du script g�n�r�." 
     Test-PSScript -Filepath $ProjectPaths.Destination -IncludeSummaryReport
   }
 }

  If ($dontShow -and $HideConsole)
  {
    Write-Verbose "Pensez � appeler la m�thode Show-PSWindow apr�s `$$FormName.ShowDialog()."
  }
 
 Finalyze
 
 if ($passThru)
 {
   Write-Debug "Emission de l'objet fichier : $($ProjectPaths.Destination)"
   gci $ProjectPaths.Destination
 } 
 Write-Debug ("[{0}] Fin du script atteinte." -F $MyInvocation.MyCommand)
 Write-Verbose "Conversion termin�e : $($ProjectPaths.Source)"
} #Convert-Form