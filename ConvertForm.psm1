#PowerShell Form Converter

Import-LocalizedData -BindingVariable ConvertFormMsgs -Filename ConvertFormLocalizedData.psd1 -EA Stop
 
 #On charge les m�thodes de construction et d'analyse du fichier C#
Import-Module "$psScriptRoot\Transform.psm1" -DisableNameChecking -Verbose:$false

 #Analyse d'un pspath
."$psScriptRoot\Tools\New-PSPathInfo.ps1"

try {
  $OLDWP,$WarningPreference=$WarningPreference,'SilentlyContinue'
  Add-Type -TypeDefinition @'
  using System;
  
  namespace ConvertForm {
      [Serializable]
      public class OperationCanceledException : System.ApplicationException
      {
         public OperationCanceledException() : base()
         {
         }
         
         public OperationCanceledException(string message) : base(message)
         {
         }
         
         public OperationCanceledException(string message, Exception innerException)
         : base(message, innerException)
         {
         }
      }
  
      [Serializable]
      public class ComponentNotSupportedException : System.ApplicationException
      {
         public ComponentNotSupportedException() : base()
         {
         }
         
         public ComponentNotSupportedException(string message) : base(message)
         {
         }
         
         public ComponentNotSupportedException(string message, Exception innerException)
         : base(message, innerException)
         {
         }
      }
  
      [Serializable]
      public class CSParseException : System.ApplicationException
      {
         public CSParseException() : base()
         {
         }
         
         public CSParseException(string message) : base(message)
         {
         }
         
         public CSParseException(string message, Exception innerException)
         : base(message, innerException)
         {
         }
      }
  } 
'@
} Finally{
#bug ? https://connect.microsoft.com/PowerShell/feedbackdetail/view/917335
#-IgnoreWarnings do not work 
#-WV IgnoreWarnings do not work
 $WarningPreference=$OLDWP  
}

function Convert-Form {
# .ExternalHelp ConvertForm-Help.xml           
  [CmdletBinding(DefaultParameterSetName="Path")] 
  [OutputType([System.String])] 
 Param(
      #On attend un nom de fichier
     [ValidateNotNullOrEmpty()]
     [Parameter(Position=0,Mandatory=$True,ValueFromPipeline=$True, ParameterSetName="Path")]
   [string]$Path,
   
     [ValidateNotNullOrEmpty()]
     [Parameter(Position=0,Mandatory=$True,ValueFromPipeline=$True, ParameterSetName="LiteralPath")]
     [Alias('PSPath')]
   [string]$LiteralPath,
       
       #On attend un nom de r�pertoire
      [parameter(position=1,ValueFromPipelineByPropertyName=$True)]
    [PSObject] $Destination, #todo teste delayed SB    
    
      [parameter(position=1,ValueFromPipelineByPropertyName=$True)]
    [PSObject] $DestinationLiteral, #todo teste delayed SB     
    
     [Parameter(Position=2,Mandatory=$false)]
     [ValidateSet("unknown", "string", "unicode", "bigendianunicode", "utf8", "utf7", "utf32", "ascii", "default", "oem")]
    [string] $Encoding='default',
    
    [switch] $noLoadAssemblies, 
    
    [switch] $noShowDialog,
     
    [switch] $Force,
     
    [switch] $HideConsole,
    
    [switch] $asFunction, 
    #http://pshcreator.codeplex.com
    #Cr�er une fonction Launcher
    #ajouter la ligne d'appel :
    # $psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("WMI AutoScript", {LaunchMain},"ALT+F5") | out-Null
    #Exemple : "G:\PS\ConvertForm\Tests\WMI Explorer.png"
    #
    # OverloadDefinitions                                                                                                 
    # -------------------                                                                                                 
    # Microsoft.PowerShell.Host.ISE.ISEMenuItem Add(string displayName, scriptblock action, System.Windows.Input.KeyGesture shortcut)                                                                           
    # void Add(Microsoft.PowerShell.Host.ISE.ISEMenuItem item)                                                            
    # void ICollection[ISEMenuItem].Add(Microsoft.PowerShell.Host.ISE.ISEMenuItem item)     
   
    [switch] $PassThru
 )

 process {
  
  [Switch] $isVerbose= $null
  [void]$PSBoundParameters.TryGetValue('Verbose',[REF]$isVerbose)
  if ($isVerbose)
  { $VerbosePreference='Continue' } 
  
  $_EA= $null
  [void]$PSBoundParameters.TryGetValue('ErrorAction',[REF]$_EA)
  
  if ($_EA -eq $null)
  {
     #R�cup�re la valeur du contexte de l'appelant
    $ErrorActionPreference=$PSCmdlet.SessionState.PSVariable.Get('ErrorActionPreference').Value
  }
  else 
  { 
     #Priorit�: On remplace sa valeur
    $ErrorActionPreference=$_EA
  }
   
  [boolean] $STA=$false
  
  $isLiteral=$PsCmdlet.ParameterSetName -eq "LiteralPath"
  
  $isDestination=$PSBoundParameters.ContainsKey('Destination')
  $isDestinationLiteral=$PSBoundParameters.ContainsKey('DestinationLiteral')
  if ($isDestination -and $isDestinationLiteral)
  { Throw (New-Object System.ArgumentException($ConvertFormMsgs.ParameterIsExclusif)) }
  
  $isDestinationBounded=$isDestination -or $isDestinationLiteral
  
  if ($isDestinationLiteral) 
  { $Destination=($DestinationLiteral -as [String]).Trim()}
  else
  { $Destination=($Destination -as [String]).Trim()}
   
  #Valide les pr�requis concernant les fichiers
  if ($isLiteral)
  { $SourcePathInfo=New-PSPathInfo -LiteralPath ($LiteralPath.Trim())|Add-FileSystemValidationMember }
  else
  { $SourcePathInfo=New-PSPathInfo -Path ($Path.Trim())|Add-FileSystemValidationMember }
 
  $FileName=$SourcePathInfo.GetFileName()
  
   #Le PSPath doit exister, ne pas �tre un r�pertoire, ne pas contenir de globbing et �tre sur le FileSystem
   #On doit lit un fichier.
   #On pr�cise le raison de de l'erreur
  if (!$SourcePathInfo.isFileSystemItemFound()) 
  {
    if (!$SourcePathInfo.isDriveExist) 
    {Throw (New-Object System.ArgumentException(($ConvertFormMsgs.DriveNotFound  -F $FileName),'Source')) } 
  
       #C'est un chemin relatif, le drive courant appartient-il au provider FileSystem ? 
    if (!$SourcePathInfo.isAbsolute -and !$SourcePathInfo.isCurrentLocationFileSystem)
    {Throw (New-Object System.ArgumentException(($ConvertFormMsgs.FileSystemPathRequiredForCurrentLocation -F $FileName),'Source')) }
  
    if (!$SourcePathInfo.isFileSystemProvider)
    {Throw (New-Object System.ArgumentException(($ConvertFormMsgs.FileSystemPathRequired -F $FileName),'Source')) }
  
    if ($SourcePathInfo.isWildcard) 
    {Throw (New-Object System.ArgumentException(($ConvertFormMsgs.GlobbingUnsupported -F $FileName),'Source'))}
    else
    {Throw (New-Object System.ArgumentException(($ConvertFormMsgs.ItemNotFound -F $FileName),'Source')) } 
  }
  $SourceFI=$FileName.GetasFileInfo()
  if ($SourceFI.Attributes -eq 'Directory')
  { Throw (New-Object System.ArgumentException(($ConvertFormMsgs.ParameterMustBeAfile -F $FileName),'Source')) } 
  
   #Le cast de Destination renvoit-il une cha�ne ayant au moins un caract�re diff�rent d'espace ? 
  if ($Destination -ne [String]::Empty)
  {
    if ($isDestinationLiteral) 
    { $DestinationPathInfo=New-PSPathInfo -LiteralPath $Destination|Add-FileSystemValidationMember }  
    else
    { $DestinationPathInfo=New-PSPathInfo -Path $Destination|Add-FileSystemValidationMember }
    
    $FileName=$DestinationPathInfo.GetFileName()

    #Le PSPath doit �tre valide, ne pas contenir de globbing ( sauf si literalPath) et �tre sur le FileSystem
    #Le PSPath doit exister et pointer sur un r�pertoire :  { md C:\temp\test00 -Force}
    #On pr�cise la raison de l'erreur
    if (!$DestinationPathInfo.IsaValidNameForTheFileSystem()) 
    {
      if (!$DestinationPathInfo.isDriveExist) 
      {Throw (New-Object System.ArgumentException(($ConvertFormMsgs.DriveNotFound  -F $FileName),'Destination')) }  
  
      if (!$DestinationPathInfo.isAbsolute -and !$DestinationPathInfo.isCurrentLocationFileSystem)
      {Throw (New-Object System.ArgumentException(($ConvertFormMsgs.FileSystemPathRequiredForCurrentLocation -F $FileName),'Destination')) }
      
      if (!$DestinationPathInfo.isFileSystemProvider)
      {Throw (New-Object System.ArgumentException(($ConvertFormMsgs.FileSystemPathRequired -F $FileName),'Destination')) }
      
      if ($DestinationPathInfo.isWildcard)
      {Throw (New-Object System.ArgumentException(($ConvertFormMsgs.GlobbingUnsupported -F $FileName),'Destination')) }
    }
    elseif (!$DestinationPathInfo.isItemExist)
    {Throw (New-Object System.ArgumentException(($ConvertFormMsgs.PathNotFound -F $FileName),'Destination')) }
    elseif (!$DestinationPathInfo.IsDirectoryExist($Filename))
    { Throw (New-Object System.ArgumentException(($ConvertFormMsgs.ParameterMustBeAdirectory -F $FileName),'Destination')) } 
    
    $ProjectPaths=New-FilesName $psScriptRoot $SourceFI $DestinationPathInfo -verbose:$isVerbose 
  }
  else 
  { 
     #$Destination n'est pas utilisable ou n'a pas �t� pr�cis� ( $null -> String.Empty) 
    $ProjectPaths=New-FilesName $psScriptRoot $SourceFI
  }
   
   #Teste s'il n'y a pas de conflit dans les switchs
   #Probl�me potentiel: la form principale masque la console, la fermeture de la seconde fen�tre r�affichera la console
  If ( $HideConsole -and $noLoadAssemblies )
  { Write-Warning $ConvertFormMsgs.ParameterHideConsoleNotNecessary } 
   
  Write-Debug "Fin des contr�les."

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
  [boolean] $IsUsedPropertiesResources= $false  # On utilise le fichier de ressources des propri�t�s du projet
  
  Write-Verbose ($ConvertFormMsgs.BeginAnalyze -F $ProjectPaths.Source)

  if ($isLiteral)
  { $Lignes= Get-Content -Literalpath $ProjectPaths.Source -ErrorAction Stop }
  else
  { $Lignes= Get-Content -Path $ProjectPaths.Source -ErrorAction Stop }
  
  Write-Debug "D�but de la premi�re analyse"
  foreach ($Ligne in $Lignes)
  {
    if (! $isDebutCodeInit)
    {  # On d�marre l'insertion � partir de cette ligne
       # On peut donc supposer que l'on parse un fichier cr�� par le designer VS
      if ($Ligne.contains('InitializeComponent()')) {$isDebutCodeInit= $true}
    }
    else 
    {  
      if ($Ligne.Trim() -eq [string]::Empty) {continue}
     
       # Fin de la m�thode rencontr�e ou ligne vide, on quitte l'it�ration. 
      if (($Ligne.trim() -eq "}") -or ($Ligne.trim() -eq [string]::Empty)) {break}
      
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
       #todo test sous PS v2 et v3
       if (-not $STA)
       {
          $STAReason=[string]::Empty 
          if ($Ligne.contains('System.Windows.Forms.WebBrowser') )
          { $STAReason='component WebBrowser' }
          if ($Ligne.contains('System.ComponentModel.BackgroundWorker') )
          { $STAReason='component BackgroundWorker' }
          if ( $Ligne -match "\s*this\.(.*)\.AllowDrop = true;$")
          { $STAReason='Drag and Drop' }
          if ( $Ligne -match "\s*this\.(.*)\.(AutoCompleteMode|AutoCompleteSource) = System.Windows.Forms.(AutoCompleteMode|AutoCompleteSource).(.*);$")
          { $STAReason='AutoCompleteMode' }
          if ( $STAReason -ne [string]::Empty)
          { 
            $STA=$true
            Write-Warning ($ConvertFormMsgs.AddSTARequirement -F $STAReason)
          }
       }                  
      }
     
     #La form n�cessite-t-elle l'usage du fichier resx du projet ?
     if ( ($IsUsedPropertiesResources -eq $false) -and ($Ligne -Match '^(.*)= global::(.*?\.Properties.Resources\.)') )
     { 
       $IsUsedPropertiesResources=$true
       Write-debug "N�cessite le fichier resx du propri�t�s du projet"
     }
    }#else
  } #foreach

  Write-debug "Nom de la forme: '$FormName'"
  if (!$isDebutCodeInit)
  {  
    $PSCmdlet.WriteError(
    (New-Object System.Management.Automation.ErrorRecord (
         #Recr�e l'exception trapp�e avec un message personnalis� 
	   (new-object ConvertForm.CSParseException( ($ConvertFormMsgs.InitializeComponentNotFound -F $ProjectPaths.Source ))),                         
       "AnalyzeWinformDesignerFileError", 
       "InvalidData",
       ("[{0}]" -f $ProjectPaths.Source)
       )  
    )
    )
    return  
  }
   
  if ($FormName -eq [string]::Empty) 
  {
     $WarningName=[string]::Empty
     if ($ProjectPaths.Source -notMatch "(.*)\.designer\.cs$")
     { $WarningName=$ConvertFormMsgs.DesignerNameNotFound }
    $PSCmdlet.WriteError(
     (New-Object System.Management.Automation.ErrorRecord (
         #Recr�e l'exception trapp�e avec un message personnalis� 
	   (new-object ConvertForm.CSParseException(($ConvertFormMsgs.FormNameNotFound -F $ProjectPaths.Source,$WarningName))),                         
       "AnalyzeWinformDesignerFileError", 
       "InvalidData",
       ("[{0}]" -f $ProjectPaths.Source)
       )  
     )
    )
    return
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
  [void]$LinesNewScript.Add( (Add-Header $ProjectPaths.Destination $($MyInvocation.Line) $ProjectPaths.Source ))
  if ( $asFunction )
  { [void]$LinesNewScript.Add('Function GenerateForm {') }

  if ($STA)
  { 
    Write-Debug "[Ajout Code] Add-TestApartmentState"
    [void]$LinesNewScript.Add( (Add-TestApartmentState) ) 
  } 
    
  If ($HideConsole -and !$noLoadAssemblies)
  { 
    Write-Debug "[Ajout Code] Win32FunctionsType"
    [void]$LinesNewScript.Add((Add-Win32FunctionsType))
    [void]$LinesNewScript.Add((Add-Win32FunctionsWrapper))
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
    $Ofs=[string]::Empty
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
  Remove-Variable Temp
  
  
  Write-Debug "D�but de la seconde analyse"
  for ($i=0; $i -le $Components.Count-1 ;$i++)
  {    
      #Contr�le la pr�sence d'un composant de gestion de ressources (images graphique principalement)
     if ($IsUsedResources -eq $false)
     {
       $crMgr=[regex]::match($Components[$i],"\s= new System\.ComponentModel\.ComponentResourceManager\(typeof\((.*)\)\);$")
       if ($crMgr.success)
       {
         $IsUsedResources = $True
         Write-Debug "IsUsedResources : $IsUsedResources"
         continue
       }
     }
      # Recherche les noms des possibles ErrorProvider 
      #Ligne :  this.errorProvider2 = new System.Windows.Forms.ErrorProvider(this.components);
      #Write-Debug "Test ErrorProviders: $($Components[$i])"
     if ($Components[$i] -match ('^\s*this\.(.*) = new System.Windows.Forms.ErrorProvider\(this.components\);$'))
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
           -3..0|%{ $Components[$i+$_]=[string]::Empty}
         }#If
      }#ForEach
     # -----------------------------------------------------------------------------------------------------------------
      
      # Suppression des lignes contenant un appel aux m�thodes suivantes : SuspendLayout, ResumeLayout et PerformLayout
      #  SuspendLayout() force Windows � ne pas redessiner la form. 
      #Ligne se terminant seulement par Layout(false); ou Layout(true); ou Layout();
      if ($Components[$i] -match ('Layout\((false|true)??\);$'))
      {$Components[$i]=[string]::Empty;continue}
  
        #Les lignes suivantes ne sont pas prise en compte 
        #   this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
        #   this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
      if ($Components[$i].Contains('AutoScale'))
      {$Components[$i]=[string]::Empty;Continue}
  
      # Aucun �quivalent ne semble exister en Powershell pour ces commandes :
      # Pour les contr�les : DataGridView, NumericUpDown et PictureBox
      # Suppression des lignes de gestion du DataBinding. 
      if ($Components[$i].Contains('((System.ComponentModel.ISupportInitialize)(') )
      {$Components[$i]=[string]::Empty;Continue}
  }#for
  Backup-Collection $Components 'Modifications des d�clarations multi-lignes effectu�es.'
  #-----------------------------------------------------------------------------
  #  Fin de traitements des propri�t�s "multi-lignes"
  #----------------------------------------------------------------------------- 
  
  If(!$noLoadAssemblies)
  {
     Write-Debug "[Ajout Code] chargement des assemblies"
     $Assemblies=@('System.Windows.Forms','System.Drawing')
     
     [void]$LinesNewScript.Add($ConvertFormMsgs.LoadingAssemblies)
     Add-LoadAssembly $LinesNewScript $Assemblies
  }

  [void]$LinesNewScript.Add( (Add-GetScriptDirectory) )

  if ($IsUsedPropertiesResources)
  { 
    try {
      Push-Location "$($ProjectPaths.SourcePath)\Resources"
      
      [void]$LinesNewScript.Add( (Add-ManagePropertiesResources "$($ProjectPaths.Sourcename)Properties"))
      $rsxSource = Join-Path $ProjectPaths.SourcePath 'Properties\Resources.resx'
      $rsxDestination = Join-Path $ProjectPaths.DestinationPath ($ProjectPaths.SourceName+'Properties.resources')
      New-ResourcesFile -Source $rsxSource -Destination $rsxDestination -isLiteral:$isLiteral -EA $ErrorActionPreference -verbose:$isVerbose
    } finally {
      Pop-Location
    }
  }

  if ($IsUsedResources)
  { 
    [void]$LinesNewScript.Add( (Add-ManageResources $ProjectPaths.Sourcename)) 
  	$rsxSource = Join-Path $ProjectPaths.SourcePath ($ProjectPaths.SourceName+'.resx')
    $rsxDestination = Join-Path $ProjectPaths.DestinationPath ($ProjectPaths.SourceName+'.resources')
    New-ResourcesFile -Source $rsxSource -Destination $rsxDestination -isLiteral:$isLiteral -EA $ErrorActionPreference -verbose:$isVerbose 
  }

  #On ajoute la cr�ation de la form avant tout autre composant
  #Le code de chaque composant r�f�ren�ant cet objet est assur� de son existence
  [void]$LinesNewScript.Add("`$$FormName = New-Object System.Windows.Forms.Form`r`n")
  
  Write-Debug "D�but de la troisi�me analyse"
  $progress=0
  $setBrkPnt=$true
  $BPLigneRead,$BPLigneWrite=$null
  
   #Lance la modification du texte d'origine
  foreach ($Ligne in $Components)
  {
      Write-debug "---------Traite la ligne : $Ligne"
     if ($setBrkPnt -and ($DebugPreference -ne "SilentlyContinue"))
     {
       $BPLigneRead=Set-PSBreakpoint -Variable Ligne -Mode Read -Action { Write-Debug "[R]$Ligne"}
       $BPLigneWrite=Set-PSBreakpoint -Variable Ligne -Mode Write -Action { Write-Debug "[W]$Ligne"}
       $setBrkPnt=$false
     }
     $progress++                     
     Write-Progress -id 1 -activity ($ConvertFormMsgs.TransformationProgress -F $Components.Count) -status $ConvertFormMsgs.TransformationProgressStatus -percentComplete (($progress/$Components.count)*100)
       #On supprime les espaces en d�but et en fin de cha�nes
       #Cela facilite la construction des expressions r�guli�res
     $Ligne = $Ligne.trim()
     if ($Ligne -eq [string]::Empty) {Continue} #Ligne suivante
  
       # On ajoute la cr�ation d'un �v�nement
       # Gestion d'un event d'un composant :  this.btnRunClose.Click += new System.EventHandler(this.btnRunClose_Click);
  
       # La ligne d�bute par "this" suivi d'un point puis du nom du composant puis du nom de l'event
       # this.TxtBoxSaisirNombre.Validating += new System.ComponentModel.CancelEventHandler(this.TxtBox1_Validating);
     if ($Ligne -match '^this\.?[^\.]+\.\w+ \+= new [A-Za-z0-9_\.]+EventHandler\(') 
     { 
         # On r�cup�re le nom du composant et le nom de l'�v�nement dans $T[1],$T[2]
        $T=$Ligne.Split(@('.','+'))
         #On ajoute le scriptblock g�rant l'�v�nement
        [void]$LinesNewScript.Add( (Add-EventComponent $T[1] $T[2].Trim()) )
        Continue
     }
        #Gestion d'un event de la form : this.Load += new System.EventHandler(this.Form1_Load);
     elseif ($Ligne -match '^this\.?\w+ \+= new [A-Za-z0-9_\.]+EventHandler\(') 
     {
        # On r�cup�re le nom du composant et le nom de l'�v�nement dans $T[1],$T[2]
       $T=$Ligne.Split(@('.','+'))
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
     $MatchTmp =[Regex]::Match($Ligne,"^(.*?) = (this|global::|\(\().*")   
     if ($MatchTmp.Success -eq $false)
     {$Ligne = $Ligne -replace "^(.*)= (.*)\.(\w+);$", '$1=[$2]::$3'}
  
      # Suppression du token C# de fin de ligne 
     $Ligne = $Ligne -replace '\s*;\s*$',''
     
      # Suppression du token d'appel de m�thode. ATTENTION. Utile uniquement pour les constructeurs !
     $Ligne = $Ligne -replace "\(\)$",''
  
      # Les lignes comment�es le restent et le traitement de la ligne courante se poursuit
     $Ligne = $Ligne -replace "^//",'#'
      
      # Remplacement des types boolean par les variables d�di�es
      #Pour une affectation ou dans un appel de m�thode 
     $Ligne = $Ligne -replace " true",' $true'
     $Ligne = $Ligne -replace " false",' $false'
      
      #Pour une affectation uniquement
     $Ligne = $Ligne -replace ' = null$',' = $null'

      #Pour une affectation uniquement
      $Ligne = $Ligne -replace ' = this$'," = `$$FormName"
  
      # Remplacement du format de typage des donn�es
      #PB A quoi cela correspond-il ? si on remplace ici pb par la suite sur certaines lignes
      # A priori le traitement n'est pas complet et fausse les analyses suivantes.
      #$Ligne = $Ligne -replace "\((\w+\.\w+\.\w+\.\w+)\)", '[$1]' 
       
       # Remplacement, dans le cadre du remplissage d'objets avec des valeurs, de 
       # la cha�ne "new XXXXXX[] {" 
     $Ligne = $Ligne -replace "new [A-Za-z0-9_\.]+\[\] \{",'@('
      # Tjs dans le cadre du remplissage de listbox, remplacement de "})" par "))"
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
         [void]$LinesNewScript.Add("# $FormName")
          #On ajoute les possibles ErrorProvider
         if ($ErrorProviders.Count -gt 0)
         { 
            [string[]]$S=$ErrorProviders|% {Add-ErrorProvider $_ $FormName}
            [void]$LinesNewScript.Add("$S")
         } 
          # Il n'existe qu'une ligne de ce type
         Continue 
      }
      if ($IsTraiteMethodesForm)
      {   # On modifie les cha�nes d�butant par "this"
          # Ex : "this.Controls.Add(this.maskedTextBox1) devient "$Form1.Controls.Add(this.maskedTextBox1)" 
         $Ligne = $Ligne -replace "^this.(.*)", "`$$FormName.`$1"
          # Ensuite on remplace toutes les occurences de "this". 
          # Ex :"$Form.Controls.Add(this.button1)" devient "$Form1.Controls.Add($button1)"         
         if ($Ligne.Contains('this.'))  
         { $ligne = $Ligne.replace('this.', '$') }
      }
      else
      {   # On modifie les cha�nes d�butant par "this" qui op�rent sur les composants
          # ,on remplace toutes les occurences de "this". 
          # Ex : "this.treeView1.TabIndex = 18" devient "$treeView1.TabIndex = 18" 
         if ($Ligne.StartsWith('this.')) 
         { $Ligne = $Ligne.replace('this.','$') }
      }
        
        #Remplace le token d'appel d'un constructeur d'instance des composants graphiques. 
        # this.PanelMainFill = new System.Windows.Forms.Panel();
      $Ligne = $Ligne.replace(' new ', ' New-Object ')
       #Todo BUG
       #     this.tableLayoutPanelFill.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 50F));
       #     this.tableLayoutPanelFill.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 50F));
       # result :
       #     $tableLayoutPanelFill.ColumnStyles.Add(New-Object System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 50F))
       #
       #projet : ConvertForm\TestsWinform\Test5Panel\FrmTest5PanelTableLayoutPanel.Designer.cs

      $ligne = $Ligne.replace('(new ', '(New-Object ')
      
      $Ligne = $Ligne -replace "(^.*= New-Object System.Drawing.SizeF\()([0-9]+)F, ([0-9]+)F\)$", '$1$2, $3)'
       #Traite les ressources 
      If ($IsUsedResources)
      {   
         $Ligne = $Ligne -replace '^(.*?) = \(\((.*)\)\(resources.GetObject\("(.*)"\)\)\)$', '$1= [$2] $Resources["$3"]'
      }

#       Write-debug "IsUsedPropertiesResources=$IsUsedPropertiesResources"
#       Write-debug "`t $Ligne"
#       write-debug "matches $($Ligne -match '^(?<Object>.*) = global::(.*?\.Properties.Resources\.)(?<Key>.*);$')"
      write-debug '----'
      if ($IsUsedPropertiesResources -and ($Ligne -match '^(?<Object>.*) = global::(.*?\.Properties.Resources\.)(?<Key>.*)$'))
      { 
        #todo culture ResourceManager.GetObject("Go", resourceCulture);
        # transforme : this.pictureBox1.Image = global::TestFrm.Properties.Resources.Koala;
        #  en        : pictureBox1.Image = $PropertiesResources["Koala"]
        #
        # Koala est le nom d'une cl� du fichier resx du projet : 
        # TestFrm.Properties est un espace de nom,  .Resources est une classe et Koala une propri�t� statique
        # les fichiers associ�e:
        #  Projet\Frm\Properties\Resources.Designer.cs
        #  Projet\Frm\Properties\Resources.resx
       $nl='{0}= $PropertiesResources["{1}"]' -F $Matches.Object,$Matches.Key
       [void]$LinesNewScript.Add($nl)
       continue
      }
  # Todo BUG
# ConvertForm\TestsWinform\Test14BoitesDeDialogue\FrmTest14BoitesDeDialogue.Designer.cs
#       #
#       $toolStripMenuItem2.DropDownItems.AddRange(@(
#       $toolStripMenuItem11))
#       $toolStripMenuItem2.Name = "toolStripMenuItem2"
#       resources.ApplyResources(this.toolStripMenuItem2, "toolStripMenuItem2")
#       $toolStripMenuItem4.Name = "toolStripMenuItem4"
#       resources.ApplyResources(this.toolStripMenuItem4, "toolStripMenuItem4")  
      
  #    resources.ApplyResources(this.rdbtnEnglish, "rdbtnEnglish");
  #    this.rdbtnFrench.AccessibleDescription = null;
  #    this.toolTipFr.SetToolTip(this.rdbtnEnglish, resources.GetString("rdbtnEnglish.ToolTip"));  
  #
  #result :
#     $rdbtnEnglish.AccessibleDescription = null
#     $rdbtnEnglish.AccessibleName = null
#     resources.ApplyResources(this.rdbtnEnglish, "rdbtnEnglish")
#     $rdbtnEnglish.BackgroundImage = null
#     $rdbtnEnglish.Font = null
#     $rdbtnEnglish.Name = "rdbtnEnglish"
#     $rdbtnEnglish.TabStop = $true
#     $toolTipFr.SetToolTip($rdbtnEnglish, resources.GetString("rdbtnEnglish.ToolTip"))  
  #
  #Projet: ConvertForm\TestsWinform\Test19Localisation\FrmMain.Designer.cs
  #
  # r�vision de la gestion des ressources
  #       Write-host $ligne
  #        $Ligne = $Ligne -replace "^(.*)= \(\((.*)\)\(resources.GetObject\((.*)\)\)\)$", '$1= [$2] $Resources[$3]'
  #        Write-host $ligne
  #          #$$$2 �chappe le caract�re dollar dans une regex
  #        $Ligne = $Ligne -replace "^(.*)\(this.(.*), resources.GetString\((.*)\)\)$", '$1($$$2, $Resources[$3])'
  #        Write-host $ligne
          
  
  # -------  Traite les propri�t�s .Font
      $MatchTmp =[Regex]::Match($Ligne,'^(.*)(\.Font =.*System.Drawing.Font\()(.*)\)$')   
      if ($MatchTmp.Success -eq $true)
      { 
          #On traite la partie param�tres d'une d�claration 
         $ParametresFont = Select-PropertyFONT $MatchTmp
         $ligne = ConvertTo-Line $MatchTmp (1,2) $ParametresFont
         [void]$LinesNewScript.Add($ligne+')')
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
         $ligne = $ligne.replace('[System.','.Anchor = [System.')
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
         $ligne = $ligne.replace('[System.','.ShortcutKeys = [System.')
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
         $Ligne = $Ligne.Replace('System.Drawing.Color.FromArgb','[System.Drawing.Color]::FromArgb')
         [void]$LinesNewScript.Add($Ligne+')')
         continue
      }                                                                 
   # -------  Traite les appels de m�thode statique
     #System.Parse("-00:00:01");
     #System.TimeSpan.Parse("-00:00:01");
     #System.T1.T2.T3.Parse("-00:00:01");
     #todo : regex en une passe 
     if ($Ligne -notmatch '^(.*) =\s*(\$|\()')
     { 
      # Write-Debug "Change m�thode statique : $Ligne"
       $Ligne = $Ligne -replace '^(.*) =\s*(.[^\s]*)\.(.[^\.\s]*?)\(','$1 = [$2]::$3(' 
     } 
     
     Write-debug '---------------------'      
      [void]$LinesNewScript.Add($Ligne)
   } #foreach

  if ($DebugPreference -ne "SilentlyContinue")
  { $BPLigneRead,$BPLigneWrite | Remove-PSBreakpoint }
  Write-Debug "Conversion du code CSharp effectu�e."
  
   [void]$LinesNewScript.Add( (Add-SpecialEventForm $FormName -HideConsole:$HideConsole))
   If ($IsUsedResources)
   {  
      Write-Debug "[Ajout Code]Lib�ration des ressources"
      [void]$LinesNewScript.Add($ConvertFormMsgs.DisposeResources)
      [void]$LinesNewScript.Add('$Reader.Close()') 
   }

   If ($IsUsedPropertiesResources)
   {  
      Write-Debug "[Ajout Code]Lib�ration des ressources des propri�t�s du projet"
      [void]$LinesNewScript.Add('$PropertiesReader.Close()') 
   }
   
   If (!$noShowDialog)
   { 
      Write-Debug "[Ajout Code] Appel � la m�thode ShowDialog/Dispose"
      [void]$LinesNewScript.Add("`$ModalResult=`$$FormName.ShowDialog()") 
      [void]$LinesNewScript.Add($ConvertFormMsgs.DisposeForm)
       #Showdialog() need explicit Dispose()
      [void]$LinesNewScript.Add("`$$FormName.Dispose()")
   }
   If (!$noShowDialog -and $HideConsole )
   {
      Write-Debug "[Ajout de code] Show-Window"
      [void]$LinesNewScript.Add('Show-Window')
   }
  if ( $asFunction )
  {  
    [void]$LinesNewScript.Add("}# GenerateForm`r`n")
    [void]$LinesNewScript.Add("#Todo : When you use several addons, rename the 'GenerateForm' function.") 
    [void]$LinesNewScript.Add('#Todo : Complete and uncomment the next line.')
    [void]$LinesNewScript.Add("#`$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add('Todo DisplayName', {GenerateForm},'ALT+F5')")
  }
  
     # Ecriture du fichier de sortie
  try {
     if ((!$isDestinationBounded -and $isLiteral) -or $isDestinationLiteral)
     { $DestinationExist=Test-Path -LiteralPath $ProjectPaths.Destination }
     else
     { $DestinationExist=Test-Path -Path $ProjectPaths.Destination }
	 
      if (!$Force -and $DestinationExist)
      {  
        $Choice=Read-Choice ($ConvertFormMsgs.ReadChoiceCaption -F $ProjectPaths.Destination) $ConvertFormMsgs.ReadChoiceMessage
        if ($Choice -eq $ChoiceNO)
        { Write-Warning $ConvertFormMsgs.OperationCancelled; Return }
      }
  
      Write-Verbose ($ConvertFormMsgs.GenerateScript -F $ProjectPaths.Destination)
      if ((!$isDestinationBounded -and $isLiteral) -or $isDestinationLiteral)
      { Out-File -InputObject $LinesNewScript -LiteralPath $ProjectPaths.Destination -Encoding $Encoding -Width 999 }
      else
      { Out-File -InputObject $LinesNewScript -FilePath $ProjectPaths.Destination -Encoding $Encoding -Width 999 }
   } catch {
       #[System.UnauthorizedAccessException] #fichier prot�g� en �criture
       #[System.IO.IOException] #Espace insuffisant sur le disque.
      $PSCmdlet.WriteError(
        (New-Object System.Management.Automation.ErrorRecord (           
           $_.Exception,                         
           "CreateScriptError", 
           "WriteError",
           ("[{0}]" -f $ProjectPaths.Destination)
           )  
        )
      )  
      return  
   }

   Write-Verbose $ConvertFormMsgs.SyntaxVerification 
   $SyntaxErrors=@(Test-PSScript -Filepath $ProjectPaths.Destination -IncludeSummaryReport)
   if ($SyntaxErrors.Count -gt 0)
   { Write-Error -Message ($ConvertFormMsgs.SyntaxError -F $ProjectPaths.Destination) -Category "SyntaxError" -ErrorId "CreateScriptError" -TargetObject  $ProjectPaths.Destination }
     
   If ($noShowDialog -and $HideConsole)
   { Write-Verbose $ConvertFormMsgs.CallShowWindow }
   
   if ($passThru)
   {
     Write-Debug "Emission de l'objet fichier : $($ProjectPaths.Destination)"
     gci $ProjectPaths.Destination
   } 
   Write-Debug ("[{0}] Fin d'analyse du script." -F $MyInvocation.MyCommand)
   Write-Verbose ($ConvertFormMsgs.ConversionComplete-F $ProjectPaths.Source)
  }#process
} #Convert-Form


function Test-PSScript {  
# .ExternalHelp ConvertForm-Help.xml           
  [CmdletBinding()] 
    [OutputType([System.String])] 
 #Valide la syntaxe d'un fichier powershell (ps1,psm1,psd1)
 #From http://blogs.microsoft.co.il/blogs/scriptfanatic/archive/2009/09/07/parsing-powershell-scripts.aspx 
 #$FilePath contient des noms de fichier litt�raux
   param(                                
      [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]  
      [ValidateNotNullOrEmpty()]  
      [Alias('PSPath','FullName')]  
      [System.String[]] $FilePath, 

      [Switch]$IncludeSummaryReport 
   ) 

   begin 
   { $total=$fails=$FileUnknown=0 }   

   process 
   { 
       $FilePath | 
        Foreach-Object { 
           if(Test-Path -LiteralPath $_ -PathType Leaf) 
           { 
              $Path = Convert-Path -LiteralPath $_  
  
              $Errors = $null 
              $Content = Get-Content -LiteralPath $Path  
              $Tokens = [System.Management.Automation.PsParser]::Tokenize($Content,[ref]$Errors) 
              if($Errors -ne $null) 
              { 
                 $fails++ 
                 $Errors | 
                  Foreach-Object {  
                    $CurrentError=$_
                    $CurrentError.Token | 
                     Add-Member -MemberType NoteProperty -Name Path -Value $Path -PassThru | 
                     Add-Member -MemberType NoteProperty -Name ErrorMessage -Value $CurrentError.Message -PassThru 
                 } 
              } 
             $total++
           }#if 
           else 
           { Write-Warning "File unknown :'$_'";$FileUnknown++ } 
       }#for 
   }#process  

   end  
   { 
      if($IncludeSummaryReport)  
      { 
         Write-Verbose "$total script(s) processed, $fails script(s) contain syntax errors,  $FileUnknown file(s) unknown." 
      } 
   } 
}#Test-PSScript

Function OnRemoveConvertForm {
  Remove-Module Transform
}#OnRemovePsIonicZip
 
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = { OnRemoveConvertForm }
Export-ModuleMember -Function Convert-Form,Test-PSScript 